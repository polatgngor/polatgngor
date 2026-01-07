const Redis = require('ioredis');
const { Driver } = require('../models');
const { Op } = require('sequelize');
const logger = require('../lib/logger');

const redis = new Redis({
    host: process.env.REDIS_HOST || '127.0.0.1',
    port: process.env.REDIS_PORT ? parseInt(process.env.REDIS_PORT) : 6379,
    password: process.env.REDIS_PASSWORD || undefined
});

const STALE_THRESHOLD_MS = 5 * 60 * 1000; // 5 minutes
const DISCONNECT_GRACE_MS = 60 * 1000; // 60 seconds


async function cleanupStaleDrivers() {
    try {
        const types = ['sari', 'turkuaz', 'vip', '8+1'];
        let removedCount = 0;

        for (const type of types) {
            const key = `drivers:geo:${type}`;
            // Get all drivers in GEO set
            // zrange 0 -1 returns all elements
            const driverIds = await redis.zrange(key, 0, -1);

            for (const idStr of driverIds) {
                const driverId = idStr;

                // Check meta
                const metaKey = `driver:${driverId}:meta`;
                const [lastLocUpdate, disconnectedTs] = await redis.hmget(metaKey, 'last_loc_update', 'disconnected_ts');


                const now = Date.now();
                let isStale = false;
                let reason = '';

                // 1. Check Disconnect Grace Period
                if (disconnectedTs) {
                    const diffDisconnect = now - parseInt(disconnectedTs);
                    if (diffDisconnect > DISCONNECT_GRACE_MS) {
                        isStale = true;
                        reason = 'grace_period_expired';
                    }
                }

                // 2. Check Stale Location (Ghost driver)
                if (!isStale) {
                    if (!lastLocUpdate) {
                        // If no location update at all (and no disconnect flag?), treat as stale eventually
                        // But maybe they just logged in? Let's use same threshold
                        isStale = true;
                        reason = 'no_location_data';
                    } else {
                        const diffLoc = now - parseInt(lastLocUpdate);
                        if (diffLoc > STALE_THRESHOLD_MS) {
                            isStale = true;
                            reason = 'stale_location';
                        }
                    }
                }

                if (isStale) {
                    // Remove from Redis GEO
                    await redis.zrem(key, driverId);

                    // Update Redis Meta
                    await redis.hset(metaKey, 'available', '0');

                    // Update MySQL
                    await Driver.update(
                        { is_available: false },
                        { where: { user_id: driverId } }
                    );

                    removedCount++;
                    logger.info(`[cleanup] Removed stale driver ${driverId} (Type: ${type})`);
                }
            }
        }

        if (removedCount > 0) {
            logger.info(`[cleanup] Total stale drivers removed: ${removedCount}`);
        }
    } catch (err) {
        logger.error({ err }, 'Error in cleanupStaleDrivers');
    }
}

module.exports = cleanupStaleDrivers;
