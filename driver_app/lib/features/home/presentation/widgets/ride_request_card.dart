import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/services/socket_service.dart';
import '../providers/incoming_requests_provider.dart';
import '../providers/optimistic_ride_provider.dart';


class RideRequestCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> request;

  const RideRequestCard({super.key, required this.request});

  @override
  ConsumerState<RideRequestCard> createState() => _RideRequestCardState();
}

class _RideRequestCardState extends ConsumerState<RideRequestCard> with TickerProviderStateMixin {
  final Completer<GoogleMapController> _controller = Completer();
  late AnimationController _timerController;
  late AnimationController _flowController; // Neon Flow Animation

  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  List<LatLng> _currentRoutePoints = []; // Base points for animation
  List<LatLng> _flowPolylinePoints = []; // Current animated strip

  // Metrics (Driver -> Pickup)
  String _pickupDistance = '...';
  String _pickupDuration = '...';

  // Default timeout duration (reduced to sync with backend)
  static const int _timeoutSeconds = 30;

  bool _isAccepting = false; // Optimistic UI state

  @override
  void initState() {
    super.initState();
    _setupTimer();
    _setupFlowAnimation();
    _setupMapData();
    _calculatePickupMetrics();
  }

  void _setupFlowAnimation() {
     // Animation Removed
  }

  void _calculateFlowPolyline(double t) {
      if (_currentRoutePoints.length < 2) return;
      
      final int totalPoints = _currentRoutePoints.length;
      final int stripLength = (totalPoints * 0.20).clamp(5, 50).toInt(); // 20% or min 5 points
      
      // Calculate indices
      final int headIndex = (t * (totalPoints + stripLength)).floor(); 
      final int tailIndex = headIndex - stripLength;
      
      final List<LatLng> visiblePoints = [];
      
      for (int i = 0; i < totalPoints; i++) {
         if (i >= tailIndex && i <= headIndex) {
            visiblePoints.add(_currentRoutePoints[i]);
         }
      }
      
      setState(() {
         _flowPolylinePoints = visiblePoints;
      }); 
  }

  @override
  void dispose() {
    _timerController.dispose();
    _flowController.dispose();
    super.dispose();
  }
  Future<void> _calculatePickupMetrics() async {
    try {
      final start = widget.request['start'];
      if (start != null && start['lat'] != null && start['lng'] != null) {
        final pickupLat = double.parse(start['lat'].toString());
        final pickupLng = double.parse(start['lng'].toString());

        // Get Driver Location (Instant if possible)
        Position? position = await Geolocator.getLastKnownPosition();
        position ??= await Geolocator.getCurrentPosition();

        final distMeters = Geolocator.distanceBetween(
          position.latitude, 
          position.longitude, 
          pickupLat, 
          pickupLng
        );

        final distKm = distMeters / 1000;
        // Heuristic: 20km/h avg speed in city = ~3 mins per km + 2 min base
        final durationMins = (distKm * 3) + 2; 

        if (mounted) {
          setState(() {
            _pickupDistance = '${distKm.toStringAsFixed(1)} km';
            _pickupDuration = '${durationMins.toStringAsFixed(0)} dk';
          });
        }
      }
    } catch (e) {
      debugPrint('Error calculating pickup metrics: $e');
    }
  }

  void _setupTimer() {
    int durationSeconds = _timeoutSeconds;
    
    // Check for strict backend expiration
    if (widget.request['expires_at'] != null) {
      final expiresAt = int.tryParse(widget.request['expires_at'].toString());
      if (expiresAt != null) {
        final now = DateTime.now().millisecondsSinceEpoch;
        final remainingMs = expiresAt - now;
        if (remainingMs <= 0) {
           durationSeconds = 0;
           // Trigger immediate timeout handling if needed? 
           // For now, let's just show 0 and allowed system to reap it via socket event or auto-close
        } else {
           durationSeconds = (remainingMs / 1000).ceil();
        }
      }
    }

    _timerController = AnimationController(
      vsync: this,
      duration: Duration(seconds: durationSeconds > 0 ? durationSeconds : 1),
    )..reverse(from: 1.0);
  }

  // dispose moved to top

  // ... map setup ...

