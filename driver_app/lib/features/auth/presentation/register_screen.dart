import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/widgets/custom_toast.dart';
import 'auth_provider.dart';
import '../data/vehicle_repository.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  // final _driverCardController = TextEditingController(); // Removed
  
  // Plate controllers
  final _plateMiddleController = TextEditingController(); // For 34 (ABC) or Others (Numbers)
  final _plateSuffixController = TextEditingController(); // For 34 (Numbers) 

  final _formKey = GlobalKey<FormState>();
  
  String _selectedVehicleType = 'sari';
  String _selectedRegion = 'Anadolu';
  String _selectedDistrict = 'Ataşehir';
  String _selectedPlateCity = '34';

  // Files
  File? _profilePhoto;
  File? _vehicleLicense;
  File? _ibbCard;
  File? _drivingLicense;
  File? _identityCard;

  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  late String phone;
  late String verificationToken;

  Map<String, List<String>> _vehicleData = {};
  String? _selectedBrand;
  String? _selectedModel;
  final List<String> _cityCodes = ['34', '06', '35', '07', '16', '41', '59']; // Common ones

  @override
  void initState() {
    super.initState();
    _loadVehicleData();
  }

  Future<void> _loadVehicleData() async {
    try {
      final data = await ref.read(vehicleRepositoryProvider).getVehicleData();
      if (mounted) {
        setState(() {
          _vehicleData = data;
        });
      }
    } catch (e) {
      debugPrint('Error loading vehicles: $e');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final extra = GoRouterState.of(context).extra as Map<String, dynamic>?;
    if (extra != null) {
        phone = extra['phone'] as String;
        verificationToken = extra['verification_token'] as String;
    } else {
        phone = '';
        verificationToken = '';
    }
  }

  Future<void> _pickImage(String type) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image != null) {
      setState(() {
        switch (type) {
          case 'photo': _profilePhoto = File(image.path); break;
          case 'vehicle': _vehicleLicense = File(image.path); break;
          case 'ibb': _ibbCard = File(image.path); break;
          case 'driving': _drivingLicense = File(image.path); break;
          case 'identity': _identityCard = File(image.path); break;
        }
      });
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (_profilePhoto == null || _vehicleLicense == null || _ibbCard == null || _drivingLicense == null || _identityCard == null) {
        CustomNotificationService().show(
          context,
          'Lütfen tüm belgeleri ve fotoğrafınızı yükleyiniz.',
          ToastType.error,
        );
        return;
    }

    // Construct Plate
    String fullPlate;
    if (_selectedPlateCity == '34') {
       fullPlate = '$_selectedPlateCity ${_plateMiddleController.text.toUpperCase()} ${_plateSuffixController.text}';
    } else {
       // "06 T 1234"
       fullPlate = '$_selectedPlateCity T ${_plateMiddleController.text}';
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await ref.read(authProvider.notifier).register(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        verificationToken: verificationToken,
        vehiclePlate: fullPlate,
        vehicleBrand: _selectedBrand!,
        vehicleModel: _selectedModel!,
        vehicleType: _selectedVehicleType,
        driverCardNumber: null, // Removed form input
        workingRegion: _selectedRegion,
        workingDistrict: _selectedDistrict,
        photo: _profilePhoto,
        vehicleLicense: _vehicleLicense,
        ibbCard: _ibbCard,
        drivingLicense: _drivingLicense,
        identityCard: _identityCard,
      );
      
      if (mounted) {
         context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        CustomNotificationService().show(
          context,
          'Kayıt başarısız: $e',
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('auth.register_title'.tr()),
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
                  'auth.driver_register_header'.tr(),
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'auth.driver_register_subtitle'.tr(),
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                const SizedBox(height: 24),

                // Personal Info
                Text('auth.personal_info'.tr(), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
                const SizedBox(height: 16),
                
                // Profile Photo
                Center(
                  child: GestureDetector(
                    onTap: () => _pickImage('photo'),
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: _profilePhoto != null ? FileImage(_profilePhoto!) : null,
                      child: _profilePhoto == null ? const Icon(Icons.camera_alt, size: 40, color: Colors.grey) : null,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(child: Text('auth.upload_profile_photo'.tr(), style: TextStyle(color: Colors.grey[600]))),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _firstNameController,
                        decoration: InputDecoration(
                          labelText: 'auth.first_name_label'.tr(),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        ),
                        validator: (v) => v?.isEmpty == true ? 'auth.validation_required'.tr() : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _lastNameController,
                        decoration: InputDecoration(
                          labelText: 'auth.last_name_label'.tr(),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        ),
                        validator: (v) => v?.isEmpty == true ? 'auth.validation_required'.tr() : null,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 32),
                Text('auth.vehicle_info_header'.tr(), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
                const SizedBox(height: 16),
                
                // Smart Plate Input
                Text('auth.plate'.tr(), style: const TextStyle(fontSize: 14, color: Colors.grey)),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // City Code Dropdown
                    SizedBox(
                      width: 80,
                      child: DropdownButtonFormField<String>(
                        value: _selectedPlateCity,
                        items: _cityCodes.map((code) => DropdownMenuItem(value: code, child: Text(code))).toList(),
                        onChanged: (val) {
                           setState(() {
                             _selectedPlateCity = val!;
                             _plateMiddleController.clear();
                             _plateSuffixController.clear();
                           });
                        },
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 8),
                    
                    // Logic based on selection
                    if (_selectedPlateCity == '34') ...[
                      // 34 ABC 123
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _plateMiddleController,
                          decoration: InputDecoration(
                            hintText: 'ABC',
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                            counterText: "",
                          ),
                          maxLength: 3,
                          textCapitalization: TextCapitalization.characters,
                          validator: (v) => (v?.isEmpty ?? true) ? '!' : null,
                        ),
                      ),
                       const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _plateSuffixController,
                          decoration: InputDecoration(
                            hintText: '123',
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                            counterText: "",
                          ),
                          keyboardType: TextInputType.number,
                          maxLength: 4,
                          validator: (v) => (v?.isEmpty ?? true) ? '!' : null,
                        ),
                      ),
                    ] else ...[
                      // 06 T 1234
                       Container(
                         height: 58,
                         width: 50,
                         alignment: Alignment.center,
                         decoration: BoxDecoration(
                           color: Colors.grey[200],
                           borderRadius: BorderRadius.circular(16),
                           border: Border.all(color: Colors.transparent)
                         ),
                         child: const Text('T', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                       ),
                       const SizedBox(width: 8),
                       Expanded(
                        child: TextFormField(
                          controller: _plateMiddleController, // Reusing middle for number part in non-34 case
                          decoration: InputDecoration(
                            hintText: '1234',
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                            counterText: '',
                          ),
                          keyboardType: TextInputType.number,
                          maxLength: 5,
                          validator: (v) => (v?.isEmpty ?? true) ? '!' : null,
                        ),
                      ),
                    ],

                  ],
                ),
                
                const SizedBox(height: 16),
                
                const SizedBox(height: 16),
                
                // Vehicle Brand Dropdown
                DropdownButtonFormField<String>(
                  value: _selectedBrand,
                  decoration: InputDecoration(
                    labelText: 'Araç Markası',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                  items: _vehicleData.keys.map((brand) {
                    return DropdownMenuItem(value: brand, child: Text(brand));
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedBrand = val;
                      _selectedModel = null; // Reset model
                    });
                  },
                   validator: (v) => v == null ? 'Lütfen marka seçiniz' : null,
                ),
                const SizedBox(height: 16),

                // Vehicle Model Dropdown
                DropdownButtonFormField<String>(
                  value: _selectedModel,
                  decoration: InputDecoration(
                    labelText: 'Araç Modeli',
                     filled: true,
                     fillColor: const Color(0xFFF8FAFC),
                     border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                     enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                  items: (_selectedBrand != null && _vehicleData.containsKey(_selectedBrand))
                      ? _vehicleData[_selectedBrand]!.map((model) {
                          return DropdownMenuItem(value: model, child: Text(model));
                        }).toList()
                      : [],
                  onChanged: (val) => setState(() => _selectedModel = val),
                  validator: (v) => v == null ? 'Lütfen model seçiniz' : null,
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  value: _selectedVehicleType,
                  decoration: InputDecoration(
                      labelText: 'auth.vehicle_type'.tr(),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
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
                
                DropdownButtonFormField<String>(
                  value: _selectedRegion,
                  decoration: InputDecoration(
                      labelText: 'auth.working_region_header'.tr(),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                  items: [
                    DropdownMenuItem(value: 'Anadolu', child: Text('auth.region_anadolu'.tr())),
                    DropdownMenuItem(value: 'Avrupa', child: Text('auth.region_avrupa'.tr())),
                  ],
                  onChanged: (v) => setState(() => _selectedRegion = v!),
                ),
                const SizedBox(height: 16),

                 DropdownButtonFormField<String>(
                  value: _selectedDistrict,
                  decoration: InputDecoration(
                      labelText: 'auth.district_select_label'.tr(),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Ataşehir', child: Text('Ataşehir')),
                    DropdownMenuItem(value: 'Kadıköy', child: Text('Kadıköy')),
                    DropdownMenuItem(value: 'Ümraniye', child: Text('Ümraniye')),
                    DropdownMenuItem(value: 'Maltepe', child: Text('Maltepe')),
                    DropdownMenuItem(value: 'Beşiktaş', child: Text('Beşiktaş')),
                    DropdownMenuItem(value: 'Şişli', child: Text('Şişli')),
                  ],
                  onChanged: (v) => setState(() => _selectedDistrict = v!),
                ),

                const SizedBox(height: 32),
                Text('auth.photos_header'.tr(), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
                const SizedBox(height: 16),

                _buildUploadButton('auth.upload_vehicle_license'.tr(), _vehicleLicense, () => _pickImage('vehicle')),
                const SizedBox(height: 12),
                _buildUploadButton('auth.upload_ibb_card'.tr(), _ibbCard, () => _pickImage('ibb')),
                const SizedBox(height: 12),
                _buildUploadButton('auth.upload_driving_license'.tr(), _drivingLicense, () => _pickImage('driving')),
                const SizedBox(height: 12),
                _buildUploadButton('auth.upload_identity_card'.tr(), _identityCard, () => _pickImage('identity')),
                
                const SizedBox(height: 32),

                ElevatedButton(
                  onPressed: _isLoading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                    backgroundColor: const Color(0xFF1A77F6), // Theme Blue
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text('auth.complete_app_btn'.tr(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUploadButton(String label, File? file, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: file != null ? Colors.green : Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(
              file != null ? Icons.check_circle : Icons.cloud_upload_outlined,
              color: file != null ? Colors.green : Colors.grey[600],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                file != null ? '$label (Yüklendi)' : label,
                style: TextStyle(
                  color: file != null ? Colors.green[700] : Colors.grey[800],
                  fontWeight: file != null ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            if (file != null)
              SizedBox(
                height: 40,
                width: 40,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.file(file, fit: BoxFit.cover),
                ),
              )
          ],
        ),
      ),
    );
  }
}
