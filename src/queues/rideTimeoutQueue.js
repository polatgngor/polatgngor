const { Queue, QueueScheduler } = require('bullmq');
const IORedis = require('ioredis');

const connection = new IORedis({
  host: process.env.REDIS_HOST || '127.0.0.1',
  port: process.env.REDIS_PORT ? parseInt(process.env.REDIS_PORT) : 6379,
  password: process.env.REDIS_PASSWORD || undefined,
  // important for BullMQ: allow blocking commands by setting this to null
  maxRetriesPerRequest: null
});

// initialize QueueScheduler so delayed jobs are moved to waiting and can be processed by workers
// QueueScheduler must be created once in the app (it can be in the same process that creates Queue or Worker)
const queueScheduler = new QueueScheduler('ride-timeout-queue', { connection });

// optional: log when scheduler is ready/fails
(async () => {
  try {
    await queueScheduler.waitUntilReady();
    console.log('[ride-timeout-queue] QueueScheduler is ready');
  } catch (err) {
    console.error('[ride-timeout-queue] QueueScheduler failed to start', err && err.stack ? err.stack : err);
  }
})();

const rideTimeoutQueue = new Queue('ride-timeout-queue', {
  connection
});

module.exports = { rideTimeoutQueue, connection, queueScheduler };