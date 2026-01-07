const { DataTypes } = require('sequelize');

module.exports = (sequelize) =>
  sequelize.define(
    'Ride',
    {
      id: { type: DataTypes.BIGINT.UNSIGNED, autoIncrement: true, primaryKey: true },
      passenger_id: { type: DataTypes.BIGINT.UNSIGNED, allowNull: false },
      driver_id: { type: DataTypes.BIGINT.UNSIGNED, allowNull: true },
      start_lat: { type: DataTypes.DOUBLE, allowNull: false },
      start_lng: { type: DataTypes.DOUBLE, allowNull: false },
      start_address: { type: DataTypes.STRING(255), allowNull: true },
      end_lat: { type: DataTypes.DOUBLE, allowNull: true },
      end_lng: { type: DataTypes.DOUBLE, allowNull: true },
      end_address: { type: DataTypes.STRING(255), allowNull: true },

      // ENUM ve NOT NULL: DB ile uyumlu
      vehicle_type: {
        type: DataTypes.ENUM('sari', 'turkuaz', 'vip', '8+1'),
        allowNull: false
      },

      options: { type: DataTypes.JSON, allowNull: true },

      payment_method: {
        type: DataTypes.ENUM('pos', 'nakit'),
        allowNull: false
      },

      fare_estimate: { type: DataTypes.DECIMAL(10, 2), allowNull: true },
      fare_actual: { type: DataTypes.DECIMAL(10, 2), allowNull: true },
      code4: { type: DataTypes.STRING(4), allowNull: true },
      status: {
        type: DataTypes.ENUM('requested', 'assigned', 'started', 'completed', 'cancelled', 'auto_rejected'),
        defaultValue: 'requested'
      },
      cancel_reason: { type: DataTypes.STRING(255), allowNull: true },
      actual_route: { type: DataTypes.JSON, allowNull: true } // Stores array of {lat, lng, ts}
    },
    {
      tableName: 'rides',
      timestamps: true,
      createdAt: 'created_at',
      updatedAt: 'updated_at',
      underscored: true,
      // Performance: Add indices for frequently queried fields
      indexes: [
        { fields: ['status'] },
        { fields: ['driver_id'] },
        { fields: ['passenger_id'] },
        { fields: ['status', 'driver_id'] } // Composed index
      ]
    }
  );