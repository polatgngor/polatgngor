const { User, Driver, UserDevice, Wallet, Rating, sequelize } = require('../models');
const { hashPassword, comparePassword } = require('../utils/hash');
const { blacklistToken } = require('../utils/tokenBlacklist');
const jwt = require('jsonwebtoken');
const redis = require('../utils/redisClient');

async function getProfile(req, res) {
  try {
    const userId = req.user.userId;
    const user = await User.findByPk(userId, {
      attributes: [
        'id',
        'role',
        'first_name',
        'last_name',
        'phone',
        'profile_picture',
        ['profile_picture', 'profile_photo'],
        'is_active',
        'created_at',
        'level',
        'ref_code',
        'ref_count',
        'referrer_id'
      ]
    });
    if (!user) return res.status(404).json({ message: 'User not found' });

    let userJson = user.toJSON();
    // Ensure profile_photo is set (Sequelize alias handling safety)
    if (user.dataValues.profile_photo) {
      userJson.profile_photo = user.dataValues.profile_photo;
    } else if (user.profile_picture) {
      userJson.profile_photo = user.profile_picture;
    }

    // if driver, include driver details
    let driver = null;
    if (user.role === 'driver') {

      // ---------------------------------------------------
      // Auto-approve logic moved to manual trigger /ack-pending
      // ---------------------------------------------------

      // Parallel Fetch: Driver Details + Wallet
      const [driverRecord, wallet] = await Promise.all([
        Driver.findOne({
          where: { user_id: userId },
          attributes: ['vehicle_plate', 'vehicle_type', 'vehicle_brand', 'vehicle_model', 'status', 'is_available']
        }),
        Wallet.findOne({ where: { user_id: userId } })
      ]);

      if (driverRecord) {
        driver = driverRecord.toJSON();
        driver.wallet_balance = wallet ? wallet.balance : 0.00;
      }
    }

    // Get Rating Stats
    // Get Rating Stats
    const ratingStats = await Rating.findOne({
      where: { rated_id: userId },
      attributes: [
        [sequelize.fn('AVG', sequelize.col('stars')), 'avg_rating'],
        [sequelize.fn('COUNT', sequelize.col('id')), 'rating_count']
      ]
    });

    const avgRating = ratingStats && ratingStats.dataValues.avg_rating ? parseFloat(ratingStats.dataValues.avg_rating).toFixed(1) : "0.0";
    const ratingCount = ratingStats && ratingStats.dataValues.rating_count ? parseInt(ratingStats.dataValues.rating_count) : 0;

    userJson.avg_rating = avgRating;
    userJson.rating_count = ratingCount;

    return res.json({ user: userJson, driver });
  } catch (err) {
    console.error('getProfile err', err);
    return res.status(500).json({ message: 'Server error' });
  }
}

async function updateProfile(req, res) {
  try {
    const userId = req.user.userId;
    const { first_name, last_name, profile_picture } = req.body;
    const user = await User.findByPk(userId);
    if (!user) return res.status(404).json({ message: 'User not found' });
    if (first_name) user.first_name = first_name;
    if (last_name) user.last_name = last_name;
    if (profile_picture) user.profile_picture = profile_picture;
    await user.save();
    return res.json({ ok: true, user: { ...user.toJSON(), profile_photo: user.profile_picture } });
  } catch (err) {
    console.error('updateProfile err', err);
    return res.status(500).json({ message: 'Server error' });
  }
}

async function changePhone(req, res) {
  try {
    const userId = req.user.userId;
    const { new_phone, code } = req.body;
    if (!new_phone || !code) return res.status(400).json({ message: 'new_phone and code required' });

    // ensure unique
    const exists = await User.findOne({ where: { phone: new_phone } });
    if (exists) return res.status(409).json({ message: 'Phone already in use' });

    // Verify OTP
    const key = `otp:${new_phone}`;
    const storedOtp = await redis.get(key);

    if (!storedOtp) {
      return res.status(400).json({ message: 'OTP expired or not found' });
    }
    if (storedOtp !== code) {
      return res.status(400).json({ message: 'Invalid OTP' });
    }

    // OTP Valid - Update Phone
    const user = await User.findByPk(userId);
    user.phone = new_phone;
    await user.save();

    // Clear OTP
    await redis.del(key);

    return res.json({ ok: true, phone: new_phone });
  } catch (err) {
    console.error('changePhone err', err);
    return res.status(500).json({ message: 'Server error' });
  }
}

