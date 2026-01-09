import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:driver_app/core/services/socket_service.dart';
import 'package:easy_localization/easy_localization.dart';

class RideRequestScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> requestData;

  const RideRequestScreen({Key? key, required this.requestData}) : super(key: key);

  @override
  ConsumerState<RideRequestScreen> createState() => _RideRequestScreenState();
}

class _RideRequestScreenState extends ConsumerState<RideRequestScreen> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _setupMap();
  }

  void _setupMap() {
    final startLat = widget.requestData['start']['lat'];
    final startLng = widget.requestData['start']['lng'];
    final endLat = widget.requestData['end']['lat'];
    final endLng = widget.requestData['end']['lng'];

    if (startLat != null && startLng != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('start'),
          position: LatLng(double.parse(startLat.toString()), double.parse(startLng.toString())),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(title: 'ride.pickup'.tr()),
        ),
      );
    }

    if (endLat != null && endLng != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('end'),
          position: LatLng(double.parse(endLat.toString()), double.parse(endLng.toString())),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: 'ride.dropoff'.tr()),
        ),
      );
    }
  }

  void _acceptRide() {
    final socketService = ref.read(socketServiceProvider);
    final rideId = widget.requestData['ride_id'];
    
    // Socket üzerinden kabul et
    socketService.socket.emit('driver:accept_request', {'ride_id': rideId});
    
    debugPrint('Ride Accepted: $rideId');
    Navigator.pop(context, true); // true dönerse kabul edildi
  }

  void _rejectRide() {
    final socketService = ref.read(socketServiceProvider);
    final rideId = widget.requestData['ride_id'];
    
    // Socket üzerinden reddet
    socketService.socket.emit('driver:reject_request', {'ride_id': rideId});
    
    debugPrint('Ride Rejected: $rideId');
    Navigator.pop(context, false); // false dönerse reddedildi
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.requestData;
    final distance = data['distance'] != null ? (data['distance'] / 1000).toStringAsFixed(1) : '--';
    final duration = data['duration'] != null ? (data['duration'] / 60).toStringAsFixed(0) : '--';
    final fare = data['fare_estimate'] ?? '--';
    final startAddress = data['start']['address'] ?? 'Bilinmeyen Konum';
    final endAddress = data['end']['address'] ?? 'Bilinmeyen Varış';

    return Scaffold(
      body: Stack(
        children: [
          // Harita Arkaplanı
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _markers.isNotEmpty 
                  ? _markers.first.position 
                  : const LatLng(41.0082, 28.9784), // Default Istanbul
              zoom: 13,
            ),
            markers: _markers,
            onMapCreated: (controller) => _mapController = controller,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),

          // Alt Bilgi Kartı
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'incoming_request.new_request_alert'.tr(),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildInfoItem(Icons.timer, '$duration dk'),
                      _buildInfoItem(Icons.directions, '$distance km'),
                      _buildInfoItem(Icons.attach_money, '₺$fare'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildLocationRow(Icons.my_location, 'ride.pickup'.tr(), startAddress, Colors.orange),
                  const SizedBox(height: 10),
                  _buildLocationRow(Icons.location_on, 'ride.dropoff'.tr(), endAddress, Colors.amber),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _rejectRide,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: const BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: const Text(
                            'sheet.new_request.reject'.tr(),
                            style: const TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _acceptRide,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: const Text(
                            'sheet.new_request.accept'.tr(),
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Column(
      children: [
        Icon(icon, color: Colors.grey[600], size: 28),
        const SizedBox(height: 4),
        Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildLocationRow(IconData icon, String label, String address, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                address,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
