const { Driver, User } = require('../models');

async function listDrivers(req, res) {
  try {
    const status = req.query.status || null;
    const where = {};
    if (status) where.status = status;
    const drivers = await Driver.findAll({
      where,
      include: [{ model: User, as: 'user', attributes: ['id', 'first_name', 'last_name', 'phone', 'is_active', 'level', 'ref_count'] }]
    });
    return res.json({ drivers });
  } catch (err) {
    console.error('listDrivers err', err);
    return res.status(500).json({ message: 'Server error' });
  }
}

async function approveDriver(req, res) {
  try {
    const userId = parseInt(req.params.id, 10);
    const driver = await Driver.findOne({ where: { user_id: userId } });
    if (!driver) return res.status(404).json({ message: 'Driver not found' });

    driver.status = 'approved';
    await driver.save();

    return res.json({ ok: true, driver });
  } catch (err) {
    console.error('approveDriver err', err);
    return res.status(500).json({ message: 'Server error' });
  }
}

async function rejectDriver(req, res) {
  try {
    const userId = parseInt(req.params.id, 10);
    const driver = await Driver.findOne({ where: { user_id: userId } });
    if (!driver) return res.status(404).json({ message: 'Driver not found' });

    driver.status = 'rejected';
    await driver.save();
    return res.json({ ok: true, driver });
  } catch (err) {
    console.error('rejectDriver err', err);
    return res.status(500).json({ message: 'Server error' });
  }
}

// NEW: tüm kullanıcıların level / ref bilgisi
async function listUserLevels(req, res) {
  try {
    const role = req.query.role || null; // optional filter: passenger/driver/admin
    const where = {};
    if (role) where.role = role;

    const users = await User.findAll({
      where,
      attributes: [
        'id',
        'role',
        'first_name',
        'last_name',
        'phone',
        'is_active',
        'level',
        'ref_count',
        'ref_code',
        'referrer_id',
        'created_at'
      ],
      order: [['ref_count', 'DESC']]
    });

    return res.json({ users });
  } catch (err) {
    console.error('listUserLevels err', err);
    return res.status(500).json({ message: 'Server error' });
  }
}

module.exports = { listDrivers, approveDriver, rejectDriver, listUserLevels };