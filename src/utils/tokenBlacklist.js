const redis = require('./redisClient');

/**
 * Add token to blacklist with given TTL milliseconds
 * @param {string} token
 * @param {number} ttlMs
 */
async function blacklistToken(token, ttlMs) {
  if (!token) return;
  const key = `bl:${token}`;
  // set with px TTL
  await redis.set(key, '1', 'PX', ttlMs);
}

/**
 * Check whether token is blacklisted
 * @param {string} token
 * @returns {boolean}
 */
async function isBlacklisted(token) {
  if (!token) return false;
  const key = `bl:${token}`;
  const v = await redis.get(key);
  return !!v;
}

module.exports = { blacklistToken, isBlacklisted, redis };
