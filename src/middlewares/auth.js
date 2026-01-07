const { verifyAccessToken } = require('../utils/jwt');
const { isBlacklisted } = require('../utils/tokenBlacklist');
const redis = require('../utils/redisClient');

async function authMiddleware(req, res, next) {
  try {
    const header = req.headers.authorization;
    if (!header) return res.status(401).json({ message: 'Authorization header missing' });
    const parts = header.split(' ');
    if (parts.length !== 2 || parts[0] !== 'Bearer') return res.status(401).json({ message: 'Invalid auth format' });
    const token = parts[1];

    // check blacklist
    if (await isBlacklisted(token)) return res.status(401).json({ message: 'Token invalidated' });

    const payload = verifyAccessToken(token); // throws if invalid

    // Single Device Enforcement
    if (payload.session_id) {
      const storedSession = await redis.get(`session:${payload.userId}`);
      if (!storedSession || storedSession !== payload.session_id) {
        return res.status(401).json({ message: 'Session expired or logged in on another device' });
      }
    }

    req.user = payload; // { userId, role, session_id, iat, exp ... }
    req.token = token;
    return next();
  } catch (err) {
    return res.status(401).json({ message: 'Unauthorized' });
  }
}

module.exports = authMiddleware;