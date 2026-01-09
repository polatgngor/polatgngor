import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../auth/data/auth_service.dart';

part 'ride_repository.g.dart';

@Riverpod(keepAlive: true)
DriverRideRepository driverRideRepository(Ref ref) {
  return DriverRideRepository(ref);
}

class DriverRideRepository {
  final Ref _ref;
  final Dio _dio = Dio();

  DriverRideRepository(this._ref);

  Future<void> ratePassenger(String rideId, int stars, String? comment) async {
    final token = await _ref.read(authServiceProvider).getToken();
    if (token == null) throw Exception('No token');

    try {
      await _dio.post(
        '${AppConstants.apiUrl}/rides/$rideId/rate',
        data: {
          'stars': stars,
          'comment': comment,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } on DioException catch (e) {
      throw e.response?.data['message'] ?? 'Rating failed';
    }
  }

  Future<void> updatePlate(String plate) async {
    final token = await _ref.read(authServiceProvider).getToken();
    if (token == null) throw Exception('No token');

    try {
      await _dio.put(
        '${AppConstants.apiUrl}/driver/plate',
        data: {'vehicle_plate': plate},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } on DioException catch (e) {
      throw e.response?.data['message'] ?? 'Failed to update plate';
    }
  }

  Future<Map<String, dynamic>> getEarnings({DateTime? from, DateTime? to, String? period}) async {
    final token = await _ref.read(authServiceProvider).getToken();
    if (token == null) throw Exception('No token');

    try {
      final Map<String, dynamic> queryParams = {};
      if (period != null) {
        queryParams['period'] = period;
      } else {
        if (from != null) queryParams['from'] = from.toUtc().toIso8601String();
        if (to != null) queryParams['to'] = to.toUtc().toIso8601String();
      }

      final response = await _dio.get(
        '${AppConstants.apiUrl}/driver/earnings',
        queryParameters: queryParams,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return {
        'total': double.tryParse((response.data['total'] ?? 0).toString()) ?? 0.0,
        'count': int.tryParse((response.data['count'] ?? 0).toString()) ?? 0,
        'ref_count': int.tryParse((response.data['ref_count'] ?? 0).toString()) ?? 0,
        'level': int.tryParse((response.data['level'] ?? 1).toString()) ?? 1,
        'rating': (response.data['rating'] ?? '5.0').toString(),
        'rides': response.data['rides'] ?? [], // Pass rides list through
      };
    } on DioException catch (e) {
      throw e.response?.data['message'] ?? 'Failed to fetch earnings';
    }
  }
  Future<Map<String, dynamic>?> getActiveRide() async {
    final token = await _ref.read(authServiceProvider).getToken();
    if (token == null) throw Exception('No token');

    try {
      final response = await _dio.get(
        '${AppConstants.apiUrl}/rides/active',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      
      if (response.data['active'] == true) {
        return {
          'ride': response.data['ride'],
          'driver': response.data['driver'], // Though for driver app, driver info is self
        };
      }
      return null;
    } on DioException catch (e) {
      return null;
    }
  }

  Future<void> cancelRide(String rideId, String reason) async {
    final token = await _ref.read(authServiceProvider).getToken();
    if (token == null) throw Exception('No token');

    try {
      await _dio.post(
        '${AppConstants.apiUrl}/rides/$rideId/cancel',
        data: {'reason': reason, 'ride_id': rideId},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } on DioException catch (e) {
      throw e.response?.data['message'] ?? 'Cancellation failed';
    }
  }

  Future<List<Map<String, dynamic>>> getMessages(String rideId) async {
    final token = await _ref.read(authServiceProvider).getToken();
    if (token == null) throw Exception('No token');

    try {
      final response = await _dio.get(
        '${AppConstants.apiUrl}/rides/$rideId/messages',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return List<Map<String, dynamic>>.from(response.data['messages'] ?? []);
    } on DioException catch (e) {
      throw e.response?.data['message'] ?? 'Failed to fetch messages';
    }
  }
}
