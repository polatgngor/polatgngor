const { verifyAccessToken } = require('../../utils/jwt');

module.exports = (socket, next) => {
    try {
        const token = socket.handshake.auth && socket.handshake.auth.token;
        if (!token) return next(new Error('Authentication error - token missing'));

        const payload = verifyAccessToken(token);
        socket.user = payload; // { userId, role }
        return next();
    } catch (err) {
        return next(new Error('Authentication error'));
    }
};
