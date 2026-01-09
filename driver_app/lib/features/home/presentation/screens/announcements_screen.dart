import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/services/api_service.dart';

// Filter record
class AnnouncementFilter {
  final String targetApp;
  final String? type;

  const AnnouncementFilter({required this.targetApp, this.type});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnnouncementFilter &&
          runtimeType == other.runtimeType &&
          targetApp == other.targetApp &&
          type == other.type;

  @override
  int get hashCode => targetApp.hashCode ^ type.hashCode;
}

final announcementsProvider = FutureProvider.family<List<Map<String, dynamic>>, AnnouncementFilter>((ref, filter) async {
  final apiService = ref.read(apiServiceProvider);
  final queryParams = {
    'target_app': filter.targetApp,
    if (filter.type != null) 'type': filter.type,
  };
  final response = await apiService.get('/announcements', queryParameters: queryParams);
  return List<Map<String, dynamic>>.from(response.data);
});

class AnnouncementsScreen extends ConsumerWidget {
  final String? type;

  const AnnouncementsScreen({super.key, this.type});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final announcementsAsync = ref.watch(announcementsProvider(AnnouncementFilter(targetApp: 'driver', type: type)));
    
    String title = 'announcements.title_all'.tr();
    if (type == 'announcement') title = 'announcements.title_announcements'.tr();
    if (type == 'campaign') title = 'announcements.title_campaigns'.tr();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
      ),
      body: announcementsAsync.when(
        data: (announcements) {
          if (announcements.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Icon(Icons.campaign_outlined, size: 64, color: Colors.grey[400]),
                   const SizedBox(height: 16),
                   Text('announcements.empty'.tr(), style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: announcements.length,
            itemBuilder: (context, index) {
              final item = announcements[index];
              final isCampaign = item['type'] == 'campaign';
              
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (item['image_url'] != null)
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        child: Image.network(
                          item['image_url'],
                          height: 150,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            height: 150,
                            color: Colors.grey[200],
                            child: const Center(child: Icon(Icons.image_not_supported, color: Colors.grey)),
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isCampaign)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'announcements.campaign_tag'.tr(),
                                style: TextStyle(
                                  color: Colors.green[700],
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          const SizedBox(height: 8),
                          Text(
                            item['title'] ?? '',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item['content'] ?? '',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              height: 1.5,
                            ),
                          ),
                          if (item['created_at'] != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _formatDate(item['created_at']),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[400],
                              ),
                            ),
                          ]
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('announcements.error'.tr(args: [err.toString()]))),
      ),
    );
  }
  
  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}.${date.month}.${date.year}';
    } catch (e) {
      return '';
    }
  }
}
