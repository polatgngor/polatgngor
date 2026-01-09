/**
 * Censors a name to protect privacy (e.g., "Ahmet Yılmaz" -> "A**** Y****")
 * @param {string} firstName 
 * @param {string} lastName 
 * @returns {string} Censored full name
 */
exports.censorName = (firstName, lastName) => {
    const censor = (str) => {
        if (!str || str.length < 2) return str;
        return str[0] + '****';
    };

    const f = censor(firstName);
    const l = censor(lastName);

    return `${f} ${l}`.trim();
};
