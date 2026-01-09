const express = require('express');
const router = express.Router();
const { Announcement } = require('../models');
const { Op } = require('sequelize');

// Get active announcements
router.get('/', async (req, res) => {
    try {
        const { target_app } = req.query; // 'driver', 'customer', or null for both

        const where = {
            is_active: true,
            [Op.or]: [
                { expires_at: null },
                { expires_at: { [Op.gt]: new Date() } }
            ]
        };

        if (target_app) {
            where.target_app = {
                [Op.or]: [target_app, 'both']
            };
        }

        const rows = await Announcement.findAll({
            where,
            order: [['created_at', 'DESC']]
        });

        res.json(rows);
    } catch (error) {
        console.error('Error fetching announcements:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

module.exports = router;
