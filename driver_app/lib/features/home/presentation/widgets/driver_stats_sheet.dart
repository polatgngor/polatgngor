import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../rides/data/ride_repository.dart';
import 'package:easy_localization/easy_localization.dart';

class DriverStatsSheet extends ConsumerStatefulWidget {
  final int refCount;
  final String refCode;
  final DraggableScrollableController? controller;
  final bool isOnline;
  final ValueChanged<bool>? onStatusChanged;
  final ScrollController? scrollController;

  const DriverStatsSheet({
    super.key, 
    this.refCount = 0, 
    this.refCode = '',
    this.controller,
    this.scrollController,
    required this.isOnline,
    this.onStatusChanged,
  });

  @override
  ConsumerState<DriverStatsSheet> createState() => _DriverStatsSheetState();
}

class _DriverStatsSheetState extends ConsumerState<DriverStatsSheet> {
  double _earnings = 0.0;
  int _rideCount = 0;
  int _fetchedRefCount = 0; // Local validation
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchEarnings();
  }

  Future<void> _fetchEarnings() async {
    try {
      // Use server-side "Daily" calculation (Turkey Time)
      final data = await ref.read(driverRideRepositoryProvider).getEarnings(period: 'daily');
      if (mounted) {
        setState(() {
          _earnings = data['total'];
          _rideCount = data['count'];
          _fetchedRefCount = data['ref_count'] ?? widget.refCount;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching earnings: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Map<String, dynamic> _getLevelInfo() {
    final refCount = _isLoading ? widget.refCount : _fetchedRefCount;
    if (refCount < 25) {
      return {
        'name': 'sheet.stats.rank_standard'.tr(),
        'nextLevel': 'sheet.stats.rank_silver'.tr(),
        'target': 25,
        'current': refCount,
        'color': Colors.grey,
      };
    } else if (refCount < 50) {
      return {
        'name': 'sheet.stats.rank_silver'.tr(),
        'nextLevel': 'sheet.stats.rank_gold'.tr(),
        'target': 50,
        'current': refCount,
        'color': const Color(0xFFC0C0C0), // Silver color
      };
    } else if (refCount < 100) {
      return {
        'name': 'sheet.stats.rank_gold'.tr(),
        'nextLevel': 'sheet.stats.rank_platinum'.tr(),
        'target': 100,
        'current': refCount,
        'color': const Color(0xFFFFD700), // Gold color
      };
    } else {
      return {
        'name': 'sheet.stats.rank_platinum'.tr(),
        'nextLevel': 'Max',
        'target': 100,
        'current': refCount,
        'color': const Color(0xFFE5E4E2), // Platinum color
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    final levelInfo = _getLevelInfo();
    final int target = levelInfo['target'];
    final int current = levelInfo['current'];
    final double progress = target > 0 ? (current / target).clamp(0.0, 1.0) : 1.0;
    final int remaining = target - current;
    
    // Primary Blue
    const primaryBlue = Color(0xFF1A77F6);

    // ADAPTIVE HEIGHT LOGIC
    final double screenHeight = MediaQuery.of(context).size.height;
    final double safeAreaBottom = MediaQuery.of(context).viewPadding.bottom;
    // Reduced from 350.0 based on user feedback ("3/1 oranında küçülmeli")
    const double kContentHeight = 250.0; 
    
    final double targetHeight = kContentHeight + safeAreaBottom;
    // Clamp between 0.15 and 0.85
    final double targetFraction = (targetHeight / screenHeight).clamp(0.15, 0.85);

    return DraggableScrollableSheet(
      controller: widget.controller,
      initialChildSize: targetFraction,
      minChildSize: 0.12, // Lower min size for compact sheet
      maxChildSize: targetFraction, 
      snap: true,
      builder: (context, scrollController) {
        return Container(
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
            physics: const ClampingScrollPhysics(),
            child: Column(
              children: [
                // Drag Handle - at top
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  ),
                ),
                // Content
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    24, 
                    0, 
                    24, 
                    24 + MediaQuery.of(context).viewPadding.bottom
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                // HEADER: Earnings (Left) - Handle (Center) - Switch (Right)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16, top: 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // LEFT: Earnings
                      SizedBox(
                        width: 140, 
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '₺${_earnings.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: Colors.black87,
                                letterSpacing: -1,
                                height: 1.1,
                              ),
                            ),
                            Text(
                              'sheet.stats.daily_earnings'.tr(),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey,
                                height: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // RIGHT: Status Switch
                      SizedBox(
                        width: 140,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              widget.isOnline ? 'sheet.stats.available'.tr() : 'sheet.stats.busy'.tr(),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: widget.isOnline ? primaryBlue : Colors.red,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Transform.scale(
                              scale: 1.1,
                              child: Switch.adaptive(
                                value: widget.isOnline,
                                onChanged: widget.onStatusChanged,
                                activeColor: primaryBlue,
                                activeTrackColor: primaryBlue.withOpacity(0.2),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // BODY: Only Level Bar (Compact)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.withOpacity(0.1)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                           Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'sheet.stats.level'.tr(),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                levelInfo['name'],
                                style: const TextStyle(
                                  fontSize: 18, 
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black87
                                ),
                              ),
                            ],
                          ),
                          if (widget.refCode.isNotEmpty) 
                            Text(
                              widget.refCode,
                              style: const TextStyle(
                                fontSize: 26, 
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF1A77F6), // primaryBlue
                                letterSpacing: -1,
                                height: 1.1,
                              ),
                            )
                          else
                            ElevatedButton.icon(
                              onPressed: () {},
                              icon: const Icon(Icons.person_add_alt_1, size: 16),
                              label: Text('sheet.stats.invite'.tr(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1A77F6),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                elevation: 0,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.grey[100],
                          color: primaryBlue,
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Puan Text
                       Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'sheet.stats.points'.tr(args: [current.toString(), target.toString()]),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey[500],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
      },
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value, IconData icon, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
             color: Colors.black.withOpacity(0.03),
             blurRadius: 10,
             offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[500],
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
