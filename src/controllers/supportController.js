const db = require('../db');
const socketProvider = require('../lib/socketProvider');
const { hasProfanity } = require('../utils/profanityFilter');

// Create a new ticket
exports.createTicket = async (req, res) => {
    const { subject, message } = req.body;
    // Robust User ID extraction: Check both possible keys
    const userId = req.user.userId || req.user.id;

    if (!userId) {
        console.error('[Support] Create Ticket Failed: User ID missing in token', req.user);
        return res.status(401).json({ error: 'Unauthorized: User ID missing.' });
    }

    if (!subject || !message) {
        return res.status(400).json({ error: 'Subject and message are required.' });
    }

    try {
        // 1. Validate Profanity
        if (hasProfanity(subject) || hasProfanity(message)) {
            return res.status(400).json({ error: 'Mesajınız veya konunuz uygunsuz içerik barındırıyor.' });
        }

        // 1. Create Ticket
        const [ticketResult] = await db.query(
            'INSERT INTO support_tickets (user_id, subject, status, created_at) VALUES (?, ?, ?, NOW())',
            [userId, subject, 'open']
        );
        const ticketId = ticketResult.insertId;

        // 2. Add First Message
        await db.query(
            'INSERT INTO support_messages (ticket_id, sender_id, sender_type, message, created_at) VALUES (?, ?, ?, ?, NOW())',
            [ticketId, userId, 'user', message]
        );

        res.status(201).json({ message: 'Ticket created successfully.', ticketId });
    } catch (error) {
        console.error('Create Ticket Error:', error);
        res.status(500).json({ error: 'Internal server error.' });
    }
};

// Get tickets for the logged user
exports.getMyTickets = async (req, res) => {
    const userId = req.user.userId || req.user.id;

    if (!userId) {
        return res.status(401).json({ error: 'Unauthorized.' });
    }

    try {
        const [tickets] = await db.query(
            'SELECT * FROM support_tickets WHERE user_id = ? ORDER BY created_at DESC',
            [userId]
        );
        res.json(tickets);
    } catch (error) {
        console.error('Get Tickets Error:', error);
        res.status(500).json({ error: 'Internal server error.' });
    }
};

// Get messages for a specific ticket
exports.getTicketMessages = async (req, res) => {
    const userId = req.user.userId || req.user.id;
    const { ticketId } = req.params;

    if (!userId) {
        return res.status(401).json({ error: 'Unauthorized.' });
    }

    try {
        // Check if ticket belongs to user (Security)
        const [ticket] = await db.query('SELECT user_id FROM support_tickets WHERE id = ?', [ticketId]);
        if (ticket.length === 0) return res.status(404).json({ error: 'Ticket not found.' });

        // Strict equality check for security
        if (String(ticket[0].user_id) !== String(userId)) return res.status(403).json({ error: 'Unauthorized.' });

        const [messages] = await db.query(
            'SELECT * FROM support_messages WHERE ticket_id = ? ORDER BY created_at ASC',
            [ticketId]
        );
        res.json(messages);
    } catch (error) {
        console.error('Get Messages Error:', error);
        res.status(500).json({ error: 'Internal server error.' });
    }
};

// Send a message
exports.sendMessage = async (req, res) => {
    const userId = req.user.userId || req.user.id;
    const { ticketId } = req.params;
    const { message } = req.body;

    if (!userId) {
        return res.status(401).json({ error: 'Unauthorized.' });
    }

    if (!message) return res.status(400).json({ error: 'Message cannot be empty.' });

    try {
        // Verify ownership
        const [ticket] = await db.query('SELECT * FROM support_tickets WHERE id = ?', [ticketId]);
        if (ticket.length === 0) return res.status(404).json({ error: 'Ticket not found.' });

        if (String(ticket[0].user_id) !== String(userId)) return res.status(403).json({ error: 'Unauthorized.' });

        if (hasProfanity(message)) {
            return res.status(400).json({ error: 'Mesajınız uygunsuz içerik barındırıyor.' });
        }

        // Insert Message
        const [result] = await db.query(
            'INSERT INTO support_messages (ticket_id, sender_id, sender_type, message, created_at) VALUES (?, ?, ?, ?, NOW())',
            [ticketId, userId, 'user', message]
        );

        // If ticket was closed/answered, maybe reopen it? (Optional logic, keeping simple for now)

        // Fetch the new message to emit
        const [newMsg] = await db.query('SELECT * FROM support_messages WHERE id = ?', [result.insertId]);

        // Emit Real-time Event
        const io = socketProvider.getIO();
        if (io) {
            io.to(`ticket_${ticketId}`).emit('new_support_message', newMsg[0]);
        }

        res.status(201).json(newMsg[0]);
    } catch (error) {
        console.error('Send Message Error:', error);
        res.status(500).json({ error: 'Internal server error.' });
    }
};
