import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../data/ride_repository.dart';

part 'ride_state_provider.g.dart';

enum RideStatus {
  idle,           // No active ride
  searching,      // Looking for driver
  driverFoundTransition, // NEW: Optimistic transition state ("Zınk")
  driverFound,    // Driver assigned
  rideStarted,    // Ride in progress
  completed,      // Ride finished, show rating
  noDriverFound,  // Timeout/no driver available
}

class RideState {
  final LatLng? startLocation;
  final String? startAddress;
  final LatLng? endLocation;
  final String? endAddress;
  final String vehicleType; // 'sari', 'turkuaz', 'vip', '8+1'
  final bool openTaximeter;
  final bool hasPet;
  final String paymentMethod; // 'nakit', 'pos'
  final RideStatus status;
  final String? currentRideId;
  final Set<Polyline> polylines;
  final double? estimatedFare;
  final int? distanceMeters;
  final int? durationSeconds;
  final Map<String, dynamic>? driverInfo;
  final String? code4;
  final Map<String, double>? fareEstimates;
  final LatLng? driverLocation;
  final int? lastResetTime;
  final bool isSelectingOnMap;
  final String? selectionMode; // 'start' or 'end'

  const RideState({
    this.startLocation,
    this.startAddress,
    this.endLocation,
    this.endAddress,
    this.vehicleType = 'sari',
    this.openTaximeter = false,
    this.hasPet = false,
    this.paymentMethod = 'nakit',
    this.status = RideStatus.idle,
    this.currentRideId,
    this.polylines = const {},
    this.estimatedFare,
    this.distanceMeters,
    this.durationSeconds,
    this.driverInfo,
    this.code4,
    this.driverLocation,
    this.fareEstimates,
    this.lastResetTime,
    this.isSelectingOnMap = false,
    this.selectionMode,
  });

  RideState copyWith({
    LatLng? startLocation,
    String? startAddress,
    LatLng? endLocation,
    String? endAddress,
    String? vehicleType,
    bool? openTaximeter,
    bool? hasPet,
    String? paymentMethod,
    RideStatus? status,
    String? currentRideId,
    Set<Polyline>? polylines,
    double? estimatedFare,
    int? distanceMeters,
    int? durationSeconds,
    Map<String, dynamic>? driverInfo,
    String? code4,
    LatLng? driverLocation,
    Map<String, double>? fareEstimates,
    int? lastResetTime,
    bool? isSelectingOnMap,
    String? selectionMode,
  }) {
    return RideState(
      startLocation: startLocation ?? this.startLocation,
      startAddress: startAddress ?? this.startAddress,
      endLocation: endLocation ?? this.endLocation,
      endAddress: endAddress ?? this.endAddress,
      vehicleType: vehicleType ?? this.vehicleType,
      openTaximeter: openTaximeter ?? this.openTaximeter,
      hasPet: hasPet ?? this.hasPet,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      status: status ?? this.status,
      currentRideId: currentRideId ?? this.currentRideId,
      polylines: polylines ?? this.polylines,
      estimatedFare: estimatedFare ?? this.estimatedFare,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      driverInfo: driverInfo ?? this.driverInfo,
      code4: code4 ?? this.code4,
      driverLocation: driverLocation ?? this.driverLocation,
      fareEstimates: fareEstimates ?? this.fareEstimates,
      lastResetTime: lastResetTime ?? this.lastResetTime,
      isSelectingOnMap: isSelectingOnMap ?? this.isSelectingOnMap,
      selectionMode: selectionMode ?? this.selectionMode,
    );
  }
  double? get fare => estimatedFare;
}

@Riverpod(keepAlive: true)
class Ride extends _$Ride {
  @override
  RideState build() {
    return const RideState();
  }

  void setStartLocation(LatLng location, String address) {
    state = state.copyWith(startLocation: location, startAddress: address);
  }

  void setEndLocation(LatLng location, String address) {
    state = state.copyWith(endLocation: location, endAddress: address);
  }

