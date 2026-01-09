const { DataTypes } = require('sequelize');

module.exports = (sequelize) =>
  sequelize.define(
    'Notification',
    {
      id: { type: DataTypes.BIGINT.UNSIGNED, autoIncrement: true, primaryKey: true },
      user_id: { type: DataTypes.BIGINT.UNSIGNED, allowNull: false },
      type: { type: DataTypes.STRING(100), allowNull: false },
      title: { type: DataTypes.STRING(255), allowNull: true },
      body: { type: DataTypes.TEXT, allowNull: true },
      data: { type: DataTypes.JSON, allowNull: true },
      is_read: { type: DataTypes.BOOLEAN, defaultValue: false }
    },
    {
      tableName: 'notifications',
      timestamps: true,
      createdAt: 'created_at',
      updatedAt: false,
      underscored: true
    }
  );