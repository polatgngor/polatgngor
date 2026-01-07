require('dotenv').config();
const http = require('http');
const app = require('./src/app');
const { sequelize } = require('./src/models');
const initSockets = require('./src/sockets');
const logger = require('./src/lib/logger');
const { rideTimeoutQueue } = require('./src/queues/rideTimeoutQueue');
const metrics = require('./src/metrics');
const Redis = require('ioredis');

// start worker (side-effect require)
require('./src/workers/rideTimeoutWorker');
const cleanupStaleDrivers = require('./src/cron/cleanupDrivers');


const PORT = process.env.PORT || 3000;
const server = http.createServer(app);

const redis = new Redis({
  host: process.env.REDIS_HOST || '127.0.0.1',
  port: process.env.REDIS_PORT ? parseInt(process.env.REDIS_PORT) : 6379,
  password: process.env.REDIS_PASSWORD || undefined
});

async function start() {
  try {
    await sequelize.authenticate();
    logger.info('✅ MySQL connected (Sequelize).');
    await sequelize.sync({ alter: true });
    logger.info('✅ Sequelize models synced.');

    // Init Socket.IO (attaches to server)
    initSockets(server);

    // Init FCM (Fail Fast Check)
    const { initFirebase } = require('./src/lib/fcm');
    initFirebase();

    // Init Background Jobs
    require('./src/startup/initCron')();
    require('./src/startup/initWorkers')();

    server.listen(PORT, () => {
      logger.info(`🚀 Server listening on http://localhost:${PORT}`);
    });

    // Periodic health/queue polling for metrics
    setInterval(async () => {
      try {
        const { connection } = require('./src/queues/rideTimeoutQueue'); // lazy load
        const jobs = await connection.getJobCountByTypes('wait', 'active', 'completed', 'failed');
        // Update prometheus metric here if needed (currently separate in metrics.js)
      } catch (e) {
        // ignore
      }

      try {
        // redis connectivity
        const pong = await redis.ping();
        metrics.redisUp.set(pong === 'PONG' ? 1 : 0);
      } catch (e) {
        metrics.redisUp.set(0);
        logger.error({ err: e }, 'Redis health check failed');
      }

      try {
        // db connectivity
        await sequelize.authenticate();
        metrics.dbUp.set(1);
      } catch (e) {
        metrics.dbUp.set(0);
        logger.error({ err: e }, 'DB health check failed');
      }
    }, parseInt(process.env.METRICS_POLL_INTERVAL_MS || '5000', 10));

    // Cleanup Job (Every 1 minute)
    setInterval(() => {
      cleanupStaleDrivers();
    }, 60 * 1000);

  } catch (err) {
    logger.error({ err }, 'Startup error');
    // Also print to console directly in case logger fails or format is weird
    console.error('CRITICAL STARTUP ERROR:', err);
    process.exit(1);
  }
}

start();