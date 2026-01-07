const express = require('express');
const router = express.Router();
const supportController = require('../controllers/supportController');
const authenticateToken = require('../middlewares/auth');

// Create a new support ticket
router.post('/create', authenticateToken, supportController.createTicket);

// Get all tickets for the logged-in user
router.get('/my-tickets', authenticateToken, supportController.getMyTickets);

// Get messages for a specific ticket
router.get('/:ticketId/messages', authenticateToken, supportController.getTicketMessages);

// Send a new message to a ticket
router.post('/:ticketId/message', authenticateToken, supportController.sendMessage);

module.exports = router;