  void _setupMapData() {
    final start = widget.request['start'];
    final end = widget.request['end'];

    _markers = {};
    if (start != null && start['lat'] != null && start['lng'] != null) {
      _markers.add(Marker(
        markerId: const MarkerId('start'),
        position: LatLng(double.parse(start['lat'].toString()), double.parse(start['lng'].toString())),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ));
    }

    if (end != null && end['lat'] != null && end['lng'] != null) {
      _markers.add(Marker(
        markerId: const MarkerId('end'),
        position: LatLng(double.parse(end['lat'].toString()), double.parse(end['lng'].toString())),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ));
    }
    
    // Add logic for polyline decoding
    if (widget.request['polyline'] != null) {
      final String encodedPolyline = widget.request['polyline'].toString();
      final List<LatLng> decodedPoints = _decodePolyline(encodedPolyline);
      
      if (decodedPoints.isNotEmpty) {
        _currentRoutePoints = decodedPoints; // Set for animation
        _polylines.add(Polyline(
          polylineId: const PolylineId('route'),
          points: decodedPoints,
          color: const Color(0xFF0865ff), // Deep Blue Base
          width: 5,
        ));
      }
    } else if (_markers.length == 2) {
       // Fallback: Straight line if no polyline data
       _polylines.add(Polyline(
          polylineId: const PolylineId('route_straight'),
          points: _markers.map((m) => m.position).toList(),
          color: const Color(0xFF1A77F6),
          width: 4,
          patterns: [PatternItem.dash(10), PatternItem.gap(5)], // Dashed for fallback
       ));
    }
    
    if (mounted) setState(() {});
  }

  // Simple Polyline Decoder (Google Encoded Polyline Algorithm)
  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

  Future<void> _acceptRide() async {
    if (_isAccepting) return;
    
    setState(() {
      _isAccepting = true;
    });

    // 2. Trigger Global Logic (Background) - FIRST to set optimistic state
    ref.read(optimisticRideProvider.notifier).acceptRide(widget.request);

    // 1. Close this screen IMMEDIATELY ("Zınk" diye kapansın)
    ref.read(incomingRequestsProvider.notifier).clearRequests();
  }

