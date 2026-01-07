import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:intl/intl.dart';
import '../data/notification_repository.dart';

final notificationsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.read(notificationRepositoryProvider).getNotifications();
});

class NotificationScreen extends ConsumerWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('notification.title'.tr()),
        backgroundColor: Colors.yellow[700],
      ),
      body: notificationsAsync.when(
        data: (notifications) {
          if (notifications.isEmpty) {
            return Center(child: Text('notification.empty'.tr()));
          }
          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              final isRead = notification['is_read'] == true;
              final date = DateTime.parse(notification['created_at']).toLocal();

              return Card(
                color: isRead ? Colors.white : Colors.yellow[50],
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: Icon(
                    isRead ? Icons.notifications_none : Icons.notifications_active,
                    color: isRead ? Colors.grey : Colors.orange,
                  ),
                  title: Text(
                    notification['title'] ?? 'notification.default_title'.tr(),
                    style: TextStyle(
                      fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(notification['message'] ?? ''),
                      const SizedBox(height: 4),
                      Text(
                        notification['formatted_date'] ?? '-',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  onTap: () async {
                    if (!isRead) {
                      try {
                        await ref.read(notificationRepositoryProvider).markAsRead(notification['id']);
                        ref.refresh(notificationsProvider);
                      } catch (_) {}
                    }
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('notification.error'.tr(args: [err.toString()]))),
      ),
    );
  }
}
