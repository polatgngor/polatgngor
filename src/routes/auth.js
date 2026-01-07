const express = require('express');
const router = express.Router();
const authController = require('../controllers/authController');
const otpController = require('../controllers/otpController');
const authenticateToken = require('../middlewares/auth');
const rateLimiter = require('../middlewares/rateLimiter');

const multer = require('multer');
const path = require('path');
const fs = require('fs');

// Configure Multer for Registration Uploads
const storage = multer.diskStorage({
    destination: function (req, file, cb) {
        const uploadDir = 'uploads/drivers/';
        if (!fs.existsSync(uploadDir)) {
            fs.mkdirSync(uploadDir, { recursive: true });
        }
        cb(null, uploadDir);
    },
    filename: function (req, file, cb) {
        // We might not have userId yet, so use timestamp and random
        const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
        const ext = path.extname(file.originalname);
        cb(null, 'driver-' + uniqueSuffix + ext);
    }
});

const upload = multer({ storage: storage });

const registerUploads = upload.fields([
    { name: 'photo', maxCount: 1 },
    { name: 'vehicle_license', maxCount: 1 },
    { name: 'ibb_card', maxCount: 1 },
    { name: 'driving_license', maxCount: 1 },
    { name: 'identity_card', maxCount: 1 }
]);

const Joi = require('joi');
const validate = require('../middlewares/validate');

// Validation Schemas
const sendOtpSchema = Joi.object({
    phone: Joi.string().pattern(/^[0-9+]+$/).min(10).max(15).required(),
    app_role: Joi.string().valid('driver', 'passenger').optional()
});

const verifyOtpSchema = Joi.object({
    phone: Joi.string().required(),
    code: Joi.string().length(6).required(),
    app_role: Joi.string().valid('driver', 'passenger').optional()
});

const registerSchema = Joi.object({
    first_name: Joi.string().min(2).max(50).required(),
    last_name: Joi.string().min(2).max(50).required(),
    role: Joi.string().valid('driver', 'passenger').required(),
    phone: Joi.string().optional(), // usually comes from token but allowed if needed
    ref_code: Joi.string().optional().allow(''),
    verification_token: Joi.string().required(),
    // Driver specific
    vehicle_plate: Joi.string().optional().allow(''),
    vehicle_brand: Joi.string().optional().allow(''),
    vehicle_model: Joi.string().optional().allow(''),
    vehicle_type: Joi.string().optional().allow(''),
    driver_card_number: Joi.string().optional().allow(''),
    working_region: Joi.string().optional().allow(''),
    working_district: Joi.string().optional().allow('')
}).unknown(true); // Allow other fields like file uploads which multer handles

// OTP Routes
// Limit: 3 requests per 3 minutes (180000 ms)
router.post('/send-otp', rateLimiter({
    windowMs: 3 * 60 * 1000,
    max: 3,
    keyPrefix: 'rl:otp',
    message: 'Çok fazla SMS isteği gönderdiniz. Lütfen 3 dakika bekleyin.'
}), validate(sendOtpSchema), otpController.sendOtp);

router.post('/verify-otp', validate(verifyOtpSchema), otpController.verifyOtp);

// Registration (after OTP verification for new users)
router.post('/register', registerUploads, validate(registerSchema), authController.register);

// Secure routes
router.post('/device-token', authenticateToken, authController.updateDeviceToken);
router.post('/refresh-token', authController.refreshToken);

module.exports = router;
