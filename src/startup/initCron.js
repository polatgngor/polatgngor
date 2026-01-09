const cleanupStaleDrivers = require('../cron/cleanupDrivers');
const logger = require('../lib/logger');

module.exports = function initCron() {
    logger.info('Initializing Cron Jobs...');

    // Cleanup Job (Every 1 minute)
    setInterval(() => {
        cleanupStaleDrivers();
    }, 60 * 1000);
};
