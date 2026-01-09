import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/services/ringtone_service.dart';

part 'incoming_requests_provider.g.dart';

@Riverpod(keepAlive: true)
class IncomingRequests extends _$IncomingRequests {
  @override
  List<Map<String, dynamic>> build() {
    return [];
  }

  void addRequest(Map<String, dynamic> request) {
    if (!state.any((r) => r['ride_id'] == request['ride_id'])) {
      state = [...state, request];
      
      // Trigger Ringtone
      ref.read(ringtoneServiceProvider).playRingtone();
    }
  }

  void removeRequest(String rideId) {
    state = state.where((r) => r['ride_id'].toString() != rideId).toList();
    
    // Stop if empty
    if (state.isEmpty) {
       ref.read(ringtoneServiceProvider).stopRingtone();
    }
  }

  void clearRequests() {
    state = [];
    ref.read(ringtoneServiceProvider).stopRingtone();
  }
}
