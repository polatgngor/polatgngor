const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

class FCMService {
    constructor() {
        this.initialized = false;
        this.secondaryApp = null;
        this.init();
    }

    init() {
        try {
            // 1. Initialize Primary App (firebase-service-account.json) - Default
            const serviceAccountPath = path.join(__dirname, '../../firebase-service-account.json');

            if (fs.existsSync(serviceAccountPath)) {
                if (!admin.apps.length) {
                    const serviceAccount = require(serviceAccountPath);
                    admin.initializeApp({
                        credential: admin.credential.cert(serviceAccount)
                    });
                    console.log('[fcm] Primary Firebase admin initialized');
                }
                this.initialized = true;
            } else {
                console.warn('[fcm] Warning: firebase-service-account.json not found.');
            }

            // 2. Initialize Secondary App (firebase-service-account2.json) - Legacy
            try {
                const serviceAccount2Path = path.join(__dirname, '../../firebase-service-account2.json');
                if (fs.existsSync(serviceAccount2Path)) {
                    const serviceAccount2 = require(serviceAccount2Path);
                    // Check if already initialized to avoid error
                    const existingApp = admin.apps.find(app => app.name === 'secondary');
                    if (!existingApp) {
                        this.secondaryApp = admin.initializeApp({
                            credential: admin.credential.cert(serviceAccount2)
                        }, 'secondary');
                        console.log('[fcm] Secondary Firebase admin initialized (Legacy)');
                    } else {
                        this.secondaryApp = existingApp;
                    }
                } else {
                    console.warn('[fcm] Warning: firebase-service-account2.json not found. Legacy Android support disabled.');
                }
            } catch (e2) {
                console.warn('[fcm] Setup secondary app failed:', e2.message);
            }

        } catch (error) {
            console.error('[fcm] Error initializing FCM:', error);
        }
    }

    /**
     * Send a notification to a specific device token
     */
    async sendNotification(token, title, body, data = {}) {
        if (!this.initialized && !this.secondaryApp) {
            console.warn('[fcm] FCM not initialized, skipping notification:', title);
            return false;
        }

        if (!token) {
            console.warn('[fcm] No token provided for notification');
            return false;
        }

        const message = {
            android: {
                priority: 'high',
                ttl: 0,
                notification: {
                    channelId: 'incoming_request_channel',
                    priority: 'max',
                    defaultSound: true,
                    visibility: 'public',
                },
                data: {
                    ...data,
                    click_action: 'FLUTTER_NOTIFICATION_CLICK',
                    type: 'request_incoming',
                }
            },
            apns: {
                headers: {
                    'apns-priority': '10',
                    'apns-push-type': 'alert',
                },
                payload: {
                    aps: {
                        contentAvailable: true,
                        sound: 'default',
                    }
                }
            },
            notification: {
                title,
                body,
            },
            data: {
                ...data, // Flatten data for iOS/general
                click_action: 'FLUTTER_NOTIFICATION_CLICK',
                type: 'request_incoming',
            },
            token: token,
        };

        // Helper to send using a specific app
        const trySend = async (appInstance) => {
            try {
                const response = await appInstance.messaging().send(message);
                return { success: true, response };
            } catch (error) {
                return { success: false, error };
            }
        };

        // 1. Try Primary
        let result = { success: false };
        if (admin.apps.length > 0) {
            result = await trySend(admin);
        }

        // 2. Retry with Secondary if Mismatch
        if (!result.success && this.secondaryApp) {
            // Check error code usually: error.code === 'messaging/mismatched-credential'
            // But we can just retry on any failure safely as a fallback
            if (result.error && (result.error.code === 'messaging/mismatched-credential' || result.error.code === 'messaging/invalid-argument')) {
                console.log(`[fcm] Primary failed (${result.error.code}). Retrying with Secondary app...`);
                result = await trySend(this.secondaryApp);
            }
        }

        if (result.success) {
            console.log('[fcm] Successfully sent message:', result.response);
            return true;
        } else {
            console.error('[fcm] Error sending message (Both apps failed):', result.error);
            return false;
        }
    }
}

module.exports = new FCMService();
