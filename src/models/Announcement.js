const { DataTypes } = require('sequelize');

module.exports = (sequelize) => {
    return sequelize.define('Announcement', {
        id: {
            type: DataTypes.BIGINT.UNSIGNED,
            autoIncrement: true,
            primaryKey: true
        },
        title: {
            type: DataTypes.STRING(255),
            allowNull: false
        },
        body: {
            type: DataTypes.TEXT,
            allowNull: false
        },
        target_app: {
            type: DataTypes.ENUM('passenger', 'driver', 'both'),
            allowNull: false,
            defaultValue: 'both'
        },
        is_active: {
            type: DataTypes.BOOLEAN,
            defaultValue: true
        },
        expires_at: {
            type: DataTypes.DATE,
            allowNull: true
        },
        created_at: {
            type: DataTypes.DATE,
            defaultValue: DataTypes.NOW
        }
    }, {
        tableName: 'announcements',
        underscored: true,
        timestamps: true, // adds createdAt, updatedAt
        updatedAt: 'updated_at',
        createdAt: 'created_at'
    });
};
