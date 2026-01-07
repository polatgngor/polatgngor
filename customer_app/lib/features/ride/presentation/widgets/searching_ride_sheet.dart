import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../cancellation_reason_sheet.dart';
import 'package:easy_localization/easy_localization.dart';
import '../ride_state_provider.dart';

class SearchingRideSheet extends ConsumerWidget {
  const SearchingRideSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rideState = ref.watch(rideProvider);
    final isFound = rideState.status == RideStatus.driverFoundTransition || rideState.status == RideStatus.driverFound;

    return Column(
      key: const ValueKey('searching_unified'),
      children: [
        const SizedBox(height: 12),
        // Custom Glowing Progress Bar (Morphs Color)
        _GlowingProgressIndicator(isSuccess: isFound),
        const SizedBox(height: 20),
        
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            isFound ? 'home.driver_found'.tr() : 'sheet.searching.title'.tr(),
            key: ValueKey(isFound ? 'found_title' : 'search_title'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 6),
        
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            isFound 
               ? 'Sizi eşleştiriyoruz, lütfen bekleyin...' 
               : 'sheet.searching.desc'.tr(),
             key: ValueKey(isFound ? 'found_desc' : 'search_desc'),
            style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 24),
        
        // Cancel Button (Hide or Disable during transition?)
        // User asked for smooth transition. Usually you can't cancel once driver found logic starts.
        AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: isFound ? 0.0 : 1.0,
          child: IgnorePointer(
            ignoring: isFound,
            child: SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => const CancellationReasonSheet(),
                  );
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: Colors.red.withOpacity(0.08),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  'sheet.searching.cancel'.tr(),
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GlowingProgressIndicator extends StatefulWidget {
  final bool isSuccess;
  const _GlowingProgressIndicator({required this.isSuccess});

  @override
  State<_GlowingProgressIndicator> createState() => _GlowingProgressIndicatorState();
}

class _GlowingProgressIndicatorState extends State<_GlowingProgressIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1, milliseconds: 500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 6,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(3),
      ),
      child: ClipRRect( 
        borderRadius: BorderRadius.circular(3),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                // Bar always moves from left to right
                final double start = -0.4;
                final double end = 1.4;
                final double pos = start + (end - start) * _controller.value;
                
                // Color transition: Blue -> Green
                final Color barColor = widget.isSuccess ? Colors.green : Theme.of(context).primaryColor;
                
                return Stack(
                  clipBehavior: Clip.none, 
                  children: [
                     Positioned(
                      left: pos * width,
                      width: width * 0.35, 
                      top: 0,
                      bottom: 0,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        decoration: BoxDecoration(
                          color: barColor,
                          borderRadius: BorderRadius.circular(3),
                          boxShadow: [
                            BoxShadow(
                              color: barColor.withOpacity(0.8), // Glow
                              blurRadius: 10,
                              spreadRadius: 2,
                            )
                          ]
                        ),
                      ),
                     )
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
