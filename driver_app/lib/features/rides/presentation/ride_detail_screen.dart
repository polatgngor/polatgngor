import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../home/presentation/screens/driver_chat_screen.dart';
import '../../rides/presentation/widgets/rating_dialog.dart';
import '../../../core/utils/string_utils.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/directions_service.dart';
import '../../notifications/presentation/notification_provider.dart';

class RideDetailScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> ride;

  const RideDetailScreen({super.key, required this.ride});

  @override
  ConsumerState<RideDetailScreen> createState() => _RideDetailScreenState();
}

class _RideDetailScreenState extends ConsumerState<RideDetailScreen> {
  late GoogleMapController _mapController;
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};
  
  @override
  void initState() {
    super.initState();
    _setupMapData();
    _fetchPolyline();
  }

  void _setupMapData() {
    final startLat = double.tryParse(widget.ride['start_lat']?.toString() ?? '');
    final startLng = double.tryParse(widget.ride['start_lng']?.toString() ?? '');
    final endLat = double.tryParse(widget.ride['end_lat']?.toString() ?? '');
    final endLng = double.tryParse(widget.ride['end_lng']?.toString() ?? '');

    if (startLat != null && startLng != null) {
      _markers.add(Marker(
        markerId: const MarkerId('start'),
        position: LatLng(startLat, startLng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: InfoWindow(title: 'history.detail.pickup'.tr()),
      ));
    }

    if (endLat != null && endLng != null) {
      _markers.add(Marker(
        markerId: const MarkerId('end'),
        position: LatLng(endLat, endLng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: InfoWindow(title: 'history.detail.dropoff'.tr()),
      ));
    }
  }

  Future<void> _fetchPolyline() async {
    final startLat = double.tryParse(widget.ride['start_lat']?.toString() ?? '');
    final startLng = double.tryParse(widget.ride['start_lng']?.toString() ?? '');
    final endLat = double.tryParse(widget.ride['end_lat']?.toString() ?? '');
    final endLng = double.tryParse(widget.ride['end_lng']?.toString() ?? '');

    if (startLat != null && startLng != null && endLat != null && endLng != null) {
       try {
         final points = await ref.read(directionsServiceProvider).getRoute(
            LatLng(startLat, startLng),
            LatLng(endLat, endLng)
         );
         
         if (mounted && points.isNotEmpty) {
            setState(() {
              _polylines.add(Polyline(
                polylineId: const PolylineId('route'),
                points: points,
                color: Theme.of(context).primaryColor,
                width: 5,
                jointType: JointType.round,
                startCap: Cap.roundCap,
                endCap: Cap.roundCap,
              ));
            });
            Future.delayed(const Duration(milliseconds: 300), _fitBounds);
         }
       } catch (e) {
         debugPrint('Polyline error: $e');
       }
    }
  }

  Future<void> _fitBounds() async {
    if (_markers.isEmpty && _polylines.isEmpty) return;
    
    double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
    
    // Include route points in bounds
    if (_polylines.isNotEmpty) {
      for (var p in _polylines.first.points) {
         if (p.latitude < minLat) minLat = p.latitude;
         if (p.latitude > maxLat) maxLat = p.latitude;
         if (p.longitude < minLng) minLng = p.longitude;
         if (p.longitude > maxLng) maxLng = p.longitude;
      }
    } else {
      for (var m in _markers) {
         if (m.position.latitude < minLat) minLat = m.position.latitude;
         if (m.position.latitude > maxLat) maxLat = m.position.latitude;
         if (m.position.longitude < minLng) minLng = m.position.longitude;
         if (m.position.longitude > maxLng) maxLng = m.position.longitude;
      }
    }
    
    await _mapController.animateCamera(CameraUpdate.newLatLngBounds(
      LatLngBounds(
        southwest: LatLng(minLat, minLng),
        northeast: LatLng(maxLat, maxLng),
      ),
      50, 
    ));
  }

  @override
  Widget build(BuildContext context) {
    final ride = widget.ride;
    final status = ride['status'];
    final fare = ride['fare_actual'] ?? ride['fare_estimated'];
    final dateStr = ride['formatted_date'] ?? '-';
    final paymentMethod = ride['payment_method'];
    
    // Passenger Info
    final passenger = ride['passenger'];
    final passengerName = passenger != null 
        ? StringUtils.maskName('${passenger['first_name']} ${passenger['last_name']}')
        : null;
    final profilePhoto = passenger?['profile_photo'];

    final bool canChat = _isChatAvailable(ride['created_at']);
    
    // Rating Info
    final myRating = ride['my_rating'];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('history.detail.title'.tr()),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 30),
        child: Column(
          children: [
            // 1. Map Container - Styled
            Container(
              height: 250, 
              margin: const EdgeInsets.all(16),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 5)),
                ],
              ),
              child: GoogleMap(
                initialCameraPosition: const CameraPosition(
                  target: LatLng(41.0082, 28.9784), 
                  zoom: 12,
                ),
                onMapCreated: (controller) {
                  _mapController = controller;
                },
                markers: _markers,
                polylines: _polylines,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Fare & Date Header
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                       // Left: Price & Payment Type
                       Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '₺${fare ?? 0}',
                            style: TextStyle(
                               fontSize: 40, 
                               fontWeight: FontWeight.w900,
                               color: Colors.black, // Changed to Black
                               letterSpacing: -1.0,
                               height: 1.0,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildPaymentText(paymentMethod),
                        ],
                      ),
                      
                      // Right: Date & Time
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.transparent, // No background
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade300), // Border only
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_month_rounded, size: 24, color: Colors.grey[700]),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end, // Right align
                              children: [
                                Text(
                                  DateFormat('dd MMM yyyy', context.locale.languageCode).format(DateTime.tryParse(ride['created_at'] ?? '') ?? DateTime.now()),
                                  style: TextStyle(color: Colors.grey[900], fontSize: 15, fontWeight: FontWeight.w900),
                                ),
                                Text(
                                  DateFormat('HH:mm').format(DateTime.tryParse(ride['created_at'] ?? '') ?? DateTime.now()),
                                  style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Route
                  _buildAddressRow(Icons.radio_button_checked, ride['start_address'] ?? 'Başlangıç', isStart: true),
                  _buildAddressRow(Icons.location_on, ride['end_address'] ?? 'Varış', isStart: false),
                  
                  // Rating Section (Moved Above)
                    if (status == 'completed') ...[
                       if (myRating != null) ...[
                         Align(
                           alignment: Alignment.centerLeft,
                           child: Text(
                              'history.detail.rating_given'.tr(), 
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                           ),
                         ),
                         const SizedBox(height: 16),
                         Container(
                           width: double.infinity,
                           padding: const EdgeInsets.all(16),
                           decoration: BoxDecoration(
                             borderRadius: BorderRadius.circular(16),
                             border: Border.all(color: Colors.grey.withOpacity(0.2)),
                           ),
                           child: Column(
                             children: [
                               Row(
                                 mainAxisAlignment: MainAxisAlignment.center,
                                 children: List.generate(5, (index) => Icon(
                                   index < (myRating['stars'] ?? 0) ? Icons.star_rounded : Icons.star_outline_rounded,
                                   color: Colors.amber,
                                   size: 32,
                                 )),
                               ),
                               if (myRating['comment'] != null && myRating['comment'].isNotEmpty) ...[
                                 const SizedBox(height: 12),
                                 Text(
                                   '"${myRating['comment']}"',
                                   style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey[600], fontSize: 13),
                                   textAlign: TextAlign.center,
                                 ),
                               ]
                             ],
                           ),
                         ), // Added closing
                         const SizedBox(height: 32),
                       ] else 
                         Column(
                           children: [
                             SizedBox(
                               width: double.infinity,
                               child: ElevatedButton.icon(
                                 onPressed: () async {
                                    final result = await showDialog(
                                      context: context,
                                      builder: (_) => DriverRatingDialog(rideId: ride['id'].toString(), passengerName: passengerName ?? ''),
                                    );
                                    
                                     if (result != null && result is int && mounted) {
                                        setState(() {
                                           ride['my_rating'] = {
                                             'stars': result,
                                             'comment': '', // Placeholder
                                           };
                                        });
                                     }
                                 },
                                  style: ElevatedButton.styleFrom(
                                   backgroundColor: Colors.black,
                                   foregroundColor: Colors.white,
                                   padding: const EdgeInsets.symmetric(vertical: 16),
                                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                   elevation: 0,
                                 ),
                                 icon: const Icon(Icons.star, size: 20),
                                 label: Text('history.detail.rate_passenger'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
                               ),
                             ),
                             const SizedBox(height: 32),
                           ],
                         ),
                    ],

                  const Divider(height: 1), 
                  const SizedBox(height: 32),

                  // Passenger Card
                  if (passenger != null) ...[
                    Text(
                       'history.detail.passenger'.tr(), 
                       style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA), 
                        borderRadius: BorderRadius.circular(16), 
                        border: Border.all(color: const Color(0xFFEEF2F6)),
                      ),
                      child: Row(
                        children: [
                          ClipOval(
                            child: Container(
                              width: 56, height: 56,
                              color: Colors.white,
                              child: (profilePhoto != null && profilePhoto.isNotEmpty)
                                  ? Image.network(
                                      profilePhoto.startsWith('http') 
                                          ? profilePhoto
                                          : '${AppConstants.baseUrl}/$profilePhoto',
                                      fit: BoxFit.cover,
                                      errorBuilder: (ctx, _, __) => const Icon(Icons.person, color: Colors.grey, size: 30),
                                    )
                                  : const Icon(Icons.person, color: Colors.grey, size: 30),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  passengerName ?? 'history.detail.passenger'.tr(),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                          // Actions
                          if (canChat)
                            Consumer(
                              builder: (context, ref, child) {
                                final rideIdInt = int.tryParse(ride['id'].toString()) ?? 0;
                                final notifState = ref.watch(notificationNotifierProvider);
                                final unreadCount = (notifState.unreadRideCounts[rideIdInt] ?? 0) + (int.tryParse(ride['unread_count']?.toString() ?? '0') ?? 0);
                                
                                return IconButton(
                                  onPressed: () {
                                    ref.read(notificationNotifierProvider.notifier).markRideRead(rideIdInt);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => DriverChatScreen(rideId: ride['id'].toString()))
                                    );
                                  },
                                  icon: unreadCount > 0 ? Badge(
                                    label: Text('$unreadCount'),
                                    backgroundColor: Colors.red,
                                    child: const Icon(Icons.chat_bubble_outline),
                                  ) : const Icon(Icons.chat_bubble_outline),
                                  color: Theme.of(context).primaryColor,
                                );
                              }
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPaymentText(String? method) {
    bool isCard = method == 'card' || method == 'credit_card';
    return Text(
      isCard ? 'history.detail.payment_pos'.tr() : 'history.detail.payment_cash'.tr(),
      style: TextStyle(
        color: isCard ? const Color(0xFF6366F1) : const Color(0xFF22C55E),
        fontSize: 22, // Reduced size
        fontWeight: FontWeight.w900,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildAddressRow(IconData icon, String text, {required bool isStart}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Icon(icon, color: Theme.of(context).primaryColor, size: 24),
            if (isStart) 
              Container(width: 2, height: 24, margin: const EdgeInsets.symmetric(vertical: 4), color: Colors.grey[200]),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isStart ? 'history.detail.pickup'.tr() : 'history.detail.dropoff'.tr(),
                style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                text,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, height: 1.3),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }

  bool _isChatAvailable(String? dateStr) {
    if (dateStr == null) return false;
    try {
      final date = DateTime.parse(dateStr); 
      final diff = DateTime.now().difference(date.toLocal());
      return diff.inHours < 12;
    } catch (e) {
      return false;
    }
  }
}
