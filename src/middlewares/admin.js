module.exports = function adminMiddleware(req, res, next) {
  try {
    const user = req.user;
    if (!user || user.role !== 'admin') {
      return res.status(403).json({ message: 'Admin access required' });
    }
    return next();
  } catch (err) {
    return res.status(500).json({ message: 'Server error' });
  }
};