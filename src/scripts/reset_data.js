require('dotenv').config();
const { sequelize } = require('../models');
const Redis = require('ioredis');
const logger = require('../lib/logger');

const redis = new Redis({
    host: process.env.REDIS_HOST || '127.0.0.1',
    port: process.env.REDIS_PORT ? parseInt(process.env.REDIS_PORT) : 6379,
    password: process.env.REDIS_PASSWORD || undefined
});

async function resetData() {
    const confirmation = process.argv[2];
    if (confirmation !== '--force') {
        logger.error('⚠️  SAFETY CHECK FAILED: You must use --force to run this script.');
        logger.error('Usage: npm run db:reset -- --force');
        process.exit(1);
    }

    logger.warn('☢️  STARTING NUCLEAR DATA RESET ☢️');

    try {
        // 1. Reset MySQL Data
        logger.info('MySQL: Disabling Foreign Key Checks...');
        await sequelize.query('SET FOREIGN_KEY_CHECKS = 0', { raw: true });

        const models = Object.keys(sequelize.models);
        logger.info(`MySQL: Truncating ${models.length} tables...`);

        // DROP and Re-create tables (Fixes 'Too many keys' and schema drift)
        logger.info('MySQL: Dropping and Re-syncing tables (Nuclear Option)...');

        // Explicitly drop bad tables if sync force fails on them
        await sequelize.query('DROP TABLE IF EXISTS support_messages CASCADE', { raw: true }).catch(() => { });
        await sequelize.query('DROP TABLE IF EXISTS support_tickets CASCADE', { raw: true }).catch(() => { });
        await sequelize.query('DROP TABLE IF EXISTS users CASCADE', { raw: true }).catch(() => { });
        await sequelize.query('DROP TABLE IF EXISTS RideMessages CASCADE', { raw: true }).catch(() => { }); // Just in case
        await sequelize.query('DROP TABLE IF EXISTS Rides CASCADE', { raw: true }).catch(() => { });

        await sequelize.drop({ force: true }); // Drop all defined models
        await sequelize.sync({ force: true }); // Recreate
        // for (const modelName of models) {
        //     const model = sequelize.models[modelName];
        //     await model.truncate({ cascade: true, restartIdentity: true, force: true });
        // }

        logger.info('MySQL: Enabling Foreign Key Checks...');
        await sequelize.query('SET FOREIGN_KEY_CHECKS = 1', { raw: true });
        logger.info('✅ MySQL Data Cleared.');

        // 2. Reset Redis Data
        logger.info('Redis: Flushing all data...');
        await redis.flushall();
        logger.info('✅ Redis Data Flushed.');

        logger.info('🎉 SYSTEM RESET COMPLETE. IT IS NOW A GHOST TOWN.');
        process.exit(0);
    } catch (error) {
        logger.error('❌ FATAL ERROR DURING RESET:', error);
        process.exit(1);
    }
}

resetData();
