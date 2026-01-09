const { User, Driver, UserDevice } = require('../models');
const { signAccessToken, verifyAccessToken, verifyRefreshToken, signRefreshToken } = require('../utils/jwt');

const { computeLevelFromRefCount, generateRefCode } = require('../services/levelService');

async function register(req, res) {
  try {
    let {
      first_name,
      last_name,
      role,
      ref_code,
      vehicle_plate,
      vehicle_brand,
      vehicle_model,
      vehicle_type,
      driver_card_number,
      verification_token // REQUIRED
    } = req.body;

    // Sanitize inputs
    if (first_name) first_name = first_name.trim();
    if (last_name) last_name = last_name.trim();
    if (vehicle_plate) vehicle_plate = vehicle_plate.trim();
    if (driver_card_number) driver_card_number = driver_card_number.trim();

    // 1. Verify Token
    if (!verification_token) {
      return res.status(401).json({ message: 'Verification token required' });
    }

    let decoded;
    try {
      decoded = verifyAccessToken(verification_token);
    } catch (e) {
      return res.status(401).json({ message: 'Invalid or expired verification token' });
    }

    // Ensure this token was issued for registration
    if (!decoded.phone || !decoded.is_registration_verified) {
      return res.status(401).json({ message: 'Invalid token claims' });
    }

    const phone = decoded.phone;

    // Check if user already exists
    const exists = await User.findOne({ where: { phone } });
    if (exists) return res.status(409).json({ message: 'Phone already registered' });

    if (!first_name || !last_name) {
      return res.status(400).json({ message: 'first_name and last_name required' });
    }

    const user = await User.create({
      first_name,
      last_name,
      phone,
      // password_hash removed
      role: role || 'passenger'
    });

    // Kendi ref_code'unu ata
    user.ref_code = generateRefCode(user.id);

    // Eğer kayıt olurken ref_code geldiyse, referans işle
    if (ref_code) {
      const referrer = await User.findOne({ where: { ref_code } });
      if (referrer) {
        user.referrer_id = referrer.id;
        referrer.ref_count = (referrer.ref_count || 0) + 1;
        referrer.level = computeLevelFromRefCount(referrer.ref_count);
        await referrer.save();
      }
    }

    await user.save();

    // if driver role, create driver record with details
    if (user.role === 'driver') {
      await Driver.create({
        user_id: user.id,
        status: 'pending',
        vehicle_plate: vehicle_plate || null,
        vehicle_brand: vehicle_brand || null,
        vehicle_model: vehicle_model || null,
        vehicle_type: vehicle_type || 'sari',
        driver_card_number: driver_card_number || null,
        working_region: req.body.working_region || null,
        working_district: req.body.working_district || null,
        vehicle_license_file: req.files && req.files['vehicle_license'] ? req.files['vehicle_license'][0].path.replace(/\\/g, '/') : null,
        ibb_card_file: req.files && req.files['ibb_card'] ? req.files['ibb_card'][0].path.replace(/\\/g, '/') : null,
        driving_license_file: req.files && req.files['driving_license'] ? req.files['driving_license'][0].path.replace(/\\/g, '/') : null,
        identity_card_file: req.files && req.files['identity_card'] ? req.files['identity_card'][0].path.replace(/\\/g, '/') : null
      });
    }

    // Update user profile photo if provided (for both drivers and passengers)
    if (req.files && req.files['photo']) {
      user.profile_picture = req.files['photo'][0].path.replace(/\\/g, '/');
      await user.save();
    }

    // Generate Login Token immediately after registration so they are logged in
    const accessToken = signAccessToken({ userId: user.id, role: user.role });
    const refreshToken = signRefreshToken({ userId: user.id, role: user.role });

    return res.status(201).json({
      ok: true,
      accessToken,
      refreshToken,
      user: {
        id: user.id,
        phone: user.phone,
        role: user.role,
        first_name: user.first_name,
        last_name: user.last_name,
        level: user.level,
        ref_code: user.ref_code,
        ref_count: user.ref_count,
        vehicle_type: req.body.vehicle_type || 'sari', // Echo back or default
        vehicle_plate: req.body.vehicle_plate || null,
        vehicle_brand: req.body.vehicle_brand || null,
        vehicle_model: req.body.vehicle_model || null,
        driver_status: 'pending', // Default for new drivers
        profile_photo: user.profile_picture, // Backward compatibility
      }
    });
  } catch (err) {
    console.error('register err', err);
    return res.status(500).json({ message: 'Server error' });
  }
}

// Deprecated: Login is now handled via otpController.verifyOtp
// async function login(req, res) { ... }

async function updateDeviceToken(req, res) {
  try {
    const userId = req.user.userId;
    const { token, platform } = req.body;
    if (!token) return res.status(400).json({ message: 'token required' });

    // Check if token already exists for this user
    const existing = await UserDevice.findOne({
      where: { user_id: userId, device_token: token }
    });

    if (!existing) {
      await UserDevice.create({
        user_id: userId,
        device_token: token,
        platform: platform || 'android'
      });
    }

    return res.json({ ok: true });
  } catch (err) {
    console.error('updateDeviceToken err', err);
    return res.status(500).json({ message: 'Server error' });
  }
}

async function refreshToken(req, res) {
  try {
    const { token } = req.body;
    if (!token) return res.status(401).json({ message: 'Refresh token required' });

    let decoded;
    try {
      decoded = verifyRefreshToken(token);
    } catch (e) {
      return res.status(403).json({ message: 'Invalid refresh token' });
    }

    const { userId, role } = decoded;

    // Optional: check if user still exists/active (extra security)
    // const user = await User.findByPk(userId);
    // if (!user || !user.is_active) return res.status(403);

    const accessToken = signAccessToken({ userId, role });

    // Optional: Rotate refresh token? (Send new one)
    // For now, keep the old one valid until expiry (30d)

    return res.json({ accessToken });
  } catch (err) {
    console.error('refreshToken err', err);
    return res.status(500).json({ message: 'Server error' });
  }
}

module.exports = { register, updateDeviceToken, refreshToken };
