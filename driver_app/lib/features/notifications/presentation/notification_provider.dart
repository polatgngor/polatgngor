import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/socket_service.dart';
import '../../auth/presentation/auth_provider.dart';

// part 'notification_provider.g.dart';

class NotificationState {
  final Map<int, int> unreadRideCounts;
  final int unreadAnnouncementCount;

  const NotificationState({
    this.unreadRideCounts = const {},
    this.unreadAnnouncementCount = 0,
  });

  int get totalUnreadMessages => unreadRideCounts.values.fold(0, (a, b) => a + b);
  int get total => totalUnreadMessages + unreadAnnouncementCount;

  NotificationState copyWith({
    Map<int, int>? unreadRideCounts,
    int? unreadAnnouncementCount,
  }) {
    return NotificationState(
      unreadRideCounts: unreadRideCounts ?? this.unreadRideCounts,
      unreadAnnouncementCount: unreadAnnouncementCount ?? this.unreadAnnouncementCount,
    );
  }
}

class NotificationNotifier extends Notifier<NotificationState> {
  int? _activeChatRideId;

  @override
  NotificationState build() {
    _init();
    return const NotificationState();
  }

  Future<void> _init() async {
    // Only init if user is logged in
    final authState = ref.read(authProvider); // Changed from watch to read to avoid loop, we rely on parent to rebuild if auth flows.
    
    if (authState.value == null) return;
    
    // Fetch initial counts
    await fetchCounts();

    // Listen to Socket
    final socketService = ref.read(socketServiceProvider);
    
    // Remove existing listener to prevent duplicates
    socketService.off('notification:new_message');
    
    // Listen for new messages targeting me (Global Alert)
    socketService.on('notification:new_message', (data) {
      if (data == null) return;
      debugPrint('Driver Notification Received: $data');
      final rideId = data['ride_id'];
      if (rideId != null) {
        // If we are currently in this chat, don't show badge
        if (_activeChatRideId == rideId) {
           ref.read(socketServiceProvider).emit('ride:mark_read', {'ride_id': rideId});
           return;
        }
        
        incrementMessageCount(rideId);
      }
    });

    // Handle ride:mark_read locally if needed via socket? No, better via method calls.
  }

  Future<void> fetchCounts() async {
    try {
      final response = await ref.read(apiServiceProvider).get('/notifications/counts');
      final data = response.data;
      
      final totalMsg = data['total_unread_messages'] ?? 0;
      final totalAnnounce = data['unread_announcements'] ?? 0;
      
      final Map<String, dynamic> rawMap = data['unread_per_ride'] ?? {};
      final Map<int, int> rideCounts = {};
      rawMap.forEach((k, v) {
        final val = v is int ? v : int.tryParse(v.toString()) ?? 0;
        final key = int.tryParse(k) ?? 0;
        if (key > 0) rideCounts[key] = val;
      });

      state = state.copyWith(
        unreadRideCounts: rideCounts,
        unreadAnnouncementCount: totalAnnounce,
      );
    } catch (e) {
      debugPrint('Fetch counts error: $e');
    }
  }

  void incrementMessageCount(int rideId) {
    final currentMap = Map<int, int>.from(state.unreadRideCounts);
    currentMap[rideId] = (currentMap[rideId] ?? 0) + 1;
    state = state.copyWith(unreadRideCounts: currentMap);
  }

  void markRideRead(int rideId) {
    // 1. Call API/Socket
    ref.read(socketServiceProvider).emit('ride:mark_read', {'ride_id': rideId});
    
    // 2. Optimistic Update
    final currentMap = Map<int, int>.from(state.unreadRideCounts);
    if (currentMap.containsKey(rideId)) {
       currentMap.remove(rideId); 
       state = state.copyWith(unreadRideCounts: currentMap);
    }
  }

  void enterChat(int rideId) {
    _activeChatRideId = rideId;
    markRideRead(rideId);
  }

  void leaveChat() {
    _activeChatRideId = null;
  }
  
  Future<void> markAnnouncementsRead() async {
    try {
        await ref.read(apiServiceProvider).post('/notifications/announcements/read');
        state = state.copyWith(unreadAnnouncementCount: 0);
    } catch (e) {
        debugPrint('Mark announcements read error: $e');
    }
  }
}

final notificationNotifierProvider = NotifierProvider<NotificationNotifier, NotificationState>(NotificationNotifier.new);
