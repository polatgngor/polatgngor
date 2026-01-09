const express = require('express');
const router = express.Router();
const ridesController = require('../controllers/ridesController');
const auth = require('../middlewares/auth');
const Joi = require('joi');
const validate = require('../middlewares/validate');

const createRideSchema = Joi.object({
    start_lat: Joi.number().min(-90).max(90).required(),
    start_lng: Joi.number().min(-180).max(180).required(),
    start_address: Joi.string().allow('').optional(),
    end_lat: Joi.number().min(-90).max(90).allow(null).optional(),
    end_lng: Joi.number().min(-180).max(180).allow(null).optional(),
    end_address: Joi.string().allow('').optional(),
    vehicle_type: Joi.string().valid('sari', 'turkuaz', 'vip', '8+1').default('sari'),
    payment_method: Joi.string().valid('cash', 'card', 'pos', 'nakit').default('cash'), // covering all bases
    options: Joi.object().optional()
});

// List / history (passenger or driver)
router.get('/', auth, ridesController.getRides);

// Estimate ride fare
router.post('/estimate', auth, ridesController.estimateRide);

// Create a ride (passenger)
router.post('/', auth, validate(createRideSchema), ridesController.createRide);

// Get active ride
router.get('/active', auth, ridesController.getActiveRide);

// Get ride details
router.get('/:id', auth, ridesController.getRide);

// Cancel ride
router.post('/:id/cancel', auth, ridesController.cancelRide);

// Rate ride
router.post('/:id/rate', auth, ridesController.rateRide);

// Get messages
router.get('/:id/messages', auth, ridesController.getMessages);

module.exports = router;