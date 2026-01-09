const { DataTypes } = require('sequelize');

module.exports = (sequelize) =>
  sequelize.define(
    'RideMessage',
    {
      id: { type: DataTypes.BIGINT.UNSIGNED, autoIncrement: true, primaryKey: true },
      ride_id: { type: DataTypes.BIGINT.UNSIGNED, allowNull: false },
      sender_id: { type: DataTypes.BIGINT.UNSIGNED, allowNull: false },
      message: { type: DataTypes.TEXT, allowNull: true },
      read_at: { type: DataTypes.DATE, allowNull: true }
    },
    {
      tableName: 'ride_messages',
      timestamps: true,
      createdAt: 'created_at',
      updatedAt: false,
      underscored: true
    }
  );