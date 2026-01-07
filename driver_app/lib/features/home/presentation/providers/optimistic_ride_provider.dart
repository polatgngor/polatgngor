import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/services/socket_service.dart';
import '../../../../core/services/notification_service.dart';
import 'incoming_requests_provider.dart';

part 'optimistic_ride_provider.g.dart';

class OptimisticState {
  final Map<String, dynamic>? activeRide;
  final bool isMatching;
  final bool isCompleting; // New flag to signal completion

  const OptimisticState({
    this.activeRide,
    this.isMatching = false,
    this.isCompleting = false,
  });

  OptimisticState copyWith({
    Map<String, dynamic>? activeRide,
    bool? isMatching,
    bool? isCompleting,
  }) {
    return OptimisticState(
      activeRide: activeRide ?? this.activeRide,
      isMatching: isMatching ?? this.isMatching,
      isCompleting: isCompleting ?? this.isCompleting,
    );
  }
}

@Riverpod(keepAlive: true)
class OptimisticRide extends _$OptimisticRide {
  @override
  OptimisticState build() {
    return const OptimisticState();
  }

  void completeRide() {
     state = state.copyWith(isCompleting: true, activeRide: null);
  }
  
  void startMatching() {
    state = state.copyWith(isMatching: true, isCompleting: false);
  }
  
  void cancelMatching() {
     state = state.copyWith(isMatching: false);
  }

  void setOptimistic(Map<String, dynamic> ride) {
    // When ride is set, we are done matching
    state = state.copyWith(activeRide: ride, isMatching: false, isCompleting: false);
  }

  void updateStatus(String status) {
    if (state.activeRide != null) {
      final updatedRide = Map<String, dynamic>.from(state.activeRide!);
      updatedRide['status'] = status;
      state = state.copyWith(activeRide: updatedRide);
    }
  }

  void clear() {
    state = const OptimisticState(); // Resets isMatching to false
  }

  // GLOBAL ACCEPT LOGIC ("Zınk" Implementation)
  Future<void> acceptRide(Map<String, dynamic> request) async {
    final rideId = request['ride_id'];
    
    // 1. Immediately switch Home UI to "Matching/Processing" state
    startMatching();

    // 2. Emit Socket Event (Background)
    ref.read(socketServiceProvider).socket.emit('driver:accept_request', {'ride_id': rideId});

    // 3. WAIT (The "Oyalama" / Transition Delay)
    // This allows the user to see the "Matching..." sheet on the Home Screen.
    // If we didn't wait, the success might come too fast or instant.
    await Future.delayed(const Duration(milliseconds: 1500));

    // CHECK Race Condition:
    // If request:accept_failed arrived during the delay, the request would be removed from incomingRequestsProvider.
    // If so, ABORT to prevent sticking in "Assigned" state.
    final stillExists = ref.read(incomingRequestsProvider).any((r) => r['ride_id'].toString() == rideId.toString());
    
    if (!stillExists) {
        // Only cancel matching if it failed and we are still in matching state.
        // If it succeeded, 'request:accepted_confirm' might have already handled it (unlikely due to delay).
        // But if it failed, 'request:accept_failed' would have cleared it.
        // We ensure we exit the matching state.
        cancelMatching();
        return;
    }

    // 4. Construct Optimistic Ride Object
    final Map<String, dynamic> optimisticRide = {
       'id': rideId,
       'ride_id': rideId,
       'status': 'assigned',
       'start_lat': request['start']['lat'],
       'start_lng': request['start']['lng'],
       'start_address': request['start']['address'],
       'end_lat': request['end']['lat'],
       'end_lng': request['end']['lng'],
       'end_address': request['end']['address'],
       'passenger': request['passenger'] ?? {},
       'fare_estimate': request['fare_estimate'],
       'distance_meters': request['distance'],
       'duration_seconds': request['duration'],
       'code4': request['code4'] ?? '****',
       'payment_method': request['payment_method'],
       'options': request['options'],
    };

    // 5. Trigger Global Optimistic Update (Switch to Passenger Info Sheet)
    setOptimistic(optimisticRide);

    // 6. Clear requests (Safety check, though UI should have popped)
    ref.read(incomingRequestsProvider.notifier).clearRequests();
  }
}
