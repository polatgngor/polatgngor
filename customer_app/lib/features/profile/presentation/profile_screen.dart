import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_constants.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/presentation/widgets/otp_sheet.dart';
import '../../../core/widgets/custom_toast.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  bool _isLoading = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).value;
    _firstNameController = TextEditingController(text: user?.firstName ?? '');
    _lastNameController = TextEditingController(text: user?.lastName ?? '');
    
    // Force refresh profile data to get latest ratings
    Future.microtask(() => ref.invalidate(authProvider));
    
    _firstNameController.addListener(_checkForChanges);
    _lastNameController.addListener(_checkForChanges);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  void _checkForChanges() {
    final user = ref.read(authProvider).value;
    if (user == null) return;
    
    final newFirst = _firstNameController.text.trim();
    final newLast = _lastNameController.text.trim();
    
    setState(() {
      _hasChanges = (newFirst != user.firstName || newLast != user.lastName) && 
                    newFirst.isNotEmpty && 
                    newLast.isNotEmpty;
    });
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);
    try {
      final newFirst = _firstNameController.text.trim();
      final newLast = _lastNameController.text.trim();
      
      await ref.read(authRepositoryProvider).updateProfile(
        firstName: newFirst,
        lastName: newLast,
      );
      
      // Refresh auth state to get updated user info
      // Assuming authProvider listens to a stream or we can force refresh if needed.
      // For now, let's assume updateProfile success means backend is updated.
      // We might need to manually update local state or re-fetch.
      // Ideally authProvider should auto-refresh or we have a method to reload profile.
      // Let's reload profile via repository if possible or just invalidate.
      ref.invalidate(authProvider); 
      
      if (mounted) {
        CustomNotificationService().show(
          context,
          'profile.updated'.tr(),
          ToastType.success,
        );
        setState(() => _hasChanges = false);
      }
    } catch (e) {
      if (mounted) {
        CustomNotificationService().show(
          context,
          'profile.error'.tr(args: [e.toString()]),
          ToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() => _isLoading = true);
      try {
        final File imageFile = File(pickedFile.path);
        await ref.read(authRepositoryProvider).uploadProfilePhoto(imageFile);
        
        // Refresh profile to show new image
        ref.invalidate(authProvider);
        
        if (mounted) {
           CustomNotificationService().show(
            context,
            'profile.updated'.tr(),
            ToastType.success,
           );
        }
      } catch (e) {
        if (mounted) {
          CustomNotificationService().show(
            context,
            'profile.error'.tr(args: [e.toString()]),
            ToastType.error,
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.value;
    final primaryColor = Theme.of(context).primaryColor;

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('profile.title'.tr()),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 10),
          // Profile Avatar
          // Profile Avatar
          Center(
            child: GestureDetector(
              onTap: _pickAndUploadImage,
              child: Stack(
                children: [
                   Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: ClipOval(
                      child: (user.profilePhoto != null && user.profilePhoto!.isNotEmpty)
                          ? Image.network(
                              user.profilePhoto!.startsWith('http') 
                                  ? user.profilePhoto! 
                                  : '${AppConstants.baseUrl}/${user.profilePhoto!.replaceAll(RegExp(r'^/+'), '')}',
                              fit: BoxFit.cover,
                              width: 100,
                              height: 100,
                              errorBuilder: (context, error, stackTrace) =>
                                  Center(child: Icon(Icons.error, color: Colors.grey[400])),
                            )
                          : Center(
                              child: Text(
                                user.firstName.isNotEmpty ? user.firstName[0].toUpperCase() : '?',
                                style: TextStyle(fontSize: 40, color: primaryColor, fontWeight: FontWeight.bold),
                              ),
                            ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: primaryColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.edit, size: 16, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
          // Rating Display
          // Rating Display
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.star_rounded, color: Colors.amber, size: 32),
                  const SizedBox(width: 4),
                  Text(
                    user.avgRating?.toString() ?? '0.0',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'drawer.profile_reviews'.tr(args: [(user.ratingCount ?? 0).toString()]),
                style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // --- Personal Info Section ---
          Text(
            'profile.personal_info'.tr(),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          
          // Inline Editing Fields
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _firstNameController,
                  label: 'profile.first_name'.tr(),
                  icon: Icons.person_outline,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  controller: _lastNameController,
                  label: 'profile.last_name'.tr(),
                  icon: Icons.person_outline,
                ),
              ),
            ],
          ),
          
          // Save Button (Visible only when changes exist)
          AnimatedCrossFade(
            firstChild: Container(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text('profile.save_changes'.tr()),
                ),
              ),
            ),
            crossFadeState: _hasChanges ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),

          const SizedBox(height: 24),
          _buildInfoTile('profile.reference_code'.tr(), user.refCode ?? '-', Icons.share_outlined, context),
          const SizedBox(height: 32),
          
          const Divider(),
          const SizedBox(height: 20),

          // --- Security Section ---
          Text(
            'profile.security'.tr(),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          
          _buildReadOnlyField(
             label: 'profile.phone'.tr(),
             value: user.phone, // Read only here
             actionLabel: 'profile.change'.tr(),
             onAction: () => context.push('/profile/change-phone'),
             icon: Icons.phone_android,
          ),
          
          const SizedBox(height: 16),


          
          // Reduced spacing
          const SizedBox(height: 16),
          
          _buildActionTile(
            context,
            'profile.delete_account'.tr(),
            Icons.delete_outline,
            Colors.red,
            () => _showDeleteAccountDialog(context, ref),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20, color: Colors.grey[600]),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  // Improved Info Tile for Read-Only data with optional action
  Widget _buildReadOnlyField({
    required String label,
    required String value,
    required String actionLabel,
    required VoidCallback onAction,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600], size: 22),
          const SizedBox(width: 16),
          Expanded(
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                 Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
               ],
             ),
          ),
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              actionLabel,
              style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildInfoTile(String label, String value, IconData icon, BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).primaryColor),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildActionTile(BuildContext context, String title, IconData icon, Color color, VoidCallback onTap) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 16)),
      trailing: Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey[400]),
      onTap: onTap,
    );
  }

  void _showDeleteAccountDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('profile.delete_account'.tr()),
        content: Text(
          'profile.delete_account_confirm'.tr(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('profile.cancel'.tr(), style: const TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Get current phone to send OTP
              final user = ref.read(authProvider).value;
              final phone = user?.phone;
              
              if (phone != null) {
                _showDeleteOtpSheet(context, ref, phone);
              } else {
                  CustomNotificationService().show(
                    context,
                    'Telefon numarası bulunamadı',
                    ToastType.error,
                  );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('profile.delete'.tr()),
          ),
        ],
      ),
    );
  }

  void _showDeleteOtpSheet(BuildContext context, WidgetRef ref, String phone) {
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
          onVerified: (code) async {
             Navigator.pop(context); // Close sheet
             try {
                // Use Notifier to ensure global state update (logout effect)
                await ref.read(authProvider.notifier).deleteAccount(code);
                if (context.mounted) {
                  context.go('/login');
                  CustomNotificationService().show(
                    context,
                    'profile.deleted'.tr(),
                    ToastType.success,
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  CustomNotificationService().show(
                    context,
                    'profile.error'.tr(args: [e.toString()]),
                    ToastType.error,
                  );
                }
              }
          },
        ),
      ),
    );
  }
}
