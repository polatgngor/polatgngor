const express = require('express');
const router = express.Router();
const savedPlaceController = require('../controllers/savedPlaceController');
const authenticateToken = require('../middlewares/auth');

router.use(authenticateToken);

router.get('/', savedPlaceController.list);
router.post('/', savedPlaceController.create);
router.delete('/:id', savedPlaceController.remove);

module.exports = router;
