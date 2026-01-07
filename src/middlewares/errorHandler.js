const logger = require('../lib/logger');

const errorHandler = (err, req, res, next) => {
    const statusCode = err.statusCode || 500;
    const message = err.message || 'Internal Server Error';

    // Log payload
    const logPayload = {
        message,
        statusCode,
        url: req.originalUrl,
        method: req.method,
        ip: req.ip,
    };

    // Only log stack trace for 500 errors or non-operational errors
    if (statusCode === 500) {
        logPayload.stack = err.stack;
        logger.error(logPayload, 'Unhandled Error');
    } else {
        logger.warn(logPayload, 'Operational Error');
    }

    res.status(statusCode).json({
        success: false,
        message,
        ...(process.env.NODE_ENV === 'development' && { stack: err.stack }),
    });
};

module.exports = errorHandler;
