const { Worker } = require('bullmq');
const { connection } = require('../queues/rideTimeoutQueue');
const { Ride, RideRequest, Notification, UserDevice } = require('../models');
const socketProvider = require('../lib/socketProvider');
const Redis = require('ioredis');
const logger = require('../lib/logger');
const metrics = require('../metrics');
const { sendPushToTokens } = require('../lib/fcm');

const redis = new Redis({
  host: process.env.REDIS_HOST || '127.0.0.1',
  port: process.env.REDIS_PORT ? parseInt(process.env.REDIS_PORT) : 6379,
  password: process.env.REDIS_PASSWORD || undefined
});

logger.info('🚀 ride-timeout-worker starting...');

const worker = new Worker(
  'ride-timeout-queue',
  async (job) => {
    logger.info({ jobId: job.id, data: job.data }, 'ride-timeout-worker job received');
    try {
      const { rideId } = job.data;
      const ride = await Ride.findByPk(rideId);
      if (!ride) {
        logger.warn({ rideId }, 'ride not found in timeout worker');
        return;
      }

      if (ride.status !== 'requested') {
        logger.info({ rideId, status: ride.status }, 'ride not in requested status, skipping auto-reject');
        return;
      }

      ride.status = 'auto_rejected';
      await ride.save();

      await RideRequest.update({ timeout: true }, { where: { ride_id: rideId } });

      const passengerMeta = await redis.hgetall(`user:${ride.passenger_id}:meta`);
      const io = socketProvider.getIO();
      if (passengerMeta && passengerMeta.socketId && io) {
        io.to(passengerMeta.socketId).emit('ride:auto_rejected', {
          ride_id: rideId,
          message: 'No drivers accepted your request in time'
        });
        // Also emit status update for frontend controller compatibility
        io.to(passengerMeta.socketId).emit('ride:status_update', {
          ride_id: rideId,
          status: 'auto_rejected'
        });
      }

      try {
        await Notification.create({
          user_id: ride.passenger_id,
          type: 'ride_auto_rejected',
          title: 'Çağrı reddedildi',
          body: 'Maalesef çağrınıza hiç sürücü cevap vermedi.',
          data: { ride_id: rideId },
          is_read: false
        });
      } catch (e) {
        logger.warn({ err: e }, 'Could not persist auto_reject notification');
      }

      // Notify drivers who received the request
      try {
        const requests = await RideRequest.findAll({ where: { ride_id: rideId } });
        for (const req of requests) {
          if (io) {
            io.to(`driver:${req.driver_id}`).emit('request:timeout', {
              ride_id: rideId,
              message: 'Request timed out'
            });
          }
        }
      } catch (e) {
        logger.warn({ err: e }, 'Failed to notify drivers of timeout');
      }

      // NEW: passenger push
      try {
        const devices = await UserDevice.findAll({ where: { user_id: ride.passenger_id } });
        const tokens = devices.map((d) => d.device_token);
        if (tokens.length > 0) {
          await sendPushToTokens(
            tokens,
            {
              title: 'Çağrı reddedildi',
              body: 'Maalesef çağrınıza hiç sürücü cevap vermedi.'
            },
            {
              type: 'ride_auto_rejected',
              ride_id: String(ride.id)
            }
          );
        }
      } catch (e) {
        logger.warn({ err: e.message || e }, 'auto_reject passenger push failed');
      }

      metrics.bullJobProcessed.inc({ queue: 'ride-timeout-queue' });
      logger.info({ rideId }, 'ride auto_rejected processed');
    } catch (err) {
      logger.error({ err, jobId: job.id }, 'ride-timeout-worker processing error');
      metrics.bullJobFailures.inc({ queue: 'ride-timeout-queue' });
      throw err;
    }
  },
  { connection }
);

worker.on('failed', (job, err) => {
  logger.error({ jobId: job.id, err }, 'ride-timeout-worker job failed');
  metrics.bullJobFailures.inc({ queue: 'ride-timeout-queue' });
});

worker.on('completed', (job) => {
  logger.info({ jobId: job.id }, 'ride-timeout-worker job completed');
  metrics.bullJobProcessed.inc({ queue: 'ride-timeout-queue' });
});

module.exports = worker;