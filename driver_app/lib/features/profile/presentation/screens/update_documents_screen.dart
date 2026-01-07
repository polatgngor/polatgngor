import 'dart:io';
import 'package:easy_localization/easy_localization.dart';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:driver_app/features/auth/data/vehicle_repository.dart';
import 'package:driver_app/features/auth/presentation/auth_provider.dart';
import 'package:driver_app/features/auth/presentation/widgets/otp_sheet.dart';
import '../../../../core/widgets/custom_toast.dart';

class UpdateDocumentsScreen extends ConsumerStatefulWidget {
  const UpdateDocumentsScreen({super.key});

  @override
  ConsumerState<UpdateDocumentsScreen> createState() => _UpdateDocumentsScreenState();
}

class _UpdateDocumentsScreenState extends ConsumerState<UpdateDocumentsScreen> {
  // Files
  File? _vehicleLicenseFile;
  File? _ibbCardFile;
  File? _drivingLicenseFile;
  File? _identityCardFile;

  bool _isLoading = false;

  // Brand/Model
  Map<String, List<String>> _vehicleData = {};
  String? _selectedBrand;
  String? _selectedModel;
  String _selectedVehicleType = 'sari'; // Default

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    // Load Vehicle Data
    try {
      final data = await ref.read(vehicleRepositoryProvider).getVehicleData();
      if (mounted) {
        final authState = ref.read(authProvider);
        final user = authState.value?['user'];
        
        setState(() {
          _vehicleData = data;
          // Pre-fill if exists
          if (user != null) {
              if (data.containsKey(user['vehicle_brand'])) {
                  _selectedBrand = user['vehicle_brand'];
                  if (data[user['vehicle_brand']]!.contains(user['vehicle_model'])) {
                      _selectedModel = user['vehicle_model'];
                  }
              }
              _selectedVehicleType = user['vehicle_type'] ?? 'sari';
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading vehicles: $e');
    }
  }

  Future<void> _pickFile(Function(File) onPicked) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.path != null) {
      setState(() {
        onPicked(File(result.files.single.path!));
      });
    }
  }

  Future<void> _submitRequest() async {
    // Basic validation
    // Require Brand/Model selection if we are showing them
    if (_selectedBrand == null || _selectedModel == null) {
       CustomNotificationService().show(
        context,
        'profile.brand_select_error'.tr(),
        ToastType.error,
      );
      return;
    }

    // At least one file?? Or is it optional if just updating vehicle info?
    // Let's keep it lenient: if files are null, they won't be updated.
    // But since this is "Update Documents", maybe files are the focus?
    // User requested "vehicle update" here too. Let's allow files to be null if vehicle info is changed.

    // Get Phone Number
    final authState = ref.read(authProvider);
    final phone = authState.value?['user']?['phone'];
    
    if (phone == null) {
        CustomNotificationService().show(
          context,
          'profile.phone_error'.tr(),
          ToastType.error,
        );
      return;
    }

    // Show OTP Dialog
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 24, right: 24, top: 24),
        child: OtpVerificationSheet(
          phone: phone, 
          onVerified: (code) => _performUpdate(code),
        ),
      ),
    );
  }

  Future<void> _performUpdate(String otpCode) async {
    Navigator.pop(context); // Close OTP sheet

    setState(() {
      _isLoading = true;
    });

    try {
      final repo = ref.read(vehicleRepositoryProvider);
      
      // We pass request_type = 'update_info'
      await repo.requestVehicleChange(
        requestType: 'update_info',
        otpCode: otpCode, 
        // Pass selected dropdown values
        brand: _selectedBrand!,
        model: _selectedModel!,
        vehicleType: _selectedVehicleType,
        
        vehicleLicense: _vehicleLicenseFile,
        ibbCard: _ibbCardFile,
        drivingLicense: _drivingLicenseFile,
        identityCard: _identityCardFile,
      );

      if (mounted) {
        CustomNotificationService().show(
          context,
          'profile.success_update'.tr(),
          ToastType.success,
        );
        // Force refresh of auth state to catch 'pending' status
        await ref.refresh(authProvider.future);
        
        if (mounted) {
           // If router didn't redirect us yet, pop.
           if (ModalRoute.of(context)?.isCurrent ?? false) {
             Navigator.pop(context);
           }
        }
      }
    } catch (e) {
      if (mounted) {
        CustomNotificationService().show(
          context,
          'Hata: ${e.toString()}',
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
    // ... (Existing variables)
    final authState = ref.watch(authProvider);
    final user = authState.value?['user'];
    
    final currentPlate = user?['vehicle_plate'] ?? 'Bilinmiyor';

    return Scaffold(
      appBar: AppBar(
        title: Text('profile.update_docs'.tr()),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.withOpacity(0.1)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: const Color(0xFF1A77F6).withOpacity(0.1), shape: BoxShape.circle),
                        child: const Icon(Icons.directions_car_filled_rounded, color: Color(0xFF1A77F6)),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        "profile.current_plate".tr(),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      currentPlate, 
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF2D3242))
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                       const Icon(Icons.info_outline_rounded, size: 16, color: Colors.grey),
                       const SizedBox(width: 6),
                       Expanded(
                         child: Text(
                          "profile.plate_change_note".tr(),
                          style: const TextStyle(fontSize: 13, color: Colors.grey, height: 1.3),
                         ),
                       ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            Text('profile.update_vehicle_info'.tr(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D3242))),
            const SizedBox(height: 16),

             // Vehicle Type Dropdown
            DropdownButtonFormField<String>(
              value: _selectedVehicleType,
              decoration: InputDecoration(
                labelText: 'profile.type_label'.tr(),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
              ),
              items: [
                DropdownMenuItem(value: 'sari', child: Text('auth.vehicle_sari'.tr())),
                DropdownMenuItem(value: 'turkuaz', child: Text('auth.vehicle_turkuaz'.tr())),
                DropdownMenuItem(value: 'vip', child: Text('auth.vehicle_vip'.tr())),
                DropdownMenuItem(value: '8+1', child: Text('auth.vehicle_8plus1'.tr())),
              ],
              onChanged: (v) => setState(() => _selectedVehicleType = v!),
            ),
            const SizedBox(height: 16),

             // Brand Dropdown
            DropdownButtonFormField<String>(
              value: _selectedBrand,
              decoration: InputDecoration(
                labelText: 'profile.brand_label'.tr(),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
              ),
              items: _vehicleData.keys.map((brand) {
                return DropdownMenuItem(value: brand, child: Text(brand));
              }).toList(),
              onChanged: (val) => setState(() { _selectedBrand = val; _selectedModel = null; }),
               validator: (v) => v == null ? 'profile.brand_select_error'.tr() : null,
            ),
            const SizedBox(height: 16),

            // Model Dropdown
            DropdownButtonFormField<String>(
              value: _selectedModel,
              decoration: InputDecoration(
                labelText: 'profile.model_label'.tr(),
                 border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                 filled: true,
                 fillColor: const Color(0xFFF9FAFB),
                 enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
              ),
              items: (_selectedBrand != null && _vehicleData.containsKey(_selectedBrand))
                  ? _vehicleData[_selectedBrand]!.map((model) {
                      return DropdownMenuItem(value: model, child: Text(model));
                    }).toList()
                  : [],
              onChanged: (val) => setState(() => _selectedModel = val),
              validator: (v) => v == null ? 'profile.model_select_error'.tr() : null,
            ),
            
            const SizedBox(height: 32),
            
            Text(
              'profile.documents_optional'.tr(),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D3242)),
            ),
            Padding(
               padding: const EdgeInsets.only(top: 4, bottom: 16),
               child: Text("profile.documents_optional_desc".tr(), style: const TextStyle(color: Colors.grey)),
            ),

            _buildFilePicker(
              label: 'profile.vehicle_license'.tr(),
              file: _vehicleLicenseFile,
              onPicked: (f) => _vehicleLicenseFile = f,
            ),
            _buildFilePicker(
              label: 'profile.ibb_license'.tr(),
              file: _ibbCardFile,
              onPicked: (f) => _ibbCardFile = f,
            ),
            _buildFilePicker(
              label: 'profile.driver_license'.tr(),
              file: _drivingLicenseFile,
              onPicked: (f) => _drivingLicenseFile = f,
            ),
            _buildFilePicker(
              label: 'profile.identity_card'.tr(),
              file: _identityCardFile,
              onPicked: (f) => _identityCardFile = f,
            ),

            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A77F6),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        'profile.submit_changes'.tr(),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildFilePicker({
    required String label,
    required File? file,
    required Function(File) onPicked,
  }) {
    final isSelected = file != null;
    return GestureDetector(
      onTap: () => _pickFile(onPicked),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF0FDF4) : Colors.white, // Green tint if selected
          borderRadius: BorderRadius.circular(16),
          border: isSelected 
              ? Border.all(color: Colors.green.withOpacity(0.5))
              : Border.all(color: Colors.grey.shade300), // Dashed border is hard in Flutter without package, stick to solid grey
        ),
        child: Row(
          children: [
             Container(
               width: 40, height: 40,
               decoration: BoxDecoration(
                 color: isSelected ? Colors.green : const Color(0xFFF3F4F6),
                 borderRadius: BorderRadius.circular(12),
               ),
               child: Icon(
                 isSelected ? Icons.check_rounded : Icons.cloud_upload_rounded,
                 color: isSelected ? Colors.white : Colors.grey[600],
                 size: 20,
               ),
             ),
             const SizedBox(width: 16),
             Expanded(
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Text(
                     label,
                     style: TextStyle(
                       fontWeight: FontWeight.bold, 
                       color: isSelected ? Colors.green[900] : Colors.black87
                     ),
                   ),
                   if (isSelected)
                     Text(
                       (file?.path.split('/').last) ?? '',
                       style: TextStyle(fontSize: 12, color: Colors.green[700]),
                       maxLines: 1,
                       overflow: TextOverflow.ellipsis,
                     )
                   else
                    Text(
                      'profile.tap_to_upload'.tr(),
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                 ],
               ),
             ),
             if (isSelected)
                Icon(Icons.edit_outlined, color: Colors.green[700], size: 20)
             else
                Icon(Icons.chevron_right_rounded, color: Colors.grey[300]),
          ],
        ),
      ),
    );
  }
}
