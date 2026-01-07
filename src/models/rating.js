const { DataTypes } = require('sequelize');

module.exports = (sequelize) =>
  sequelize.define(
    'Rating',
    {
      id: { type: DataTypes.BIGINT.UNSIGNED, autoIncrement: true, primaryKey: true },
      ride_id: { type: DataTypes.BIGINT.UNSIGNED, allowNull: false },
      rater_id: { type: DataTypes.BIGINT.UNSIGNED, allowNull: false },
      rated_id: { type: DataTypes.BIGINT.UNSIGNED, allowNull: false },
      stars: { type: DataTypes.TINYINT.UNSIGNED, allowNull: false },
      comment: { type: DataTypes.TEXT, allowNull: true }
    },
    {
      tableName: 'ratings',
      timestamps: true,
      createdAt: 'created_at',
      updatedAt: false,
      underscored: true
    }
  );