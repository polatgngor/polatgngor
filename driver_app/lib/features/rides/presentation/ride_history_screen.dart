import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:dio/dio.dart';
import '../../../core/constants/app_constants.dart';
import '../../auth/data/auth_service.dart';
import 'ride_detail_screen.dart';
import '../../../core/widgets/shimmer_loading.dart';
import '../../notifications/presentation/notification_provider.dart';

final driverRideHistoryProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final authService = ref.read(authServiceProvider);
  final token = await authService.getToken();
  if (token == null) throw Exception('No token');
  
  final dio = Dio();
  final response = await dio.get(
    '${AppConstants.apiUrl}/rides',
    options: Options(headers: {'Authorization': 'Bearer $token'}),
  );
  final data = response.data;
  if (data['rides'] != null) {
    return List<Map<String, dynamic>>.from(data['rides']);
  }
  return [];
});

class RideHistoryScreen extends ConsumerWidget {
  const RideHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ridesAsync = ref.watch(driverRideHistoryProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('history.title'.tr()),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: ridesAsync.when(
        data: (rides) {
          if (rides.isEmpty) {
            return Center(child: Text('history.no_rides'.tr(), style: TextStyle(color: Colors.grey[600])));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: rides.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final ride = rides[index];
              return _buildRideCard(context, ref, ride);
            },
          );
        },
        loading: () => const RideHistorySkeleton(),
        error: (err, stack) => Center(child: Text('Hata: $err')),
      ),
    );
  }

  Widget _buildRideCard(BuildContext context, WidgetRef ref, Map<String, dynamic> ride) {
    final date = DateTime.tryParse(ride['created_at'] ?? '') ?? DateTime.now();
    final status = ride['status'];
    final fare = ride['fare_actual'] ?? ride['fare_estimated'];
    final pickup = ride['start_address'] ?? 'history.unknown'.tr();
    final dropoff = ride['end_address'] ?? 'history.unknown'.tr();
    final statusColor = _getStatusColor(status);
    
    // BADGE LOGIC
    final rideId = int.tryParse(ride['id'].toString()) ?? 0;
    final notifState = ref.watch(notificationNotifierProvider);
    final realtimeCount = notifState.unreadRideCounts[rideId];
    final staticCount = int.tryParse(ride['unread_count']?.toString() ?? '0') ?? 0;
    final unreadCount = realtimeCount ?? staticCount;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
               builder: (context) => RideDetailScreen(ride: ride),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Status Accent Strip Removed
              /*
              Container(
                width: 6,
                color: statusColor,
              ),
              */
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                     // Header: Price, Payment & Date
                     Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Left: Price & Badge
                          Row(
                            children: [
                              Text(
                                fare != null ? '₺$fare' : '-',
                                style: TextStyle(
                                  fontSize: 20, // Enlarged
                                  fontWeight: FontWeight.w800, 
                                  color: Theme.of(context).primaryColor
                                ),
                              ),
                              if (unreadCount > 0)
                                Padding(
                                  padding: const EdgeInsets.only(left: 8.0),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '$unreadCount',
                                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          
                          // Right: Date
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade300, width: 1),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_month_rounded, size: 20, color: Colors.grey[700]),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        DateFormat('dd MMM yyyy', 'tr').format(date),
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                                      ),
                                      Text(
                                        DateFormat('HH:mm').format(date),
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey[600]),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
  
                    const Divider(height: 1, color: Colors.black12, indent: 48, endIndent: 48),
  
                     // Route Info with Timeline
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Timeline Column
                          Column(
                            children: [
                              Icon(Icons.radio_button_checked, size: 16, color: Theme.of(context).primaryColor),
                              Container(width: 2, height: 32, color: Colors.grey[200]),
                              Icon(Icons.location_on, size: 16, color: Theme.of(context).primaryColor),
                            ],
                          ),
                          const SizedBox(width: 12),
                          // Addresses
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  pickup,
                                  style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 24), 
                                Text(
                                  dropoff,
                                  style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Detail Arrow Row (Bottom Right)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                           Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Theme.of(context).primaryColor),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getStatusText(String? status) {
    switch (status) {
      case 'completed': return 'history.status.completed'.tr();
      case 'cancelled': return 'history.status.cancelled'.tr();
      case 'started': return 'history.status.started'.tr();
      default: return status ?? '-';
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'completed': return const Color(0xFF1A77F6); // Primary Blue
      case 'cancelled': return Colors.red;
      case 'started': return Colors.blueAccent;
      default: return Colors.grey;
    }
  }
}
