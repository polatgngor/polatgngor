const Redis = require('ioredis');
const logger = require('../lib/logger');

const redis = new Redis({
  host: process.env.REDIS_HOST || '127.0.0.1',
  port: process.env.REDIS_PORT ? parseInt(process.env.REDIS_PORT) : 6379,
  password: process.env.REDIS_PASSWORD || undefined
});

/**
 * Creates a rate limiter middleware
 * @param {Object} options
 * @param {number} options.windowMs - Time window in milliseconds
 * @param {number} options.max - Max requests per window
 * @param {string} options.keyPrefix - Prefix for redis keys
 * @param {string} options.message - Error message to send
 */
const rateLimiter = ({ 
  windowMs = 60 * 1000, 
  max = 5, 
  keyPrefix = 'rl',
  message = 'Çok fazla istek gönderdiniz, lütfen biraz bekleyin.' 
}) => {
  return async (req, res, next) => {
    try {
      // Use IP or specialized header for identification
      const ip = req.headers['x-forwarded-for'] || req.socket.remoteAddress;
      // If user is authenticated, use userId, otherwise use IP
      // For OTP, we might want to limit by Phone Number if available in body, 
      // but IP is safer as a fallback for abuse before body parsing or if body is random.
      
      // Let's use a composite key: Prefix + IP
      // If specific body field is needed (like phone), we can add custom logic later.
      const key = `${keyPrefix}:${ip}`;

      const current = await redis.incr(key);

      if (current === 1) {
        // First request, set expiry
        await redis.pexpire(key, windowMs);
      }

      if (current > max) {
        return res.status(429).json({ 
          success: false,
          message: message 
        });
      }

      next();
    } catch (err) {
      logger.error({ err }, 'Rate limiter error');
      // If redis fails, fail open (allow request) or closed?
      // Fail open is usually safer for UX unless under heavy attack.
      next();
    }
  };
};

module.exports = rateLimiter;
