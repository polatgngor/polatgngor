const Redis = require('ioredis');
const redis = new Redis({
  host: process.env.REDIS_HOST || '127.0.0.1',
  port: process.env.REDIS_PORT ? parseInt(process.env.REDIS_PORT) : 6379,
  password: process.env.REDIS_PASSWORD || undefined
});
const socketProvider = require('../lib/socketProvider');
const { rideTimeoutQueue } = require('../queues/rideTimeoutQueue');
const { User, UserDevice, RideRequest } = require('../models');
const { sendPushToTokens } = require('../lib/fcm');
const { getDriverPrioritySeconds } = require('../services/levelService');

// config
const DEFAULT_RADIUS_KM = 3;
const MAX_CANDIDATES = 10;
const BROADCAST_BATCH = 5;
const ACCEPT_TIMEOUT_SECONDS = parseInt(process.env.RIDE_ACCEPT_TIMEOUT_SECONDS || '20'); // seconds

function geoKeyForVehicle(vt) {
  return `drivers:geo:${vt || 'sari'}`;
}

async function findNearbyDrivers(vehicle_type, lat, lng, radiusKm = DEFAULT_RADIUS_KM, limit = MAX_CANDIDATES) {
  const key = geoKeyForVehicle(vehicle_type);
  // console.log(`[findNearbyDrivers] searching key:${key} lat:${lat} lng:${lng} radius:${radiusKm} limit:${limit}`);

  const raw = await redis.georadius(key, lng, lat, radiusKm, 'km', 'WITHDIST', 'ASC', 'COUNT', limit);
  if (!raw) return [];
  return raw.map((item) => {
    if (Array.isArray(item) && item.length > 0) {
      return String(item[0]);
    }
    return String(item);
  });
}

// Helper: Determine region from coordinates (approximate)
function getRegion(lat, lng) {
  // Istanbul longitude split approx 29.0
  // < 29.0 => Avrupa
  // >= 29.0 => Anadolu
  if (!lng) return null;
  return lng < 29.0 ? 'Avrupa' : 'Anadolu';
}

/**
 * Emit ride request to provided drivers (driverIds order assumed).
 * Also schedules the single timeout job (no second wave).
 * Returns array of driverIds that were actually sent to.
 *
 * Passenger tarafında radius level'e göre ayarlanıyor,
 * burada da sürücü level'ına göre çağrı düşme zamanı ayarlanıyor:
 *   platinum  -> 0 sn
 *   gold      -> 1 sn
 *   silver    -> 2 sn
 *   standard  -> 3 sn
 * 
 * NEW: Return Home Priority (Dönüş Önceliği)
 * If current time is 06:00-09:00 or 17:00-21:00
 * AND driver is in Opposite Region (e.g. Anadolu driver in Avrupa)
 * AND ride destination is Driver's Home Region (e.g. going to Anadolu)
 * THEN prioritySeconds = 0 (ignore level)
 */
