import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/utils/string_utils.dart';
import '../../../../core/services/socket_service.dart';
import '../../../../core/services/directions_service.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../features/auth/data/auth_service.dart';
import '../screens/driver_chat_screen.dart';
import 'driver_cancellation_sheet.dart';
import 'package:pinput/pinput.dart';
import '../providers/optimistic_ride_provider.dart';
import '../../../../core/widgets/custom_toast.dart';
import 'package:flutter/services.dart';

class PassengerInfoSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> rideData;
  final DraggableScrollableController? controller;
  final LatLng? driverLocation; // Driver's current location
  final int? currentDistanceMeters;
  final int? currentDurationSeconds;
  final ScrollController? scrollController;

  const PassengerInfoSheet({
    super.key, 
    required this.rideData,
    this.controller,
    this.scrollController,
    this.driverLocation,
    this.currentDistanceMeters,
    this.currentDurationSeconds,
  });

  @override
  ConsumerState<PassengerInfoSheet> createState() => _PassengerInfoSheetState();
}

class _PassengerInfoSheetState extends ConsumerState<PassengerInfoSheet> {
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _otpFocusNode = FocusNode();
  double _currentMaxHeight = 0.5;
  bool _isVerifying = false;

  @override
  void dispose() {
    _otpController.dispose();
    _otpFocusNode.dispose();
    super.dispose();
  }

  // Removed _onOtpDigitChanged as Pinput handles it internally

  void _verifyAndStartRide(String code) {
    if (code.length == 4 && !_isVerifying) {
      HapticFeedback.mediumImpact();
      final rideId = widget.rideData['ride_id']?.toString() ?? widget.rideData['id']?.toString();
      if (rideId != null) {
        // Optimistic UI: Start immediately without spinner
        FocusScope.of(context).unfocus(); // Hide keyboard
        
        // Update global optimistic state to 'started' - this expands the sheet instantly
        ref.read(optimisticRideProvider.notifier).updateStatus('started');

        // Emit to server
        ref.read(socketServiceProvider).socket.emit('driver:start_ride', {
          'ride_id': rideId,
          'code': code,
        });

        // Fail-safe: if server rejects (very rare), we rely on socket listeners to show error
        // No local spinner state to manage.
      }
    }
  }

  @override
  void initState() {
    super.initState();
    // ADAPTIVE INIT
    WidgetsBinding.instance.addPostFrameCallback((_) {
       if (mounted) {
          final double screenHeight = MediaQuery.of(context).size.height;
          final double safeAreaBottom = MediaQuery.of(context).viewPadding.bottom;
          // BUFFER: Added +20px to ensure no internal scrolling
          const double kPickupHeight = 420.0; 
          const double kStartedHeight = 340.0;
          
          final bool isStarted = widget.rideData['status'] == 'started';
          final double targetPixelHeight = isStarted ? kStartedHeight : kPickupHeight;
          final double targetFraction = ((targetPixelHeight + safeAreaBottom) / screenHeight).clamp(0.20, 0.90);

          setState(() {
            _currentMaxHeight = targetFraction;
          });
          
          if (widget.controller != null && widget.controller!.isAttached) {
             widget.controller!.jumpTo(targetFraction);
          }
       }
    });
  }

  @override
  void didUpdateWidget(PassengerInfoSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldStatus = oldWidget.rideData['status'];
    final newStatus = widget.rideData['status'];
    
    if (oldStatus != newStatus) {
       // ADAPTIVE CALC
       final double screenHeight = MediaQuery.of(context).size.height;
       final double safeAreaBottom = MediaQuery.of(context).viewPadding.bottom;
       // BUFFER: Added +20px
       const double kPickupHeight = 420.0; 
       const double kStartedHeight = 340.0;
       
       final double targetPixel = (newStatus == 'started') ? kStartedHeight : kPickupHeight;
       final double targetSize = ((targetPixel + safeAreaBottom) / screenHeight).clamp(0.20, 0.90);
       final bool isExpanding = targetSize > _currentMaxHeight;
       final duration = const Duration(milliseconds: 300);
       
       if (isExpanding) {
           // Unlock first to allow expansion
           setState(() {
             _currentMaxHeight = targetSize;
           });
           WidgetsBinding.instance.addPostFrameCallback((_) {
             if (widget.controller != null && widget.controller!.isAttached) {
               widget.controller!.animateTo(targetSize, duration: duration, curve: Curves.easeInOut);
             }
           });
       } else {
           // Animate first then lock
           if (widget.controller != null && widget.controller!.isAttached) {
             widget.controller!.animateTo(targetSize, duration: duration, curve: Curves.easeInOut);
           }
           Future.delayed(duration + const Duration(milliseconds: 50), () {
              if (mounted) {
                setState(() {
                  _currentMaxHeight = targetSize;
                });
              }
           });
       }
    }
  }

