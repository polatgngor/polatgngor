const express = require('express');
const router = express.Router();
const { updatePlate, getEarnings, requestVehicleChange, getChangeRequests, approveTestAccount } = require('../controllers/driverController');
const auth = require('../middlewares/auth');

const multer = require('multer');
const path = require('path');
const fs = require('fs');

// Driver Uploads Config
const storage = multer.diskStorage({
    destination: function (req, file, cb) {
        const uploadDir = 'uploads/driver_requests/';
        if (!fs.existsSync(uploadDir)) {
            fs.mkdirSync(uploadDir, { recursive: true });
        }
        cb(null, uploadDir);
    },
    filename: function (req, file, cb) {
        const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
        const ext = path.extname(file.originalname);
        cb(null, 'req-' + uniqueSuffix + ext);
    }
});
const upload = multer({ storage: storage });

const requestUploads = upload.fields([
    { name: 'new_vehicle_license', maxCount: 1 },
    { name: 'new_ibb_card', maxCount: 1 },
    { name: 'new_driving_license', maxCount: 1 },
    { name: 'new_identity_card', maxCount: 1 }
]);

router.put('/plate', auth, updatePlate);
router.get('/earnings', auth, getEarnings);

// Change Requests
router.post('/change-request', auth, requestUploads, requestVehicleChange);
router.get('/change-requests', auth, getChangeRequests);

// Test Account Trigger
router.post('/test-approve', auth, approveTestAccount);

module.exports = router;