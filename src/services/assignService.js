const Redis = require('ioredis');
const { sequelize, Ride, RideRequest, Notification, User, UserDevice } = require('../models');
const { rideTimeoutQueue } = require('../queues/rideTimeoutQueue');
const socketProvider = require('../lib/socketProvider');
const { sendPushToTokens } = require('../lib/fcm');

const redis = new Redis({
  host: process.env.REDIS_HOST || '127.0.0.1',
  port: process.env.REDIS_PORT ? parseInt(process.env.REDIS_PORT) : 6379,
  password: process.env.REDIS_PASSWORD || undefined
});

const LOCK_TTL_MS = 30 * 1000; // 30s lock (should be >= accept timeout)

/**
 * Try to atomically assign ride to driver.
 * Returns { success: boolean, reason?:string, ride?:Ride }
 */
async function assignRideAtomic(rideId, driverId) {
  const lockKey = `ride:lock:${rideId}`;
  const lockVal = String(driverId);

  // try to set lock NX PX
  const lockSet = await redis.set(lockKey, lockVal, 'NX', 'PX', LOCK_TTL_MS);
  if (!lockSet) {
    return { success: false, reason: 'lock_not_acquired' };
  }

  // Begin DB transaction
  const t = await sequelize.transaction();
  try {
    // reload ride with lock
    const ride = await Ride.findOne({
      where: { id: rideId },
      transaction: t,
      lock: t.LOCK.UPDATE
    });

    if (!ride) {
      await t.rollback();
      await redis.del(lockKey);
      return { success: false, reason: 'ride_not_found' };
    }

    if (ride.status !== 'requested') {
      await t.rollback();
      await redis.del(lockKey);
      return { success: false, reason: `invalid_status_${ride.status}` };
    }

    // assign
    ride.driver_id = driverId;
    ride.status = 'assigned';
    await ride.save({ transaction: t });

    // Fetch driver details for vehicle type and to update availability
    const { Driver } = require('../models');
    const driverRecord = await Driver.findOne({ where: { user_id: driverId }, transaction: t });

    // Mark driver as busy (is_available = false)
    if (driverRecord) {
      await Driver.update(
        { is_available: false },
        { where: { user_id: driverId }, transaction: t }
      );
    }

    // update ride_request entry for this driver as accepted
    await RideRequest.update(
      { driver_response: 'accepted', response_at: new Date() },
      { where: { ride_id: rideId, driver_id: driverId }, transaction: t }
    );

    await t.commit();

    // --- Update Redis Availability & Method ---
    try {
      await redis.hset(`driver:${driverId}:meta`, 'available', '0');
      // Notify other candidates that ride is taken
      (async () => {
        try {
          // Find waiting drivers
          const { RideRequest } = require('../models');
          const others = await RideRequest.findAll({
            where: {
              ride_id: rideId,
              driver_id: { [require('sequelize').Op.ne]: driverId },
              driver_response: 'no_response'
            }
          });

          if (others.length > 0) {
            const io = socketProvider.getIO();
            if (io) {
              for (const req of others) {
                // Use ROOM broadcasting which is more reliable than redis socketId fetch
                io.to(`driver:${req.driver_id}`).emit('request:taken', { ride_id: rideId });
              }
            }
          }
        } catch (e) { console.warn('Notify others failed', e); }
      })();

      // Remove from GEO
      if (driverRecord) {
        const vt = driverRecord.vehicle_type || 'sari';
        const geoKey = `drivers:geo:${vt}`;
        await redis.zrem(geoKey, String(driverId));
      }
    } catch (redisErr) {
      console.warn('Could not update Redis availability for driver', driverId, redisErr);
    }
    // ------------------------------------------

    // remove timeout job if present
    const jobId = `ride_timeout_${rideId}`;
    try {
      await rideTimeoutQueue.remove(jobId);
    } catch (e) {
      // ignore if removal fails or job already processed
      console.warn('Could not remove timeout job', jobId, e.message || e);
    }

    // join passenger and driver sockets to a room so they can share updates/chat
    try {
      const io = socketProvider.getIO();
      if (io) {
        const passengerMeta = await redis.hgetall(`user:${ride.passenger_id}:meta`);
        const driverMeta = await redis.hgetall(`driver:${driverId}:meta`);
        const passengerSocketId = passengerMeta && passengerMeta.socketId ? passengerMeta.socketId : null;
        const driverSocketId = driverMeta && driverMeta.socketId ? driverMeta.socketId : null;
        const room = `ride:${rideId}`;

        if (passengerSocketId) {
          const passengerSocket = io.sockets.sockets.get(passengerSocketId);
          if (passengerSocket) passengerSocket.join(room);
        }
        if (driverSocketId) {
          const driverSocket = io.sockets.sockets.get(driverSocketId);
          if (driverSocket) driverSocket.join(room);
        }

        // Emit a short room event so both clients can listen if they choose
        try {
          io.to(room).emit('ride:room_joined', { ride_id: rideId });
        } catch (e) {
          // ignore
        }
      }
    } catch (e) {
      console.warn('Could not join sockets to ride room', e.message || e);
    }

    // Create notifications for passenger and driver (non-blocking)
    try {
      // passenger notification
      await Notification.create({
        user_id: ride.passenger_id,
        type: 'ride_assigned',
        title: 'Sürücü atandı',
        body: `Sürücünüz atandı (ID: ${driverId}).`,
        data: { ride_id: ride.id, driver_id: driverId },
        is_read: false
      });
    } catch (e) {
      console.warn('Could not create passenger notification for ride assigned', e.message || e);
    }

    try {
      // driver notification (optional: inform driver that assignment confirmed)
      await Notification.create({
        user_id: driverId,
        type: 'ride_assigned_driver',
        title: 'Yolculuk atandı',
        body: `Yolculuk atandı (ride: ${ride.id}).`,
        data: { ride_id: ride.id, passenger_id: ride.passenger_id },
        is_read: false
      });
    } catch (e) {
      console.warn('Could not create driver notification for ride assigned', e.message || e);
    }

    // passenger push
    try {
      const passengerId = ride.passenger_id;
      const devices = await UserDevice.findAll({ where: { user_id: passengerId } });
      const tokens = devices.map((d) => d.device_token);
      if (tokens.length > 0) {
        await sendPushToTokens(
          tokens,
          {
            title: 'Sürücü atandı',
            body: 'Taksi çağrınıza bir sürücü atandı.'
          },
          {
            type: 'ride_assigned',
            ride_id: String(ride.id),
            driver_id: String(driverId)
          }
        );
      }
    } catch (e) {
      console.warn('assignRideAtomic passenger push failed', e.message || e);
    }

    // driver push
    try {
      const devices = await UserDevice.findAll({ where: { user_id: driverId } });
      const tokens = devices.map((d) => d.device_token);
      if (tokens.length > 0) {
        await sendPushToTokens(
          tokens,
          {
            title: 'Yolculuk atandı',
            body: 'Size yeni bir yolculuk atandı.'
          },
          {
            type: 'ride_assigned_driver',
            ride_id: String(rideId),
            passenger_id: String(ride.passenger_id)
          }
        );
      }
    } catch (e) {
      console.warn('assignRideAtomic driver push failed', e.message || e);
    }

    // delete lock
    await redis.del(lockKey);

    return { success: true, ride };
  } catch (err) {
    await t.rollback();
    await redis.del(lockKey);
    console.error('assignRideAtomic error', err);
    return { success: false, reason: 'exception', error: err.message };
  }
}

module.exports = { assignRideAtomic };