import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';

final rideRepositoryProvider = Provider<RideRepository>((ref) {
  return RideRepository(ref.read(apiClientProvider).client);
});

class RideRepository {
  final Dio _dio;

  RideRepository(this._dio);

  Future<Map<String, dynamic>> createRide({
    required double startLat,
    required double startLng,
    required String startAddress,
    double? endLat,
    double? endLng,
    String? endAddress,
    required String vehicleType,
    required String paymentMethod,
    Map<String, dynamic>? options,
  }) async {
    try {
      final response = await _dio.post('/rides', data: {
        'start_lat': startLat,
        'start_lng': startLng,
        'start_address': startAddress,
        'end_lat': endLat,
        'end_lng': endLng,
        'end_address': endAddress,
        'vehicle_type': vehicleType,
        'payment_method': paymentMethod,
        'options': options,
      });
      return response.data;
    } on DioException catch (e) {
      throw e.response?.data['message'] ?? 'Ride creation failed';
    }
  }

  Future<void> cancelRide(String rideId, {String? reason}) async {
    try {
      await _dio.post('/rides/$rideId/cancel', data: {
        if (reason != null) 'reason': reason,
      });
    } on DioException catch (e) {
      throw e.response?.data['message'] ?? 'Cancellation failed';
    }
  }

  Future<void> rateRide(String rideId, int stars, String? comment) async {
    try {
      await _dio.post('/rides/$rideId/rate', data: {
        'stars': stars,
        'comment': comment,
      });
    } on DioException catch (e) {
      throw e.response?.data['message'] ?? 'Rating failed';
    }
  }

  Future<List<Map<String, dynamic>>> getMessages(String rideId) async {
    try {
      final response = await _dio.get('/rides/$rideId/messages');
      return List<Map<String, dynamic>>.from(response.data['messages']);
    } on DioException catch (e) {
      throw e.response?.data['message'] ?? 'Failed to fetch messages';
    }
  }
  Future<Map<String, dynamic>?> getActiveRide() async {
    try {
      final response = await _dio.get('/rides/active');
      if (response.data['active'] == true) {
        return {
          'ride': response.data['ride'],
          'driver': response.data['driver'],
        };
      }
      return null;
    } on DioException catch (e) {
      // If 404 or other error, assume no active ride
      return null;
    }
  }

  Future<Map<String, dynamic>> getFareEstimates({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) async {
    try {
      final response = await _dio.post('/rides/estimate', data: {
        'start_lat': startLat,
        'start_lng': startLng,
        'end_lat': endLat,
        'end_lng': endLng,
      });
      return response.data;
    } on DioException catch (e) {
      throw e.response?.data['message'] ?? 'Failed to fetch estimates';
    }
  }
}
