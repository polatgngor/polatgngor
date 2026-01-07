import 'dart:async';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/socket_service.dart';
import '../../../core/services/directions_service.dart';
import '../../ride/presentation/ride_booking_sheet.dart';
import '../../../core/services/notification_service.dart';
import '../../ride/presentation/ride_state_provider.dart';
import '../../notifications/presentation/notification_provider.dart';
import 'widgets/custom_drawer.dart';
import '../../ride/presentation/widgets/rating_dialog.dart';
import '../../ride/data/ride_repository.dart';
import '../../ride/data/places_service.dart';
import '../../ride/presentation/ride_controller.dart';
import '../../../core/utils/map_utils.dart';
import '../../splash/presentation/home_loading_screen.dart'; // Import Loading Screen
import 'package:flutter_native_splash/flutter_native_splash.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with WidgetsBindingObserver, TickerProviderStateMixin {
  final Completer<GoogleMapController> _controller = Completer();
  GoogleMapController? _mapController;
  bool _isUserInteracting = false;
  
  // Loading State
  bool _isLoading = true;
  // Lazy Loading for "Heavy" widgets (Map) to prevent transition freeze
  bool _readyForHeavyContent = false;

  
  // Default location (Istanbul Ataşehir)
  static const CameraPosition _kDefaultLocation = CameraPosition(
    target: LatLng(40.9971, 29.1007),
    zoom: 10.0,
  );

  final DraggableScrollableController _sheetController = DraggableScrollableController();
  double _sheetMaxHeight = 0.45;

  // Driver Animation
  late AnimationController _markerController;
  LatLng? _prevDriverPos;
  LatLng? _targetDriverPos;
  LatLng? _driverLocation; // (Existing or unrelated, just context)
  LatLng? _currentAnimatedPos;
  BitmapDescriptor? _driverIcon;
  
  // Flow Animation Removed


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // OPTIMIZED: Delay heavy content (Map) initialization by one frame
    // This ensures the navigation to this screen is INSTANT (showing the loading screen)
    // before we block the thread with Map creation.
    WidgetsBinding.instance.addPostFrameCallback((_) {
       Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) setState(() => _readyForHeavyContent = true);
       });
    });

    
    _markerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2), // Smooth 2s transition
    );
    
    _markerController.addListener(() {
      if (_prevDriverPos != null && _targetDriverPos != null) {
        final double t = _markerController.value;
        final double lat = _prevDriverPos!.latitude + (_targetDriverPos!.latitude - _prevDriverPos!.latitude) * t;
        final double lng = _prevDriverPos!.longitude + (_targetDriverPos!.longitude - _prevDriverPos!.longitude) * t;
        setState(() {
          _currentAnimatedPos = LatLng(lat, lng);
        });
      }
    });
    
    // Flow Animation Removed

    _initialize();
    _loadDriverIcon();
    
    // Smooth Transition Timer
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        FlutterNativeSplash.remove(); // Remove NATIVE splash now
        setState(() => _isLoading = false); // Fade out overlay
      }
    });
  }

  // Flow Methods Removed

  Future<void> _loadDriverIcon() async {
    try {
      final icon = await BitmapDescriptor.fromAssetImage(
        const ImageConfiguration(devicePixelRatio: 2.5), 
        'assets/images/taxi.png'
      );
      if (mounted) {
        setState(() => _driverIcon = icon);
      }
    } catch (e) {
      debugPrint('Driver icon load error: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncRideState();
    }
  }

  Future<void> _initialize() async {
    await _initSocket();
    if (mounted) {
      // Initialize Notifications
      ref.read(notificationServiceProvider).initialize();
      // Sync ride state on startup
      await _syncRideState();

      // Adjust sheet size after sync
      WidgetsBinding.instance.addPostFrameCallback((_) {
         if (_sheetController.isAttached) {
             final status = ref.read(rideProvider).status;
             
             // Same adaptive logic as ref.listen
             final double screenHeight = MediaQuery.of(context).size.height;
             final double safeArea = MediaQuery.of(context).viewPadding.bottom;
             double pixelHeight = 350.0;

             // REF: User Requests & Buffer for Fixed Content
             // Searching/Found -> 220 + Buffer = 240
             if (status == RideStatus.searching) pixelHeight = 240.0;
             else if (status == RideStatus.driverFound) pixelHeight = 370.0; 
             else if (status == RideStatus.rideStarted) pixelHeight = 230.0; 
             else if (status == RideStatus.driverFoundTransition) pixelHeight = 240.0;
             else if (status == RideStatus.noDriverFound) pixelHeight = 320.0;
             else pixelHeight = 410.0; // Reduced from 460 (Removed bottom padding)

             // Strict clamp to ensure it fits but doesn't overflow
             double targetHeight = ((pixelHeight + safeArea) / screenHeight).clamp(0.12, 0.95);

             _sheetController.jumpTo(targetHeight);
         }
      });
    }
  }

  Future<void> _syncRideState() async {
    try {
      final repository = ref.read(rideRepositoryProvider);
      await ref.read(rideProvider.notifier).syncState(repository);
    } catch (e) {
      debugPrint('Error syncing ride state: $e');
    }
  }

  Future<void> _initSocket() async {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'accessToken');
    if (token != null) {
      final socketService = ref.read(socketServiceProvider);
      socketService.init(token);
    }
  }

  Future<void> _fetchAndDrawRoute(LatLng start, LatLng end) async {
    try {
      final result = await ref.read(directionsServiceProvider).getRoute(start, end);
      
      if (result.isNotEmpty && result['points'] != null) {
        final List<LatLng> points = result['points'];
        
          ref.read(rideProvider.notifier).setPolylines({
          // Base Polyline
          Polyline(
            polylineId: const PolylineId('route'),
            points: points,
            color: const Color(0xFF0865ff), // Deep Blue (Requested)
            width: 5, // Slightly thinner (was 4 or 5?) - User said "birazcık daha ince" 
            // Wait, previous was 4. "Daha ince" means 3 or 3.5. Let's make it 3.5.
            // Oh wait, previous code showed width: 4.
            // Let's try 3.5.
            jointType: JointType.round,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
            geodesic: true,
          ),
        });
        
        // Update Route Info (Distance/Duration)
        if (result['distance_value'] != null && result['duration_value'] != null) {
           ref.read(rideProvider.notifier).setRouteInfo(
             fare: 0, // We calculated fare earlier or backend does it
             distance: result['distance_value'],
             duration: result['duration_value'],
           );
        }
      }
    } catch (e) {
      debugPrint('Error drawing route: $e');
    }
  }

  Set<Marker> _createMarkers(RideState rideState) {
    if (rideState.isSelectingOnMap) return {}; // Clean map during selection

    final markers = <Marker>{};

    // Show Start Marker ONLY if End Location is set (User Request: "Sadece başlangıç ve bitiş girildiğinde ikon koyulsun")
    // AND Ride not started
    if (rideState.startLocation != null && rideState.endLocation != null && rideState.status != RideStatus.rideStarted) {
      markers.add(
        Marker(
          markerId: const MarkerId('start'),
          position: rideState.startLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue), // Theme Blue
          infoWindow: InfoWindow(title: rideState.startAddress ?? 'ride.start_location'.tr()),
        ),
      );
    }

    // Show End Marker UNLESS Driver Found (pickup phase) - User requested removal during pickup
    if (rideState.endLocation != null && rideState.status != RideStatus.driverFound) {
      markers.add(
        Marker(
          markerId: const MarkerId('end'),
          position: rideState.endLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue), // Blue (was Red)
          infoWindow: InfoWindow(title: rideState.endAddress ?? 'ride.end_location'.tr()),
        ),
      );
    }

    // Show Driver Marker (Taxi) - Even during Ride Started (User Request: "Müşterinin anlık konumu taksi olsun")
  if (_currentAnimatedPos != null) {
    markers.add(
      Marker(
        markerId: const MarkerId('driver'),
        position: _currentAnimatedPos!,
        icon: _driverIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
        anchor: const Offset(0.5, 0.5), // Center anchor for car icon
        infoWindow: InfoWindow(title: 'ride.driver'.tr()),
        // ZIndex higher to stay on top
        zIndex: 2, 
      ),
    );
  }

    // Flow Marker removed in favor of Polyline Overlay


    return markers;
  }


  void _fitBounds(List<LatLng> points) {
    if (points.isEmpty || _mapController == null) return;

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (var point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        100, // Padding to ensure markers are not cut off
      ),
    );
  }

  Future<void> _animateToUser() async {
    _isUserInteracting = false;
    final position = await ref.read(locationServiceProvider).getCurrentPosition();
    final controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(
        target: LatLng(position.latitude, position.longitude),
        zoom: 12, 
      ),
    ));
  }
 
  @override
  void dispose() {
    // _flowController.dispose(); // Removed
    _markerController.dispose();
    _sheetController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rideState = ref.watch(rideProvider);
    
    // Auto-tracking disabled as per user request
    // ref.listen(currentLocationProvider, ...);

    ref.listen(rideProvider, (previous, next) {
      // Delay state updates to avoid 'setState during build' or 'markNeedsBuild'
      WidgetsBinding.instance.addPostFrameCallback((_) {
         if (!mounted) return;

          // Handle Driver Location Animation
          if (next.driverLocation != previous?.driverLocation) {
            if (next.driverLocation != null) {
              if (_currentAnimatedPos == null) {
                _currentAnimatedPos = next.driverLocation;
              } else {
                _prevDriverPos = _currentAnimatedPos;
                _targetDriverPos = next.driverLocation;
                _markerController.reset();
                _markerController.forward();
              }
            } else {
              setState(() {
                _currentAnimatedPos = null;
                _prevDriverPos = null;
                _targetDriverPos = null;
              });
            }
          }

          // Auto-zoom to fit route
          if (next.polylines.isNotEmpty && _mapController != null && previous?.polylines != next.polylines) {
             final points = next.polylines.first.points;
             if (points.isNotEmpty) {
                if (next.status == RideStatus.driverFound) {
                   // User request: "Biraz yaklaşsın ama zorla fitBounds yapmasın"
                   // Animate to driver/start location with a comfortable zoom level
                   _mapController!.animateCamera(
                      CameraUpdate.newCameraPosition(
                        CameraPosition(target: points.first, zoom: 14.5),
                      ),
                   );
                } else {
                   // Default: Fit bounds for other states
                   _fitBounds(points);
                }
             }
          }

          // Update local route points for animation
          // if (next.polylines.isNotEmpty) {
          //    _currentRoutePoints = next.polylines.first.points;
          // } else {
          //    _currentRoutePoints = [];
          //    _flowPolylinePoints = [];
          // }
          
          // Animate Sheet based on Status
          if (_sheetController.isAttached) {
            // ADAPTIVE CALCULATION
            final double screenHeight = MediaQuery.of(context).size.height;
            final double safeArea = MediaQuery.of(context).viewPadding.bottom;
            
            double pixelHeight = 350.0;
            
            switch (next.status) {
              case RideStatus.searching:
                pixelHeight = 240.0;
                break;
              case RideStatus.noDriverFound:
                pixelHeight = 320.0; // Increased from 240.0
                break;
              case RideStatus.driverFoundTransition:
                pixelHeight = 240.0;
                break;
              case RideStatus.driverFound: // Pickup
                pixelHeight = 370.0; 
                break;
              case RideStatus.rideStarted: // Trip
                pixelHeight = 230.0; 
                break;
              default: // Ride Request / Initial
                pixelHeight = 410.0; 
            }
            
             double targetHeight = ((pixelHeight + safeArea) / screenHeight).clamp(0.12, 0.95);

            // Only animate if status changed or strictly needed
            if (previous?.status != next.status) {
                final bool isExpanding = targetHeight > _sheetMaxHeight;
                final duration = const Duration(milliseconds: 500);
                final curve = Curves.easeInOutCubic;

                if (isExpanding) {
                    // Growing: Unlock ceiling first so it can expand
                    setState(() {
                       _sheetMaxHeight = targetHeight;
                    });
                     WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (_sheetController.isAttached) {
                           _sheetController.animateTo(targetHeight, duration: duration, curve: curve);
                        }
                     });
                } else {
                    // Shrinking: Animate down first while ceiling is still high
                    if (_sheetController.isAttached) {
                       _sheetController.animateTo(targetHeight, duration: duration, curve: curve);
                    }
                    
                    // Lock ceiling after animation finishes prevents snapping
                    Future.delayed(duration + const Duration(milliseconds: 50), () {
                       if (mounted) {
                          setState(() {
                             _sheetMaxHeight = targetHeight < 0.2 ? 0.2 : targetHeight;
                          });
                       }
                    });
                }
            }
          }
          
          // Handle Ride Completion
          if (next.status == RideStatus.completed && previous?.status != RideStatus.completed) {
            if (next.currentRideId != null) {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) {
                  final driver = next.driverInfo;
                  final driverName = driver != null 
                      ? '${driver['first_name']} ${driver['last_name']}' 
                      : 'ride.driver'.tr();
                  return RatingDialog(rideId: next.currentRideId!, driverName: driverName);
                },
              ).then((_) {
                if (mounted) { // double check
                  ref.read(rideProvider.notifier).resetRide();
                  setState(() {
                      _currentAnimatedPos = null;
                      _prevDriverPos = null;
                      _targetDriverPos = null;
                      _currentAnimatedPos = null;
                      _prevDriverPos = null;
                      _targetDriverPos = null;
                      // _currentRoutePoints = []; // Removed
                      // _flowPolylinePoints = []; // Removed
                  });
                }
              });
            } else {
              ref.read(rideProvider.notifier).resetRide();
            }
          }
      });
    });


    return Scaffold(
      resizeToAvoidBottomInset: false, // PERFORMANCE FIX
      drawer: const CustomDrawer(),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              // Map Layer
              Listener(
                onPointerDown: (_) => _isUserInteracting = true,
                child: _readyForHeavyContent ? GoogleMap(
                  trafficEnabled: false,
                  mapType: MapType.normal,
                  initialCameraPosition: _kDefaultLocation,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false, // Disable default button
                  zoomControlsEnabled: false,
                  onMapCreated: (GoogleMapController controller) {
                    _controller.complete(controller);
                    _mapController = controller;
                  },
                  markers: _createMarkers(rideState),
                  polylines: {
                     ...rideState.polylines,
                     // Flow Polyline Removed
                  },
                ) : const SizedBox.shrink(), // Lightweight on first frame
              ),
              
              // Menu Button (Top Left)
              Positioned(
                top: 50,
                left: 16,
                  child: Builder(
                  builder: (context) {
                    final notifState = ref.watch(notificationNotifierProvider);
                    return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: notifState.total > 0
                          ? Badge.count(
                              count: notifState.total,
                              backgroundColor: Colors.red,
                              child: const Icon(Icons.menu, color: Colors.black),
                            )
                          : const Icon(Icons.menu, color: Colors.black),
                      onPressed: () {
                        Scaffold.of(context).openDrawer();
                      },
                    ),
                  );
                 }
                ),
              ),

              // BRANDING LOGO (Bottom Left - Floating)
               if (!rideState.isSelectingOnMap)
              AnimatedBuilder(
                animation: _sheetController,
                builder: (context, child) {
                  double sheetHeight = 0.0;
                  try {
                     if (_sheetController.isAttached) {
                        sheetHeight = _sheetController.size * constraints.maxHeight;
                     } else {
                        // ADAPTIVE FALLBACK
                        final double safeArea = MediaQuery.of(context).viewPadding.bottom;
                        sheetHeight = 410.0 + safeArea; 
                     }
                  } catch (e) {
                     sheetHeight = 0;
                  }

                  // SAFE AREA validation for buttons
                  double bottomPos = sheetHeight + 10;
                  double minBottom = MediaQuery.of(context).viewPadding.bottom + 16;
                  if (bottomPos < minBottom) bottomPos = minBottom;

                  return Positioned(
                    left: 16,
                    bottom: bottomPos,
                    child: child!,
                  );
                },
                child: Container(
                    height: 48,
                    // padding removed to bring text closer to edge if needed, or kept minimal
                    padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8), 
                    // Decoration removed for transparent look
                    child: Center(
                      child: Text(
                        'taksibu',
                        style: GoogleFonts.montserrat(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -1.0,
                          color: const Color(0xFF0866ff),
                        ),
                      ),
                    ),
                  ),
              ),

              // Custom Location Button (Animated)
              if (rideState.status != RideStatus.searching && rideState.status != RideStatus.noDriverFound)
              AnimatedBuilder(
                animation: _sheetController,
                builder: (context, child) {
                  // Calculate position based on sheet size
                  double sheetHeight = 0.0;
                  try {
                    // size is fraction (0.0 - 1.0)
                     if (_sheetController.isAttached) {
                        sheetHeight = _sheetController.size * constraints.maxHeight;
                     } else {
                        // ADAPTIVE FALLBACK
                        final double safeArea = MediaQuery.of(context).viewPadding.bottom;
                        sheetHeight = 410.0 + safeArea; 
                     }
                  } catch (e) {
                     sheetHeight = 0;
                  }

                  // SAFE AREA validation for buttons
                  double bottomPos = sheetHeight + 16;
                  double minBottom = MediaQuery.of(context).viewPadding.bottom + 16;
                  if (bottomPos < minBottom) bottomPos = minBottom;

                  return Positioned(
                    right: 16,
                    bottom: bottomPos,
                    child: child!,
                  );
                },
                child: Material(
                  color: Colors.white,
                  shape: const CircleBorder(),
                  elevation: 4,
                  shadowColor: Colors.black26,
                  child: InkWell(
                    onTap: _animateToUser,
                    customBorder: const CircleBorder(),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Icon(
                        Icons.my_location,
                        color: Theme.of(context).primaryColor, 
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),

              // Ride Booking Sheet
              if (!rideState.isSelectingOnMap)
              Padding( // Wrap in Padding/Container if needed, or just the sheet
                 padding: EdgeInsets.zero,
                  child: DraggableScrollableSheet(
                    controller: _sheetController,
                    initialChildSize: _sheetMaxHeight, // Open at max height directly
                    minChildSize: 0.12, // Ultra-low min size for compact sheets
                    maxChildSize: _sheetMaxHeight, 
                    snap: true, 
                    builder: (context, scrollController) {
                      return RideBookingSheet(scrollController: scrollController);
                    },
                  ),
              ),

              // MAP SELECTION OVERLAY (Pin + Confirm Button)
              if (rideState.isSelectingOnMap) ...[
                // Center PIN
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 35.0), // Adjust for pin tip
                    child: Icon(
                      Icons.location_on, 
                      size: 50, 
                      color: rideState.selectionMode == 'start' 
                          ? Theme.of(context).primaryColor 
                          : Colors.red,
                    ),
                  ),
                ),
                // Center Shadow/Dot
                 Center(
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      shape: BoxShape.circle,
                      boxShadow: [
                         BoxShadow(
                           color: Colors.black.withOpacity(0.2),
                           blurRadius: 4,
                         )
                      ]
                    ),
                  ),
                ),
                
                // Top "Cancel" Button
                Positioned(
                  top: 50,
                  left: 16,
                  child: SafeArea(
                    child: CircleAvatar(
                      backgroundColor: Colors.white,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.black),
                        onPressed: () {
                           ref.read(rideProvider.notifier).toggleMapSelection(false);
                        },
                      ),
                    ),
                  ),
                ),

                // Bottom "Confirm" Button
                Positioned(
                  bottom: 30,
                  left: 20,
                  right: 20,
                  child: SafeArea(
                    child: ElevatedButton(
                      onPressed: () async {
                         if (_mapController != null) {
                            try {
                               // Get center location
                               final bounds = await _mapController!.getVisibleRegion();
                               final centerLat = (bounds.northeast.latitude + bounds.southwest.latitude) / 2;
                               final centerLng = (bounds.northeast.longitude + bounds.southwest.longitude) / 2;
                               
                               // Get Address
                               final places = ref.read(placesServiceProvider);
                               String address = "Harita Konumu"; // Default fallback
                               try {
                                   final addr = await places.getAddressFromCoordinates(centerLat, centerLng);
                                   if (addr != null && addr.isNotEmpty) {
                                      address = addr;
                                   }
                               } catch (e) {
                                  debugPrint('Address fetch error: $e');
                               }
                               
                               if (rideState.selectionMode == 'start') {
                                  ref.read(rideProvider.notifier).setStartLocation(LatLng(centerLat, centerLng), address);
                                  ref.read(rideProvider.notifier).toggleMapSelection(false);
                                  // RETURN TO FORM
                                  if (mounted) context.push('/location-selection'); 
                               } else {
                                  // 1. Set State
                                  ref.read(rideProvider.notifier).setEndLocation(LatLng(centerLat, centerLng), address);
                                  
                                  // 2. Close Selection UI IMMEDIATELY for instant feedback
                                  ref.read(rideProvider.notifier).toggleMapSelection(false);
                                  
                                  // 3. Calculate Route (Async)
                                  // Pass explicit coordinates to ensure it uses the fresh values
                                  final rideState = ref.read(rideProvider);
                                  ref.read(rideControllerProvider.notifier).updateRoute(
                                     rideState.startLocation, // Ensure start is used if available
                                     LatLng(centerLat, centerLng)
                                  );
                               }
                               
                            } catch (e) {
                               debugPrint('Selection error $e');
                            }
                         }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        elevation: 4,
                      ),
                      child: Text(
                        'location_selection.confirm_location'.tr(), 
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                      ),
                    ),
                  ),
                ),
              ],
              
              // Loading Overlay (Soft Transition)
              Positioned.fill(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 1500), // Slower fade
                  switchOutCurve: Curves.easeOut, // Soft curve
                  child: _isLoading 
                      ? const HomeLoadingScreen()
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          );
        }
      ),
    );
  }
}
