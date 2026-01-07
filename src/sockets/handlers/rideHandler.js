const { Ride, RideRequest, User, Driver, Rating, Wallet, WalletTransaction, UserDevice } = require('../../models');
const { assignRideAtomic } = require('../../services/assignService');
const { sendPushToTokens } = require('../../lib/fcm');
const socketProvider = require('../../lib/socketProvider');
const Redis = require('ioredis');

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

    // -------------------------
    // PASSENGER REJOIN
    // -------------------------
    socket.on('passenger:rejoin', async (payload) => {
        try {
            if (role !== 'passenger') return;
            const ride = await Ride.findOne({
                where: { passenger_id: userId, status: ['assigned', 'started'] }
            });
            if (ride) {
                const room = `ride:${ride.id}`;
                socket.join(room);
                console.log(`Passenger ${userId} rejoined room ${room}`);
            }
        } catch (err) {
            console.error('passenger:rejoin err', err);
        }
    });

    // -------------------------
    // DRIVER: ACCEPT REQUEST
    // -------------------------
    socket.on('driver:accept_request', async (payload) => {
        try {
            if (role !== 'driver') return socket.emit('request:accept_failed', { ride_id: payload.ride_id, reason: 'forbidden' });

            const rideId = payload.ride_id;
            const driverId = userId;
            const result = await assignRideAtomic(rideId, driverId);
            if (!result.success) return socket.emit('request:accept_failed', { ride_id: rideId, reason: result.error });

            const ride = result.ride;
            const driverDetails = await Driver.findOne({ where: { user_id: driverId } });
            const driverUser = await User.findByPk(driverId);

            const driverRatings = await Rating.findAll({ where: { rated_id: driverId } });
            let driverRatingAvg = 5.0;
            if (driverRatings.length > 0) {
                driverRatingAvg = driverRatings.reduce((a, b) => a + b.stars, 0) / driverRatings.length;
            }

            const driverInfo = {
                id: driverId,
                first_name: driverUser.first_name,
                last_name: driverUser.last_name,
                phone: driverUser.phone,
                profile_picture: driverUser.profile_picture,
                profile_photo: driverUser.profile_picture, // Backward compatibility
                rating: parseFloat(driverRatingAvg.toFixed(1)),
                vehicle: {
                    plate: driverDetails ? driverDetails.vehicle_plate : '',
                    type: driverDetails ? driverDetails.vehicle_type : 'sari'
                }
            };

            const room = `ride:${ride.id}`;
            socket.join(room);

            // Notify passenger
            const passengerMeta = await redis.hgetall(`user:${ride.passenger_id}:meta`);
            if (passengerMeta && passengerMeta.socketId) {
                io.to(passengerMeta.socketId).emit('ride:assigned', {
                    ride_id: ride.id,
                    driver: driverInfo,
                    code4: ride.code4,
                    eta: null
                });
                // Passenger joins room
                const ps = io.sockets.sockets.get(passengerMeta.socketId);
                if (ps) ps.join(room);
            }

            // FCM
            try {
                const { censorName } = require('../../utils/formatters');
                const devices = await UserDevice.findAll({ where: { user_id: ride.passenger_id } });
                const tokens = devices.map(d => d.device_token);
                if (tokens.length > 0) {
                    const censoredDriverName = censorName(driverInfo.first_name, driverInfo.last_name);
                    await sendPushToTokens(tokens, { title: 'Sürücü yola çıktı', body: `${censoredDriverName} kabul etti.` }, { type: 'ride_assigned', ride_id: String(ride.id) });
                }
            } catch (e) { }

            // Confirm to driver
            const passengerUser = await User.findByPk(ride.passenger_id);
            socket.emit('request:accepted_confirm', {
                ride_id: rideId,
                assigned: true,
                passenger: { id: ride.passenger_id, first_name: passengerUser.first_name, last_name: passengerUser.last_name, phone: passengerUser.phone, profile_picture: passengerUser.profile_picture, profile_photo: passengerUser.profile_picture }
            });

        } catch (err) {
            console.error('accept_request error', err);
            socket.emit('request:accept_failed', { ride_id: payload && payload.ride_id, reason: 'server_error' });
        }
    });

    // -------------------------
    // DRIVER: REJECT REQUEST
    // -------------------------
    socket.on('driver:reject_request', async (payload) => {
        try {
            if (role !== 'driver') return;
            const { ride_id } = payload;
            await RideRequest.update({ driver_response: 'rejected', response_at: new Date() }, { where: { ride_id, driver_id: userId } });
            socket.emit('request:rejected_confirm', { ride_id });
        } catch (e) { }
    });

    // -------------------------
    // DRIVER: START RIDE
    // -------------------------
    socket.on('driver:start_ride', async (payload) => {
        try {
            if (role !== 'driver') return;
            const { ride_id, code } = payload;
            const ride = await Ride.findByPk(ride_id);
            if (!ride || String(ride.code4) !== String(code) || ride.status !== 'assigned') {
                return socket.emit('start_ride_failed', { ride_id, reason: 'invalid' });
            }

            ride.status = 'started';
            await ride.save();

            io.to(`ride:${ride.id}`).emit('ride:started', { ride_id: ride.id });

            // FCM
            try {
                const devices = await UserDevice.findAll({ where: { user_id: ride.passenger_id } });
                const tokens = devices.map(d => d.device_token);
                if (tokens.length) await sendPushToTokens(tokens, { title: 'Yolculuk Başladı', body: 'İyi yolculuklar!' }, { type: 'ride_started', ride_id: String(ride.id) });
            } catch (e) { }

            socket.emit('start_ride_ok', { ride_id: ride.id });
        } catch (e) {
            socket.emit('start_ride_failed', { reason: 'server_error' });
        }
    });

    // -------------------------
    // DRIVER: END RIDE
    // -------------------------
    socket.on('driver:end_ride', async (payload) => {
        try {
            if (role !== 'driver') return;
            const { ride_id, fare_actual } = payload;
            const ride = await Ride.findByPk(ride_id);

            if (!ride || ride.status !== 'started') return socket.emit('end_ride_failed', { ride_id, reason: 'invalid' });

            ride.status = 'completed';
            ride.fare_actual = fare_actual;

            // Validate Fare
            const estimate = parseFloat(ride.fare_estimate);
            const actual = parseFloat(fare_actual);

            if (!isNaN(estimate) && estimate > 0) {
                const minFare = estimate * 0.90;
                const maxFare = estimate * 1.25;

                if (actual < minFare || actual > maxFare) {
                    return socket.emit('end_ride_failed', {
                        ride_id,
                        reason: 'fare_out_of_range',
                        message: `Tutar tahmini tutardan (${estimate} TL) çok farklı olamaz. (${minFare.toFixed(2)} - ${maxFare.toFixed(2)} TL arası)`
                    });
                }
            } else {
                // Fallback validation if no estimate
                if (actual < 175 || actual > 50000) {
                    return socket.emit('end_ride_failed', { ride_id, reason: 'fare_out_of_range' });
                }
            }

            // Persist route
            try {
                const rawPoints = await redis.lrange(`ride:${ride.id}:route`, 0, -1);
                if (rawPoints.length) ride.actual_route = rawPoints.map(p => JSON.parse(p));
                await redis.del(`ride:${ride.id}:route`);
            } catch (e) { }

            await ride.save();

            // Wallet Logic
            let wallet = await Wallet.findOne({ where: { user_id: userId } });
            if (!wallet) wallet = await Wallet.create({ user_id: userId, balance: 0 });
            const fare = parseFloat(fare_actual);
            await wallet.update({ balance: parseFloat(wallet.balance) + fare, total_earnings: parseFloat(wallet.total_earnings || 0) + fare });
            await WalletTransaction.create({ wallet_id: wallet.id, amount: fare, type: 'ride_earnings', reference_id: ride.id, description: `Ride #${ride.id}` });

            // Restore Availability
            await Driver.update({ is_available: true }, { where: { user_id: userId } });
            await redis.hset(`driver:${userId}:meta`, 'available', '1');
            const meta = await redis.hgetall(`driver:${userId}:meta`);
            if (meta.lat && meta.lng) {
                await redis.geoadd(geoKeyForVehicle(meta.vehicle_type || 'sari'), meta.lng, meta.lat, String(userId));
            }

            io.to(`ride:${ride.id}`).emit('ride:completed', { ride_id: ride.id, fare_actual });
            socket.leave(`ride:${ride.id}`);
            socket.emit('end_ride_ok', { ride_id });

        } catch (e) {
            socket.emit('end_ride_failed', { reason: 'server_error' });
        }
    });

    // -------------------------
    // DRIVER: CANCEL RIDE
    // -------------------------
    socket.on('driver:cancel_ride', async (payload) => {
        // Simplification for brevity - logic mimics index.js
        try {
            if (role !== 'driver') return;
            const { ride_id, reason } = payload;
            const ride = await Ride.findByPk(ride_id);
            if (!ride) return;

            await ride.update({ status: 'cancelled', cancelled_by: 'driver', cancellation_reason: reason });

            const passengerMeta = await redis.hgetall(`user:${ride.passenger_id}:meta`);
            if (passengerMeta && passengerMeta.socketId) {
                io.to(passengerMeta.socketId).emit('ride:cancelled', { ride_id, reason });
            }

            // Restore Avail
            await Driver.update({ is_available: true }, { where: { user_id: userId } });
            await redis.hset(`driver:${userId}:meta`, 'available', '1');
            const meta = await redis.hgetall(`driver:${userId}:meta`);
            if (meta.lat) await redis.geoadd(geoKeyForVehicle(meta.vehicle_type || 'sari'), meta.lng, meta.lat, String(userId));

            socket.leave(`ride:${ride.id}`);
            socket.emit('cancel_ride_ok', { ride_id });
        } catch (e) { }
    });

};
