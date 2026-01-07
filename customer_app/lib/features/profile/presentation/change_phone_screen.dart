import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/presentation/widgets/otp_sheet.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../../../core/widgets/custom_toast.dart';

class ChangePhoneScreen extends ConsumerStatefulWidget {
  const ChangePhoneScreen({super.key});

  @override
  ConsumerState<ChangePhoneScreen> createState() => _ChangePhoneScreenState();
}

class _ChangePhoneScreenState extends ConsumerState<ChangePhoneScreen> {
  final _phoneController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _showOtpSheet(String phone) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20, 
          right: 20, 
          top: 20
        ),
        child: OtpVerificationSheet(
          phone: phone,
          onVerified: (code) => _submitNewPhone(phone, code),
        ),
      ),
    );
  }

  Future<void> _submitNewPhone(String phone, String code) async {
    Navigator.pop(context); // Close sheet
    setState(() => _isLoading = true);
    
    try {
      await ref.read(authRepositoryProvider).changePhone(phone, code);
      
      // Refresh user profile
      await ref.refresh(authProvider.future);

      if (mounted) {
        CustomNotificationService().show(
          context,
          'profile.phone_updated'.tr(),
          ToastType.success,
        );
        Navigator.pop(context); // Go back
      }
    } catch (e) {
      if (mounted) {
         CustomNotificationService().show(
          context,
          'Hata: $e',
          ToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _startUpdate() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty || phone.length < 10) {
      CustomNotificationService().show(
        context,
        'profile.valid_phone_error'.tr(),
        ToastType.error,
      );
      return;
    }
    _showOtpSheet(phone);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('profile.change_phone_title'.tr()),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
              Text(
              'profile.current_phone'.tr(),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            // Display current phone if available
             Consumer(builder: (context, ref, _) {
               final authState = ref.watch(authProvider);
               final currentPhone = authState.value?.phone ?? '-'; // userModel.phone
               return Container(
                 width: double.infinity,
                 padding: const EdgeInsets.all(16),
                 decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                 child: Text(currentPhone, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
               );
             }),
            
            const SizedBox(height: 32),
            Text(
              'profile.new_phone'.tr(),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  hintText: '5XX XXX XX XX',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  prefixIcon: Icon(Icons.phone, color: Colors.grey),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'profile.otp_info'.tr(),
                      style: TextStyle(fontSize: 12, color: Colors.blue[800], height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _startUpdate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _isLoading 
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text('profile.send_code_btn'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