   @override
  Widget build(BuildContext context) {
    // Note: We use _pickupDistance/_pickupDuration calculated in initState
    
    final fare = widget.request['fare_estimate'] ?? '-';
    final addressStart = widget.request['start']['address'] ?? 'incoming_request.start_location'.tr();
    final addressEnd = widget.request['end']['address'] ?? 'incoming_request.end_location'.tr();
    
    // Parse Options
    final options = widget.request['options'] as Map<String, dynamic>? ?? {};
    final bool openTaximeter = options['open_taximeter'] == true;
    final bool hasPet = options['has_pet'] == true;
    final String paymentMethod = widget.request['payment_method']?.toString() ?? 'nakit';
    final bool isCash = paymentMethod == 'nakit';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            spreadRadius: 5,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge, 
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
           // 1. Header & Map (Top Half)
           Stack(
             children: [
               SizedBox(
                 height: 180, // Reduced height
                 child: GoogleMap(
                   initialCameraPosition: CameraPosition(
                    target: _markers.isNotEmpty ? _markers.first.position : const LatLng(0,0),
                     zoom: 12,
                   ),
                   markers: _markers,
                   polylines: {
                     ..._polylines,
                     // Flow logic removed
                   },
                   zoomControlsEnabled: false,
                   liteModeEnabled: false,
                   myLocationButtonEnabled: false,
                   onMapCreated: (controller) {
                     _controller.complete(controller);
                     if (_markers.isNotEmpty) {
                       Future.delayed(const Duration(milliseconds: 300), () {
                         controller.animateCamera(CameraUpdate.newLatLngBounds(
                           _boundsFromLatLngList(_markers.map((m) => m.position).toList()),
                           60,
                         ));
                       });
                     }
                   },
                 ),
               ),
               // Removed Badge from here
             ],
           ),

           // 2. Info Section (Bottom Half)
           Padding(
             padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
             child: Column(
               children: [
                 // Price | Payment | Badge Row
                 Row(
                   crossAxisAlignment: CrossAxisAlignment.center,
                   children: [
                     Expanded(
                       child: Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           // Payment Method (Header) - Replaces "Estimated Earnings"
                           Text(
                             isCash ? 'earnings.payment_cash'.tr() : 'earnings.payment_pos'.tr(),
                             style: TextStyle(
                               color: isCash ? const Color(0xFF2E7D32) : const Color(0xFF7B1FA2),
                               fontWeight: FontWeight.w900,
                               fontSize: 18, 
                               letterSpacing: 0.5,
                             ),
                           ),
                           const SizedBox(height: 4),
                           // Price
                           FittedBox(
                             fit: BoxFit.scaleDown,
                             alignment: Alignment.centerLeft,
                             child: Text(
                               '₺$fare',
                               style: const TextStyle(
                                 fontSize: 36, // Slightly larger
                                 fontWeight: FontWeight.w900,
                                 color: Colors.black87,
                                 height: 1.0,
                                 letterSpacing: -1.0,
                               ),
                             ),
                           ),
                         ],
                       ),
                     ),
                     // New Badge (Driver -> Pickup)
                     Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A77F6), // Theme Blue
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Row(
                           mainAxisSize: MainAxisSize.min,
                           children: [
                              const Icon(Icons.access_time_filled, size: 14, color: Colors.white70),
                              const SizedBox(width: 4),
                              Text(
                                _pickupDuration,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              Container(
                                height: 12, 
                                width: 1, 
                                color: Colors.white24, 
                                margin: const EdgeInsets.symmetric(horizontal: 8),
                              ),
                              const Icon(Icons.directions_car, size: 14, color: Colors.white70),
                              const SizedBox(width: 4),
                              Text(
                                _pickupDistance,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                           ],
                        ),
                     ),
                   ],
                 ),
                 
                 // Removed "Tahmini Kazanç" Text row entirely
                 
                 // Options Chips
                 if (openTaximeter || hasPet) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        if (openTaximeter)
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.calculate_outlined, size: 16, color: Colors.grey[700]),
                                const SizedBox(width: 6),
                                Text(
                                  'incoming_request.open_taximeter'.tr(),
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[800]),
                                ),
                              ],
                            ),
                          ),
                        if (hasPet)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.pets, size: 16, color: Colors.grey[700]),
                                const SizedBox(width: 6),
                                Text(
                                  'incoming_request.pet'.tr(),
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[800]),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                 ],

                 const SizedBox(height: 24),

                 // Visual Address Timeline (Updated Icons/Colors)
                 Row(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     // Timeline Line
                     Column(
                       children: [
                         // Start Icon: Blue Circle
                         const Icon(Icons.radio_button_checked, color: Color(0xFF1A77F6), size: 20),
                         Container(
                           width: 2,
                           height: 40, // Slightly taller to accommodate multiline text if needed
                           color: Colors.black, // Changed to Black
                           margin: const EdgeInsets.symmetric(vertical: 2),
                         ),
                         // End Icon: Blue Pin
                         const Icon(Icons.location_on, color: Color(0xFF1A77F6), size: 20),
                       ],
                     ),
                     const SizedBox(width: 16),
                     // Addresses
                     Expanded(
                       child: Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                            _buildAddressText(addressStart, isTitle: true), // Force Title/Bold
                            const SizedBox(height: 24), 
                            _buildAddressText(addressEnd, isTitle: true),   // Force Title/Bold
                         ],
                       ),
                     ),
                   ],
                 ),

                 const SizedBox(height: 32),

                 // Accept Button (Unchanged style)
                 SizedBox(
                   width: double.infinity,
                   height: 56,
                   child: ElevatedButton(
                     onPressed: _acceptRide,
                     style: ElevatedButton.styleFrom(
                       backgroundColor: const Color(0xFF1A77F6), // Theme Blue
                       foregroundColor: Colors.white,
                       elevation: 0,
                       shape: RoundedRectangleBorder(
                         borderRadius: BorderRadius.circular(16),
                       ),
                     ),
                     child: Text(
                       'incoming_request.accept'.tr(),
                       style: const TextStyle(
                         fontSize: 18,
                         fontWeight: FontWeight.bold,
                         letterSpacing: 1.0,
                       ),
                     ),
                   ),
                 ),
               ],
             ),
           ),
           
           const SizedBox(height: 24),
           
            AnimatedBuilder(
              animation: _timerController,
              builder: (context, child) {
                final val = _timerController.value;
                Color? color;
                if (val > 0.5) {
                  color = Color.lerp(Colors.amber, Colors.green, (val - 0.5) * 2);
                } else {
                  color = Color.lerp(Colors.red, Colors.amber, val * 2);
                }

                return LinearProgressIndicator(
                  value: val,
                  backgroundColor: Colors.grey[100],
                  valueColor: AlwaysStoppedAnimation<Color>(color ?? Colors.green),
                  minHeight: 6,
                );
              },
            ),
         ],
      ),
    );
  }

  Widget _buildAddressText(String text, {required bool isTitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          maxLines: 2, // Allow up to 2 lines
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 16, // Increased from 15
            fontWeight: FontWeight.bold, // Always bold as requested
            color: Colors.black87, // Stronger color
            height: 1.3,
          ),
        ),
      ],
    );
  }

  LatLngBounds _boundsFromLatLngList(List<LatLng> list) {
    if (list.isEmpty) return LatLngBounds(northeast: const LatLng(0,0), southwest: const LatLng(0,0));
    double? x0, x1, y0, y1;
    for (LatLng latLng in list) {
      if (x0 == null) {
        x0 = x1 = latLng.latitude;
        y0 = y1 = latLng.longitude;
      } else {
        if (latLng.latitude > x1!) x1 = latLng.latitude;
        if (latLng.latitude < x0) x0 = latLng.latitude;
        if (latLng.longitude > y1!) y1 = latLng.longitude;
        if (latLng.longitude < y0!) y0 = latLng.longitude;
      }
    }
    return LatLngBounds(northeast: LatLng(x1!, y1!), southwest: LatLng(x0!, y0!));
  }
}