async function emitRideRequest(ride, opts = {}) {
  const vehicle_type = ride.vehicle_type;
  const lat = opts.startLat;
  const lng = opts.startLng;
  const passenger_info = opts.passenger_info || {};
  const radiusKm = opts.radiusKm || DEFAULT_RADIUS_KM;

  // New: Calculate Absolute Expiry Time
  const nowTs = Date.now();
  const timeoutMs = Math.max(1000, ACCEPT_TIMEOUT_SECONDS * 1000);
  const expiresAt = nowTs + timeoutMs;

  const io = socketProvider.getIO();
  const sentDrivers = new Set(); // Track unique drivers sent to

  // Initial candidate list passed in?
  if (opts.driverIds && opts.driverIds.length > 0) {
    opts.driverIds.forEach(id => sentDrivers.add(String(id)));
  }

  const payloadBase = {
    ride_id: ride.id,
    start: { lat: ride.start_lat, lng: ride.start_lng, address: ride.start_address },
    end: { lat: ride.end_lat, lng: ride.end_lng, address: ride.end_address },
    vehicle_type: vehicle_type,
    options: ride.options || {},
    fare_estimate: ride.fare_estimate || null,
    passenger: passenger_info,
    distance: opts.distanceMeters,
    duration: opts.durationSeconds,
    polyline: opts.polyline,
    payment_method: ride.payment_method,
    expires_at: expiresAt // SYNC FIX: Send absolute timeout
  };

  // Determine Ride Destination Region (for priority)
  const rideDestRegion = getRegion(ride.end_lat, ride.end_lng);
  // Check Time Window for Priority
  const hour = new Date().getHours();
  const isPeakHour = (hour >= 6 && hour < 9) || (hour >= 17 && hour < 21);

  // We need Driver table for working_region
  const { Driver } = require('../models');

  // --- MATCHING LOOP FUNCTION ---
  const attemptMatch = async (isFirstRun = false) => {
    // If timeout passed, stop
    if (Date.now() >= expiresAt) return;

    // 1. Find nearby drivers
    // Note: We search again to find NEW drivers who came online/entered zone
    const nearby = await findNearbyDrivers(vehicle_type, lat, lng, radiusKm, MAX_CANDIDATES);

    // Filter out already sent
    const newCandidates = nearby.filter(id => !sentDrivers.has(String(id)));

    if (newCandidates.length === 0) {
      if (isFirstRun) console.log(`[matchService] ride ${ride.id} - no drivers found in first run`);
      return;
    }

    // 2. Prepare Drivers with Level/Priority
    const users = await User.findAll({
      where: { id: newCandidates },
      attributes: ['id', 'level']
    });

    const driversDetails = await Driver.findAll({
      where: { user_id: newCandidates },
      attributes: ['user_id', 'working_region']
    });

    const levelMap = new Map();
    for (const u of users) levelMap.set(String(u.id), u.level || 'standard');

    const regionMap = new Map();
    for (const d of driversDetails) regionMap.set(String(d.user_id), d.working_region);

    const driversWithLevel = newCandidates.map((driverId) => {
      const level = levelMap.get(String(driverId)) || 'standard';
      let prioritySeconds = getDriverPrioritySeconds(level);

      // PRIORITY LOGIC
      if (isPeakHour && rideDestRegion) {
        const driverHomeRegion = regionMap.get(String(driverId));
        const driverCurrentRegion = getRegion(lat, lng); // Assume driver near start
        if (driverHomeRegion && driverCurrentRegion && driverHomeRegion !== driverCurrentRegion) {
          if (rideDestRegion === driverHomeRegion) {
            prioritySeconds = 0;
            console.log(`[matchService] Driver ${driverId} (Home Priority) -> 0s`);
          }
        }
      }

      console.log(`[matchService] Driver ${driverId} Level: ${level} Priority: ${prioritySeconds}s`);
      return { driverId: String(driverId), level, prioritySeconds };
    });

    // Sort by priority
    driversWithLevel.sort((a, b) => a.prioritySeconds - b.prioritySeconds);

    // 2b. Batch Fetch Devices for Push Notifications (N+1 Fix)
    const allDevices = await UserDevice.findAll({
      where: { user_id: newCandidates },
      attributes: ['user_id', 'device_token']
    });

    // Group tokens by user_id
    const deviceMap = new Map();
    for (const d of allDevices) {
      if (!deviceMap.has(String(d.user_id))) {
        deviceMap.set(String(d.user_id), []);
      }
      deviceMap.get(String(d.user_id)).push(d.device_token);
    }

    // 3. Process Batch
    let count = 0;
    for (const d of driversWithLevel) {
      if (count >= BROADCAST_BATCH) break; // Throttle per tick if needed

      const { driverId, prioritySeconds } = d;
      const meta = await redis.hgetall(`driver:${driverId}:meta`);

      if (!meta || !meta.available || meta.available !== '1') {
        continue;
      }

      const socketId = meta.socketId;
      const delayMs = prioritySeconds * 1000;

      setTimeout(async () => {
        // Double check availability key (unlocked?)
        try {
          // Fix: Broadcast to driver specific room (handles both UI and Background Service)
          if (io && io.to) {
            const room = `driver:${driverId}`;
            console.log(`[matchService] emitting request:incoming to ROOM ${room} (Discovery)`);
            io.to(room).emit('request:incoming', {
              ...payloadBase,
              sent_at: Date.now()
            });
          }

          // Send Push (using pre-fetched tokens)
          const tokens = deviceMap.get(String(driverId));
          if (tokens && tokens.length > 0) {
            // Fire and forget push - SILENT (Null notification) for "Zınk" without Banner
            sendPushToTokens(tokens, null, { type: 'request_incoming', ride_id: String(ride.id), vehicle_type: vehicle_type }).catch(() => { });
          }
        } catch (err) {
          console.warn('[matchService] emit failed', driverId, err);
        }
      }, delayMs);

      // Mark as sent
      sentDrivers.add(driverId);

      // Fire and forget DB log
      RideRequest.create({
        ride_id: ride.id,
        driver_id: driverId,
        sent_at: new Date(),
        driver_response: 'no_response',
        timeout: false
      }).catch(() => { });

      count++;
    }
  };

  // --- START EXECUTION ---

  // 1. Initial Attempt
  await attemptMatch(true);

  // 2. Loop Interval (Every 5 seconds check for new drivers)
  const DISCOVERY_INTERVAL_MS = 5000;
  const intervalId = setInterval(async () => {
    const remaining = expiresAt - Date.now();
    if (remaining <= 500) { // Buffer
      clearInterval(intervalId);
      return;
    }
    await attemptMatch(false);
  }, DISCOVERY_INTERVAL_MS);

  // Ensure interval clears after timeout
  setTimeout(() => clearInterval(intervalId), timeoutMs);

  // Schedule Backend Timeout Logic (Status Update)
  const jobId = `ride_timeout_${ride.id}`;
  try {
    await rideTimeoutQueue.add(
      'ride-timeout',
      { rideId: ride.id },
      {
        jobId,
        delay: timeoutMs,
        removeOnComplete: true,
        removeOnFail: true
      }
    );
    console.log(`[matchService] ride ${ride.id} scheduled timeout job ${jobId} delayMs=${timeoutMs}`);
  } catch (e) {
    console.warn('[matchService] job failed', e);
  }

  return Array.from(sentDrivers);
}

module.exports = { findNearbyDrivers, emitRideRequest };
