import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/constants/app_constants.dart';

final vehicleRepositoryProvider = Provider((ref) => VehicleRepository(const FlutterSecureStorage()));

class VehicleRepository {
  final Dio _dio = Dio();
  final FlutterSecureStorage _storage;

  VehicleRepository(this._storage);

  Future<Map<String, List<String>>> getVehicleData() async {
    try {
      final response = await _dio.get('${AppConstants.apiUrl}/vehicles/data');
      if (response.statusCode == 200 && response.data['success'] == true) {
        final Map<String, dynamic> data = response.data['data'];
        return data.map((key, value) => MapEntry(key, List<String>.from(value)));
      }
      return {};
    } catch (e) {
      throw Exception('Araç verileri alınamadı: $e');
    }
  }

  Future<void> requestVehicleChange({
    required String requestType,
    required String otpCode, // NEW
    String? plate,
    String? brand,
    String? model,
    String? vehicleType,
    dynamic vehicleLicense,
    dynamic ibbCard,
    dynamic drivingLicense,
    dynamic identityCard,
  }) async {
    try {
      // Get Token
      final token = await _storage.read(key: 'accessToken');
      if (token == null) throw Exception('Oturum bulunamadı');

      final Map<String, dynamic> dataMap = {
        'request_type': requestType,
        'otp_code': otpCode,
      };

      if (plate != null) dataMap['new_plate'] = plate;
      if (brand != null) dataMap['new_brand'] = brand;
      if (model != null) dataMap['new_model'] = model;
      if (vehicleType != null) dataMap['new_vehicle_type'] = vehicleType;

      FormData formData = FormData.fromMap(dataMap);

      if (vehicleLicense != null) {
        String fileName = vehicleLicense.path.split('/').last;
        formData.files.add(MapEntry('new_vehicle_license', await MultipartFile.fromFile(vehicleLicense.path, filename: fileName)));
      }
      if (ibbCard != null) {
        String fileName = ibbCard.path.split('/').last;
        formData.files.add(MapEntry('new_ibb_card', await MultipartFile.fromFile(ibbCard.path, filename: fileName)));
      }
      if (drivingLicense != null) {
        String fileName = drivingLicense.path.split('/').last;
        formData.files.add(MapEntry('new_driving_license', await MultipartFile.fromFile(drivingLicense.path, filename: fileName)));
      }
      if (identityCard != null) {
        String fileName = identityCard.path.split('/').last;
        formData.files.add(MapEntry('new_identity_card', await MultipartFile.fromFile(identityCard.path, filename: fileName)));
      }

      await _dio.post(
        '${AppConstants.apiUrl}/driver/change-request',
        data: formData,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Talep gönderilemedi');
    }
  }

  // Get Pending Requests
  Future<List<Map<String, dynamic>>> getChangeRequests() async {
    try {
      final token = await _storage.read(key: 'accessToken');
      if (token == null) throw Exception('Oturum bulunamadı');

      final response = await _dio.get(
        '${AppConstants.apiUrl}/driver/change-requests',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      
      if (response.data['ok'] == true) {
        return List<Map<String, dynamic>>.from(response.data['requests']);
      }
      return [];
    } catch (e) {
      // throw Exception('Talepler alınamadı: $e');
      return []; // Return empty on error for now
    }
  }
}
