const { DataTypes } = require('sequelize');

module.exports = (sequelize) =>
  sequelize.define(
    'User',
    {
      id: { type: DataTypes.BIGINT.UNSIGNED, autoIncrement: true, primaryKey: true },
      role: {
        type: DataTypes.ENUM('passenger', 'driver', 'admin'),
        allowNull: false,
        defaultValue: 'passenger'
      },

      // DB'de NOT NULL, burada da zorunlu yapıyoruz
      first_name: { type: DataTypes.STRING(100), allowNull: false },
      last_name: { type: DataTypes.STRING(100), allowNull: false },

      phone: { type: DataTypes.STRING(32), allowNull: false, unique: true },
      // password_hash removed
      profile_picture: { type: DataTypes.STRING(255), allowNull: true },
      is_active: { type: DataTypes.BOOLEAN, defaultValue: true },

      // referral / level fields
      ref_code: { type: DataTypes.STRING(32), allowNull: true, unique: true },
      referrer_id: { type: DataTypes.BIGINT.UNSIGNED, allowNull: true },
      ref_count: { type: DataTypes.INTEGER, allowNull: false, defaultValue: 0 },
      level: {
        type: DataTypes.ENUM('standard', 'silver', 'gold', 'platinum'),
        allowNull: false,
        defaultValue: 'standard'
      },
      last_announcement_view_at: { type: DataTypes.DATE, allowNull: true },

      // FCM Token removed (using UserDevice table)
    },
    {
      tableName: 'users',
      timestamps: true,
      createdAt: 'created_at',
      updatedAt: 'updated_at',
      underscored: true
    }
  );