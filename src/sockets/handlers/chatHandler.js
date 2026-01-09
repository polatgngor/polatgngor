const { Ride, RideMessage, User, UserDevice } = require('../../models');
const { hasProfanity } = require('../../utils/profanityFilter');
const { sendPushToTokens } = require('../../lib/fcm');
const socketProvider = require('../../lib/socketProvider');

module.exports = (io, socket) => {
  const { userId } = socket.user;

  // 1. Join Chat
  socket.on('ride:join', async (payload) => {
    try {
      const { ride_id } = payload;
      if (!ride_id) return;

      const ride = await Ride.findByPk(ride_id);
      if (!ride) return socket.emit('join_failed', { reason: 'ride_not_found' });

      // Auth check
      if (String(ride.passenger_id) !== String(userId) && String(ride.driver_id) !== String(userId)) {
        return;
      }

      // Expired check
      if (ride.status === 'completed' && ride.updated_at) {
        const TWELVE_HOURS = 12 * 60 * 60 * 1000;
        if (Date.now() - new Date(ride.updated_at).getTime() > TWELVE_HOURS) {
          return socket.emit('join_failed', { reason: 'chat_expired', message: 'Sohbet süresi doldu.' });
        }
      }

      const room = `ride:${Number(ride.id)}`;
      socket.join(room);
      socket.emit('ride:joined', { room });
    } catch (e) {
      console.error('ride:join', e);
    }
  });

  // 2. Leave Chat
  socket.on('ride:leave', (payload) => {
    const { ride_id } = payload;
    if (ride_id) socket.leave(`ride:${ride_id}`); // Corrected typo ride.id -> ride_id
  });

  // 2.5 Mark Read
  socket.on('ride:mark_read', async (payload) => {
    try {
      const { ride_id } = payload;
      if (!ride_id) return;
      const { Op } = require('sequelize');

      // Update all messages in this ride where sender != me and read_at is null
      await RideMessage.update(
        { read_at: new Date() },
        {
          where: {
            ride_id: ride_id,
            sender_id: { [Op.ne]: userId },
            read_at: null
          }
        }
      );

      // Notify sender that messages were read (optional but good for UX checkmarks)
      // socket.to(`ride:${ride_id}`).emit('ride:messages_read', { ride_id, by: userId });
      // Actually we just need to confirm to self or update local state
    } catch (e) {
      console.error('ride:mark_read', e);
    }
  });

  // 3. Send Message
  socket.on('ride:message', async (payload) => {
    try {
      const { ride_id, text } = payload;
      if (hasProfanity(text)) {
        return socket.emit('message_failed', { reason: 'profanity', message: 'Uygunsuz içerik.' });
      }

      const ride = await Ride.findByPk(ride_id);
      if (!ride) return;

      // Persist
      const msg = await RideMessage.create({ ride_id, sender_id: userId, message: text });

      // Broadcast
      const room = `ride:${Number(ride.id)}`;
      io.to(room).emit('ride:message', {
        ride_id: Number(ride.id),
        sender_id: userId,
        text,
        sent_at: msg.created_at
      });

      // FCM & Socket Notification to other party
      let otherId = String(ride.passenger_id) === String(userId) ? ride.driver_id : ride.passenger_id;
      if (otherId) {
        // 1. Send via Socket if online
        const Redis = require('ioredis');
        const redis = new Redis({
          host: process.env.REDIS_HOST || '127.0.0.1',
          port: process.env.REDIS_PORT ? parseInt(process.env.REDIS_PORT) : 6379,
          password: process.env.REDIS_PASSWORD || undefined
        });

        let otherKeyPrefix = 'user:';
        if (String(userId) === String(ride.passenger_id)) {
          otherKeyPrefix = 'driver:';
        } else {
          otherKeyPrefix = 'user:';
        }

        const meta = await redis.hgetall(`${otherKeyPrefix}${otherId}:meta`);
        if (meta && meta.socketId) {
          io.to(meta.socketId).emit('notification:new_message', {
            ride_id: Number(ride.id),
            text,
            sender_id: userId,
            created_at: msg.created_at
          });
        }
        redis.quit();

        // 2. FCM
        const devices = await UserDevice.findAll({ where: { user_id: otherId } });
        const tokens = devices.map(d => d.device_token);
        if (tokens.length) {
          const sender = await User.findByPk(userId);
          const senderName = `${sender.first_name} ${sender.last_name}`;
          await sendPushToTokens(tokens, { title: 'Yeni Mesaj', body: `${senderName}: ${text}` }, { type: 'ride_chat', ride_id: String(ride.id) });
        }
      }

    } catch (e) {
      socket.emit('message_failed', { reason: 'error' });
    }
  });

  // 4. Support
  socket.on('support:join', (payload) => {
    if (payload.ticket_id) socket.join(`ticket_${payload.ticket_id}`);
  });
  socket.on('support:leave', (payload) => {
    if (payload.ticket_id) socket.leave(`ticket_${payload.ticket_id}`);
  });
};
