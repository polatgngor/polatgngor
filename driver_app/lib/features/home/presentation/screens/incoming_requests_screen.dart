import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/incoming_requests_provider.dart';
import '../widgets/ride_request_card.dart';

import '../../../../core/services/ringtone_service.dart';
import 'package:easy_localization/easy_localization.dart';

import '../providers/optimistic_ride_provider.dart'; // Import Added

class IncomingRequestsScreen extends ConsumerStatefulWidget {
  const IncomingRequestsScreen({super.key});

  @override
  ConsumerState<IncomingRequestsScreen> createState() => _IncomingRequestsScreenState();
}

class _IncomingRequestsScreenState extends ConsumerState<IncomingRequestsScreen> {
  @override
  void deactivate() {
    // Stop ringtone when screen is closed/deactivated
    // Using simple read here might be safer than dispose depending on Riverpod version nuances
    // or if the navigate pop caused a race. 
    // Ideally we should verify if we should stop it (if we are truly leaving).
    ref.read(ringtoneServiceProvider).stopRingtone();
    super.deactivate();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final requests = ref.watch(incomingRequestsProvider);

    // Listen for empty list to auto-close
    ref.listen(incomingRequestsProvider, (previous, next) {
      if (next.isEmpty) {
        if (mounted) {
           final isMatching = ref.read(optimisticRideProvider).isMatching;
           final hasRide = ref.read(optimisticRideProvider).activeRide != null;

           if (isMatching || hasRide) {
              // Ride Accepted -> Go to Home (Pop all intermediate screens like Settings)
              Navigator.of(context).popUntil((route) => route.isFirst);
           } else {
              // Rejected/Timeout -> Just Pop this screen
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              }
           }
        }
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text('incoming_request.title'.tr()),
      ),
      body: requests.isEmpty
          ? Center(child: Text('incoming_request.empty'.tr()))
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 20),
              itemCount: requests.length,
              itemBuilder: (context, index) {
                return RideRequestCard(request: requests[index]);
              },
            ),
    );
  }
}
