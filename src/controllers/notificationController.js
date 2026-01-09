const { Notification, RideMessage, Announcement, User, sequelize } = require('../models');
const { Op } = require('sequelize');

async function listNotifications(req, res) {
  try {
    const userId = req.user.userId;
    const page = parseInt(req.query.page || '1', 10);
    const limit = parseInt(req.query.limit || '30', 10);
    const offset = (page - 1) * limit;
    const notifications = await Notification.findAll({
      where: { user_id: userId },
      order: [['created_at', 'DESC']],
      limit,
      offset
    });
    const { formatTurkeyDate } = require('../utils/dateUtils');
    const notificationsFormatted = notifications.map(n => {
      const plain = n.toJSON();
      plain.formatted_date = formatTurkeyDate(n.created_at);
      return plain;
    });

    return res.json({ notifications: notificationsFormatted });
  } catch (err) {
    console.error('listNotifications err', err);
    return res.status(500).json({ message: 'Server error' });
  }
}

async function markRead(req, res) {
  try {
    const userId = req.user.userId;
    const { id } = req.params;
    await Notification.update({ is_read: true }, { where: { id, user_id: userId } });
    return res.json({ ok: true });
  } catch (err) {
    console.error('markRead err', err);
    return res.status(500).json({ message: 'Server error' });
  }
}

/**
 * GET /api/notifications/counts
 * Returns total unread messages and unread announcements
 */
async function getCounts(req, res) {
  try {
    const userId = req.user.userId;
    const userRole = req.user.role; // 'passenger' or 'driver'

    // 1. Total Unread Chat Messages
    // Count where sender_id != me AND read_at IS NULL
    // AND ride is involved (implicitly filtered by querying RideMessage joins? No, sender_id check is usually enough if we trust the table integrity)
    // Actually, we should probably join Ride to ensure user is part of it? 
    // For simplicity/performance, if we only store messages for valid rides, checking sender_id != me is mostly safe,
    // BUT checking existence of Ride participation is safer.
    // However, usually checking sender_id != userId is sufficient if the user only receives messages they are allowed to see via API.
    // But here we are counting global unread for THIS user.
    // A message sent by Other to Me -> sender_id = Other.
    // How do we know it was sent TO Me? 
    // RideMessage doesn't have receiver_id. It has RideID.
    // We must ensure the User is a participant of RideID.

    // Proper Query: 
    // Count RideMessages M
    // JOIN Rides R ON M.ride_id = R.id
    // WHERE M.read_at IS NULL 
    // AND M.sender_id != userId
    // AND (R.passenger_id = userId OR R.driver_id = userId)

    // Sequelize Count with Include
    const { Ride } = require('../models');

    // Group by ride_id to get breakdown
    const unreadDestinations = await RideMessage.findAll({
      attributes: ['ride_id', [sequelize.fn('COUNT', sequelize.col('RideMessage.id')), 'count']],
      where: {
        sender_id: { [Op.ne]: userId },
        read_at: null
      },
      include: [{
        model: Ride,
        as: 'ride',
        attributes: [],
        where: {
          [Op.or]: [
            { passenger_id: userId },
            { driver_id: userId }
          ]
        },
        required: true
      }],
      group: ['ride_id']
    });

    let total_unread_messages = 0;
    const unread_per_ride = {};

    unreadDestinations.forEach(d => {
      const c = parseInt(d.dataValues.count || 0);
      unread_per_ride[d.ride_id] = c;
      total_unread_messages += c;
    });

    // 2. Unread Announcements
    // Get user's last view time
    const user = await User.findByPk(userId, { attributes: ['last_announcement_view_at'] });
    const lastView = user.last_announcement_view_at;

    const announcementWhere = {
      is_active: true,
      target_app: { [Op.in]: ['both', userRole] }
    };

    if (lastView) {
      announcementWhere.created_at = { [Op.gt]: lastView };
    }

    const unreadAnnouncementsCount = await Announcement.count({
      where: announcementWhere
    });

    return res.json({
      total_unread_messages,
      unread_per_ride, // Added breakdown
      unread_announcements: unreadAnnouncementsCount
    });

  } catch (err) {
    console.error('getCounts err', err);
    return res.status(500).json({ message: 'Server error' });
  }
}

/**
 * POST /api/notifications/announcements/read
 * Marks all announcements as read (updates timestamp)
 */
async function markAnnouncementsRead(req, res) {
  try {
    const userId = req.user.userId;
    await User.update(
      { last_announcement_view_at: new Date() },
      { where: { id: userId } }
    );
    return res.json({ ok: true });
  } catch (err) {
    console.error('markAnnouncementsRead err', err);
    return res.status(500).json({ message: 'Server error' });
  }
}

module.exports = { listNotifications, markRead, getCounts, markAnnouncementsRead };