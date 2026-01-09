// Socket.IO Main Entry Point - Refactored
const { Server } = require('socket.io');
const Redis = require('ioredis');
const socketProvider = require('../lib/socketProvider');
const authMiddleware = require('./middleware/auth');
const driverHandler = require('./handlers/driverHandler');
const rideHandler = require('./handlers/rideHandler');
const chatHandler = require('./handlers/chatHandler');
const { Driver, Ride } = require('../models');

// Redis for Connection Meta
const redis = new Redis({
  host: process.env.REDIS_HOST || '127.0.0.1',
  port: process.env.REDIS_PORT ? parseInt(process.env.REDIS_PORT) : 6379,
  password: process.env.REDIS_PASSWORD || undefined
});

module.exports = function initSockets(server) {
  const io = new Server(server, {
    cors: { origin: '*' },
    pingInterval: 10000,
    pingTimeout: 5000
  });

  socketProvider.setIO(io);

  // Authentication Middleware
  io.use(authMiddleware);

  io.on('connection', (socket) => {
    const { userId, role } = socket.user;
    console.log(`Socket connected: ${userId} (${role})`);

    // Meta & Join Rooms
    if (userId) {
      redis.hset(`user:${userId}:meta`, 'socketId', socket.id, 'lastSeen', Date.now()).catch(() => { });
      if (role === 'driver') {
        socket.join(`driver:${userId}`);
        redis.hdel(`driver:${userId}:meta`, 'disconnected_ts').catch(() => { });
        redis.hset(`driver:${userId}:meta`, 'socketId', socket.id).catch(() => { });
      }
    }

    // Register Handlers
    driverHandler(io, socket);
    rideHandler(io, socket);
    chatHandler(io, socket);

    // Global Disconnect Logic
    socket.on('disconnect', async () => {
      console.log(`Socket disconnected: ${userId}`);
      if (role === 'driver') {
        try {
          const activeRide = await Ride.findOne({ where: { driver_id: userId, status: ['assigned', 'started'] } });
          if (!activeRide) {
            // Graceful Disconnect
            await redis.hset(`driver:${userId}:meta`, 'socketId', '', 'disconnected_ts', Date.now());
            // cleanupDrivers.js cron will handle the rest
          }
        } catch (e) {
          console.error('Disconnect error', e);
        }
      }
    });
  });

  return io;
};