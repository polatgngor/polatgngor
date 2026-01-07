import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../ride_state_provider.dart';
import '../ride_controller.dart';
import 'package:easy_localization/easy_localization.dart';

class RideRequestSheet extends ConsumerWidget {
  const RideRequestSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rideState = ref.watch(rideProvider);

    return Column(
      key: const ValueKey('booking'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // "Where to?" Button
        InkWell(
          onTap: () {
            context.push('/location-selection');
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F4F8), 
              borderRadius: BorderRadius.circular(20), 
            ),
            child: Row(
              children: [
                Icon(Icons.search, color: Theme.of(context).primaryColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    rideState.endAddress ?? 'sheet.request.where_to'.tr(),
                    style: TextStyle(
                      color: rideState.endAddress != null ? Colors.black : Colors.grey[500],
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (rideState.endAddress != null)
                   GestureDetector(
                     onTap: () {
                       ref.read(rideProvider.notifier).resetRide();
                     },
                     child: Container(
                       padding: const EdgeInsets.all(4),
                       decoration: BoxDecoration(
                         color: Colors.grey[300],
                         shape: BoxShape.circle,
                       ),
                       child: const Icon(Icons.close, size: 16, color: Colors.black54),
                     ),
                   ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        // Vehicle Types
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: _VehicleOption(
                label: rideState.fareEstimates?['sari'] != null 
                    ? 'sheet.request.estimated'.tr(args: [rideState.fareEstimates!['sari']!.toStringAsFixed(0)])
                    : 'sheet.request.taxi_yellow'.tr(),
                imageAsset: 'assets/images/sari.png',
                isSelected: rideState.vehicleType == 'sari',
                onTap: () => ref.read(rideProvider.notifier).setVehicleType('sari'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _VehicleOption(
                label: rideState.fareEstimates?['turkuaz'] != null 
                    ? 'sheet.request.estimated'.tr(args: [rideState.fareEstimates!['turkuaz']!.toStringAsFixed(0)])
                    : 'sheet.request.taxi_turquoise'.tr(),
                imageAsset: 'assets/images/turkuaz.png',
                isSelected: rideState.vehicleType == 'turkuaz',
                onTap: () => ref.read(rideProvider.notifier).setVehicleType('turkuaz'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _VehicleOption(
                label: rideState.fareEstimates?['vip'] != null 
                    ? 'sheet.request.estimated'.tr(args: [rideState.fareEstimates!['vip']!.toStringAsFixed(0)])
                    : 'sheet.request.taxi_vip'.tr(),
                imageAsset: 'assets/images/vip.png',
                isSelected: rideState.vehicleType == 'vip',
                onTap: () => ref.read(rideProvider.notifier).setVehicleType('vip'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _VehicleOption(
                label: rideState.fareEstimates?['8+1'] != null 
                    ? 'sheet.request.estimated'.tr(args: [rideState.fareEstimates!['8+1']!.toStringAsFixed(0)])
                    : 'sheet.request.taxi_8plus1'.tr(),
                imageAsset: 'assets/images/sekizartibir.png',
                isSelected: rideState.vehicleType == '8+1',
                onTap: () => ref.read(rideProvider.notifier).setVehicleType('8+1'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16), 

        // Options Block (Taksimetre / Evcil Hayvan)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
           decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC), 
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('sheet.request.option_taximeter'.tr(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    Transform.scale(
                      scale: 0.8, 
                      child: Switch(
                        value: rideState.openTaximeter,
                        onChanged: (val) => ref.read(rideProvider.notifier).toggleTaximeter(val),
                        activeColor: Theme.of(context).primaryColor,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12), // Spacer
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('sheet.request.option_pet'.tr(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                     Transform.scale(
                      scale: 0.8, 
                      child: Switch(
                        value: rideState.hasPet,
                        onChanged: (val) => ref.read(rideProvider.notifier).togglePet(val),
                        activeColor: Theme.of(context).primaryColor,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 12),

        // Payment Block
        Row(
          children: [
            Expanded(
              child: _PaymentOption(
                label: 'sheet.request.payment_cash'.tr(),
                icon: Icons.payments_outlined,
                isSelected: rideState.paymentMethod == 'nakit',
                onTap: () => ref.read(rideProvider.notifier).setPaymentMethod('nakit'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _PaymentOption(
                label: 'sheet.request.payment_pos'.tr(),
                icon: Icons.credit_card,
                isSelected: rideState.paymentMethod == 'pos',
                onTap: () => ref.read(rideProvider.notifier).setPaymentMethod('pos'),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12), // Reduced spacing to button

        // Call Taxi Button
        ElevatedButton(
          onPressed: rideState.endLocation == null
              ? null // Disable if no destination
              : () {
                  ref.read(rideControllerProvider.notifier).createRide(context);
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor, // Primary Blue
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16), // Slightly reduced padding
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 2,
            shadowColor: Theme.of(context).primaryColor.withOpacity(0.4),
          ),
          child: Text(
            'sheet.request.call_taxi'.tr(),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        // SizedBox(height: 34) Removed - handled by RideBookingSheet
      ],
    );
  }
}

class _VehicleOption extends StatelessWidget {
  final String label;
  final String imageAsset;
  final bool isSelected;
  final VoidCallback onTap;

  const _VehicleOption({
    required this.label,
    required this.imageAsset,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        decoration: BoxDecoration(
          color: isSelected 
              ? Theme.of(context).primaryColor.withOpacity(0.1) 
              : const Color(0xFFF1F4F8), // Modern light gray for unselected
          border: Border.all(
            color: isSelected 
                ? Theme.of(context).primaryColor 
                : Colors.transparent, // No border when unselected
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
             Image.asset(
               imageAsset,
               height: 35, 
               fit: BoxFit.contain,
               // Original colors always visible
             ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: label.contains('₺') ? 13 : 11,
                fontWeight: FontWeight.w800, 
                color: isSelected ? Theme.of(context).primaryColor : Colors.grey[800],
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _PaymentOption({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? Colors.white 
              : const Color(0xFFF1F4F8), // Gray when not selected
          border: Border.all(
            color: isSelected 
                ? Theme.of(context).primaryColor 
                : Colors.transparent,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: isSelected 
              ? [BoxShadow(color: Theme.of(context).primaryColor.withOpacity(0.12), blurRadius: 6, offset: const Offset(0, 3))] 
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon, 
              size: 20, 
              color: isSelected ? Theme.of(context).primaryColor : Colors.grey[600]
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold, // Always bold for modern look
                color: isSelected ? Theme.of(context).primaryColor : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
