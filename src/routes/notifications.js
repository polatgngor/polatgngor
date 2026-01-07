const express = require('express');
const router = express.Router();
const notif = require('../controllers/notificationController');
const auth = require('../middlewares/auth');

router.get('/', auth, notif.listNotifications);
router.get('/counts', auth, notif.getCounts);
router.post('/announcements/read', auth, notif.markAnnouncementsRead);
router.post('/:id/read', auth, notif.markRead);

module.exports = router;