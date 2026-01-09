const axios = require('axios');

const GOOGLE_API_KEY = process.env.GOOGLE_MAPS_API_KEY;

// İstanbul taksi tarifeleri
const TARIFFS = {
  sari: {
    base: 54.5,
    perKm: 36.3,
    minFare: 175.0
  },
  turkuaz: {
    base: 62.61,
    perKm: 41.74,
    minFare: 200.0
  },
  vip: {
    base: 92.56,
    perKm: 61.7,
    minFare: 300.0
  },
  '8+1': {
    base: 70.78,
    perKm: 47.19,
    minFare: 225.0
  }
};

async function getRouteDistanceMeters(startLat, startLng, endLat, endLng) {
  if (!GOOGLE_API_KEY) {
    console.warn('[fareService] GOOGLE_MAPS_API_KEY tanımlı değil, mesafe hesaplanamayacak');
    return null;
  }

  try {
    const origin = `${startLat},${startLng}`;
    const destination = `${endLat},${endLng}`;

    const url = 'https://maps.googleapis.com/maps/api/directions/json';

    const res = await axios.get(url, {
      params: {
        origin,
        destination,
        key: GOOGLE_API_KEY,
        mode: 'driving'
      },
      timeout: 5000
    });

    if (!res.data || res.data.status !== 'OK' || !res.data.routes || res.data.routes.length === 0) {
      console.warn(
        '[fareService] Directions response OK değil:',
        res.data && res.data.status,
        res.data && res.data.error_message
      );
      return null;
    }

    const leg = res.data.routes[0].legs && res.data.routes[0].legs[0];
    if (!leg || !leg.distance || typeof leg.distance.value !== 'number') {
      console.warn('[fareService] Directions response leg/distance yok');
      return null;
    }

    const distanceMeters = leg.distance.value; // metre
    const durationSeconds = leg.duration ? leg.duration.value : 0; // saniye
    const polyline = res.data.routes[0].overview_polyline ? res.data.routes[0].overview_polyline.points : null;

    return { distanceMeters, durationSeconds, polyline };
  } catch (err) {
    console.error('[fareService] Directions API çağrısı hata:', err.message || err);
    return null;
  }
}

function computeFareEstimate(vehicleType, distanceMeters) {
  if (!distanceMeters || distanceMeters <= 0) return null;

  const vt = vehicleType || 'sari';
  const tariff = TARIFFS[vt];

  if (!tariff) {
    console.warn('[fareService] Tarif bulunamadı, vehicleType=', vehicleType, 'vt=', vt);
    return null;
  }

  const distanceKm = distanceMeters / 1000;

  const rawFare = tariff.base + distanceKm * tariff.perKm;
  const fare = Math.max(rawFare, tariff.minFare);

  return Math.round(fare * 100) / 100;
}

module.exports = {
  getRouteDistanceMeters,
  computeFareEstimate
};