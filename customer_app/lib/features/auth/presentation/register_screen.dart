import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:easy_localization/easy_localization.dart';
import 'auth_provider.dart';
import '../../../../core/widgets/custom_toast.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _refCodeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  File? _imageFile;

  late String phone;
  late String verificationToken;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final extra = GoRouterState.of(context).extra as Map<String, dynamic>?;
    if (extra != null) {
        phone = extra['phone'] as String;
        verificationToken = extra['verification_token'] as String;
    } else {
        // Fallback or error
        phone = '';
        verificationToken = '';
    }
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

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await ref.read(authProvider.notifier).register(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        verificationToken: verificationToken,
        refCode: _refCodeController.text.isNotEmpty ? _refCodeController.text.trim() : null,
        photo: _imageFile,
      );
      
      if (mounted) {
        // Registration success + Auto Login (via provider updating state)
        // Router should redirect to /home or we do it manually
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        CustomNotificationService().show(
          context,
          'Registration failed: $e',
           ToastType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('auth.register_title'.tr()),
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
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'auth.register_header'.tr(),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'auth.register_subtitle'.tr(),
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: const Color(0xFFF8FAFC),
                      backgroundImage: _imageFile != null ? FileImage(_imageFile!) : null,
                      child: _imageFile == null
                          ? Icon(Icons.camera_alt, size: 40, color: Colors.grey[400])
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: _pickImage,
                    child: Text(
                      'auth.add_profile_photo'.tr(), // Make sure to add this key or use a generic one if missing, but user asked for functionality. Using hardcoded or existing key? 
                      // 'auth.add_profile_photo' might not exist. Let's check localization files or just use hardcoded for now or generic 'Add Photo'
                      // Actually, let's use a localized string if possible, or "Profil Fotoğrafı Ekle"
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Name Row
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _firstNameController,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                        decoration: InputDecoration(
                          labelText: 'auth.first_name_label'.tr(),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        ),
                        validator: (v) => v?.isEmpty == true ? 'auth.validation_required'.tr() : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _lastNameController,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                        decoration: InputDecoration(
                          labelText: 'auth.last_name_label'.tr(),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        ),
                        validator: (v) => v?.isEmpty == true ? 'auth.validation_required'.tr() : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Ref Code
                TextFormField(
                  controller: _refCodeController,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    labelText: 'auth.ref_code_label'.tr(),
                    prefixIcon: Icon(Icons.people_outline, color: Colors.grey[500]),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                ),

                const SizedBox(height: 32),

                ElevatedButton(
                  onPressed: _isLoading ? null : _register,
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: const Color(0xFF1A77F6),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      minimumSize: const Size(double.infinity, 56),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text('auth.register_btn'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
