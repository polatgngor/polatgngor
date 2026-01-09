import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../auth/presentation/auth_provider.dart';
import '../../../auth/presentation/auth_provider.dart';
import '../../../auth/data/vehicle_repository.dart';
import 'change_taxi_screen.dart';
import 'update_documents_screen.dart';
import '../../../../core/widgets/custom_toast.dart';

// Provider to fetch pending requests
final pendingRequestsProvider = FutureProvider.autoDispose((ref) async {
  return ref.read(vehicleRepositoryProvider).getChangeRequests();
});

class VehicleManagementScreen extends ConsumerWidget {
  const VehicleManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Current User Data
    final authState = ref.watch(authProvider);
    final user = authState.value?['user']; // Assuming structure

    // Pending Requests
    final requestsAsync = ref.watch(pendingRequestsProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('profile.vehicle_management'.tr()),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Current Vehicle Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1A77F6), Color(0xFF4C94FA)], // TaxiBu Blue Gradient
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1A77F6).withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8), // Reduced padding for image
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Builder(
                      builder: (context) {
                        String type = user != null ? (user['vehicle_type'] ?? 'sari') : 'sari';
                        String assetName = 'sari.png';
                        if (type == 'turkuaz') assetName = 'turkuaz.png';
                        if (type == 'vip') assetName = 'vip.png';
                        if (type == '8+1') assetName = 'sekizartibir.png';
                        
                        return Image.asset(
                          'assets/images/$assetName',
                          width: 80, // Increased size for visibility
                          height: 80,
                        );
                      }
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user != null ? '${user['vehicle_plate'] ?? 'profile.no_plate'.tr()}' : 'profile.loading'.tr(),
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.0),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    user != null ? '${user['vehicle_brand'] ?? ''} ${user['vehicle_model'] ?? ''}' : '',
                    style: const TextStyle(fontSize: 16, color: Colors.white70, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 16),
                  // Active Vehicle Badge Removed
                  // const SizedBox(height: 16),
                  // Container(...)
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Pending Request Status
            requestsAsync.when(
              data: (requests) {
                if (requests.isEmpty) return const SizedBox.shrink();
                final latest = requests.first;
                
                // Only show if pending
                if (latest['status'] != 'pending') return const SizedBox.shrink();

                return Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF4E5), // Soft Orange
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                       Container(
                         padding: const EdgeInsets.all(10),
                         decoration: BoxDecoration(
                           color: Colors.orange.withOpacity(0.1),
                           shape: BoxShape.circle,
                         ),
                         child: const Icon(Icons.access_time_filled_rounded, color: Colors.orange, size: 24),
                       ),
                       const SizedBox(width: 16),
                       Expanded(
                         child: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             Text('profile.pending_request'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange, fontSize: 15)),
                             const SizedBox(height: 4),
                             Text('profile.new_plate'.tr(args: [latest['new_plate']]), style: TextStyle(fontSize: 13, color: Colors.orange[900])),
                           ],
                         ),
                       ),
                    ],
                  ),
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (err, stack) => const SizedBox.shrink(),
            ),

            // Actions
            Text('profile.actions'.tr(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D3242))),
            const SizedBox(height: 16),

            _buildActionCard(
              context,
              icon: Icons.swap_horiz_rounded,
              title: 'profile.change_taxi'.tr(),
              subtitle: 'profile.change_taxi_desc'.tr(),
              onTap: () {
                // If requests pending, warn user?
                if (requestsAsync.hasValue && requestsAsync.value!.any((r) => r['status'] == 'pending')) {
                   CustomNotificationService().show(
                     context,
                     'profile.pending_warning'.tr(),
                     ToastType.info,
                   );
                   return;
                }
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChangeTaxiScreen()));
              },
            ),
            
            const SizedBox(height: 16),

              _buildActionCard(
                context,
                icon: Icons.file_present,
                title: 'profile.update_docs'.tr(),
                subtitle: 'profile.update_docs_desc'.tr(),
                onTap: () {
                   // If requests pending, warn user
                  if (requestsAsync.hasValue && requestsAsync.value!.any((r) => r['status'] == 'pending')) {
                     CustomNotificationService().show(
                       context,
                       'profile.pending_warning'.tr(),
                       ToastType.info,
                     );
                     return;
                  }
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const UpdateDocumentsScreen()));
                },
                isComingSoon: false,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, {required IconData icon, required String title, required String subtitle, required VoidCallback onTap, bool isComingSoon = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withOpacity(0.1)),
          boxShadow: [
             BoxShadow(
               color: const Color(0xFF1A77F6).withOpacity(0.05),
               blurRadius: 15,
               offset: const Offset(0, 5),
             ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F4F8), // Light Blue-Grey
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: const Color(0xFF1A77F6), size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF2D3242))),
                      if (isComingSoon) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)),
                          child: Text('profile.coming_soon'.tr(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: Colors.grey[500], fontSize: 13, height: 1.4)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey[300]),
          ],
        ),
      ),
    );
  }
}

