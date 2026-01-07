const axios = require('axios');

// MutluCell Credentials (from user request)
// In production, these should be in process.env
const SMS_CONFIG = {
    username: process.env.SMS_USERNAME, // MutluCell username
    password: process.env.SMS_PASSWORD, // MutluCell password
    org: process.env.SMS_ORG,         // MutluCell org/sender ID
    url: 'https://smsgw.mutlucell.com/smsgw-ws/sndblkex'
};

async function sendSms(phone, message) {
    try {
        // Sanitize phone number: remove + if present, ensure it starts with 90 or appropriate format
        // MutluCell usually expects 905xxxxxxxxx or similar. The user example showed "90507..."
        // Let's ensure we just strip non-digits.
        let cleanPhone = phone.replace(/\D/g, '');

        // If it starts with 0 (e.g. 05...), replace with 905...
        if (cleanPhone.startsWith('0')) {
            cleanPhone = '9' + cleanPhone;
        }
        // If it starts with 5... (e.g. 507...), prepend 90
        else if (cleanPhone.startsWith('5')) {
            cleanPhone = '90' + cleanPhone;
        }

        const xmlBody = `<?xml version="1.0" encoding="UTF-8"?>
<smspack ka="${SMS_CONFIG.username}" pwd="${SMS_CONFIG.password}" org="${SMS_CONFIG.org}">
    <mesaj>
        <metin>${message}</metin>
        <nums>${cleanPhone}</nums>
    </mesaj>
</smspack>`;

        const response = await axios.post(SMS_CONFIG.url, xmlBody, {
            headers: {
                'Content-Type': 'text/xml'
            }
        });

        // MutluCell usually returns a transaction ID (long number) or error code (short number like 20, 23).
        const result = response.data.toString().trim();
        console.log(`[MutluCell] Response for ${cleanPhone}: ${result}`);

        // Error Codes:
        // 20: XML Error, 21: Auth Error, 22: User Inactive, 23: Invalid Originator (Header)
        // 24: Empty Message/Number, 25: Date Error
        if (['20', '21', '22', '23', '24', '25'].includes(result)) {
            const errorMap = {
                '20': 'XML Error (Post Data Invalid)',
                '21': 'Authentication Failed (Wrong Username/Password)',
                '22': 'User Inactive',
                '23': 'Invalid Originator (SMS Header Mismatch)',
                '24': 'Empty Message or Number'
            };
            const errorMsg = errorMap[result] || `Unknown Error (${result})`;
            console.error(`[MutluCell] SMS Failed: ${errorMsg}`);
            throw new Error(`SMS Provider Error: ${errorMsg}`);
        }

        return result;

    } catch (error) {
        console.error('[MutluCell] Error sending SMS:', error.message);
        // We don't throw here to prevent crashing the flow, but we might want to know if it failed.
        // For now, logging is enough as this is "fire and forget" or we can return false.
        return null;
    }
}

module.exports = { sendSms };
