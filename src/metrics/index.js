const client = require('prom-client');

// Collect default Node metrics (CPU, memory, eventloop, etc.)
client.collectDefaultMetrics({ prefix: 'taksibu_' });

// HTTP request counter + histogram
const httpRequestsTotal = new client.Counter({
  name: 'taksibu_http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status_code']
});

const httpRequestDuration = new client.Histogram({
  name: 'taksibu_http_request_duration_seconds',
  help: 'HTTP request duration in seconds',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [0.005, 0.01, 0.05, 0.1, 0.3, 1, 3, 5]
});

// BullMQ job metrics
const bullJobFailures = new client.Counter({
  name: 'taksibu_bull_job_failures_total',
  help: 'Total number of BullMQ job failures',
  labelNames: ['queue']
});
const bullJobProcessed = new client.Counter({
  name: 'taksibu_bull_job_processed_total',
  help: 'Total number of BullMQ jobs processed',
  labelNames: ['queue']
});

// Queue counts gauges
const queueWaiting = new client.Gauge({
  name: 'taksibu_queue_waiting',
  help: 'Number of jobs waiting in queue',
  labelNames: ['queue']
});
const queueActive = new client.Gauge({
  name: 'taksibu_queue_active',
  help: 'Number of jobs active in queue',
  labelNames: ['queue']
});
const queueDelayed = new client.Gauge({
  name: 'taksibu_queue_delayed',
  help: 'Number of delayed jobs in queue',
  labelNames: ['queue']
});
const queueFailed = new client.Gauge({
  name: 'taksibu_queue_failed',
  help: 'Number of failed jobs in queue',
  labelNames: ['queue']
});
const queueCompleted = new client.Gauge({
  name: 'taksibu_queue_completed',
  help: 'Number of completed jobs in queue',
  labelNames: ['queue']
});

// Health gauges
const redisUp = new client.Gauge({ name: 'taksibu_redis_up', help: 'Redis reachable (1 up, 0 down)' });
const dbUp = new client.Gauge({ name: 'taksibu_db_up', help: 'DB reachable (1 up, 0 down)' });

module.exports = {
  client,
  httpRequestsTotal,
  httpRequestDuration,
  bullJobFailures,
  bullJobProcessed,
  queueWaiting,
  queueActive,
  queueDelayed,
  queueFailed,
  queueCompleted,
  redisUp,
  dbUp
};