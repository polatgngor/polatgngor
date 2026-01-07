import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(ref.read(apiClientProvider).client);
});

class NotificationRepository {
  final Dio _dio;

  NotificationRepository(this._dio);

  Future<List<Map<String, dynamic>>> getNotifications({int page = 1}) async {
    try {
      final response = await _dio.get('/notifications', queryParameters: {'page': page});
      return List<Map<String, dynamic>>.from(response.data['notifications']);
    } on DioException catch (e) {
      throw e.response?.data['message'] ?? 'Failed to fetch notifications';
    }
  }

  Future<void> markAsRead(int id) async {
    try {
      await _dio.put('/notifications/$id/read');
    } on DioException catch (e) {
      throw e.response?.data['message'] ?? 'Failed to mark as read';
    }
  }
}
