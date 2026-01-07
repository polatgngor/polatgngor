import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../features/auth/data/auth_service.dart';
import '../../../../core/services/socket_service.dart';
import '../../../rides/data/ride_repository.dart';
import '../../../../core/widgets/custom_toast.dart';

class DriverCancellationSheet extends ConsumerStatefulWidget {
  final String rideId;

  const DriverCancellationSheet({super.key, required this.rideId});

  @override
  ConsumerState<DriverCancellationSheet> createState() => _DriverCancellationSheetState();
}

class _DriverCancellationSheetState extends ConsumerState<DriverCancellationSheet> {
  String? _selectedReason;
  
  final List<String> _reasons = [
    'reason.passenger_not_here'.tr(),
    'reason.passenger_wrong_location'.tr(),
    'reason.car_trouble'.tr(),
    'reason.emergency'.tr(),
    'reason.other'.tr(),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min, // Auto-height
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          
          Text(
            'ride.cancel_title'.tr(),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'ride.cancel_desc'.tr(),
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 16),
          
          ListView.separated(
            shrinkWrap: true,
            physics: const ClampingScrollPhysics(),
            itemCount: _reasons.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final reason = _reasons[index];
              final isSelected = _selectedReason == reason;
              return GestureDetector(
                onTap: () {
                  setState(() => _selectedReason = reason);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? Theme.of(context).primaryColor.withOpacity(0.05) 
                        : const Color(0xFFF8FAFC), 
                    border: Border.all(
                      color: isSelected ? Theme.of(context).primaryColor : Colors.transparent,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        reason,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          color: isSelected ? Theme.of(context).primaryColor : Colors.black87,
                        ),
                      ),
                      if (isSelected)
                        Icon(Icons.check_circle, color: Theme.of(context).primaryColor, size: 20)
                      else
                        Icon(Icons.circle_outlined, color: Colors.grey[400], size: 20),
                    ],
                  ),
                ),
              );
            },
          ),
          
          const SizedBox(height: 24),
          
          Row(
            children: [
               Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('sheet.cancel_button'.tr(), style: const TextStyle(color: Colors.grey)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _selectedReason == null 
                      ? null 
                      : () async {
                          try {
                            await ref.read(driverRideRepositoryProvider).cancelRide(widget.rideId, _selectedReason!);
                            
                            if (context.mounted) {
                              Navigator.pop(context);
                              CustomNotificationService().show(
                                context, 
                                'ride.cancel_success'.tr(), 
                                ToastType.success
                              );
                            }
                          } catch (e) {
                             if (context.mounted) {
                               Navigator.pop(context); 
                               CustomNotificationService().show(
                                 context, 
                                 'ride.cancel_fail'.tr(args: [e.toString()]), 
                                 ToastType.error
                               );
                             }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Text('ride.cancel_ride'.tr()),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}
