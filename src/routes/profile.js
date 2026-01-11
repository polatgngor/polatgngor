const express = require('express');
const router = express.Router();
const profileController = require('../controllers/profileController');
const authMiddleware = require('../middlewares/auth');
const multer = require('multer');
const path = require('path');
const fs = require('fs');

// Configure Multer
const storage = multer.diskStorage({
    destination: function (req, file, cb) {
        const uploadDir = 'uploads/';
        // Create directory if it doesn't exist
        if (!fs.existsSync(uploadDir)) {
            fs.mkdirSync(uploadDir, { recursive: true });
        }
        cb(null, uploadDir);
    },
    filename: function (req, file, cb) {
        // unique filename: userId-timestamp-ext
        const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
        const ext = path.extname(file.originalname);
        cb(null, req.user.userId + '-' + uniqueSuffix + ext);
    }
});

const upload = multer({ storage: storage });

router.get('/', authMiddleware, profileController.getProfile);
router.put('/', authMiddleware, profileController.updateProfile);
router.post('/change-phone', authMiddleware, profileController.changePhone);
router.post('/password', authMiddleware, profileController.changePassword);
router.post('/logout', authMiddleware, profileController.logout);
router.post('/delete', authMiddleware, profileController.deleteAccount);
router.post('/device', authMiddleware, profileController.registerDevice);
router.post('/upload-photo', authMiddleware, upload.single('photo'), profileController.uploadPhoto);

module.exports = router;