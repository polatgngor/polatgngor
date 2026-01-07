import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/foundation.dart';
import '../constants/app_constants.dart';

final directionsServiceProvider = Provider((ref) => DirectionsService());

class DirectionsService {
  final Dio _dio = Dio();

  Future<Map<String, dynamic>> getRoute(LatLng start, LatLng end) async {
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
        final encoded = route['overview_polyline']['points'];
        final leg = route['legs'][0];
        
        return {
          'points': _decodePolyline(encoded),
          'distance': leg['distance']['text'],
          'duration': leg['duration']['text'],
          'distance_value': leg['distance']['value'], // meters
          'duration_value': leg['duration']['value'], // seconds
        };
      }
      return {};
    } catch (e) {
      debugPrint('Directions Error: $e');
      return {};
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
