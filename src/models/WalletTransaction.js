const { DataTypes } = require('sequelize');

module.exports = (sequelize) =>
    sequelize.define(
        'WalletTransaction',
        {
            id: { type: DataTypes.BIGINT.UNSIGNED, autoIncrement: true, primaryKey: true },
            wallet_id: { type: DataTypes.BIGINT.UNSIGNED, allowNull: false },
            amount: { type: DataTypes.DECIMAL(10, 2), allowNull: false },
            type: {
                type: DataTypes.ENUM('ride_earnings', 'withdrawal', 'correction', 'other'),
                allowNull: false
            },
            reference_id: { type: DataTypes.BIGINT.UNSIGNED, allowNull: true },
            description: { type: DataTypes.STRING(255), allowNull: true }
        },
        {
            tableName: 'wallet_transactions',
            timestamps: true,
            createdAt: 'created_at',
            updatedAt: false, // No update necessary for transaction history
            underscored: true
        }
    );
