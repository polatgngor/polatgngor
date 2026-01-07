import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/constants/app_constants.dart';

final directionsServiceProvider = Provider<DirectionsService>((ref) {
  return DirectionsService();
});

class RouteInfo {
  final List<LatLng> points;
  final int distanceMeters;
  final int durationSeconds;

  RouteInfo({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
  });
}

class DirectionsService {
  final Dio _dio = Dio();

  Future<RouteInfo?> getRoute(LatLng origin, LatLng destination) async {
    final String url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=${origin.latitude},${origin.longitude}&destination=${destination.latitude},${destination.longitude}&key=${AppConstants.googleMapsApiKey}';

    try {
      final response = await _dio.get(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = response.data;
        
        if ((data['routes'] as List).isEmpty) return null;

        final route = data['routes'][0];
        final String encodedPolyline = route['overview_polyline']['points'];
        final legs = route['legs'][0];
        final distance = legs['distance']['value'] as int;
        final duration = legs['duration']['value'] as int;

        return RouteInfo(
          points: _decodePolyline(encodedPolyline),
          distanceMeters: distance,
          durationSeconds: duration,
        );
      } else {
        throw Exception('Failed to load directions');
      }
    } catch (e) {
      throw Exception('Error fetching directions: $e');
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> poly = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      poly.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return poly;
  }
}
