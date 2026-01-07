function computeLevelFromRefCount(refCount) {
  if (!refCount || refCount < 25) return 'standard';
  if (refCount < 50) return 'silver';
  if (refCount < 100) return 'gold';
  return 'platinum';
}

function getPassengerRadiusKmByLevel(level) {
  switch (level) {
    case 'silver':
      return 2.5;
    case 'gold':
      return 3.0;
    case 'platinum':
      return 3.5;
    default:
      return 2.0; // standard
  }
}

/**
 * Sürücü için öncelik (saniye cinsinden gecikme):
 * platinum  -> 0 sn (en erken)
 * gold      -> 1 sn
 * silver    -> 2 sn
 * standard  -> 3 sn (en geç)
 */
function getDriverPrioritySeconds(level) {
  switch (level) {
    case 'platinum':
      return 0;
    case 'gold':
      return 1;
    case 'silver':
      return 2;
    default:
      return 3; // standard
  }
}

function generateRefCode(userId) {
  return `TB${userId}`;
}

module.exports = {
  computeLevelFromRefCount,
  getPassengerRadiusKmByLevel,
  getDriverPrioritySeconds,
  generateRefCode
};