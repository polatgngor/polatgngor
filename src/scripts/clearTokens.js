require('dotenv').config();
const { sequelize, UserDevice } = require('../models');

async function clearTokens() {
    try {
        await sequelize.authenticate();
        console.log('✅ Connected to DB');

        // Truncate table (fastest way to clear all rows and reset ids)
        await UserDevice.destroy({
            where: {},
            truncate: true
        });

        console.log('✅ All FCM tokens cleared from user_devices table.');
        process.exit(0);
    } catch (err) {
        console.error('❌ Error clearing tokens:', err);
        process.exit(1);
    }
}

clearTokens();
