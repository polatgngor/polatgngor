import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ride_state_provider.dart';
import 'driver_assigned_sheet.dart';
import 'widgets/searching_ride_sheet.dart';
import 'widgets/no_driver_sheet.dart';
import 'widgets/ride_request_sheet.dart';
import 'widgets/driver_found_transition_sheet.dart';

class RideBookingSheet extends ConsumerWidget {
  final ScrollController? scrollController;
  
  const RideBookingSheet({super.key, this.scrollController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rideState = ref.watch(rideProvider);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: ListView(
        controller: scrollController, // Vital for DraggableScrollableSheet
        physics: const ClampingScrollPhysics(),
        padding: EdgeInsets.zero,
        shrinkWrap: true, // Only if needed, but DraggableScrollableSheet usually handles size
        children: [
          // Handle Area
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            color: Colors.transparent,
            child: Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          
          // Main Content
          Padding(
            padding: EdgeInsets.fromLTRB(
              16, 
              0, 
              16, 
              16 + MediaQuery.of(context).viewPadding.bottom // Increased to 16 for better spacing
            ), 
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              switchInCurve: Curves.easeInOut,
              switchOutCurve: Curves.easeInOut,
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(
                  opacity: animation,
                  child: child,
                );
              },
              child: _buildCurrentSheet(rideState),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentSheet(RideState rideState) {
    // Content is now part of the ListView, so we don't need another ScrollView here
    // unless the content itself needs internal scrolling (nested).
    // For now, let's keep it simple content.
    if (rideState.status == RideStatus.searching || rideState.status == RideStatus.driverFoundTransition) {
      return const SearchingRideSheet();
    } else if (rideState.status == RideStatus.noDriverFound) {
      return const NoDriverSheet();
    } else if (rideState.status == RideStatus.driverFound || rideState.status == RideStatus.rideStarted) {
      return KeyedSubtree(
        key: ValueKey(rideState.status),
        child: const DriverAssignedSheet(),
      );
    } else {
      return const RideRequestSheet();
    }
  }
}
