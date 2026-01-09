const { Driver, Ride, Wallet, WalletTransaction, User, Rating, sequelize } = require('../models');
const { Op } = require('sequelize');

async function updatePlate(req, res) {
  try {
    const userId = req.user.userId;
    const { vehicle_plate } = req.body;
    if (!vehicle_plate) return res.status(400).json({ message: 'vehicle_plate required' });
    const driver = await Driver.findOne({ where: { user_id: userId } });
    if (!driver) return res.status(404).json({ message: 'Driver record not found' });
    driver.vehicle_plate = vehicle_plate;
    await driver.save();
    return res.json({ ok: true, driver });
  } catch (err) {
    console.error('updatePlate err', err);
    return res.status(500).json({ message: 'Server error' });
  }
}

/**
 * GET /api/driver/earnings?from=YYYY-MM-DD&to=YYYY-MM-DD
 * returns sum of fare_actual for completed rides where driver_id = userId
 */
async function getEarnings(req, res) {
  try {
    const userId = req.user.userId;
    // Log request params
    console.log('[getEarnings] Request for user:', userId, 'Query:', req.query);

    // Fix: Force UTC if 'Z' is missing to prevent local time interpretation
    const parseDate = (d) => {
      if (!d) return null;
      if (!d.endsWith('Z')) return new Date(d + 'Z');
      return new Date(d);
    };

    let from = parseDate(req.query.from);
    let to = parseDate(req.query.to);
    const period = req.query.period; // 'daily', 'weekly', 'monthly'

    // Server-side Date Calculation (Turkey Time: UTC+3)
    if (period) {
      const now = new Date();
      // Add 3 hours to get Turkey time, then truncate to start of period, then subtract 3 hours to get UTC again
      // Or cleaner: Work with UTC dates but aligning to Turkey day boundaries if needed.
      // Easiest: Just use standard UTC days for now, but ensure 'daily' means 'from 00:00 UTC today'.

      // Let's settle for simple UTC based calculation which is consistent for Server
      // Ideally, we should use libraries like 'moment-timezone' but we don't have it installed.
      // We will do a manual offset of +3 hours for "Turkey Day Start".

      const offsetMs = 3 * 60 * 60 * 1000;
      const turkeyTime = new Date(now.getTime() + offsetMs);

      if (period === 'daily') {
        // Start of Turkey Day: yyyy-mm-dd 00:00:00
        turkeyTime.setUTCHours(0, 0, 0, 0);
        from = new Date(turkeyTime.getTime() - offsetMs); // Back to UTC
        to = new Date(); // Now
      } else if (period === 'weekly') {
        const day = turkeyTime.getUTCDay(); // 0 (Sun) to 6 (Sat)
        const diff = turkeyTime.getUTCDate() - day + (day === 0 ? -6 : 1); // Adjust to get Monday
        turkeyTime.setUTCDate(diff);
        turkeyTime.setUTCHours(0, 0, 0, 0);
        from = new Date(turkeyTime.getTime() - offsetMs);
        to = new Date();
      } else if (period === 'monthly') {
        turkeyTime.setUTCDate(1);
        turkeyTime.setUTCHours(0, 0, 0, 0);
        from = new Date(turkeyTime.getTime() - offsetMs);
        to = new Date();
      }
    }

    const where = { driver_id: userId, status: 'completed' };
    if (from || to) {
      where.created_at = {};
      if (from) where.created_at[Op.gte] = from;
      if (to) where.created_at[Op.lte] = to;
    }

    console.log('[getEarnings] Constructed Where:', JSON.stringify(where, null, 2));

    console.log('[getEarnings] Constructed Where:', JSON.stringify(where, null, 2));

    // Parallel Fetching: Rides, User Stats, Rating
    const [rides, user, ratingData] = await Promise.all([
      Ride.findAll({
        where,
        attributes: ['id', 'created_at', 'fare_actual', 'start_address', 'end_address', 'payment_method'],
        order: [['created_at', 'DESC']]
      }),
      User.findByPk(userId, { attributes: ['ref_count', 'level', 'role'] }),
      Rating.findOne({
        where: { rated_id: userId },
        attributes: [[sequelize.fn('AVG', sequelize.col('stars')), 'avg_rating']]
      })
    ]);

    console.log('[getEarnings] Found rides count:', rides.length);

    // if driver, include driver details
    let driver = null;
    if (user.role === 'driver') {
      // Parallel Fetch: Driver Details + Wallet
      const [driverRecord, wallet] = await Promise.all([
        Driver.findOne({
          where: { user_id: userId },
          attributes: ['vehicle_plate', 'vehicle_type', 'status', 'is_available'],
          raw: true
        }),
        Wallet.findOne({ where: { user_id: userId }, raw: true })
      ]);

      if (driverRecord) {
        driver = driverRecord;
        driver.wallet_balance = wallet ? wallet.balance : 0.00;
      }
    }
    const total = rides.reduce((s, r) => s + (parseFloat(r.fare_actual || 0) || 0), 0);
    const count = rides.length;
    const avgRating = ratingData ? parseFloat(ratingData.dataValues.avg_rating || 0).toFixed(1) : "5.0";

    // Turkey Time Offset (UTC+3)
    const { formatTurkeyDate } = require('../utils/dateUtils');

    const ridesFormatted = rides.map(r => {
      const plain = r.toJSON();
      plain.date_formatted = formatTurkeyDate(r.created_at);
      return plain;
    });

    return res.json({
      total,
      count,
      rides: ridesFormatted,
      ref_count: user ? user.ref_count : 0,
      level: user ? user.level : 1,
      rating: avgRating
    });
  } catch (err) {
    console.error('getEarnings err', err);
    return res.status(500).json({ message: 'Server error' });
  }
}

