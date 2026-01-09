const { DataTypes } = require('sequelize');

module.exports = (sequelize) =>
    sequelize.define(
        'SavedPlace',
        {
            id: { type: DataTypes.BIGINT.UNSIGNED, autoIncrement: true, primaryKey: true },
            user_id: { type: DataTypes.BIGINT.UNSIGNED, allowNull: false },

            title: { type: DataTypes.STRING(64), allowNull: false }, // "Home", "Work", "My Cafe"
            address: { type: DataTypes.STRING(255), allowNull: false },
            lat: { type: DataTypes.DOUBLE, allowNull: false },
            lng: { type: DataTypes.DOUBLE, allowNull: false },

            icon: { type: DataTypes.STRING(32), allowNull: true, defaultValue: 'place' } // To map to mobile icons
        },
        {
            tableName: 'saved_places',
            timestamps: true,
            createdAt: 'created_at',
            updatedAt: 'updated_at',
            underscored: true
        }
    );
