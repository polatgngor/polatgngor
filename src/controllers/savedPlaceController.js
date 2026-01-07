const { SavedPlace } = require('../models');

/**
 * GET /api/saved-places
 * List user's saved places
 */
async function list(req, res) {
    try {
        const userId = req.user.userId;
        const places = await SavedPlace.findAll({
            where: { user_id: userId },
            order: [['created_at', 'DESC']]
        });
        return res.json({ places });
    } catch (err) {
        console.error('list saved places err', err);
        return res.status(500).json({ message: 'Server error' });
    }
}

/**
 * POST /api/saved-places
 * Create a new saved place
 */
async function create(req, res) {
    try {
        const userId = req.user.userId;
        const { title, address, lat, lng, icon } = req.body;

        if (!title || !address || !lat || !lng) {
            return res.status(400).json({ message: 'Missing required fields' });
        }

        const place = await SavedPlace.create({
            user_id: userId,
            title,
            address,
            lat,
            lng,
            icon: icon || 'place'
        });

        return res.status(201).json({ place });
    } catch (err) {
        console.error('create saved place err', err);
        return res.status(500).json({ message: 'Server error' });
    }
}

/**
 * DELETE /api/saved-places/:id
 * Delete a saved place
 */
async function remove(req, res) {
    try {
        const userId = req.user.userId;
        const { id } = req.params;

        const place = await SavedPlace.findByPk(id);
        if (!place) {
            return res.status(404).json({ message: 'Place not found' });
        }

        if (Number(place.user_id) !== Number(userId)) {
            return res.status(403).json({ message: 'Forbidden' });
        }

        await place.destroy();
        return res.json({ ok: true });
    } catch (err) {
        console.error('delete saved place err', err);
        return res.status(500).json({ message: 'Server error' });
    }
}

module.exports = {
    list,
    create,
    remove
};
