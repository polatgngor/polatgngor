import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'ride_state_provider.dart';
import 'ride_controller.dart';
import '../../../core/services/location_service.dart';
import '../data/places_service.dart';
import '../data/saved_place_model.dart';
import 'saved_places_provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../core/widgets/custom_toast.dart';

class LocationSelectionScreen extends ConsumerStatefulWidget {
  const LocationSelectionScreen({super.key});

  @override
  ConsumerState<LocationSelectionScreen> createState() => _LocationSelectionScreenState();
}

class _LocationSelectionScreenState extends ConsumerState<LocationSelectionScreen> {
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();
  final FocusNode _startFocus = FocusNode();
  final FocusNode _endFocus = FocusNode();
  
  List<PlacePrediction> _predictions = [];
  Timer? _debounce;
  bool _isSelectingStart = false; // Track which field is being edited

  @override
  void initState() {
    super.initState();
    final rideState = ref.read(rideProvider);
    if (rideState.startAddress != null) {
      _startController.text = rideState.startAddress!;
    } else {
      _startController.text = "location_selection.current_location".tr();
      // If start location is missing, try fetching it
      if (rideState.startLocation == null) {
         _fetchCurrentLocation();
      }
    }
    if (rideState.endAddress != null) {
      _endController.text = rideState.endAddress!;
    }

    _startFocus.addListener(() {
      if (_startFocus.hasFocus) {
        setState(() {
          _isSelectingStart = true;
          _predictions = [];
        });
      }
    });

    _endFocus.addListener(() {
      if (_endFocus.hasFocus) {
        setState(() {
          _isSelectingStart = false;
          _predictions = [];
        });
      }
    });
  }

