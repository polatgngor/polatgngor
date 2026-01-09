const TR_OFFSET = 3 * 60 * 60 * 1000;

/**
 * Formats a Date string or object to Turkey Time (UTC+3) string.
 * Format: DD.MM.YYYY HH:mm
 * @param {string|Date} dateInput 
 * @returns {string} Formatted date string
 */
function formatTurkeyDate(dateInput) {
    if (!dateInput) return '';

    // Create Date object (handling ISO strings correctly)
    // If string doesn't end in Z and is ISO-like, it might be parsed as local, 
    // but Sequelize usually returns ISO UTC strings like "2023-12-09T08:30:00.000Z".
    const utcDate = new Date(dateInput);

    if (isNaN(utcDate.getTime())) return '';

    // Add offset to get "Local Turkey Time" represented in a Date object
    // Note: This Date object will technically represent a different moment in time relative to epoch 
    // if interpreted as UTC, but its getters (getUTCDate etc) will return the correct Turkey numbers.
    const trDate = new Date(utcDate.getTime() + TR_OFFSET);

    const day = trDate.getUTCDate().toString().padStart(2, '0');
    const month = (trDate.getUTCMonth() + 1).toString().padStart(2, '0');
    const year = trDate.getUTCFullYear();
    const hour = trDate.getUTCHours().toString().padStart(2, '0');
    const minute = trDate.getUTCMinutes().toString().padStart(2, '0');

    return `${day}.${month}.${year} ${hour}:${minute}`;
}

module.exports = { formatTurkeyDate, TR_OFFSET };
