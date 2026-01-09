import 'dart:async';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/socket_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/widgets/custom_toast.dart';
import '../../auth/data/auth_service.dart';
import 'widgets/match_processing_sheet.dart';
import 'widgets/driver_stats_sheet.dart';
import 'screens/incoming_requests_screen.dart';
import 'providers/incoming_requests_provider.dart';
import 'providers/optimistic_ride_provider.dart';
import 'widgets/passenger_info_sheet.dart';
import 'widgets/driver_drawer.dart';
import '../../rides/presentation/widgets/rating_dialog.dart';
import '../../rides/data/ride_repository.dart';
import '../../../core/services/ringtone_service.dart';
import '../../../core/services/directions_service.dart';
import '../../splash/presentation/home_loading_screen.dart'; // Import Loading Screen
import 'package:flutter_native_splash/flutter_native_splash.dart';
import '../../notifications/presentation/notification_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with WidgetsBindingObserver, TickerProviderStateMixin {
  final Completer<GoogleMapController> _controller = Completer();
  GoogleMapController? _mapController; // Added as per instruction
  // Default to Istanbul center if location not yet found
  LatLng _currentPosition = const LatLng(41.0082, 28.9784); 
  bool _hasRealLocation = false;
  
  // Loading State
  bool _isLoading = true;

  
  bool _isOnline = false;
  StreamSubscription<Position>? _positionSubscription;
  Map<String, dynamic>? _incomingRequest; 
  Map<String, dynamic>? _activeRide;
  String _refCode = ''; 
  
  Timer? _locationUpdateTimer;
  
  // Flow Animation Removed

  Set<Polyline> _polylines = {};
  
  // Route Stats
  int? _routeDistanceMeters;
  int? _routeDurationSeconds;
  DateTime? _lastRouteFetchTime;
  
  // Lazy Loading for "Heavy" widgets (Map) to prevent transition freeze
  bool _readyForHeavyContent = false;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>(); // ADDED KEY

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // OPTIMIZED: Delay heavy content (Map) initialization
    WidgetsBinding.instance.addPostFrameCallback((_) {
       Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) setState(() => _readyForHeavyContent = true);
       });
    });

    
    // Flow Animation Removed

    _initializeLocation();
    WakelockPlus.enable();
    // Initialize Notifications
    ref.read(notificationServiceProvider).initialize();
    // Sync state on startup
    _syncState();
    

    // Smooth Transition Timer
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        FlutterNativeSplash.remove(); // Remove NATIVE splash now
        setState(() => _isLoading = false); // Fade out overlay
      }
    });
  } // End of initState

  // Methods Removed

  final DraggableScrollableController _statsSheetController = DraggableScrollableController();
  final DraggableScrollableController _passengerInfoController = DraggableScrollableController();

  Future<void> _checkOverlayPermission() async {
    // On Android 10+, special permission is needed to start activity from background
    // or to show over other apps.
    if (Theme.of(context).platform == TargetPlatform.android) {
        final status = await Permission.systemAlertWindow.status;
        if (!status.isGranted) {
           // Show dialog explaining why
           if (mounted) {
             showDialog(
               context: context,
               builder: (ctx) => AlertDialog(
                 title: const Text('İzin Gerekli'),
                 content: const Text('Arka planda kapalıyken bile çağrı geldiğinde uygulamanın açılabilmesi için "Diğer uygulamaların üzerinde gösterim" iznine ihtiyacımız var. Lütfen açılan ekranda Taksibu Sürücü uygulamasını bulup izni açınız.'),
                 actions: [
                   TextButton(
                     onPressed: () => Navigator.pop(ctx), 
                     child: const Text('Daha Sonra')
                   ),
                   ElevatedButton(
                     onPressed: () {
                       Navigator.pop(ctx);
                       Permission.systemAlertWindow.request();
                     },
                     child: const Text('İzni Ver'),
                   ),
                 ],
               ),
             );
           }
        }

        // Check for Notification Permission (Android 13+)
        // Critical for WakeUpReceiver to post the FullScreenIntent Notification
        final notifStatus = await Permission.notification.status;
        if (!notifStatus.isGranted) {
           await Permission.notification.request();
        }

        // Also check for "Ignore Battery Optimizations" to ensure socket stays alive
        final batteryStatus = await Permission.ignoreBatteryOptimizations.status;
        if (!batteryStatus.isGranted) {
           if (mounted) {
             showDialog(
               context: context,
               builder: (ctx) => AlertDialog(
                 title: const Text('Pil Optimizasyonu'),
                 content: const Text('Uygulamanın arka planda kesintisiz çalışabilmesi ve çağrıları kaçırmamanız için "Pil Optimizasyonunu Yoksay" izni vermeniz gerekmektedir.'),
                 actions: [
                   TextButton(
                     onPressed: () => Navigator.pop(ctx), 
                     child: const Text('Daha Sonra')
                   ),
                   ElevatedButton(
                     onPressed: () {
                       Navigator.pop(ctx);
                       Permission.ignoreBatteryOptimizations.request();
                     },
                     child: const Text('İzni Ver'),
                   ),
                 ],
               ),
             );
           }
        }
    }
  }




  Future<void> _animateToLocation() async {
    try {
      final position = await ref.read(locationServiceProvider).determinePosition();
      final controller = await _controller.future;
      controller.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(position.latitude, position.longitude),
          zoom: 12, 
        ),
      ));
    } catch (_) {}
  }

  @override
  void dispose() {
    // Flow controller removed
    _statsSheetController.dispose();
    _passengerInfoController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _positionSubscription?.cancel();
    _locationUpdateTimer?.cancel();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listen for Optimistic Updates (Zero Latency)
    ref.listen(optimisticRideProvider, (previous, next) {
      // Logic for Switching States
      if (next.isMatching || next.activeRide != null) {
         // Eğer drawer açıksa kapat (Kullanıcı isteği: drawer açık olsa bile ana ekrana dönmeli)
         if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
            _scaffoldKey.currentState?.closeDrawer();
         }
      }

      if (next.isCompleting) {
        // Optimistic Completion: Clear sheet immediately ("Zınk")
        setState(() {
          _activeRide = null;
          _polylines.clear();
          _activeRide = null;
          _polylines.clear();
          // Flow Reset Removed
        });
        debugPrint('Optimistic Completion Triggered');
        // We don't need to do anything else, the socket 'end_ride_ok' will eventually confirm,
        // but the user is already unblocked.
        
      } else if (next.activeRide != null) {
        // Optimistic Success: Switch to Ride
        setState(() {
          _activeRide = next.activeRide;
          _fetchAndDrawRoute(fitBounds: true);
        });
        debugPrint('Optimistic Ride Update applied: ${next.activeRide!['status']}');
      } else if (next.activeRide == null && !next.isMatching) {
         // Cleared (e.g. failure reverting)
         if (_activeRide != null && previous?.activeRide != null) {
            // Only if we were in optimistic state, revert.
             setState(() {
               _activeRide = null;
               _polylines.clear();
               _polylines.clear();
               // Flow Reset Removed
             });
         }
      }
    });

    return Scaffold(
      key: _scaffoldKey, // Attach Key
      resizeToAvoidBottomInset: false, // PERFORMANCE FIX: Prevent Map resize when keyboard opens
      drawer: const DriverDrawer(),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              // Map Layer
              _readyForHeavyContent ? GoogleMap(
                  trafficEnabled: true,
                  mapType: MapType.normal,
                  initialCameraPosition: CameraPosition(
                    target: _currentPosition,
                    zoom: 12, // Standardized City View
                  ),
                  myLocationEnabled: true,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      // Padding reduced to 0 to match Customer App (hiding Google Logo under sheet)
                      padding: EdgeInsets.zero, 
                      onMapCreated: (GoogleMapController controller) {
                        _controller.complete(controller);
                      },
                      markers: _createMarkers(),
                      polylines: {
                        ..._polylines,
                        // Flow removed
                           // Flow removed
                      },
                    ) : const SizedBox.shrink(), // Lightweight on first frame

              // Menu Button (Top Left)
              Positioned(
                top: 50,
                left: 16,
                child: Builder(
                  builder: (context) => Container(
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
                      icon: Consumer(
                        builder: (context, ref, child) {
                          final notifState = ref.watch(notificationNotifierProvider);
                          final count = notifState.totalUnreadMessages;
                          
                          if (count > 0) {
                             return Badge(
                               label: Text('$count'),
                               backgroundColor: Colors.red,
                               child: const Icon(Icons.menu, color: Colors.black),
                             );
                          }
                          return const Icon(Icons.menu, color: Colors.black);
                        }
                      ),
                      onPressed: () {
                        Scaffold.of(context).openDrawer();
                      },
                    ),
                  ),
                ),
              ),

                // BRANDING LOGO (Bottom Left - Floating with Sheet)
                AnimatedBuilder(
                  animation: Listenable.merge([_statsSheetController, _passengerInfoController]),
                  builder: (context, child) {
                    double bottomPosition = 16.0;
                    double sheetHeight = 0.0;
                    
                    try {
                      if (_activeRide != null) {
                         if (_passengerInfoController.isAttached) {
                           sheetHeight = _passengerInfoController.size * constraints.maxHeight;
                         }
                      } else {
                         if (_statsSheetController.isAttached) {
                           sheetHeight = _statsSheetController.size * constraints.maxHeight;
                         }
                      }
                    } catch (_) {}
                    
                    if (sheetHeight == 0) {
                      // Adaptive Fallback
                      final double safeArea = MediaQuery.of(context).viewPadding.bottom;
                      double targetPixels = _activeRide != null ? 380.0 : 350.0;
                      targetPixels += safeArea;
                      sheetHeight = targetPixels;
                    }
                    
                    // SAFE AREA VALIDATION
                    double minBottom = MediaQuery.of(context).viewPadding.bottom + 16;
                    bottomPosition = sheetHeight + 10;
                    if (bottomPosition < minBottom) bottomPosition = minBottom;
                    
                    return Positioned(
                      left: 16,
                      bottom: bottomPosition,
                      child: child!,
                    );
                  },
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                    // Decoration removed
                    child: Center(
                      child: Text(
                        'taksibu',
                        style: GoogleFonts.montserrat(
                          color: const Color(0xFF0866ff),
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -1.0,
                        ),
                      ),
                    ),
                  ),
                ),

              // Custom Location Button
              AnimatedBuilder(
                animation: Listenable.merge([_statsSheetController, _passengerInfoController]),
                builder: (context, child) {
                  double bottomPosition = 16.0;
                  double sheetHeight = 0.0;
                  
                  // Calculate height based on active sheet
                  try {
                    if (_activeRide != null) {
                       if (_passengerInfoController.isAttached) {
                         sheetHeight = _passengerInfoController.size * constraints.maxHeight;
                       }
                    } else {
                       if (_statsSheetController.isAttached) {
                         sheetHeight = _statsSheetController.size * constraints.maxHeight;
                       }
                    }
                  } catch (_) {}
                  
                  // Fallback defaults if not attached yet
                  if (sheetHeight == 0) {
                      final double safeArea = MediaQuery.of(context).viewPadding.bottom;
                      double targetPixels = _activeRide != null ? 380.0 : 350.0;
                      targetPixels += safeArea;
                      sheetHeight = targetPixels; 
                  }
                  
                  // SAFE AREA VALIDATION
                  double minBottom = MediaQuery.of(context).viewPadding.bottom + 16;
                  bottomPosition = sheetHeight + 16;
                  if (bottomPosition < minBottom) bottomPosition = minBottom;
                  
                  return Positioned(
                    right: 16,
                    bottom: bottomPosition,
                    child: child!,
                  );
                },
                child: Material(
                  color: Colors.white,
                  shape: const CircleBorder(),
                  elevation: 4,
                  shadowColor: Colors.black26,
                  child: InkWell(
                    onTap: _animateToLocation,
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

              // Bottom Sheets (Swappable)
              Positioned.fill(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (Widget child, Animation<double> animation) {
                     return SlideTransition(
                       position: Tween<Offset>(
                         begin: const Offset(0.0, 1.0),
                         end: Offset.zero,
                       ).animate(animation),
                       child: child,
                     );
                  },
                  child: () {
                     // 1. Optimistic Matching State ("Zınk" Transition Sheet)
                     final optimisticState = ref.watch(optimisticRideProvider);
                     
                     if (optimisticState.isMatching) {
                       return MatchProcessingSheet(
                         key: const ValueKey('match_processing_sheet'),
                       );
                     }
                     
                     // 2. Active Ride (Passenger Info)
                     if (_activeRide != null) {
                       return PassengerInfoSheet(
                          key: const ValueKey('passenger_info_sheet'),
                          rideData: _activeRide!,
                          controller: _passengerInfoController,
                          driverLocation: _currentPosition,
                          currentDistanceMeters: _routeDistanceMeters,
                          currentDurationSeconds: _routeDurationSeconds,
                        );
                     }
                     
                     // 3. Default (Driver Stats)
                     return DriverStatsSheet(
                          key: const ValueKey('driver_stats_sheet'),
                          refCount: 12, 
                          refCode: _refCode,
                          controller: _statsSheetController,
                          isOnline: _isOnline,
                          onStatusChanged: _toggleOnlineStatus,
                        );
                  }(),
                ),
              ),

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
        },
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncState(fitBounds: false);
    } else if (state == AppLifecycleState.detached) {
      // Release service if app is killed
      FlutterBackgroundService().invoke("stopService");
    }
  }

  Future<void> _syncState({bool fitBounds = true}) async {
    try {
      // Fetch profile if refCode is empty
      if (_refCode.isEmpty) {
        try {
          final profile = await ref.read(authServiceProvider).getProfile();
          if (mounted) {
             setState(() {
                _refCode = profile['user']['ref_code'] ?? '';
             });
          }
        } catch (_) {}
      }

      // 1. Check for active ride
      final repository = ref.read(driverRideRepositoryProvider);
      final activeRideData = await repository.getActiveRide();
      
      if (activeRideData != null) {
        final ride = activeRideData['ride'];
        if (!_isOnline) {
          _toggleOnlineStatus(true);
        }
        setState(() {
          _activeRide = ride;
          _fetchAndDrawRoute(fitBounds: fitBounds);
        });


        
        if (_isOnline) {
           ref.read(socketServiceProvider).emit('driver:rejoin');
        }
      } else {
        // 2. If no active ride, we remain in our current state (Online or Offline)
        // Do NOT force offline just because there is no ride.
        if (_isOnline) {
           // We are online but have no ride -> We are searching/available
           ref.read(socketServiceProvider).emit('driver:rejoin');
           ref.read(socketServiceProvider).emitAvailability(true);
        } else {
           // We are offline, do nothing or ensure offline
           // ref.read(socketServiceProvider).emitAvailability(false);
        }
      }
    } catch (e) {
      debugPrint('Error syncing driver state: $e');
    }
  }

  void _setupSocketListeners() {
    final socket = ref.read(socketServiceProvider).socket;
    
    socket.off('request:incoming');
    socket.on('request:incoming', (data) {
      debugPrint('Driver App received request:incoming: $data');
      if (mounted) {
        debugPrint('Playing Ringtone for new request...');
        ref.read(ringtoneServiceProvider).playRingtone();
        
        final requestsNotifier = ref.read(incomingRequestsProvider.notifier);
        final currentRequests = ref.read(incomingRequestsProvider);
        final wasEmpty = currentRequests.isEmpty;

        requestsNotifier.addRequest(data);

        if (wasEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const IncomingRequestsScreen(),
            ),
          ).then((_) {
            // Handle return
          });
        }
      }
    });

    socket.off('request:timeout_alert');
    socket.on('request:timeout_alert', (data) {
       // Optional: speed up ringtone or show toast
    });

    socket.off('request:accept_failed');
    socket.on('request:accept_failed', (data) {
      if (mounted) {
        ref.read(ringtoneServiceProvider).stopRingtone();
        
        // Revert Optimistic UI
        ref.read(optimisticRideProvider.notifier).clear();
        setState(() {
          _activeRide = null; 
          _polylines.clear();
          // Flow cleanup
        });
        
        ref.read(incomingRequestsProvider.notifier).removeRequest(data['ride_id'].toString());
        
        // Show error
        CustomNotificationService().show(
          context,
          'Çağrı kabul edilemedi: ${data['reason'] ?? 'Başka sürücü aldı'}',
          ToastType.error
        );
        debugPrint('Çağrı kabul edilemedi: ${data['reason'] ?? 'Bilinmeyen hata'}');
        
        // Ensure we emit availability again so we can get new requests
        _setDriverAvailable();
      }
    });

    socket.off('request:timeout');
    socket.on('request:timeout', (data) {
      if (mounted) {
        ref.read(ringtoneServiceProvider).stopRingtone();
        ref.read(incomingRequestsProvider.notifier).removeRequest(data['ride_id'].toString());
        debugPrint('Çağrı zaman aşımına uğradı.');
      }
    });

    socket.off('request:accepted_confirm');
    socket.on('request:accepted_confirm', (data) {
      if (mounted) {
        ref.read(ringtoneServiceProvider).stopRingtone();
        setState(() {
          _activeRide = data;
          ref.read(incomingRequestsProvider.notifier).clearRequests();
          _syncState(fitBounds: true); // Revert to true to trigger smart zoom
        });


      }
    });

    socket.off('ride:cancelled');
    socket.off('ride:cancelled');
    socket.on('ride:cancelled', (data) {
      if (mounted) {
        ref.read(ringtoneServiceProvider).stopRingtone(); // Ensure ringtone stops if it was ringing
        
        // Also remove from request list just in case
        if (data['ride_id'] != null) {
           ref.read(incomingRequestsProvider.notifier).removeRequest(data['ride_id'].toString());
        }

        // Clear Optimistic UI if any
        ref.read(optimisticRideProvider.notifier).clear();
        
        setState(() {
          _activeRide = null;
          _polylines.clear();
          // Flow cleanup
        });
        
        _setDriverAvailable(); // Auto-available in background
        _setDriverAvailable(); // Auto-available in background
        debugPrint('Yolculuk iptal edildi. (${data['reason'] ?? 'Sebep belirtilmedi'})');
        
        // RESET SHEET POSITION
        WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_statsSheetController.isAttached) {
               // Calculate optimal fractional height
               final double screenHeight = MediaQuery.of(context).size.height;
               final double safeAreaBottom = MediaQuery.of(context).viewPadding.bottom;
               final double targetHeight = 250.0 + safeAreaBottom; // Matches the constant in driver_stats_sheet.dart
               final double targetFraction = (targetHeight / screenHeight).clamp(0.15, 0.85);
               
               _statsSheetController.jumpTo(targetFraction);
            }
        });
      }
    });

    socket.off('start_ride_ok');
    socket.on('start_ride_ok', (data) {
      if (mounted) {
        setState(() {
          if (_activeRide != null) {
            // Create a copy to ensure didUpdateWidget detects the change
            final updatedRide = Map<String, dynamic>.from(_activeRide!);
            updatedRide['status'] = 'started';
            _activeRide = updatedRide;
            _fetchAndDrawRoute(fitBounds: true);
          }
        });


      }
    });

    socket.off('end_ride_ok');
    socket.on('request:taken', (data) {
      if (mounted) {
        ref.read(ringtoneServiceProvider).stopRingtone();
        ref.read(incomingRequestsProvider.notifier).removeRequest(data['ride_id'].toString());
        CustomNotificationService().show(
          context,
          'Çağrı başka bir sürücü tarafından kabul edildi.',
          ToastType.info
        );
      }
    });

    socket.on('request:cancelled', (data) {
      if (mounted) {
        ref.read(ringtoneServiceProvider).stopRingtone();
        ref.read(incomingRequestsProvider.notifier).removeRequest(data['ride_id'].toString());
        CustomNotificationService().show(
          context,
          'Yolcu çağrıyı iptal etti.',
          ToastType.info
        );
      }
    });

    socket.on('end_ride_ok', (data) {
      if (mounted) {
        final rideId = _activeRide?['ride_id']?.toString() ?? data['ride_id']?.toString();
        
        // Capture passenger name before clearing state
        final passenger = _activeRide?['passenger'];
        final passengerName = passenger != null 
            ? '${passenger['first_name']} ${passenger['last_name']}' 
            : 'ride.passenger'.tr();

        setState(() {
          _activeRide = null;
          _polylines.clear();
          // Flow cleanup
        });

        _setDriverAvailable(); // Force availability

        debugPrint('Yolculuk tamamlandı.');
        
        // RESET SHEET POSITION
        WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_statsSheetController.isAttached) {
               // Calculate optimal fractional height
               final double screenHeight = MediaQuery.of(context).size.height;
               final double safeAreaBottom = MediaQuery.of(context).viewPadding.bottom;
               final double targetHeight = 250.0 + safeAreaBottom; // Matches the constant in driver_stats_sheet.dart
               final double targetFraction = (targetHeight / screenHeight).clamp(0.15, 0.85);
               
               _statsSheetController.jumpTo(targetFraction);
            }
        });
        
        // Show Rating Dialog
        if (rideId != null) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => DriverRatingDialog(rideId: rideId, passengerName: passengerName),
          ).then((_) {
             // Force sync state AGAIN after dialog closes to ensure we are back to "Searching" UI
             _syncState(fitBounds: false);
          });
        }
      }
    });
    
    socket.off('ride:rejoined');
    socket.on('ride:rejoined', (data) async {
      if (mounted) {
        try {
          setState(() {
             _activeRide = data; 
             _fetchAndDrawRoute(fitBounds: true);
          });
  
  
        } catch (e) {
          debugPrint('Error handling ride:rejoined: $e');
        }
      }
    });

    socket.off('driver:availability_error');
    socket.on('driver:availability_error', (data) {
      if (mounted) {
        setState(() {
          _isOnline = false;
        });
         debugPrint('Müsait duruma geçilemedi: ${data['message']}');
      }
    });

    socket.off('driver:availability_updated');
    socket.on('driver:availability_updated', (data) {
      if (mounted) {
        debugPrint('Availability updated: ${data['available']}');
        // Optional confirmation feedback
      }
    });

    socket.off('start_ride_failed');
    socket.on('start_ride_failed', (data) {
      if (mounted) {
        final reason = data['reason'] ?? 'unknown';
        debugPrint('Yolculuğu başlatma hatası: $reason');
      }
    });

    socket.off('end_ride_failed');
    socket.on('end_ride_failed', (data) {
      if (mounted) {
        final reason = data['reason'] ?? 'unknown';
        debugPrint('Yolculuğu bitirme hatası: $reason');
      }
    });

    socket.off('request:reject_failed');
    socket.on('request:reject_failed', (data) {
      if (mounted) {
        final reason = data['reason'] ?? 'unknown';
        debugPrint('Çağrı reddetme hatası: $reason');
      }
    });

    socket.off('request:rejected_confirm');
    socket.on('request:rejected_confirm', (data) {
      if (mounted) {
        debugPrint('Request rejected confirmed: ${data['ride_id']}');
      }
    });

    socket.off('message_failed');
    socket.on('message_failed', (data) {
      if (mounted) {
        final reason = data['reason'] ?? 'unknown';
        debugPrint('Mesaj gönderilemedi: $reason');
      }
    });

    socket.off('cancel_ride_ok');
    socket.on('cancel_ride_ok', (data) {
      if (mounted) {
        setState(() {
          _activeRide = null;
          _polylines.clear();
          // Flow cleanup
        });

        _setDriverAvailable();

        debugPrint('Yolculuk başarıyla iptal edildi.');
      }
    });

    socket.off('cancel_ride_failed');
    socket.on('cancel_ride_failed', (data) {
      if (mounted) {
        final reason = data['reason'] ?? 'unknown';
        debugPrint('İptal işlemi başarısız: $reason');
      }
    });
  }

  Future<void> _initializeLocation() async {
    try {
      final position = await ref.read(locationServiceProvider).determinePosition();
      if (!mounted) return;
      
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        _hasRealLocation = true;
      });
      
      final controller = await _controller.future;
      controller.animateCamera(CameraUpdate.newLatLng(_currentPosition));
    } catch (e) {
      if (mounted) {
        debugPrint('Konum hatası: $e');
      }
    }
  }

  Future<void> _setDriverAvailable() async {
    // If user manually switched offline, don't force online.
    if (!_isOnline) {
      debugPrint('Cannot set available: Driver is manually offline');
      return;
    }

    final socketService = ref.read(socketServiceProvider);
    
    // Ensure connected
    if (!socketService.isSocketConnected) {
       debugPrint('Socket disconnected, reconnecting before setting availability...');
       await socketService.connect();
       await Future.delayed(const Duration(milliseconds: 1000));
    }

    try {
      if (_currentPosition == null) {
        debugPrint('Current position null, fetching...');
        final pos = await ref.read(locationServiceProvider).determinePosition();
        setState(() {
          _currentPosition = LatLng(pos.latitude, pos.longitude);
        });
      }

      final vehicleType = await ref.read(authServiceProvider).getVehicleType();
      
      // Force emit availability
      socketService.emitAvailability(
        true,
        lat: _currentPosition!.latitude,
        lng: _currentPosition!.longitude,
        vehicleType: vehicleType,
      );
      
      debugPrint('Driver availability FORCE reset. Lat: ${_currentPosition!.latitude}');
      


    } catch (e) {
      debugPrint('Error setting availability: $e');
    }
  }

  void _toggleOnlineStatus(bool value) async {
    final socketService = ref.read(socketServiceProvider);
    final locationService = ref.read(locationServiceProvider);
    final authService = ref.read(authServiceProvider);

    setState(() {
      _isOnline = value;
    });

    if (_isOnline) {
      // Go Online
      await socketService.connect();
      _setupSocketListeners();
      
      final service = FlutterBackgroundService();
    if (!await service.isRunning()) {
      await service.startService();
    }

    final token = await authService.getToken();
      if (token != null) {
        service.invoke("setToken", {"token": token});
      }
      service.invoke("setAsForeground");
      
      final vehicleType = await authService.getVehicleType();
      final position = await locationService.determinePosition();
      
      socketService.emitAvailability(true, lat: position.latitude, lng: position.longitude, vehicleType: vehicleType);
      
      _positionSubscription = locationService.getPositionStream().listen((position) {
        final latLng = LatLng(position.latitude, position.longitude);
        setState(() {
          _currentPosition = latLng;
        });
        
        // DISABLED: Auto-tracking removed to allow manual map control


        socketService.emitLocationUpdate(position.latitude, position.longitude, vehicleType: vehicleType);

        // Update Route Periodically (throttled 15s)
        if (_activeRide != null) {
          final now = DateTime.now();
          if (_lastRouteFetchTime == null || now.difference(_lastRouteFetchTime!).inSeconds > 15) {
             _fetchAndDrawRoute();
          }
        }
      });

      _locationUpdateTimer?.cancel();
      _locationUpdateTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
        if (_currentPosition != null) {
           socketService.emitLocationUpdate(_currentPosition!.latitude, _currentPosition!.longitude, vehicleType: vehicleType);
        }
      });
      
      if (mounted) {
        debugPrint('Online notification displayed (snackbar removed)');
      }
    } else {
      // Go Offline
      socketService.emitAvailability(false);
      await Future.delayed(const Duration(milliseconds: 500));
      
      socketService.disconnect();
      _positionSubscription?.cancel();
      _locationUpdateTimer?.cancel();
      
      FlutterBackgroundService().invoke("stopService");
      
      if (mounted) {
        debugPrint('Offline notification displayed (snackbar removed)');
      }
    }
  }

  Set<Marker> _createMarkers() {
    if (_activeRide == null) return {};

    final isStarted = _activeRide!['status'] == 'started';
    final Set<Marker> markers = {};

    if (isStarted) {
      final endLat = double.tryParse(_activeRide!['end_lat']?.toString() ?? 
                                   _activeRide!['dropoff_location']?['lat']?.toString() ?? 
                                   _activeRide!['end']?['lat']?.toString() ?? '');
      final endLng = double.tryParse(_activeRide!['end_lng']?.toString() ?? 
                                   _activeRide!['dropoff_location']?['lng']?.toString() ?? 
                                   _activeRide!['end']?['lng']?.toString() ?? '');
      final address = _activeRide!['end_address'] ?? _activeRide!['dropoff_address'] ?? 'Varış Noktası';

      if (endLat != null && endLng != null) {
        markers.add(Marker(
          markerId: const MarkerId('destination'),
          position: LatLng(endLat, endLng),
          infoWindow: InfoWindow(title: 'Varış', snippet: address),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue), // Blue (was Red)
        ));
      }
    } else {
      final startLat = double.tryParse(_activeRide!['start_lat']?.toString() ?? 
                                     _activeRide!['pickup_location']?['lat']?.toString() ?? 
                                     _activeRide!['start']?['lat']?.toString() ?? '');
      final startLng = double.tryParse(_activeRide!['start_lng']?.toString() ?? 
                                     _activeRide!['pickup_location']?['lng']?.toString() ?? 
                                     _activeRide!['start']?['lng']?.toString() ?? '');
      final address = _activeRide!['start_address'] ?? _activeRide!['pickup_address'] ?? 'Alış Noktası';

      if (startLat != null && startLng != null) {
        markers.add(Marker(
          markerId: const MarkerId('pickup'),
          position: LatLng(startLat, startLng),
          infoWindow: InfoWindow(title: 'Yolcu', snippet: address),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue), // Blue (was Green)
        ));
      }
    }

    return markers;
  }

  Future<void> _fetchAndDrawRoute({bool fitBounds = false}) async {
    if (_activeRide == null || _currentPosition == null) return;

    try {
      _lastRouteFetchTime = DateTime.now();
      LatLng start;
      LatLng end;

      // Strict Status Check
      // Only switch to Dropoff Route if status is EXPLICITLY 'started'
      // This prevents "End Point" route showing up while still picking up passenger
      final isStarted = _activeRide!['status'] == 'started';

      if (isStarted) {
        // PHASE 2: Driver -> Dropoff
        final endLat = double.tryParse(_activeRide!['end_lat']?.toString() ?? 
                                     _activeRide!['dropoff_location']?['lat']?.toString() ?? 
                                     _activeRide!['end']?['lat']?.toString() ?? '');
        final endLng = double.tryParse(_activeRide!['end_lng']?.toString() ?? 
                                     _activeRide!['dropoff_location']?['lng']?.toString() ?? 
                                     _activeRide!['end']?['lng']?.toString() ?? '');
        
        if (endLat == null || endLng == null) return;
        start = _currentPosition!; 
        end = LatLng(endLat, endLng);
      } else {
        // PHASE 1: Driver -> Pickup (Default for assigned/accepted/driverFound)
        start = _currentPosition!;
        final pickupLat = double.tryParse(_activeRide!['start_lat']?.toString() ?? 
                                        _activeRide!['pickup_location']?['lat']?.toString() ?? 
                                        _activeRide!['start']?['lat']?.toString() ?? '');
        final pickupLng = double.tryParse(_activeRide!['start_lng']?.toString() ?? 
                                        _activeRide!['pickup_location']?['lng']?.toString() ?? 
                                        _activeRide!['start']?['lng']?.toString() ?? '');
        
        if (pickupLat == null || pickupLng == null) return;
        end = LatLng(pickupLat, pickupLng);
      }

      final routeInfo = await ref.read(directionsServiceProvider).getRouteWithInfo(start, end);
      
      if (mounted && routeInfo != null) {
        final points = routeInfo['points'] as List<LatLng>;
        final dist = routeInfo['distance_meters'] as int;
        final dur = routeInfo['duration_seconds'] as int;

        if (points.isNotEmpty) {
          setState(() {
            _polylines = {
              Polyline(
                polylineId: const PolylineId('route'),
                points: points,
                color: const Color(0xFF0865ff), // Deep Blue
                width: 4, // Thinner (Standardized)
                jointType: JointType.round,
                startCap: Cap.roundCap,
                endCap: Cap.roundCap,
                geodesic: true,
              ),
            };
            _routeDistanceMeters = dist;
            _routeDurationSeconds = dur;
            // Flow cleanup
            // Reset... Removed
            // _flowPolylinePoints = []; // Removed 
          });
          
          if (fitBounds) {
             _controller.future.then((controller) {
               // Smart Zoom: Focus on driver's current position (start of route) with pleasant zoom
               // User request: "Yaklaşsın biraz"
               controller.animateCamera(CameraUpdate.newCameraPosition(
                 CameraPosition(
                   target: points.first, 
                   zoom: 14.5,
                 ),
               ));
             });
          }
        }
      }
    } catch (e) {
      debugPrint('Error drawing route: $e');
    }
  }

  LatLngBounds _boundsFromLatLngList(List<LatLng> list) {
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
