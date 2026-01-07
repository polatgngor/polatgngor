import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_client.dart';

final supportServiceProvider = Provider<SupportService>((ref) {
  final dio = ref.watch(apiClientProvider).client;
  return SupportService(dio);
});

final myTicketsProvider = FutureProvider.autoDispose((ref) async {
  final service = ref.watch(supportServiceProvider);
  return service.getMyTickets();
});

class SupportService {
  final Dio _dio;

  SupportService(this._dio);

  Future<List<dynamic>> getMyTickets() async {
    try {
      final response = await _dio.get('/support/my-tickets');
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> createTicket(String subject, String message) async {
    try {
      await _dio.post('/support/create', data: {
        'subject': subject,
        'message': message,
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<List<dynamic>> getMessages(int ticketId) async {
    try {
      final response = await _dio.get('/support/$ticketId/messages');
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> sendMessage(int ticketId, String message) async {
    try {
      await _dio.post('/support/$ticketId/message', data: {
        'message': message,
      });
    } catch (e) {
      rethrow;
    }
  }
}
