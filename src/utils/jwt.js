const jwt = require('jsonwebtoken');

const JWT_SECRET = process.env.JWT_SECRET;
if (!JWT_SECRET) {
  console.warn('WARNING: JWT_SECRET is not defined. Using insecure default for dev only.');
}
const SECRET_KEY = JWT_SECRET || 'dev_secret_do_not_use_in_prod';

// Sign access token (short-lived)
function signAccessToken(payload, expiresIn = '7d') {
  return jwt.sign(payload, SECRET_KEY, { expiresIn });
}

// Sign refresh token (long-lived)
function signRefreshToken(payload, expiresIn = '30d') {
  return jwt.sign(payload, SECRET_KEY, { expiresIn }); // In prod, consider a separate secret
}

function verifyAccessToken(token) {
  return jwt.verify(token, SECRET_KEY);
}

function verifyRefreshToken(token) {
  return jwt.verify(token, SECRET_KEY);
}

module.exports = { signAccessToken, signRefreshToken, verifyAccessToken, verifyRefreshToken };
