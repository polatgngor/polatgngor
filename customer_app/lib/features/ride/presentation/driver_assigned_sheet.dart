import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'ride_state_provider.dart';
import 'ride_controller.dart';
import 'cancellation_reason_sheet.dart';
import 'chat_screen.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../core/utils/string_utils.dart';
import '../../../core/constants/app_constants.dart';

class DriverAssignedSheet extends ConsumerWidget {
  const DriverAssignedSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rideState = ref.watch(rideProvider);
    final driver = rideState.driverInfo;
    final code = rideState.code4;

    if (driver == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final String driverName = StringUtils.maskName('${driver['first_name']} ${driver['last_name']}');
    final double rating = double.tryParse(driver['rating']?.toString() ?? '') ?? 5.0;
    final String photoUrl = driver['profile_photo'] ?? '';
    


    final bool isStarted = rideState.status == RideStatus.rideStarted;
    
    // Stats calculation (Safe defaults)
    final double durationMins = (rideState.durationSeconds ?? 0) / 60;
    final double distanceKm = (rideState.distanceMeters ?? 0) / 1000;
    
    // Show stats if started OR if we are waiting for driver (driverFound)
    // Even if seconds is 0, show it to confirm UI presence (or handle logic)
    final bool showStats = isStarted || rideState.status == RideStatus.driverFound;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Drag Handle
        const SizedBox(height: 12),
        // Removed extra SizedBox(height: 12) here to reduce top spacing


        // Status Text moved below profile header


        // HEADER: Driver Profile & Stats
        Padding(
          padding: EdgeInsets.zero, // Removed bottom padding for precise spacing control
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start, // Align top
            children: [
               // LEFT: Driver Profile
               Expanded(
                 child: Row(
                   crossAxisAlignment: CrossAxisAlignment.center,
                   children: [
                     // Avatar
                     // Avatar
                       ClipOval(
                         child: Container(
                           width: 60, // Increased from 48
                           height: 60, // Increased from 48
                           decoration: BoxDecoration(
                               color: Colors.grey[200],
                           ),
                           child: photoUrl.isNotEmpty
                               ? Image.network(
                                   photoUrl.startsWith('http') ? photoUrl : '${AppConstants.baseUrl}/$photoUrl',
                                   fit: BoxFit.cover,
                                   errorBuilder: (context, error, stackTrace) =>
                                       Icon(Icons.person, size: 36, color: Colors.grey[400]), // Incr size
                                 )
                               : Icon(Icons.person, size: 36, color: Colors.grey[400]), // Incr size
                         ),
                       ),
                     const SizedBox(width: 12),
                     
                     // Name & Rating
                     Expanded(
                       child: Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                             Text(
                               driverName,
                               maxLines: 2,
                               overflow: TextOverflow.ellipsis,
                               style: const TextStyle(
                                 fontSize: 20, // Increased from 16
                                 fontWeight: FontWeight.w900,
                                 color: Colors.black87,
                                 height: 1.2,
                               ),
                             ),
                           const SizedBox(height: 4),
                           // Rating
                           Row(
                             children: [
                               Text(
                                 rating.toStringAsFixed(1),
                                 style: TextStyle(
                                   fontWeight: FontWeight.bold,
                                   fontSize: 12,
                                   color: Colors.grey[700],
                                 ),
                               ),
                               const SizedBox(width: 4),
                               ...List.generate(5, (index) {
                                 return Icon(
                                   index < rating.round() ? Icons.star : Icons.star_border,
                                   color: const Color(0xFFFFD700),
                                   size: 14,
                                 );
                               }),
                             ],
                           ),
                         ],
                       ),
                     ),
                   ],
                 ),
               ),
               
               const SizedBox(width: 8),

               // RIGHT: Stats Card (Blue Chip)
               // RIGHT: Stats Card & Cancel Button
               Column(
                 crossAxisAlignment: CrossAxisAlignment.end,
                 children: [
                   if (showStats)
                     Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context).primaryColor.withOpacity(0.3),
                              blurRadius: 4, 
                              offset: const Offset(0, 2),
                            )
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.access_time_filled, color: Colors.white, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              '${durationMins.ceil()} dk',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            
                            Container(
                              width: 1, 
                              height: 12, 
                              color: Colors.white.withOpacity(0.5),
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                            ),

                            const Icon(Icons.directions_car, color: Colors.white, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              '${distanceKm.toStringAsFixed(1)} km',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                     ),
                    
                    if (isStarted) ...[
                      const SizedBox(height: 8),
                      // Cancel Button (Small)
                      OutlinedButton.icon(
                         onPressed: () {
                            showModalBottomSheet(
                             context: context,
                             isScrollControlled: true,
                             backgroundColor: Colors.transparent,
                             builder: (context) => const CancellationReasonSheet(),
                           );
                         },
                         icon: const Icon(Icons.close, size: 14, color: Colors.red),
                         label: Text('button.cancel'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 11)),
                         style: OutlinedButton.styleFrom(
                           side: const BorderSide(color: Colors.red),
                           padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                           minimumSize: Size.zero, 
                           tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                           backgroundColor: Colors.transparent,
                         ),
                      ),
                    ]
                 ],
               ),
            ],
          ),
        ),


        const SizedBox(height: 16), // Clear 16px gap between Profile and Status 

        // STATUS TEXT (Moved here)
        Text(
          isStarted ? 'ride.status.ride_started'.tr() : 'ride.status.driver_coming'.tr(),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 4),
        Text(
          isStarted 
            ? 'ride.status.ride_started_desc'.tr() 
            : 'ride.status.driver_coming_desc'.tr(),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
        ),
        const SizedBox(height: 20),

        // Duplicate SizedBox(height: 24) removed


        // CODE (If not started)
        if (!isStarted) ...[
           // "Sürücüye Gösterin" Text
           Container(
             padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
             decoration: BoxDecoration(
               color: Colors.grey[100],
               borderRadius: BorderRadius.circular(8),
             ),
              child: Text(
               'ride.verification_code'.tr(),
               style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[600], letterSpacing: 1.0),
              ),
           ),
           const SizedBox(height: 8),
           Text(
             code ?? '----',
             style: const TextStyle(
               fontSize: 36, // Slightly smaller
               fontWeight: FontWeight.w900,
               letterSpacing: 6,
               color: Colors.black87,
             ),
           ),
           const SizedBox(height: 24),
        ] else ...[
             const SizedBox(height: 8),
             // Duplicate button removed
        ],

          // ACTION BUTTONS (Contact & Cancel)
          if (!isStarted)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Contact
                OutlinedButton.icon(
                  onPressed: () {
                      final rideId = ref.read(rideProvider).currentRideId;
                      if (rideId != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => ChatScreen(rideId: rideId)),
                        );
                      }
                  },
                  icon: Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Theme.of(context).primaryColor),
                  label: Text('button.message'.tr(), style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor, fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Theme.of(context).primaryColor),
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    backgroundColor: Colors.transparent,
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // Cancel (Waiting - Outlined)
                OutlinedButton.icon(
                  onPressed: () {
                    showModalBottomSheet(
                       context: context,
                       isScrollControlled: true,
                       backgroundColor: Colors.transparent,
                       builder: (context) => const CancellationReasonSheet(),
                     );
                  },
                  icon: const Icon(Icons.close, size: 16, color: Colors.red),
                  label: Text('button.cancel'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    backgroundColor: Colors.transparent,
                  ),
                ),
              ],
            ),
            
          const SizedBox(height: 12),

      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool isOutlined;
  final bool hasShadow; // NEW

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.isOutlined = false,
    this.hasShadow = false, // NEW
  });

  @override
  Widget build(BuildContext context) {
    if (isOutlined) {
      return OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 20),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: hasShadow ? 8 : 0, // Dynamic elevation
        shadowColor: hasShadow ? color.withOpacity(0.4) : Colors.transparent, // Dynamic shadow color
      ),
    );
  }
}
