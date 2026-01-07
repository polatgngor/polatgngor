import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/services/api_service.dart';

part 'support_service.g.dart';

@Riverpod(keepAlive: true)
SupportService supportService(Ref ref) {
  final apiService = ref.watch(apiServiceProvider);
  return SupportService(apiService);
}

@riverpod
Future<List<dynamic>> myTickets(Ref ref) async {
  final service = ref.watch(supportServiceProvider);
  return service.getMyTickets();
}

class SupportService {
  final ApiService _apiService;

  SupportService(this._apiService);

  Future<List<dynamic>> getMyTickets() async {
    try {
      final response = await _apiService.get('/support/my-tickets');
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> createTicket(String subject, String message) async {
    try {
      await _apiService.post('/support/create', data: {
        'subject': subject,
        'message': message,
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<List<dynamic>> getMessages(int ticketId) async {
    try {
      final response = await _apiService.get('/support/$ticketId/messages');
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> sendMessage(int ticketId, String message) async {
    try {
      await _apiService.post('/support/$ticketId/message', data: {
        'message': message,
      });
    } catch (e) {
      rethrow;
    }
  }
}
