const Joi = require('joi');

/**
 * Middleware to validate request data against a Joi schema
 * @param {Object} schema - Joi schema object
 * @param {string} source - 'body', 'query', or 'params' (default: 'body')
 */
const validate = (schema, source = 'body') => {
    return (req, res, next) => {
        const data = req[source];
        const { error } = schema.validate(data, { abortEarly: false });

        if (error) {
            const errorMessage = error.details.map((detail) => detail.message).join(', ');
            return res.status(400).json({
                success: false,
                message: 'Validation Error',
                errors: errorMessage
            });
        }

        next();
    };
};

module.exports = validate;
