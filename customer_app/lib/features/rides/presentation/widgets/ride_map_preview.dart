import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../ride/data/directions_service.dart';

class RideMapPreview extends ConsumerStatefulWidget {
  final double startLat;
  final double startLng;
  final double endLat;
  final double endLng;

  const RideMapPreview({
    super.key,
    required this.startLat,
    required this.startLng,
    required this.endLat,
    required this.endLng,
  });

  @override
  ConsumerState<RideMapPreview> createState() => _RideMapPreviewState();
}

class _RideMapPreviewState extends ConsumerState<RideMapPreview> {
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};
  GoogleMapController? _controller;

  @override
  void initState() {
    super.initState();
    _setupMap();
  }

  Future<void> _setupMap() async {
    final start = LatLng(widget.startLat, widget.startLng);
    final end = LatLng(widget.endLat, widget.endLng);

    _markers = {
      Marker(
        markerId: const MarkerId('start'),
        position: start,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ),
      Marker(
        markerId: const MarkerId('end'),
        position: end,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ),
    };

    try {
      final routeInfo = await ref.read(directionsServiceProvider).getRoute(start, end);
      if (mounted && routeInfo != null && routeInfo.points.isNotEmpty) {
        final points = routeInfo.points;
        setState(() {
          _polylines = {
            Polyline(
              polylineId: const PolylineId('route'),
              points: points,
              color: const Color(0xFF0865ff), // Deep Blue
              width: 4,
              jointType: JointType.round,
              startCap: Cap.roundCap,
              endCap: Cap.roundCap,
              geodesic: true,
            ),
          };
        });
        
        // Fit bounds after a short delay to ensure map is ready
        Future.delayed(const Duration(milliseconds: 500), () {
          _fitBounds(points);
        });
      }
    } catch (e) {
      debugPrint('Error fetching preview route: $e');
    }
  }

  void _fitBounds(List<LatLng> points) {
    if (_controller == null || points.isEmpty) return;
    
    double? x0, x1, y0, y1;
    for (LatLng latLng in points) {
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
    
    _controller!.animateCamera(CameraUpdate.newLatLngBounds(
      LatLngBounds(northeast: LatLng(x1!, y1!), southwest: LatLng(x0!, y0!)),
      20,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: GoogleMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(widget.startLat, widget.startLng),
            zoom: 12,
          ),
          markers: _markers,
          polylines: _polylines,
          zoomControlsEnabled: false,
          myLocationButtonEnabled: false,
          mapToolbarEnabled: false,
          liteModeEnabled: true, // Use lite mode for better performance in lists
          onMapCreated: (controller) {
            _controller = controller;
            if (_polylines.isNotEmpty) {
               // If polylines already loaded
               _fitBounds(_polylines.first.points);
            }
          },
        ),
      ),
    );
  }
}
