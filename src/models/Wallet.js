const { DataTypes } = require('sequelize');

module.exports = (sequelize) =>
    sequelize.define(
        'Wallet',
        {
            id: { type: DataTypes.BIGINT.UNSIGNED, autoIncrement: true, primaryKey: true },
            user_id: { type: DataTypes.BIGINT.UNSIGNED, allowNull: false, unique: true },
            balance: { type: DataTypes.DECIMAL(10, 2), allowNull: false, defaultValue: 0.00 },
            total_earnings: { type: DataTypes.DECIMAL(10, 2), allowNull: false, defaultValue: 0.00 },
            currency: { type: DataTypes.STRING(3), allowNull: false, defaultValue: 'TRY' }
        },
        {
            tableName: 'wallets',
            timestamps: true,
            createdAt: 'created_at',
            updatedAt: 'updated_at',
            underscored: true
        }
    );
