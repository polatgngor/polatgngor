const express = require('express');
const router = express.Router();
const adminController = require('../controllers/adminController');
const auth = require('../middlewares/auth');
const admin = require('../middlewares/admin');

// All admin routes require auth + admin middleware
router.use(auth);
router.use(admin);

// GET /api/admin/drivers?status=pending
router.get('/drivers', adminController.listDrivers);

// POST /api/admin/drivers/:id/approve
router.post('/drivers/:id/approve', adminController.approveDriver);

// POST /api/admin/drivers/:id/reject
router.post('/drivers/:id/reject', adminController.rejectDriver);

// NEW: GET /api/admin/users/levels?role=driver|passenger|admin
router.get('/users/levels', adminController.listUserLevels);

module.exports = router;