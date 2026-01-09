const { DataTypes } = require('sequelize');

module.exports = (sequelize) =>
  sequelize.define(
    'UserDevice',
    {
      id: { type: DataTypes.BIGINT.UNSIGNED, autoIncrement: true, primaryKey: true },
      user_id: { type: DataTypes.BIGINT.UNSIGNED, allowNull: false },
      device_token: { type: DataTypes.STRING(255), allowNull: false },
      platform: {
        type: DataTypes.ENUM('android', 'ios', 'web'),
        allowNull: false,
        defaultValue: 'android'
      },
      created_at: { type: DataTypes.DATE, allowNull: false, defaultValue: DataTypes.NOW }
    },
    {
      tableName: 'user_devices',
      timestamps: false,
      underscored: true
    }
  );