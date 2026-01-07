import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:dio/dio.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/foundation.dart';
import '../constants/app_constants.dart';

part 'directions_service.g.dart';

@Riverpod(keepAlive: true)
DirectionsService directionsService(Ref ref) => DirectionsService();

class DirectionsService {
  final Dio _dio = Dio();

  Future<List<LatLng>> getRoute(LatLng start, LatLng end) async {
    try {
      final response = await _dio.get(
        'https://maps.googleapis.com/maps/api/directions/json',
        queryParameters: {
          'origin': '${start.latitude},${start.longitude}',
          'destination': '${end.latitude},${end.longitude}',
          'key': AppConstants.googleMapsApiKey,
        },
      );

      if (response.statusCode == 200 && response.data['routes'].isNotEmpty) {
        final encoded = response.data['routes'][0]['overview_polyline']['points'];
        return _decodePolyline(encoded);
      }
      return [];
    } catch (e) {
      debugPrint('Directions Error: $e');
      return [];
    }
  }

  /// Returns route info including polyline points, distance (meters), and duration (seconds)
  Future<Map<String, dynamic>?> getRouteWithInfo(LatLng start, LatLng end) async {
    try {
      final response = await _dio.get(
        'https://maps.googleapis.com/maps/api/directions/json',
        queryParameters: {
          'origin': '${start.latitude},${start.longitude}',
          'destination': '${end.latitude},${end.longitude}',
          'key': AppConstants.googleMapsApiKey,
        },
      );

      if (response.statusCode == 200 && response.data['routes'].isNotEmpty) {
        final route = response.data['routes'][0];
        final leg = route['legs'][0];
        final encoded = route['overview_polyline']['points'];
        
        return {
          'points': _decodePolyline(encoded),
          'distance_meters': leg['distance']['value'] as int, // meters
          'duration_seconds': leg['duration']['value'] as int, // seconds
        };
      }
      return null;
    } catch (e) {
      debugPrint('Directions Error: $e');
      return null;
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
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

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }
}