async function changePassword(req, res) {
  try {
    const userId = req.user.userId;
    const { old_password, new_password } = req.body;
    if (!old_password || !new_password) return res.status(400).json({ message: 'old_password and new_password required' });

    const user = await User.findByPk(userId);
    const ok = await comparePassword(old_password, user.password_hash);
    if (!ok) return res.status(401).json({ message: 'Old password incorrect' });

    user.password_hash = await hashPassword(new_password);
    await user.save();

    // optional: blacklist current token to force re-login
    if (req.token) {
      const decoded = jwt.decode(req.token);
      const exp = decoded && decoded.exp ? decoded.exp * 1000 : null;
      if (exp) {
        const ttl = exp - Date.now();
        if (ttl > 0) await blacklistToken(req.token, ttl);
      }
    }

    return res.json({ ok: true });
  } catch (err) {
    console.error('changePassword err', err);
    return res.status(500).json({ message: 'Server error' });
  }
}

async function logout(req, res) {
  try {
    const token = req.token;
    if (!token) return res.json({ ok: true });
    const decoded = jwt.decode(token);
    const exp = decoded && decoded.exp ? decoded.exp * 1000 : null;
    if (exp) {
      const ttl = exp - Date.now();
      if (ttl > 0) {
        await blacklistToken(token, ttl);
      }
    }
    return res.json({ ok: true });
  } catch (err) {
    console.error('logout err', err);
    return res.status(500).json({ message: 'Server error' });
  }
}

// NEW: hesap silme (soft delete + token blacklist)
async function deleteAccount(req, res) {
  try {
    const userId = req.user.userId;
    const token = req.token;

    const user = await User.findByPk(userId);
    if (!user) return res.status(404).json({ message: 'User not found' });

    // Verify OTP
    const { code } = req.body;
    if (!code) return res.status(400).json({ message: 'Verification code required' });

    const key = `otp:${user.phone}`; // Verify against registered phone
    const storedOtp = await redis.get(key);

    if (!storedOtp) return res.status(400).json({ message: 'OTP expired or not found' });
    if (storedOtp !== code) return res.status(400).json({ message: 'Invalid OTP' });

    // Clear OTP
    await redis.del(key);

    // Anonymize User to allow Re-registration
    // phone is limited to 32 chars. 
    // Format: DEL_{timestamp_base36}_{last4}
    const timestamp = Date.now().toString(36);
    const suffix = user.phone.slice(-4);
    const anonymizedPhone = `DEL_${timestamp}_${suffix}`;

    // Ensure we don't exceed 32 chars
    // If original phone was long, we might need to truncate
    // But this format is approx 4+8+1+4 = 17 chars. Safe.

    user.phone = anonymizedPhone;
    user.is_active = false;
    // We can also anonymize email if it existed, but we only use phone login.

    await user.save();

    // mevcut token'ı blacklist et
    if (token) {
      const decoded = jwt.decode(token);
      const exp = decoded && decoded.exp ? decoded.exp * 1000 : null;
      if (exp) {
        const ttl = exp - Date.now();
        if (ttl > 0) {
          await blacklistToken(token, ttl);
        }
      }
    }

    return res.json({ ok: true });
  } catch (err) {
    console.error('deleteAccount err', err);
    // Handle unique constraint error if by rare chance collision happens
    return res.status(500).json({ message: 'Server error during deletion' });
  }
}

async function registerDevice(req, res) {
  try {
    const userId = req.user.userId;
    const { device_token, platform } = req.body;

    if (!device_token) {
      return res.status(400).json({ message: 'device_token required' });
    }

    const plat = platform && ['android', 'ios', 'web'].includes(platform) ? platform : 'android';

    // Aynı token daha önce kayıtlıysa tekrar ekleme (silinebilir)
    const exists = await UserDevice.findOne({ where: { user_id: userId, device_token } });
    if (!exists) {
      await UserDevice.create({ user_id: userId, device_token, platform: plat });
    }

    return res.json({ ok: true });
  } catch (err) {
    console.error('registerDevice err', err);
    return res.status(500).json({ message: 'Server error' });
  }
}

async function uploadPhoto(req, res) {
  try {
    const userId = req.user.userId;
    if (!req.file) {
      return res.status(400).json({ message: 'No file uploaded' });
    }

    // Construct public URL (assuming server runs on port 3000 or configured host)
    // We'll store relative path or full URL. Relative is more flexible.
    // req.file.filename is the saved name.
    const photoUrl = `uploads/${req.file.filename}`;

    const user = await User.findByPk(userId);
    if (!user) return res.status(404).json({ message: 'User not found' });

    user.profile_picture = photoUrl;
    await user.save();

    return res.json({ ok: true, photo_url: photoUrl, profile_photo: photoUrl });
  } catch (err) {
    console.error('uploadPhoto err', err);
    return res.status(500).json({ message: 'Server error' });
  }
}

module.exports = {
  getProfile,
  updateProfile,
  changePhone,
  changePassword,
  logout,
  deleteAccount,
  registerDevice,
  uploadPhoto
};