const { rideTimeoutWorker } = require('../workers/rideTimeoutWorker');
const logger = require('../lib/logger');

module.exports = function initWorkers() {
    logger.info('Initializing System Workers...');
    // Workers are usually self-initializing when required, 
    // but if we need explicit start logic we put it here.
    // Currently rideTimeoutWorker starts on require.

    // Future workers can be added here.
};
