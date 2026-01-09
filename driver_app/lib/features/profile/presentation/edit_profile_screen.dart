import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/widgets/custom_toast.dart';
import 'package:easy_localization/easy_localization.dart';
import 'profile_screen.dart'; // To access the driverProfileProvider
import '../../auth/data/auth_service.dart';
import '../../../../core/constants/app_constants.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  File? _imageFile;
  String? _currentPhotoUrl;

  @override
  void initState() {
    super.initState();
    // Load initial data from provider
    final profileAsync = ref.read(driverProfileProvider);
    profileAsync.whenData((data) {
      final user = data['user'];
      if (user != null) {
        _firstNameController.text = user['first_name'] ?? '';
        _lastNameController.text = user['last_name'] ?? '';
        _currentPhotoUrl = user['profile_photo'];
        setState(() {});
      }
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);

      // Upload photo if selected
      if (_imageFile != null) {
        await authService.uploadProfilePhoto(_imageFile!);
      }

      await authService.updateProfile(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
      );
      
      // Refresh profile
      ref.refresh(driverProfileProvider);
      
      if (mounted) {
        CustomNotificationService().show(
          context,
          'profile.updated'.tr(),
          ToastType.success,
        );
        context.pop();
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
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('profile.edit_title'.tr()),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      shape: BoxShape.circle,
                    ),
                    child: ClipOval(
                      child: _imageFile != null
                          ? Image.file(_imageFile!, fit: BoxFit.cover, width: 100, height: 100)
                          : (_currentPhotoUrl != null && _currentPhotoUrl!.isNotEmpty)
                              ? Image.network(
                                  _currentPhotoUrl!.startsWith('http') ? _currentPhotoUrl! : '${AppConstants.baseUrl}/$_currentPhotoUrl',
                                  fit: BoxFit.cover,
                                  width: 100, 
                                  height: 100,
                                  errorBuilder: (context, error, stackTrace) => Icon(Icons.error, color: Colors.grey[400]),
                                )
                              : Icon(Icons.camera_alt, size: 40, color: Colors.grey[400]),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _pickImage,
                  child: Text('profile.change_photo'.tr()),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _firstNameController,
                  decoration: InputDecoration(
                    labelText: 'profile.first_name'.tr(),
                    prefixIcon: const Icon(Icons.person_outline),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Theme.of(context).primaryColor),
                    ),
                  ),
                  validator: (v) => v?.isEmpty == true ? 'profile.required_firstname'.tr() : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _lastNameController,
                  decoration: InputDecoration(
                    labelText: 'profile.last_name'.tr(),
                    prefixIcon: const Icon(Icons.person_outline),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Theme.of(context).primaryColor),
                    ),
                  ),
                  validator: (v) => v?.isEmpty == true ? 'profile.required_lastname'.tr() : null,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _save,
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text('profile.save'.tr()),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
