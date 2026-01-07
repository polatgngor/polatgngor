import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/api/api_client.dart';
import '../../../notifications/presentation/notification_provider.dart';

// Key: type (announcement, campaign, or null for all)
final announcementsProvider = FutureProvider.family<List<Map<String, dynamic>>, String?>((ref, type) async {
  final apiClient = ref.read(apiClientProvider);
  
  final queryParams = {
    'target_app': 'customer',
    if (type != null) 'type': type,
  };

  try {
    final response = await apiClient.client.get('/announcements', queryParameters: queryParams);
    return List<Map<String, dynamic>>.from(response.data);
  } on DioException catch (e) {
    throw Exception(e.response?.data['message'] ?? 'Duyurular yüklenemedi');
  }
});

class AnnouncementsScreen extends ConsumerStatefulWidget {
  final String? type; // 'announcement' or 'campaign' or null

  const AnnouncementsScreen({super.key, this.type});

  @override
  ConsumerState<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends ConsumerState<AnnouncementsScreen> {

  @override
  void initState() {
    super.initState();
    // Mark as read when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
       ref.read(notificationNotifierProvider.notifier).markAnnouncementsRead();
    });
  }

  @override
  Widget build(BuildContext context) {
    final announcementsAsync = ref.watch(announcementsProvider(widget.type));
    
    String title = 'announcements.title_all'.tr();
    if (widget.type == 'announcement') title = 'announcements.title_announcements'.tr();
    if (widget.type == 'campaign') title = 'announcements.title_campaigns'.tr();

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
                    if (item['image_url'] != null && item['image_url'].toString().isNotEmpty)
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
