const redis = require('../utils/redisClient');
const { User, Driver } = require('../models');

const { signAccessToken, signRefreshToken } = require('../utils/jwt');
const { sendSms } = require('../services/smsService');
const socketProvider = require('../lib/socketProvider');

// OTP TTL in seconds (3 minutes)
const OTP_TTL = 180;

// Helper to generate 6-digit code
function generateOtp() {
    return Math.floor(100000 + Math.random() * 900000).toString();
}

/**
 * Send OTP to the phone number.
 */
async function sendOtp(req, res) {
    try {
        console.log('[DEBUG] sendOtp request received:', req.body); // NEW LOG
        let { phone } = req.body;
        if (!phone) return res.status(400).json({ message: 'Phone is required' });

        phone = phone.trim();

        // --- GOOGLE PLAY TEST ACCOUNT LOGIC ---
        // Normalize for check
        const cleanPhoneInput = phone.replace(/\D/g, '');
        const TEST_NUMBERS = ['1234567890', '0987654321'];

        if (TEST_NUMBERS.some(num => cleanPhoneInput.endsWith(num))) {
            console.log(`[Test Account] Bypassing SMS for ${phone}. Use OTP: 000000`);
            return res.json({
                ok: true,
                message: 'OTP sent (Test Account)'
            });
        }

        // 1. Generate OTP
        const otp = generateOtp();

        // 2. Store in Redis
        // Key: otp:{phone} -> value: {code}
        const key = `otp:${phone}`;
        await redis.set(key, otp, 'EX', OTP_TTL);

        // 3. Send SMS
        // Log for debugging
        console.log(`[Detailed Log] Sending OTP ${otp} to ${phone}`);

        // Asynchronously send SMS (don't block response)
        sendSms(phone, `Taksibu dogrulama kodunuz: ${otp}`).catch(err => {
            console.error('Background SMS Send Error:', err);
        });

        // We return success immediately. 
        // In a strict environment, we might await sendSms to ensure it was accepted by gateway.
        // User asked "bu stilde gönderiyoruz metin kısmını ve nums kısmını bizi ilgilendiriyor".
        // I'll keep the response fast.

        return res.json({
            ok: true,
            message: 'OTP sent'
        });
    } catch (err) {
        console.error('sendOtp err', err);
        return res.status(500).json({ message: 'Server error' });
    }
}

/**
 * Verify OTP.
 * If user exists => Login (return token).
 * If user NEW => Return verification_token to proceed to register.
 */
async function verifyOtp(req, res) {
    try {
        let { phone, code } = req.body;
        if (!phone || !code) return res.status(400).json({ message: 'Phone and code required' });

        phone = phone.trim();
        code = code.trim();

        // Variable to hold Redis key, if applicable.
        let key = null;

        // --- GOOGLE PLAY TEST ACCOUNT LOGIC ---
        // Normalize for check
        const cleanPhone = phone.replace(/\D/g, '');
        const TEST_NUMBERS = ['1234567890', '0987654321'];
        const FIXED_OTP = '000000';

        if (TEST_NUMBERS.some(num => cleanPhone.endsWith(num))) {
            if (code !== FIXED_OTP) {
                return res.status(400).json({ message: 'Invalid OTP' });
            }
            // Bypass Redis check and proceed (key remains null)
        } else {
            // Normal User Flow
            key = `otp:${phone}`;
            const storedOtp = await redis.get(key);

            if (!storedOtp) {
                return res.status(400).json({ message: 'OTP expired or not found' });
            }

            if (storedOtp !== code) {
                return res.status(400).json({ message: 'Invalid OTP' });
            }
        }

        // Check if user exists
        let user = await User.findOne({ where: { phone } });

        // Security: Check Role if provided
        const { app_role } = req.body; // 'driver' or 'passenger'
        if (user && app_role) {
            if (user.role !== app_role) {
                return res.status(403).json({
                    message: app_role === 'driver'
                        ? 'Bu hesap bir Müşteri hesabıdır. Sürücü uygulamasından giriş yapamazsınız.'
                        : 'Bu hesap bir Sürücü hesabıdır. Müşteri uygulamasından giriş yapamazsınız.'
                });
            }
        }

        if (user) {
            // --- LOGIN FLOW ---

            if (!user.is_active) {
                return res.status(403).json({ message: 'Account is deactivated' });
            }

            let driver = null;
            if (user.role === 'driver') {
                driver = await Driver.findOne({ where: { user_id: user.id } });
                if (driver && driver.status === 'pending') {
                    // Depending on business logic, maybe allow login but restricted?
                    // User requested "wait for admin approval" check in login usually.
                    // We return status so app can show "Pending" screen.
                }
                if (driver && (driver.status === 'rejected' || driver.status === 'banned')) {
                    return res.status(403).json({ message: 'Hesabınız reddedildi veya engellendi.' });
                }
            }

            // --- FORCE LOGOUT OLD DEVICE ---
            const metaKey = `user:${user.id}:meta`;
            const oldSocketId = await redis.hget(metaKey, 'socketId');
            if (oldSocketId) {
                const io = socketProvider.getIO();
                if (io) {
                    console.log(`[Auth] Forcing logout for socket ${oldSocketId}`);
                    io.to(oldSocketId).emit('force_logout');
                    // Give it a moment to receive the event then disconnect
                    setTimeout(() => {
                        io.in(oldSocketId).disconnectSockets(true);
                    }, 500);
                }
            }

            // OTP Verified & Checks Passed. NOW delete it.
            if (key) await redis.del(key);

            // Generate Session ID (Single Device Logic)
            const sessionId = Date.now().toString(36) + Math.random().toString(36).substr(2);
            await redis.set(`session:${user.id}`, sessionId);

            const token = signAccessToken({ userId: user.id, role: user.role, session_id: sessionId });
            const refreshToken = signRefreshToken({ userId: user.id, role: user.role, session_id: sessionId });

            return res.json({
                ok: true,
                is_new_user: false,
                accessToken: token,
                refreshToken: refreshToken,
                user: {

                    id: user.id,
                    role: user.role,
                    phone: user.phone,
                    first_name: user.first_name,
                    last_name: user.last_name,
                    level: user.level,
                    ref_code: user.ref_code,
                    ref_count: user.ref_count,
                    vehicle_type: driver ? driver.vehicle_type : null,
                    vehicle_plate: driver ? driver.vehicle_plate : null,
                    vehicle_brand: driver ? driver.vehicle_brand : null,
                    vehicle_model: driver ? driver.vehicle_model : null
                }
            });

        } else {
            // --- REGISTER FLOW ---
            // Return a special token or just a signed JWT with a specific claim "verified_phone"
            // to allow the user to call /register endpoint.

            // OTP Verified. Delete it.
            if (key) await redis.del(key);

            // We can use the same signAccessToken but maybe with a different scope or payload.
            // For simplicity, let's sign a token that expires quickly (e.g., 10 mins).
            const verificationToken = signAccessToken({ phone, is_registration_verified: true }, '10m');

            return res.json({
                ok: true,
                is_new_user: true,
                verification_token: verificationToken
            });
        }

    } catch (err) {
        console.error('verifyOtp err', err);
        return res.status(500).json({ message: 'Server error' });
    }
}

module.exports = { sendOtp, verifyOtp };