  Future<void> _fetchCurrentLocation() async {
    try {
      final position = await ref.read(locationServiceProvider).getCurrentPosition();
      final address = await ref.read(placesServiceProvider).getAddressFromCoordinates(
        position.latitude, 
        position.longitude
      );
      
      final displayAddress = address ?? "location_selection.current_location".tr();
      
      ref.read(rideProvider.notifier).setStartLocation(
        LatLng(position.latitude, position.longitude),
        displayAddress,
      );
      
      if (mounted) {
        setState(() {
          _startController.text = displayAddress;
        });
      }
    } catch (e) {
      // Handle error
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (query.length > 2) {
        final results = await ref.read(placesServiceProvider).getPredictions(query);
        if (mounted) {
          setState(() {
            _predictions = results;
          });
        }
      } else {
        setState(() {
          _predictions = [];
        });
      }
    });
  }

  Future<void> _onPredictionSelected(PlacePrediction prediction) async {
    final details = await ref.read(placesServiceProvider).getPlaceDetails(prediction.placeId);
    if (details != null) {
      final latLng = LatLng(details.lat, details.lng);
      final address = details.address;

      if (_isSelectingStart) {
        debugPrint('Setting Start Location: $address');
        ref.read(rideProvider.notifier).setStartLocation(latLng, address);
        _startController.text = address;
      } else {
        debugPrint('Setting End Location: $address');
        ref.read(rideProvider.notifier).setEndLocation(latLng, address);
        _endController.text = address;
        
        // Explicitly pass fresh coordinates to ensure immediate route update
        final rideState = ref.read(rideProvider);
        ref.read(rideControllerProvider.notifier).updateRoute(
          rideState.startLocation, 
          latLng // The new end location
        );

        // If end location is selected, we can go back
        if (mounted) context.pop();
      }
      
      setState(() {
        _predictions = [];
      });
      FocusScope.of(context).unfocus();
    }
  }

  Future<void> _showAddPlaceDialog() async {
    final titleController = TextEditingController();
    
    // Default address logic
    String initialAddress = _startController.text;
    if (initialAddress.isEmpty || initialAddress == "location_selection.current_location".tr()) {
        final rideState = ref.read(rideProvider);
        if (rideState.startLocation != null) {
           initialAddress = rideState.startAddress ?? "";
        }
    }
    
    if (initialAddress.isEmpty) {
        if (mounted) {
          CustomNotificationService().show(
            context,
            'location_selection.save_dialog.error_select_location'.tr(),
            ToastType.error,
          );
        }
        return;
    }

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('location_selection.save_dialog.title'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: InputDecoration(
                labelText: 'location_selection.save_dialog.label'.tr(),
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            Text(
              initialAddress,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('location_selection.save_dialog.cancel'.tr())),
          TextButton(
            onPressed: () async {
              if (titleController.text.isNotEmpty) {
                final rideState = ref.read(rideProvider);
                
                double lat = 0;
                double lng = 0;
                String addr = initialAddress;
                
                // Try to find coords for the address from provider
                if (rideState.startLocation != null && rideState.startAddress == initialAddress) {
                   lat = rideState.startLocation!.latitude;
                   lng = rideState.startLocation!.longitude;
                } else if (rideState.endLocation != null && rideState.endAddress == initialAddress) {
                   lat = rideState.endLocation!.latitude;
                   lng = rideState.endLocation!.longitude;
                } else {
                   // Fallback: Use start location if available
                   if (rideState.startLocation != null) {
                      lat = rideState.startLocation!.latitude;
                      lng = rideState.startLocation!.longitude;
                   }
                }
                
                if (lat != 0) {
                    try {
                      await ref.read(savedPlacesProvider.notifier).addPlace(
                        title: titleController.text,
                        address: addr,
                        lat: lat,
                        lng: lng,
                        icon: _getIconForTitle(titleController.text),
                      );
                      if (context.mounted) Navigator.pop(context);
                    } catch (e) {
                      // error handling
                    }
                }
              }
            },
            child: Text('location_selection.save_dialog.save'.tr()),
          ),
        ],
      ),
    );
  }

  String _getIconForTitle(String title) {
    title = title.toLowerCase();
    if (title.contains('ev')) return 'home';
    if (title.contains('iş') || title.contains('ofis')) return 'work';
    return 'place';
  }

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    _startFocus.dispose();
    _endFocus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listen to changes in RideState to keep fields in sync (e.g. if Map Selection updates them)
    ref.listen(rideProvider, (previous, next) {
      // Sync Start Address
      if (next.startAddress != _startController.text && next.startAddress != null) {
         _startController.text = next.startAddress!;
         _startController.selection = TextSelection.fromPosition(TextPosition(offset: _startController.text.length));
      } else if (next.startLocation == null && _startController.text.isNotEmpty && _startController.text != "location_selection.current_location".tr()) {
         _startController.clear();
      }

      // Sync End Address
      if (next.endAddress != _endController.text) {
         if (next.endAddress != null) {
           _endController.text = next.endAddress!;
           _endController.selection = TextSelection.fromPosition(TextPosition(offset: _endController.text.length));
         } else {
           _endController.clear();
         }
      }
    });

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header & Input Section
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back Button & Title
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                        onPressed: () => context.pop(),
                      ),
                      Text(
                        'location_selection.title'.tr(),
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Inputs Container
                  Column(
                    children: [
                      // Start Location Input
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F4F8), // Light gray
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.my_location, color: Theme.of(context).primaryColor, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _startController,
                                focusNode: _startFocus,
                                decoration: InputDecoration(
                                  hintText: 'location_selection.start_hint'.tr(),
                                  border: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  errorBorder: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                                ),
                                style: const TextStyle(fontWeight: FontWeight.w500),
                                onChanged: _onSearchChanged,
                              ),
                            ),
                            if (_startController.text.isNotEmpty)
                              GestureDetector(
                                onTap: () {
                                  _startController.clear();
                                  _onSearchChanged('');
                                },
                                child: Icon(Icons.close, color: Colors.grey[400], size: 18),
                              ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 12), // Separation space

                      // End Location Input
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F4F8), // Light gray
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.location_on, color: Theme.of(context).primaryColor, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _endController,
                                focusNode: _endFocus,
                                autofocus: true,
                                decoration: InputDecoration(
                                  hintText: 'location_selection.end_hint'.tr(),
                                  border: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  errorBorder: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                                ),
                                style: const TextStyle(fontWeight: FontWeight.w500),
                                onChanged: _onSearchChanged,
                              ),
                            ),
                             if (_endController.text.isNotEmpty)
                              GestureDetector(
                                onTap: () {
                                  _endController.clear();
                                  _onSearchChanged('');
                                },
                                child: Icon(Icons.close, color: Colors.grey[400], size: 18),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
              if (_predictions.isEmpty) ...[
                const SizedBox(height: 16),
                
                 // Map Selection Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Material(
                    color: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Theme.of(context).primaryColor.withOpacity(0.5)),
                    ),
                    child: InkWell(
                      onTap: () {
                         // Activate Map Selection Mode
                         ref.read(rideProvider.notifier).toggleMapSelection(
                           true, 
                           mode: _isSelectingStart ? 'start' : 'end'
                         );
                         context.pop(); // Close selection screen
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.map, color: Theme.of(context).primaryColor),
                            const SizedBox(width: 12),
                            Text(
                              'location_selection.select_on_map'.tr(),
                              style: TextStyle(
                                fontSize: 16, 
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).primaryColor
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'location_selection.saved_places'.tr(),
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    TextButton.icon(
                      onPressed: _showAddPlaceDialog,
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      label: Text('location_selection.add_place'.tr()),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              
              Expanded(
                child: Consumer(
                  builder: (context, ref, child) {
                    final savedPlacesState = ref.watch(savedPlacesProvider);
                    
                    return savedPlacesState.when(
                      data: (places) {
                        if (places.isEmpty) {
                           return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.bookmark_border, size: 48, color: Colors.grey[300]),
                                const SizedBox(height: 12),
                                Text('location_selection.no_saved_places'.tr(), style: TextStyle(color: Colors.grey[500])),
                              ],
                            ),
                           );
                        }
                        
                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: places.length,
                          itemBuilder: (context, index) {
                            final place = places[index];
                            return Dismissible(
                              key: Key(place.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                color: Colors.red[100],
                                child: const Icon(Icons.delete_outline, color: Colors.red),
                              ),
                              onDismissed: (direction) {
                                ref.read(savedPlacesProvider.notifier).deletePlace(place.id);
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey[200]!),
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                                    child: Icon(
                                      place.title.toLowerCase() == 'ev' ? Icons.home : 
                                      place.title.toLowerCase().contains('iş') ? Icons.work : Icons.place,
                                      color: Theme.of(context).primaryColor,
                                      size: 20,
                                    ),
                                  ),
                                  title: Text(place.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  subtitle: Text(
                                    place.address,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                  ),
                                  onTap: () {
                                     // Use this place
                                     final latLng = LatLng(place.lat, place.lng);
                                     if (_isSelectingStart) {
                                        ref.read(rideProvider.notifier).setStartLocation(latLng, place.address);
                                        _startController.text = place.address;
                                     } else {
                                        ref.read(rideProvider.notifier).setEndLocation(latLng, place.address);
                                        _endController.text = place.address;
                                        ref.read(rideControllerProvider.notifier).updateRoute();
                                        if (mounted) context.pop();
                                     }
                                  },
                                ),
                              ),
                            );
                          },
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, st) => Center(child: Text('Hata: $e')),
                    );
                  },
                ),
              ),
            ],

            // Predictions List (Only when searching)
            if (_predictions.isNotEmpty)
            Expanded(
              child: _predictions.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.map_outlined, size: 60, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text(
                            'location_selection.search_hint'.tr(),
                            style: TextStyle(color: Colors.grey[500], fontSize: 16),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                      itemCount: _predictions.length,
                      itemBuilder: (context, index) {
                        final prediction = _predictions[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey[200]!),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.place, color: Theme.of(context).primaryColor, size: 20),
                            ),
                            title: Text(
                              prediction.mainText,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            subtitle: Text(
                              prediction.secondaryText,
                              style: TextStyle(color: Colors.grey[600], fontSize: 13),
                            ),
                            onTap: () => _onPredictionSelected(prediction),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
