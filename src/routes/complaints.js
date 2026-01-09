const express = require('express');
const router = express.Router();
const auth = require('../middlewares/auth');
const { Complaint } = require('../models');

// POST /api/complaints
router.post('/', auth, async (req, res) => {
  try {
    const user = req.user;
    const { ride_id, accused_id, type, description } = req.body;
    if (!description && !type) return res.status(400).json({ message: 'type or description required' });

    const complaint = await Complaint.create({
      ride_id: ride_id || null,
      complainer_id: user.userId,
      accused_id: accused_id || null,
      type: type || null,
      description: description || null,
      status: 'open'
    });

    return res.status(201).json({ ok: true, complaint });
  } catch (err) {
    console.error('create complaint err', err);
    return res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router;