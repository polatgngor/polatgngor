import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../core/api/api_client.dart';
import '../../../core/constants/app_constants.dart';
import '../../notifications/presentation/notification_provider.dart';
import 'ride_detail_screen.dart';
import '../../../core/widgets/shimmer_loading.dart';
import '../../../core/widgets/custom_toast.dart';

class RideHistoryScreen extends ConsumerStatefulWidget {
  const RideHistoryScreen({super.key});

  @override
  ConsumerState<RideHistoryScreen> createState() => _RideHistoryScreenState();
}

class _RideHistoryScreenState extends ConsumerState<RideHistoryScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _rides = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _page = 1;
  final int _limit = 20;

  @override
  void initState() {
    super.initState();
    _fetchRides();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        _hasMore) {
      _fetchRides();
    }
  }

  Future<void> _fetchRides() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.client.get('/rides', queryParameters: {
        'page': _page,
        'limit': _limit,
      });

      final data = response.data;
      if (data['rides'] != null) {
        final List<dynamic> newRides = data['rides'];
        if (newRides.length < _limit) {
          _hasMore = false;
        }
        
        setState(() {
          _rides.addAll(List<Map<String, dynamic>>.from(newRides));
          _page++;
        });
      } else {
        _hasMore = false;
      }
    } catch (e) {
      if (mounted) {
        CustomNotificationService().show(
          context,
          'Hata: $e',
          ToastType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('drawer.rides'.tr()),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _rides.isEmpty && _isLoading
          ? const RideHistorySkeleton()
          : _rides.isEmpty && !_isLoading
              ? Center(child: Text('history.no_rides'.tr(), style: TextStyle(color: Colors.grey[600])))
              : ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  separatorBuilder: (context, index) => const SizedBox(height: 16),
                  itemCount: _rides.length + (_hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _rides.length) {
                      return const Center(child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(),
                      ));
                    }

                    final ride = _rides[index];
                    return _buildRideCard(ride);
                  },
                ),
    );
  }

  Widget _buildRideCard(Map<String, dynamic> ride) {
    final date = DateTime.tryParse(ride['created_at'] ?? '') ?? DateTime.now();
    final status = ride['status'];
    final fare = ride['fare_actual'] ?? ride['fare_estimated'];
    final pickup = ride['start_address'] ?? 'history.unknown'.tr();
    final dropoff = ride['end_address'] ?? 'history.unknown'.tr();
    final statusColor = _getStatusColor(status);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
               builder: (context) => RideDetailScreen(ride: ride),
            ),
          );
          // If rating changed, we might want to refresh list, but for now just popping back might trigger reload if implemented.
          if (result == true) {
             _fetchRides(); // Refresh list to show new rating
          }
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
                              Builder(
                                builder: (context) {
                                  // Logic: Prefer realtime, fallback to static
                                  final rideId = int.tryParse(ride['id'].toString()) ?? 0;
                                  final realtimeCount = ref.watch(notificationNotifierProvider).unreadRideCounts[rideId];
                                  final staticCount = int.tryParse(ride['unread_count']?.toString() ?? '0') ?? 0;
                                  final displayCount = realtimeCount ?? staticCount;

                                  if (displayCount > 0) {
                                    return Padding(
                                      padding: const EdgeInsets.only(left: 8.0),
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Text(
                                          displayCount.toString(),
                                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                }
                              ),
                            ],
                          ),
                          
                          // Right: Date (New Style)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(12), // Slightly increased radius
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
  
                    // Driver Info Footer Removed
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
      case 'requested': return 'history.status.requested'.tr();
      case 'assigned': return 'history.status.assigned'.tr();
      default: return status ?? '-';
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'completed': return const Color(0xFF1A77F6); // Primary Blue
      case 'cancelled': return Colors.red;
      case 'started': return Colors.blueAccent;
      case 'requested': return Colors.orange;
      case 'assigned': return Colors.teal;
      default: return Colors.grey;
    }
  }
}
