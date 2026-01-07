import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../../../core/constants/app_constants.dart';
import 'saved_place_model.dart'; // Import the model we just created

final savedPlacesServiceProvider = Provider<SavedPlacesService>((ref) {
  return SavedPlacesService(ref.read(apiClientProvider).client);
});

class SavedPlacesService {
  final Dio _dio;

  SavedPlacesService(this._dio);

  Future<List<SavedPlace>> getSavedPlaces() async {
    try {
      final response = await _dio.get('${AppConstants.apiUrl}/saved-places');
      if (response.statusCode == 200) {
        final list = response.data['places'] as List;
        return list.map((e) => SavedPlace.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      throw Exception('Failed to load saved places: $e');
    }
  }

  Future<SavedPlace> addSavedPlace({
    required String title,
    required String address,
    required double lat,
    required double lng,
    String icon = 'place',
  }) async {
    try {
      final response = await _dio.post(
        '${AppConstants.apiUrl}/saved-places',
        data: {
          'title': title,
          'address': address,
          'lat': lat,
          'lng': lng,
          'icon': icon,
        },
      );
      if (response.statusCode == 201) {
        return SavedPlace.fromJson(response.data['place']);
      }
      throw Exception('Failed to add place');
    } catch (e) {
      throw Exception('Failed to add saved place: $e');
    }
  }

  Future<void> deleteSavedPlace(String id) async {
    try {
      await _dio.delete('${AppConstants.apiUrl}/saved-places/$id');
    } catch (e) {
      throw Exception('Failed to delete saved place: $e');
    }
  }
}
