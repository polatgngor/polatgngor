// Sequelize model for drivers table adapted to existing DB schema
// The DB uses `user_id` as the primary key (no separate `id` column).
const { DataTypes } = require('sequelize');

module.exports = (sequelize) =>
  sequelize.define(
    'Driver',
    {
      // Use user_id as the primary key to match existing DB (no 'id' column)
      user_id: {
        type: DataTypes.BIGINT.UNSIGNED,
        allowNull: false,
        primaryKey: true
      },
      driver_card_number: { type: DataTypes.STRING(100), allowNull: true },
      vehicle_plate: { type: DataTypes.STRING(20), allowNull: true },
      vehicle_brand: { type: DataTypes.STRING(50), allowNull: true },
      vehicle_model: { type: DataTypes.STRING(50), allowNull: true },
      vehicle_type: { type: DataTypes.ENUM('sari', 'turkuaz', 'vip', '8+1'), allowNull: false, defaultValue: 'sari' },
      vehicle_license_file: { type: DataTypes.STRING(255), allowNull: true },
      working_region: { type: DataTypes.ENUM('Anadolu', 'Avrupa'), allowNull: true },
      working_district: { type: DataTypes.STRING(100), allowNull: true },
      ibb_card_file: { type: DataTypes.STRING(255), allowNull: true },
      driving_license_file: { type: DataTypes.STRING(255), allowNull: true },
      identity_card_file: { type: DataTypes.STRING(255), allowNull: true },
      status: { type: DataTypes.ENUM('pending', 'approved', 'rejected', 'banned'), defaultValue: 'pending' },
      is_available: { type: DataTypes.BOOLEAN, defaultValue: false }
    },
    {
      tableName: 'drivers',
      timestamps: true,
      createdAt: 'created_at',
      updatedAt: 'updated_at',
      underscored: true,
      // Performance: Indices for matchmaking
      indexes: [
        { fields: ['vehicle_type'] },
        { fields: ['is_available'] },
        { fields: ['working_region'] },
        { fields: ['vehicle_type', 'is_available'] } // Critical for finding drivers
      ]
    }
  );