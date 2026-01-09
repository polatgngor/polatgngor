require('dotenv').config();
const { sequelize, Driver, User } = require('../models');
const { Op } = require('sequelize');
const logger = require('../lib/logger');

async function approveDriver() {
    let inputPhone = process.argv[2];
    if (inputPhone === '--') {
        inputPhone = process.argv[3];
    }

    try {
        if (!inputPhone) {
            await listPendingDrivers();
            return;
        }

        // Search logic
        let phoneVariations = [inputPhone];

        // Clean basic
        const digitsOnly = inputPhone.replace(/\D/g, '');

        // Add variations
        phoneVariations.push(digitsOnly); // 905xxxxxxxxx
        phoneVariations.push('+' + digitsOnly); // +905xxxxxxxxx
        if (digitsOnly.length === 12 && digitsOnly.startsWith('90')) {
            phoneVariations.push(digitsOnly.substring(2)); // 5xxxxxxxxx
            phoneVariations.push('0' + digitsOnly.substring(2)); // 05xxxxxxxxx
        }

        logger.info(`🔍 Searching for user with variations: ${phoneVariations.join(', ')}`);

        const user = await User.findOne({
            where: {
                phone: { [Op.in]: phoneVariations }
            }
        });

        if (!user) {
            logger.error(`❌ User not found with input: ${inputPhone}`);
            await listPendingDrivers(); // Fallback to list
            process.exit(1);
        }

        if (user.role !== 'driver') {
            logger.error(`❌ User ${user.phone} is found but ROLE is '${user.role}' (Not a driver)`);
            process.exit(1);
        }

        const driver = await Driver.findOne({ where: { user_id: user.id } });
        if (!driver) {
            logger.error(`❌ Driver profile entry missing for user ID: ${user.id}`);
            process.exit(1);
        }

        // Approve
        const oldStatus = driver.status;
        driver.status = 'approved';
        driver.is_available = false;
        await driver.save();

        logger.info(`
        🎉 SUCCESSS!
        -------------------------------------------
        Driver:          ${user.first_name} ${user.last_name}
        Phone (DB):      ${user.phone}
        Vehicle Type:    ${driver.vehicle_type}
        Status Change:   ${oldStatus.toUpperCase()} -> APPROVED
        -------------------------------------------
        `);

        process.exit(0);

    } catch (error) {
        logger.error('❌ FATAL ERROR:', error);
        process.exit(1);
    }
}

async function listPendingDrivers() {
    console.log('\n📋 LISTING ALL PENDING DRIVERS:');
    console.log('-------------------------------------------');

    const pendingDrivers = await Driver.findAll({
        where: { status: 'pending' },
        include: [{
            model: User,
            as: 'user',
            attributes: ['first_name', 'last_name', 'phone']
        }]
    });

    if (pendingDrivers.length === 0) {
        console.log('   (No pending drivers found)');
    } else {
        pendingDrivers.forEach(d => {
            console.log(`   Phone: ${d.user.phone.padEnd(15)} | Name: ${d.user.first_name} ${d.user.last_name}`);
        });
    }
    console.log('-------------------------------------------');
    console.log('Usage to approve:  npm run driver:approve -- <EXACT_PHONE>');
}

approveDriver();
