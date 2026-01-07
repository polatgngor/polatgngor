const { DataTypes } = require('sequelize');

module.exports = (sequelize) =>
  sequelize.define(
    'Complaint',
    {
      id: { type: DataTypes.BIGINT.UNSIGNED, autoIncrement: true, primaryKey: true },
      ride_id: { type: DataTypes.BIGINT.UNSIGNED, allowNull: true },
      complainer_id: { type: DataTypes.BIGINT.UNSIGNED, allowNull: false },
      accused_id: { type: DataTypes.BIGINT.UNSIGNED, allowNull: true },
      type: { type: DataTypes.STRING(100), allowNull: true },
      description: { type: DataTypes.TEXT, allowNull: true },
      status: { type: DataTypes.ENUM('open','reviewing','closed'), defaultValue: 'open' }
    },
    {
      tableName: 'complaints',
      timestamps: true,
      createdAt: 'created_at',
      updatedAt: false,
      underscored: true
    }
  );