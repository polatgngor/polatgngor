import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../ride_state_provider.dart';
import 'package:easy_localization/easy_localization.dart';

class NoDriverSheet extends ConsumerWidget {
  const NoDriverSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      key: const ValueKey('noDriver'),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          // Icon Container
          Container(
             padding: const EdgeInsets.all(16), 
             decoration: BoxDecoration(
               color: Colors.red.withOpacity(0.1),
               shape: BoxShape.circle,
             ),
             child: Icon(
               Icons.local_taxi_rounded, 
               size: 40,
               color: Colors.red[400],
             ),
          ),
          const SizedBox(height: 16),
          
          Text(
            'sheet.no_driver.title'.tr(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18, 
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'sheet.no_driver.desc'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 24),
          
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                ref.read(rideProvider.notifier).resetRide();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                'sheet.no_driver.ok'.tr(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          // SizedBox(30) Removed - handled by global padding 
        ],
      ),
    );
  }
}
