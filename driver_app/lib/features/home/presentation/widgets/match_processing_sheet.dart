import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';


class MatchProcessingSheet extends StatelessWidget {
  final String? statusMessage;
  final bool isError;

  const MatchProcessingSheet({
    super.key,
    this.statusMessage,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    // ADAPTIVE HEIGHT LOGIC
    final double screenHeight = MediaQuery.of(context).size.height;
    final double safeAreaBottom = MediaQuery.of(context).viewPadding.bottom;
    const double kContentHeight = 260.0; // Icon + Text + Spacing
    
    final double targetHeight = kContentHeight + safeAreaBottom;
    final double targetFraction = (targetHeight / screenHeight).clamp(0.2, 0.5);

    return DraggableScrollableSheet(
      initialChildSize: targetFraction,
      minChildSize: 0.15,
      maxChildSize: targetFraction,
      builder: (context, scrollController) {
        return Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
             boxShadow: [
               BoxShadow(
                 color: Colors.black12,
                 blurRadius: 15,
                 spreadRadius: 2,
                 offset: Offset(0, -2),
               ),
             ],
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle Bar
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 24),

                if (isError)
                  const Icon(Icons.error_outline, size: 50, color: Colors.red)
                else
                  const SizedBox(
                    height: 50,
                    width: 50,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                
                const SizedBox(height: 24),
                
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    isError 
                      ? (statusMessage ?? 'announcements.error'.tr()) 
                      : (statusMessage ?? 'home.matching_message'.tr()),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isError ? Colors.red : Colors.black87,
                    ),
                  ),
                ),
                
                const SizedBox(height: 12),
                
                 if (!isError)
                  Text(
                    "home.please_wait".tr(),
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  
                // Add safe area padding at bottom
                SizedBox(height: 24 + MediaQuery.of(context).viewPadding.bottom),
              ],
            ),
          ),
        );
      },
    );
  }
}
