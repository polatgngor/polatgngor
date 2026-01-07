const { Driver, Ride, RideRequest, User, UserDevice } = require('../../models');
const { Op } = require('sequelize');
const Redis = require('ioredis');
const socketProvider = require('../../lib/socketProvider');

const redis = new Redis({
    host: process.env.REDIS_HOST || '127.0.0.1',
    port: process.env.REDIS_PORT ? parseInt(process.env.REDIS_PORT) : 6379,
    password: process.env.REDIS_PASSWORD || undefined
});

function geoKeyForVehicle(vehicleType) {
    return `drivers:geo:${vehicleType}`;
}

module.exports = (io, socket) => {
    const { userId, role } = socket.user;

    // 1. Set Availability
    socket.on('driver:set_availability', async (payload) => {
        try {
            if (role !== 'driver') return;
            const { available, lat, lng, vehicle_type } = payload;
            const isAvailable = available === true || available === 'true';

            const currentDriver = await Driver.findOne({ where: { user_id: userId } });
            if (!currentDriver) return;

            if (isAvailable) {
                const activeDriverWithSamePlate = await Driver.findOne({
                    where: {
                        vehicle_plate: currentDriver.vehicle_plate,
                        is_available: true,
                        user_id: { [Op.ne]: userId }
                    }
                });

                if (activeDriverWithSamePlate) {
                    return socket.emit('driver:availability_error', {
                        message: `Bu plakada (${currentDriver.vehicle_plate}) şu an başka bir sürücü aktif. Lütfen diğer sürücünün çıkış yapmasını bekleyin.`
                    });
                }
            }

            await Promise.all([
                Driver.update({ is_available: isAvailable }, { where: { user_id: userId } }),
                (async () => {
                    await redis.hset(`driver:${userId}:meta`, 'available', isAvailable ? '1' : '0');
                    await redis.hdel(`driver:${userId}:meta`, 'disconnected_ts');
                    await redis.hset(`driver:${userId}:meta`, 'socketId', socket.id);
                    if (vehicle_type) {
                        await redis.hset(`driver:${userId}:meta`, 'vehicle_type', vehicle_type);
                    }
                })(),
                (async () => {
                    if (isAvailable && lat && lng) {
                        const vType = vehicle_type || 'sari';
                        const key = geoKeyForVehicle(vType);
                        await redis.geoadd(key, lng, lat, String(userId));
                        await redis.hset(`driver:${userId}:meta`, 'last_loc_update', Date.now());
                    } else if (!isAvailable) {
                        const types = ['sari', 'turkuaz', 'siyah', '8+1'];
                        for (const t of types) {
                            await redis.zrem(geoKeyForVehicle(t), String(userId));
                        }
                    }
                })()
            ]);

            socket.emit('driver:availability_updated', { available: isAvailable });
        } catch (err) {
            console.error('driver:set_availability err', err);
            socket.emit('driver:availability_error', { message: 'Sunucu hatası oluştu.' });
        }
    });

    // 2. Update Location
    socket.on('driver:update_location', async (payload) => {
        try {
            if (role !== 'driver') return;
            const { lat, lng, vehicle_type } = payload;
            const key = geoKeyForVehicle(vehicle_type || 'sari');

            Promise.all([
                redis.geoadd(key, lng, lat, String(userId)),
                redis.hset(`driver:${userId}:meta`, 'last_loc_update', Date.now(), 'lat', lat, 'lng', lng)
            ]).catch(e => { });

            const rooms = Array.from(socket.rooms);
            for (const r of rooms) {
                if (r.startsWith('ride:')) {
                    const rideId = r.split(':')[1];
                    const point = JSON.stringify({ lat, lng, ts: Date.now() });
                    redis.rpush(`ride:${rideId}:route`, point).catch(e => { });
                    redis.expire(`ride:${rideId}:route`, 24 * 60 * 60).catch(e => { });

                    const ioInstance = socketProvider.getIO();
                    if (ioInstance) {
                        ioInstance.to(r).emit('ride:update_location', { driver_id: userId, lat, lng, ts: Date.now() });

                        // Arrival Check (User Request: "25 metreye gelince bildirim")
                        (async () => {
                            try {
                                const notifiedKey = `ride:${rideId}:arrived_notified`;
                                const isNotified = await redis.get(notifiedKey);

                                // DEBUG LOGS
                                // console.log(`[ArrivalCheck] Ride: ${rideId}, Checking distance... IsNotified: ${isNotified}`);

                                if (!isNotified) {
                                    // Fetch ride details (lightweight)
                                    const ride = await Ride.findByPk(rideId, { attributes: ['id', 'status', 'start_lat', 'start_lng', 'passenger_id'] });

                                    if (ride && ride.status === 'assigned') {
                                        // Calculate Distance (Haversine)
                                        const R = 6371e3; // metres
                                        const φ1 = lat * Math.PI / 180;
                                        const φ2 = ride.start_lat * Math.PI / 180;
                                        const Δφ = (ride.start_lat - lat) * Math.PI / 180;
                                        const Δλ = (ride.start_lng - lng) * Math.PI / 180;

                                        const a = Math.sin(Δφ / 2) * Math.sin(Δφ / 2) +
                                            Math.cos(φ1) * Math.cos(φ2) *
                                            Math.sin(Δλ / 2) * Math.sin(Δλ / 2);
                                        const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
                                        const dist = R * c; // in meters

                                        console.log(`[ArrivalCheck] Ride: ${rideId}, Distance: ${dist.toFixed(2)}m, Threshold: 50m`);

                                        if (dist < 50) {
                                            console.log(`[ArrivalCheck] Threshold reached! Sending notifications.`);
                                            await redis.set(notifiedKey, '1', 'EX', 3600); // Set flag

                                            // Emit socket event
                                            ioInstance.to(r).emit('ride:driver_arrived', { ride_id: ride.id });

                                            // Send Push
                                            const { sendPushToTokens } = require('../../lib/fcm');
                                            const devices = await UserDevice.findAll({ where: { user_id: ride.passenger_id } });
                                            const tokens = devices.map(d => d.device_token);
                                            console.log(`[ArrivalCheck] Sending Push to ${tokens.length} devices.`);

                                            if (tokens.length) {
                                                await sendPushToTokens(
                                                    tokens,
                                                    { title: 'Sürücü Geldi', body: 'Taksiniz konumunuza ulaştı.' },
                                                    { type: 'driver_arrived', ride_id: String(ride.id) }
                                                );
                                            }
                                        }
                                    } else {
                                        // console.log(`[ArrivalCheck] Ride invalid or status not assigned: ${ride ? ride.status : 'null'}`);
                                    }
                                }
                            } catch (e) {
                                console.error('Arrival check error', e);
                            }
                        })();
                    }
                }
            }
        } catch (err) {
            console.error('driver:update_location err', err);
        }
    });

    // 3. Rejoin
    socket.on('driver:rejoin', async () => {
        try {
            if (role !== 'driver') return;

            // Self-healing: Ensure joined to room and redis updated
            socket.join(`driver:${userId}`);
            await redis.hset(`driver:${userId}:meta`, 'socketId', socket.id);


            // A. Check for ACTIVE Ride
            const activeRide = await Ride.findOne({
                where: {
                    driver_id: userId,
                    status: { [Op.in]: ['accepted', 'driver_arrived', 'started'] }
                },
                include: [
                    { model: User, as: 'passenger', attributes: ['id', 'first_name', 'last_name', 'phone', 'profile_picture'] }
                ]
            });

            if (activeRide) {
                const rideJSON = activeRide.toJSON();
                // Backward Compatibility
                if (rideJSON.passenger) rideJSON.passenger.profile_photo = rideJSON.passenger.profile_picture;
                socket.emit('ride:rejoined', rideJSON);
                socket.join(`ride:${activeRide.id}`);
                return;
            }

            // B. Check for PENDING Requested Ride
            const pendingRequest = await RideRequest.findOne({
                where: { driver_id: userId, driver_response: 'no_response', timeout: false },
                order: [['sent_at', 'DESC']]
            });

            if (pendingRequest) {
                const parentRide = await Ride.findOne({
                    where: { id: pendingRequest.ride_id, status: 'searching' },
                    include: [
                        { model: User, as: 'passenger', attributes: ['id', 'first_name', 'last_name', 'phone', 'profile_picture'] }
                    ]
                });

                if (parentRide) {
                    const RIDE_ACCEPT_TIMEOUT = parseInt(process.env.RIDE_ACCEPT_TIMEOUT_SECONDS || 30) * 1000;
                    const sentTime = pendingRequest.sent_at ? new Date(pendingRequest.sent_at).getTime() : Date.now();
                    const passed = Date.now() - sentTime;

                    if (passed < RIDE_ACCEPT_TIMEOUT) {
                        const payload = {
                            ride_id: parentRide.id,
                            pickup: { lat: parentRide.start_lat, lng: parentRide.start_lng, address: parentRide.start_address },
                            destination: { lat: parentRide.end_lat, lng: parentRide.end_lng, address: parentRide.end_address },
                            passenger: parentRide.passenger,
                            fare: parentRide.fare_estimate,
                            // distance_km and duration_mins not directly in model, check if computed or missing. using defaults or null.
                            distance_km: null, // parentRide.estimated_distance_km doesn't exist on model
                            duration_mins: null, // parentRide.estimated_duration_min doesn't exist on model
                            // duration_mins: parentRide.estimated_duration_min,
                            payment_method: parentRide.payment_method || 'cash',
                            sent_at: sentTime,
                            timeout_seconds: (RIDE_ACCEPT_TIMEOUT - passed) / 1000
                        };
                        socket.emit('request:incoming', payload);
                    }
                }
            }
        } catch (err) {
            console.error('driver:rejoin err', err);
        }
    });
};
