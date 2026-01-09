const { DataTypes } = require('sequelize');

module.exports = (sequelize) =>
    sequelize.define(
        'VehicleChangeRequest',
        {
            driver_id: {
                type: DataTypes.BIGINT.UNSIGNED,
                allowNull: false
            },
            request_type: {
                type: DataTypes.ENUM('change_taxi', 'update_info'),
                allowNull: false
            },
            // New Vehicle Data
            new_plate: { type: DataTypes.STRING(20), allowNull: true },
            new_brand: { type: DataTypes.STRING(50), allowNull: true },
            new_model: { type: DataTypes.STRING(50), allowNull: true },
            new_vehicle_type: { type: DataTypes.STRING(20), allowNull: true },

            // Files (paths)
            new_vehicle_license_file: { type: DataTypes.STRING(255), allowNull: true },
            new_ibb_card_file: { type: DataTypes.STRING(255), allowNull: true },
            new_driving_license_file: { type: DataTypes.STRING(255), allowNull: true },
            new_identity_card_file: { type: DataTypes.STRING(255), allowNull: true },

            status: {
                type: DataTypes.ENUM('pending', 'approved', 'rejected'),
                defaultValue: 'pending'
            },
            admin_note: { type: DataTypes.STRING, allowNull: true }
        },
        {
            tableName: 'vehicle_change_requests',
            timestamps: true,
            underscored: true
        }
    );
