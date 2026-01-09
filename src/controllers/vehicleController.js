const vehicleData = require('../data/vehicleData');

exports.getVehicleData = (req, res) => {
    try {
        res.status(200).json({
            success: true,
            data: vehicleData
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            message: 'Araç verileri alınamadı',
            error: error.message
        });
    }
};
