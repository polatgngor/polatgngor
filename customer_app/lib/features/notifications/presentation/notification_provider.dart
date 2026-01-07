import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
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
    final authState = ref.read(authProvider); // Read only
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
      debugPrint('Customer Notification Received: $data');
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
  }  


  Future<void> fetchCounts() async {
    try {
      final response = await ref.read(apiClientProvider).client.get('/notifications/counts');
      final data = response.data;
      
      // Data: { total_unread_messages: int, unread_announcements: int }
      // Wait, backend 'getCounts' returned total unread messages count, but not per-ride breakdown in the 'counts' endpoint?
      // Backend 'getCounts' at src/controllers/notificationController.js:
      // return res.json({ total_unread_messages: ..., unread_announcements: ... });
      // It DOES NOT return breakdown map.
      // So 'unreadRideCounts' map cannot be fully populated from this endpoint alone.
      // However, 'getRides' (History) DOES return 'unread_count' per ride.
      // We can rely on 'getRides' to populate the specific ride badges when we load the history list.
      // But for the GLOBAL badge (Drawer Icon), we need the total.
      // AND used asked: "Drawer açılma ikonu var ... oraya tıkladığında geçmiş yolculuklar ... orda (1) yazsın"
      // So we need specific ride IDs that have unread messages to show badges in the inner list.
      // If 'getCounts' only returns TOTAL, we can't show "which" ride has message without fetching rides.
      // Strategy:
      // 1. 'getCounts' gives us the TOTAL count for the Drawer Badge.
      // 2. We can store a generic 'totalMessageCount' in state, OR
      // 3. We can fetch the breakdown.
      // Given the requirement: "Geçmiş yolculuklar sıralanıyor hangisindeyse orda (1) yazsın" -> Needs breakdown.
      // So 'getCounts' SHOULD ideally return the breakdown or we fetch rides.
      // Fetching all rides might be heavy just for badges.
      // BETTER: Update Backend 'getCounts' to return '{ unread_per_ride: { ride_id: count } }' instead of just total.
      // OR we just assume we fetch the first page of history and if older ones have messages we might miss them?
      // No, user wants to see it.
      
      // Let's UPDATE NotificationProvider to handle just the total first?
      // NO, I must fix backend to return breakdown if I want to show badges on specific items in the list without fetching `getRides`.
      // actually `getRides` is paginated. If the unread message is on page 5, user won't see it in list unless we tell them.
      // But `getRides` (History) has badges.
      // If we rely on `getRides` for the list badges, that's fine.
      // But for the Drawer Menu Item "Geçmiş Yolculuklar (N)", we can use the Total.
      // What about "Drawer açılma ikonu" -> Total.
      // So we technically function with just Total for the outer badges.
      // For the inner list, we use `getRides` response which has `unread_count`.
      // BUT: `unreadRideCounts` map in state is useful for REAL-TIME updates.
      // If a new message comes for Ride 123, we want to update the badge on Ride 123 card if it's visible.
      // So `unreadRideCounts` SHOULD be maintained.
      
      // Workaround: We will use the `getCounts` for total.
      // And we will use `ride:message` to increment specific keys in `unreadRideCounts`.
      // But initially `unreadRideCounts` will be empty?
      // If it's empty, we won't know which ride has messages until we fetch history.
      // That implies the badges in the list won't show up until we fetch history?
      // That's standard behavior (lazy load).
      // However, if we want the "Geçmiş Yolculuklar (1)" menu item to show "1", that comes from Total.
      
      // So:
      // State: totalUnreadMessages (int), unreadAnnouncementCount (int), unreadRideCounts (Map<int, int>) (for optimistic updates)
      
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
       currentMap.remove(rideId); // Remove or set to 0
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
        await ref.read(apiClientProvider).client.post('/notifications/announcements/read');
        state = state.copyWith(unreadAnnouncementCount: 0);
    } catch (e) {
        debugPrint('Mark announcements read error: $e');
    }
  }
}

final notificationNotifierProvider = NotifierProvider<NotificationNotifier, NotificationState>(NotificationNotifier.new);
