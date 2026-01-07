import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_constants.dart';

final placesServiceProvider = Provider<PlacesService>((ref) {
  return PlacesService();
});

class PlacePrediction {
  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;

  PlacePrediction({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
  });

  factory PlacePrediction.fromJson(Map<String, dynamic> json) {
    final structuredFormatting = json['structured_formatting'] ?? {};
    return PlacePrediction(
      placeId: json['place_id'] ?? '',
      description: json['description'] ?? '',
      mainText: structuredFormatting['main_text'] ?? '',
      secondaryText: structuredFormatting['secondary_text'] ?? '',
    );
  }
}

class PlaceDetails {
  final String placeId;
  final double lat;
  final double lng;
  final String address;

  PlaceDetails({
    required this.placeId,
    required this.lat,
    required this.lng,
    required this.address,
  });

  factory PlaceDetails.fromJson(Map<String, dynamic> json) {
    final result = json['result'];
    final geometry = result['geometry'];
    final location = geometry['location'];
    return PlaceDetails(
      placeId: result['place_id'],
      lat: location['lat'],
      lng: location['lng'],
      address: result['formatted_address'] ?? result['name'],
    );
  }
}

class PlacesService {
  final Dio _dio = Dio();
  final Uuid _uuid = const Uuid();
  String? _sessionToken;

  String getSessionToken() {
    _sessionToken ??= _uuid.v4();
    return _sessionToken!;
  }

  void clearSessionToken() {
    _sessionToken = null;
  }

  Future<List<PlacePrediction>> getPredictions(String input) async {
    if (input.isEmpty) return [];

    final token = getSessionToken();
    final url = 'https://maps.googleapis.com/maps/api/place/autocomplete/json';

    try {
      final response = await _dio.get(url, queryParameters: {
        'input': input,
        'key': AppConstants.googleMapsApiKey,
        'sessiontoken': token,
        'language': 'tr',
        // 'components': 'country:tr', // REMOVED to allow global search for Google Play
      });

      if (response.statusCode == 200) {
        final predictions = response.data['predictions'] as List;
        return predictions.map((e) => PlacePrediction.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Places Error: $e');
      return [];
    }
  }

  Future<PlaceDetails?> getPlaceDetails(String placeId) async {
    final token = getSessionToken();
    final url = 'https://maps.googleapis.com/maps/api/place/details/json';

    try {
      final response = await _dio.get(url, queryParameters: {
        'place_id': placeId,
        'key': AppConstants.googleMapsApiKey,
        'sessiontoken': token,
        'fields': 'place_id,geometry,formatted_address,name',
      });

      if (response.statusCode == 200) {
        final result = response.data;
        // Clear session token after a successful selection (Place Details call)
        clearSessionToken();
        return PlaceDetails.fromJson(result);
      }
      return null;
    } catch (e) {
      debugPrint('Place Details Error: $e');
      return null;
    }
  }

  Future<String?> getAddressFromCoordinates(double lat, double lng) async {
    final url = 'https://maps.googleapis.com/maps/api/geocode/json';

    try {
      final response = await _dio.get(url, queryParameters: {
        'latlng': '$lat,$lng',
        'key': AppConstants.googleMapsApiKey,
        'language': 'tr',
      });

      if (response.statusCode == 200) {
        final results = response.data['results'] as List;
        if (results.isNotEmpty) {
          // Prioritize street address or route over Plus Code
          for (var result in results) {
            final types = List<String>.from(result['types'] ?? []);
            if (types.contains('street_address') || 
                types.contains('route') || 
                types.contains('premise') ||
                types.contains('subpremise') ||
                types.contains('establishment')) {
              return result['formatted_address'];
            }
          }
          // Fallback to first result if no preferred type found
          return results.first['formatted_address'];
        }
      }
      return null;
    } catch (e) {
      debugPrint('Geocoding Error: $e');
      return null;
    }
  }
}