async function requestVehicleChange(req, res) {
  try {
    const userId = req.user.userId;
    const {
      request_type,
      new_plate,
      new_brand,
      new_model,
      new_vehicle_type
    } = req.body;

    // Verify OTP
    const { otp_code } = req.body;
    if (!otp_code) return res.status(400).json({ message: 'OTP doğrulama kodu gereklidir.' });

    // Get User for Phone (Secure)
    const user = await User.findByPk(userId);
    if (!user) return res.status(404).json({ message: 'User not found' });

    const key = `otp:${user.phone}`;
    const redis = require('../utils/redisClient');
    const storedOtp = await redis.get(key);

    if (!storedOtp || storedOtp !== otp_code.trim()) {
      return res.status(400).json({ message: 'Geçersiz veya süresi dolmuş kod.' });
    }

    // OTP Valid - Delete it (optional, to prevent reuse)
    await redis.del(key);

    // Get Driver
    const driver = await Driver.findOne({ where: { user_id: userId } });
    if (!driver) return res.status(404).json({ message: 'Driver not found' });

    const requestData = {
      driver_id: driver.user_id, // Driver model uses user_id as PK
      request_type: request_type || 'change_taxi', // ensure matches ENUM
      new_plate,
      new_brand,
      new_model,
      new_vehicle_type: new_vehicle_type || 'sari',
      status: 'pending'
    };

    // Handle Files
    if (req.files) {
      if (req.files['new_vehicle_license']) requestData.new_vehicle_license_file = req.files['new_vehicle_license'][0].path.replace(/\\/g, '/');
      if (req.files['new_ibb_card']) requestData.new_ibb_card_file = req.files['new_ibb_card'][0].path.replace(/\\/g, '/');
      if (req.files['new_driving_license']) requestData.new_driving_license_file = req.files['new_driving_license'][0].path.replace(/\\/g, '/');
      if (req.files['new_identity_card']) requestData.new_identity_card_file = req.files['new_identity_card'][0].path.replace(/\\/g, '/');
    }

    const { VehicleChangeRequest } = require('../models');
    await VehicleChangeRequest.create(requestData);

    // Update Driver Status to Pending (Lock out)
    driver.status = 'pending';
    driver.is_available = false;
    await driver.save();

    return res.status(201).json({ ok: true, message: 'Talebiniz alınmıştır. Yönetici onayı bekleniyor.' });

  } catch (err) {
    console.error('requestVehicleChange err', err);
    return res.status(500).json({ message: 'Server error: ' + err.message });
  }
}

async function getChangeRequests(req, res) {
  try {
    const userId = req.user.userId;
    const driver = await Driver.findOne({ where: { user_id: userId } });
    if (!driver) return res.status(404).json({ message: 'Driver not found' });

    const { VehicleChangeRequest } = require('../models');
    const requests = await VehicleChangeRequest.findAll({
      where: { driver_id: driver.user_id },
      order: [['created_at', 'DESC']]
    });

    return res.json({ ok: true, requests });
  } catch (err) {
    console.error('getChangeRequests err', err);
    return res.status(500).json({ message: 'Server error' });
  }
}


async function approveTestAccount(req, res) {
  try {
    const userId = req.user.userId;
    // 1. Get User to check phone
    const user = await User.findByPk(userId);
    if (!user) return res.status(404).json({ message: 'User not found' });

    // 2. Validate Test Number
    const TEST_NUMBERS = ['1234567890', '0987654321'];
    const cleanPhone = user.phone.replace(/\D/g, '');
    const isTestUser = TEST_NUMBERS.some(num => cleanPhone.endsWith(num));

    if (!isTestUser) {
      // Quietly ignore or return 403. Let's return success to avoid leaking logic/errors to normal users.
      // But actually, normal users shouldn't be calling this unless they sniff traffic.
      return res.json({ ok: false, message: 'Not a test account' });
    }

    // 3. Approve if Pending
    const driver = await Driver.findOne({ where: { user_id: userId } });
    if (!driver) return res.status(404).json({ message: 'Driver not found' });

    if (driver.status === 'pending') {
      console.log(`[Test Account] Explicitly approving driver ${user.phone} upon pending screen ack.`);
      driver.status = 'approved';
      driver.is_available = true;
      await driver.save();
      return res.json({ ok: true, status: 'approved' });
    }

    return res.json({ ok: true, status: driver.status });

  } catch (err) {
    console.error('approveTestAccount err', err);
    return res.status(500).json({ message: 'Server error' });
  }
}

module.exports = { updatePlate, getEarnings, requestVehicleChange, getChangeRequests, approveTestAccount };