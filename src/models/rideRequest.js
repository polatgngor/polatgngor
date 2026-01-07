// Sequelize model for ride_requests table adapted to existing DB schema
// DB table columns: id, ride_id, driver_id, sent_at, driver_response, response_at, timeout
// There are no created_at/updated_at columns in the current dump, so timestamps are disabled.
const { DataTypes } = require('sequelize');

module.exports = (sequelize) =>
  sequelize.define(
    'RideRequest',
    {
      id: { type: DataTypes.BIGINT.UNSIGNED, autoIncrement: true, primaryKey: true },
      ride_id: { type: DataTypes.BIGINT.UNSIGNED, allowNull: false },
      driver_id: { type: DataTypes.BIGINT.UNSIGNED, allowNull: false },
      sent_at: { type: DataTypes.DATE, allowNull: true },
      driver_response: { type: DataTypes.ENUM('no_response','accepted','rejected'), allowNull: true, defaultValue: 'no_response' },
      response_at: { type: DataTypes.DATE, allowNull: true },
      timeout: { type: DataTypes.BOOLEAN, defaultValue: false }
    },
    {
      tableName: 'ride_requests',
      timestamps: false, // match existing DB (no created_at/updated_at)
      underscored: true
    }
  );