  @override
  Widget build(BuildContext context) {
    final passenger = widget.rideData['passenger'] as Map<String, dynamic>?;
    final String passengerName = passenger != null 
        ? StringUtils.maskName('${passenger['first_name']} ${passenger['last_name']}') 
        : 'ride.passenger'.tr();
    final double rating = (passenger?['rating'] as num?)?.toDouble() ?? 5.0;
    final String photoUrl = passenger?['profile_photo'] ?? '';
    final String pickupAddress = widget.rideData['start_address'] ?? widget.rideData['pickup_address'] ?? 'ride.pickup_point'.tr();
    final String dropoffAddress = widget.rideData['end_address'] ?? widget.rideData['dropoff_address'] ?? 'ride.dropoff_point'.tr();
    final bool isStarted = widget.rideData['status'] == 'started';

    // Use real-time data passed from parent, otherwise fallback to ride data
    final durationMins = widget.currentDurationSeconds != null 
        ? (widget.currentDurationSeconds! / 60) 
        : ((widget.rideData['duration_seconds'] as num?)?.toDouble() ?? 600) / 60;
    final distanceKm = widget.currentDistanceMeters != null 
        ? (widget.currentDistanceMeters! / 1000) 
        : ((widget.rideData['distance_meters'] as num?)?.toDouble() ?? 2500) / 1000;

    // ADAPTIVE HEIGHT LOGIC
    final double screenHeight = MediaQuery.of(context).size.height;
    final double safeAreaBottom = MediaQuery.of(context).viewPadding.bottom;
    
    // Define heights (approximate pixels based on design)
    // Pickup Mode: Header(100) + Timeline(80) + Actions(100) + Padding ~ 380px
    const double kPickupHeight = 400.0; 
    // Started Mode: Header(100) + Timeline(80) + FinishBtn(60) + Padding ~ 320px
    const double kStartedHeight = 320.0;

    final double targetPixelHeight = isStarted ? kStartedHeight : kPickupHeight;
    final double totalTarget = targetPixelHeight + safeAreaBottom;
    
    // Calculate fraction
    final double targetFraction = (totalTarget / screenHeight).clamp(0.25, 0.85);

    // Update internal state variable if this build overrides it?
    // Note: We use _currentMaxHeight for animation state.
    // If we want purely adaptive, we should sync _currentMaxHeight with targetFraction
    // BUT we need to respect the animation logic (didUpdateWidget). 
    // Best approach: Initialize _currentMaxHeight with adaptive logic in initState/didChangeDependencies?
    // For now, let's use the calculated fraction as the REFERENCE for maxChildSize.
    
    // Logic moved to variables above, this block just returns widget
    // Clean build
    return DraggableScrollableSheet(
      controller: widget.controller,
      initialChildSize: targetFraction,
      minChildSize: 0.2, 
      maxChildSize: targetFraction,
      snap: true,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 16,
                spreadRadius: 4,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            child: AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20, 
                  8, 
                  20, 
                  MediaQuery.of(context).viewPadding.bottom + 16 // System padding + extra
                ), 
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                     // Drag Handle
                    Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // HEADER: Profile (Left) - Stats & Actions (Right)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // LEFT: Passenger Profile
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                ClipOval(
                                  child: Container(
                                    width: 60, // Increased from 48
                                    height: 60, // Increased from 48
                                    decoration: BoxDecoration( // Added decoration for modern look if supported on Container (ClipOval clips it though, let's keep it simple)
                                        color: Colors.grey[200],
                                    ),
                                    child: photoUrl.isNotEmpty
                                        ? Image.network(
                                            photoUrl.startsWith('http') ? photoUrl : '${AppConstants.baseUrl}/$photoUrl',
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) =>
                                                Icon(Icons.person, size: 36, color: Colors.grey[400]), // Incr size
                                          )
                                        : Icon(Icons.person, size: 36, color: Colors.grey[400]), // Incr size
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        passengerName,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 20, // Increased from 18
                                          fontWeight: FontWeight.w900,
                                          color: Colors.black87,
                                          height: 1.2,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Text(
                                            rating.toStringAsFixed(1),
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          ...List.generate(5, (index) {
                                            return Icon(
                                              index < rating.round() ? Icons.star : Icons.star_border,
                                              color: const Color(0xFFFFD700),
                                              size: 14,
                                            );
                                          }),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(width: 8),

                          // RIGHT: Stats Card
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                               Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).primaryColor,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Theme.of(context).primaryColor.withOpacity(0.3),
                                        blurRadius: 4, 
                                        offset: const Offset(0, 2),
                                      )
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.access_time_filled, color: Colors.white, size: 14),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${durationMins.ceil()} dk',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                      Container(
                                        width: 1, 
                                        height: 12, 
                                        color: Colors.white.withOpacity(0.5),
                                        margin: const EdgeInsets.symmetric(horizontal: 8),
                                      ),
                                      const Icon(Icons.directions_car, color: Colors.white, size: 14),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${distanceKm.toStringAsFixed(1)} km',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ],
                                  ),
                               ),
                               if (isStarted) ...[
                                 const SizedBox(height: 8),
                                  // Cancel (Started - Outlined)
                                  OutlinedButton.icon(
                                    onPressed: () {
                                      final rideId = widget.rideData['ride_id']?.toString() ?? widget.rideData['id']?.toString();
                                      if (rideId != null) {
                                        _showCancelDialog(context, ref, rideId);
                                      }
                                    },
                                    icon: const Icon(Icons.close, size: 14, color: Colors.red),
                                    label: Text('ride.cancel_ride'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 11)),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Colors.red),
                                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                                      minimumSize: Size.zero, 
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      backgroundColor: Colors.transparent,
                                    ),
                                  ),
                               ]
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12), 

                    // Route Timeline Box
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 0),
                      child: InkWell(
                        onTap: () {
                          final targetLat = isStarted 
                              ? double.tryParse(widget.rideData['end_lat']?.toString() ?? '') 
                              : double.tryParse(widget.rideData['start_lat']?.toString() ?? '');
                          final targetLng = isStarted 
                              ? double.tryParse(widget.rideData['end_lng']?.toString() ?? '') 
                              : double.tryParse(widget.rideData['start_lng']?.toString() ?? '');
                              
                          _launchMaps(
                            isStarted ? dropoffAddress : pickupAddress,
                            targetLat,
                            targetLng
                          );
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                     BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  isStarted ? Icons.location_on_rounded : Icons.my_location_rounded,
                                  color: isStarted ? Colors.red : Theme.of(context).primaryColor,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isStarted ? 'sheet.dropoff_title'.tr() : 'sheet.pickup_title'.tr(),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isStarted ? Colors.red[300] : Theme.of(context).primaryColor.withOpacity(0.6),
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      isStarted ? dropoffAddress : pickupAddress,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.black87,
                                        height: 1.2,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.navigation, color: Colors.blue, size: 20),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Action Area
                    if (!isStarted) ...[
                       Text(
                        'ride.enter_code_desc'.tr(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                       const SizedBox(height: 12),
                       _buildPinput(context),
                       const SizedBox(height: 24),
                       Row(
                         mainAxisAlignment: MainAxisAlignment.center,
                         children: [
                           // Message Box
                           OutlinedButton.icon(
                              onPressed: () {
                                 final rideId = widget.rideData['ride_id']?.toString() ?? widget.rideData['id']?.toString();
                                  if (rideId != null) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => DriverChatScreen(rideId: rideId)),
                                    );
                                  }
                              },
                              icon: Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Theme.of(context).primaryColor),
                              label: Text('ride.send_message'.tr(), style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor, fontSize: 13)),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Theme.of(context).primaryColor),
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                backgroundColor: Colors.transparent,
                              ),
                             ),
                           
                           const SizedBox(width: 12),

                           // Cancel
                           OutlinedButton.icon(
                              onPressed: () {
                                 final rideId = widget.rideData['ride_id']?.toString() ?? widget.rideData['id']?.toString();
                                  if (rideId != null) {
                                    _showCancelDialog(context, ref, rideId);
                                  }
                              },
                              icon: const Icon(Icons.close, size: 16, color: Colors.red),
                              label: Text('ride.cancel_ride'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 13)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.red),
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                backgroundColor: Colors.transparent,
                              ),
                             ),
                         ],
                       ),
                    ] else ...[
                      SizedBox(
                        height: 52,
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            final rideId = widget.rideData['ride_id']?.toString() ?? widget.rideData['id']?.toString();
                            if (rideId != null) {
                              _showEndRideDialog(context, ref, rideId);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 6,
                            shadowColor: Theme.of(context).primaryColor.withOpacity(0.4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: Text(
                            'ride.finish_trip'.tr(),
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, letterSpacing: 1),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPinput(BuildContext context) {
    final defaultPinTheme = PinTheme(
      width: 50,
      height: 50,
      textStyle: TextStyle(
          fontSize: 24,
          color: Theme.of(context).primaryColor,
          fontWeight: FontWeight.bold),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.transparent),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: Theme.of(context).primaryColor, width: 2),
    );

    final submittedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration!.copyWith(
        color: const Color(0xFFE3F2FD),
      ),
    );

    return _isVerifying 
        ? const Center(
            child: Padding(
              padding: EdgeInsets.all(12.0),
              child: SizedBox(
                height: 48,
                width: 48,
                child: CircularProgressIndicator(),
              ),
            ),
          )
        : Pinput(
            length: 4,
            controller: _otpController, 
            focusNode: _otpFocusNode,   
            defaultPinTheme: defaultPinTheme,
            focusedPinTheme: focusedPinTheme,
            submittedPinTheme: submittedPinTheme,
            showCursor: true,
            pinputAutovalidateMode: PinputAutovalidateMode.onSubmit,
            onCompleted: (pin) => _verifyAndStartRide(pin),
          );
  }

  // Helper placeholder to match replaced structure
  Widget _buildOtpField(BuildContext context, int index) {
      return const SizedBox.shrink();
  }
  
  // Note: _buildTimelineItem is unused in the build method above? 
  // Ah, the build method inlines the timeline. Keeping this helper just in case or we can remove it.


  Future<void> _launchMaps(String address, [double? lat, double? lng]) async {
    Uri url;
    
    // Prefer address if it's descriptive
    bool isGenericAddress = address.toLowerCase().contains('konum') || address.isEmpty;
    
    if (!isGenericAddress) {
       final query = Uri.encodeComponent(address);
       url = Uri.parse('google.navigation:q=$query');
    } else if (lat != null && lng != null) {
       // Fallback to coordinates
       url = Uri.parse('google.navigation:q=$lat,$lng');
    } else {
       // Last resort
       final query = Uri.encodeComponent(address);
       url = Uri.parse('google.navigation:q=$query');
    }

    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      String query;
       if (!isGenericAddress) {
          query = Uri.encodeComponent(address);
       } else if (lat != null && lng != null) {
          query = '$lat,$lng';
       } else {
          query = Uri.encodeComponent(address);
       }
       
      final webUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
      if (await canLaunchUrl(webUrl)) {
        await launchUrl(webUrl);
      }
    }
  }

  void _showCancelDialog(BuildContext context, WidgetRef ref, String rideId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DriverCancellationSheet(rideId: rideId),
    );
  }

  void _showEndRideDialog(BuildContext context, WidgetRef ref, String rideId) {
     final TextEditingController fareController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
               Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_rounded, color: Theme.of(context).primaryColor, size: 32),
              ),
              const SizedBox(height: 20),
              Text(
                'ride.end_ride_title'.tr(),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
               const SizedBox(height: 8),
              Text(
                'ride.enter_fare'.tr(),
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: fareController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.center, 
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold), 
                decoration: InputDecoration(
                  prefixText: '₺',
                  prefixStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                  hintText: '0.00',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                ),
              ),
               const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text('sheet.cancel_button'.tr(), style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        final fareText = fareController.text.replaceAll(',', '.');
                        final fare = double.tryParse(fareText);
                        
                if (fare != null) {
                          double minFare = 175;
                          double maxFare = 50000;
                          
                          // Dynamic limits based on estimate
                          // Ensure we handle string or number types for `fare_estimate`
                          final estimateRaw = widget.rideData['fare_estimate'];
                          double? estimate;
                          if (estimateRaw != null) {
                            estimate = double.tryParse(estimateRaw.toString());
                          }

                          if (estimate != null && estimate > 0) {
                              minFare = estimate * 0.90;
                              maxFare = estimate * 1.25;
                          }

                          if (fare >= minFare && fare <= maxFare) {
                              HapticFeedback.mediumImpact();
                              Navigator.pop(context);
                              
                              // OPTIMISTIC UI: Hide sheet instantly ('Zınk')
                              ref.read(optimisticRideProvider.notifier).completeRide();
                              
                              ref.read(socketServiceProvider).socket.emit('driver:end_ride', {
                                'ride_id': rideId,
                                'fare_actual': fare,
                              });
                          } else {
                              CustomNotificationService().show(
                                context,
                                'Tutar ${minFare.toStringAsFixed(2)} TL ile ${maxFare.toStringAsFixed(2)} TL arasında olmalıdır.',
                                ToastType.error
                              );
                          }
                        } else {
                           CustomNotificationService().show(
                                context,
                                'Geçerli bir tutar giriniz.',
                                ToastType.error
                              );
                        }
                      },
                       style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor, 
                        foregroundColor: Colors.white,
                        elevation: 0,
                         padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        shadowColor: Theme.of(context).primaryColor.withOpacity(0.4),
                      ),
                      child: Text('ride.finish'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
