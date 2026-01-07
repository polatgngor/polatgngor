import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class DriverFoundTransitionSheet extends StatelessWidget {
  const DriverFoundTransitionSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      // Decoration removed to blend with parent sheet
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Lottie or Icon
          // Since we don't know if Lottie asset 'success' exists, we use a robust Icon
          // but if user wants animation, we can try a loader.
          // Let's use a nice big checkmark or car icon with animation wrapper if possible.
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.green.shade50,
            ),
            child: const Icon(Icons.check_rounded, size: 48, color: Colors.green),
          ),
          const SizedBox(height: 24),
          
          Text(
            'home.driver_found'.tr(),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Sizi eşleştiriyoruz, lütfen bekleyin...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          
          const LinearProgressIndicator(
             backgroundColor: Color(0xFFEEEEEE),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
