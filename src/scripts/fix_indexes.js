require('dotenv').config();
const { sequelize } = require('../models');
const logger = require('../lib/logger');

async function fixIndexes() {
    logger.info('🔧 Starting Surgical Index Repair...');

    try {
        await sequelize.authenticate();
        logger.info('✅ MySQL Connected.');

        const tableName = 'users';

        // Get all indexes
        const [indexes] = await sequelize.query(`SHOW INDEX FROM \`${tableName}\``);

        // Extract unique index names, excluding PRIMARY
        const indexNames = [...new Set(
            indexes
                .map(row => row.Key_name)
                .filter(name => name !== 'PRIMARY')
        )];

        logger.info(`🔍 Found ${indexNames.length} non-primary indexes on '${tableName}'.`);

        // Drop them one by one
        for (const indexName of indexNames) {
            try {
                await sequelize.query(`DROP INDEX \`${indexName}\` ON \`${tableName}\``);
                logger.info(`   🗑️ Dropped index: ${indexName}`);
            } catch (e) {
                logger.error(`   ❌ Failed to drop index ${indexName}: ${e.message}`);
            }
        }

        logger.info('✅ All extra indexes cleared. Sequelize will recreate necessary ones on next startup.');
        process.exit(0);

    } catch (err) {
        logger.error('❌ Error during index repair:', err);
        // If table doesn't exist, that's fine too, but log it
        process.exit(1);
    }
}

fixIndexes();
