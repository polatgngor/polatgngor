const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

let isInitialized = false;

try {
    const serviceAccountPath = path.join(__dirname, '../../firebase-service-account.json');

    if (fs.existsSync(serviceAccountPath)) {
        const serviceAccount = require(serviceAccountPath);
        admin.initializeApp({
            credential: admin.credential.cert(serviceAccount)
        });
        isInitialized = true;
        console.log('FCM Initialized successfully');
    } else {
        console.warn('Warning: serviceAccountKey.json not found. FCM will not work.');
    }
} catch (error) {
    console.error('Error initializing FCM:', error);
}

/**
 * Send a notification to a specific device token
 * @param {string} token - FCM Device Token
 * @param {string} title - Notification Title
 * @param {string} body - Notification Body
 * @param {object} data - Custom data payload (optional)
 */
async function sendNotification(token, title, body, data = {}) {
    if (!isInitialized) {
        console.warn('FCM not initialized, skipping notification:', title);
        return false;
    }

    if (!token) {
        console.warn('No token provided for notification');
        return false;
    }

    const message = {
        // Platform specific overrides for High Priority
        android: {
            priority: 'high',
            ttl: 0, // 0 = Immediate delivery
            notification: {
                channelId: 'incoming_request_channel',
                priority: 'max',
                defaultSound: true,
                visibility: 'public',
            },
            data: {
                ...data,
                click_action: 'FLUTTER_NOTIFICATION_CLICK',
                type: 'request_incoming', // Ensure this is set for the handler
            }
        },
        apns: {
            headers: {
                'apns-priority': '10', // 10 = Immediate
                'apns-push-type': 'alert',
            },
            payload: {
                aps: {
                    contentAvailable: true, // critical for background fetch
                    sound: 'default',
                }
            }
        },
        notification: {
            title,
            body,
        },
        data: {
            ...data,
            click_action: 'FLUTTER_NOTIFICATION_CLICK',
            type: 'request_incoming',
        },
        token,
    };

    try {
        const response = await admin.messaging().send(message);
        console.log('Successfully sent message:', response);
        return true;
    } catch (error) {
        console.error('Error sending message:', error);
        return false;
    }
}

module.exports = { sendNotification };