  void setVehicleType(String type) {
    state = state.copyWith(vehicleType: type);
  }

  void toggleTaximeter(bool value) {
    state = state.copyWith(openTaximeter: value);
  }

  void togglePet(bool value) {
    state = state.copyWith(hasPet: value);
  }
  
  void setPaymentMethod(String method) {
    state = state.copyWith(paymentMethod: method);
  }

  void setRideStatus(RideStatus status, {String? rideId}) {
    state = state.copyWith(status: status, currentRideId: rideId);
  }

  void setPolylines(Set<Polyline> polylines) {
    state = state.copyWith(polylines: polylines);
  }

  void setRouteInfo({required double fare, required int distance, required int duration}) {
    state = state.copyWith(estimatedFare: fare, distanceMeters: distance, durationSeconds: duration);
  }

  void setFareEstimates(Map<String, double> estimates) {
    state = state.copyWith(fareEstimates: estimates);
  }

  void setDriverInfo(Map<String, dynamic> driver, String code) {
    state = state.copyWith(driverInfo: driver, code4: code);
  }

  void setDriverLocation(LatLng location) {
    state = state.copyWith(driverLocation: location);
  }

  void toggleMapSelection(bool value, {String? mode}) {
    state = state.copyWith(isSelectingOnMap: value, selectionMode: mode);
  }

  Future<void> syncState(RideRepository repository) async {
    final activeRideData = await repository.getActiveRide();
    if (activeRideData != null) {
      final ride = activeRideData['ride'];
      final driver = activeRideData['driver'];
      
      final statusStr = ride['status'];
      RideStatus status = RideStatus.idle;
      bool isActiveRide = false;
      
      switch (statusStr) {
        case 'requested':
          status = RideStatus.searching;
          isActiveRide = true;
          break;
        case 'assigned':
          status = RideStatus.driverFound;
          isActiveRide = true;
          break;
        case 'started':
          status = RideStatus.rideStarted;
          isActiveRide = true;
          break;
        default:
          status = RideStatus.idle;
      }

      if (!isActiveRide) {
         // Found a zombie ride (auto_rejected, completed, etc.)
         // Only reset if we thought we were active. Preserve draft (idle) state.
         if (state.status != RideStatus.idle) {
           state = const RideState();
         }
         return;
      }

      LatLng? fetchedDriverLocation;
      if (driver != null && driver['driver_lat'] != null && driver['driver_lng'] != null) {
         try {
           fetchedDriverLocation = LatLng(
             double.parse(driver['driver_lat'].toString()),
             double.parse(driver['driver_lng'].toString())
           );
         } catch (_) {}
      }

      state = state.copyWith(
        status: status,
        currentRideId: ride['id'].toString(),
        startLocation: LatLng(
          double.parse(ride['start_lat'].toString()),
          double.parse(ride['start_lng'].toString()),
        ),
        startAddress: ride['start_address'],
        endLocation: ride['end_lat'] != null ? LatLng(
          double.parse(ride['end_lat'].toString()),
          double.parse(ride['end_lng'].toString()),
        ) : null,
        endAddress: ride['end_address'],
        vehicleType: ride['vehicle_type'],
        paymentMethod: ride['payment_method'],
        estimatedFare: ride['fare_estimate'] != null ? double.parse(ride['fare_estimate'].toString()) : null,
        code4: ride['code4'],
        driverInfo: driver != null ? Map<String, dynamic>.from(driver) : null,
        driverLocation: fetchedDriverLocation,
      );
    } else {
      // No active ride found on server.
      // No active ride found on server.
      // Only reset if local state thinks we are active (searching/riding).
      // Preserve 'idle' state to allow drafting (selecting locations) without wiping.
      if (state.status != RideStatus.idle) {
        // If we thought we were searching or riding, but server says no, then we must reset.
        state = const RideState();
      }
    }
  }

  void resetRide() {
    state = RideState(
      lastResetTime: DateTime.now().millisecondsSinceEpoch,
    );
  }
}
