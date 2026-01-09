import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import '../../../core/constants/app_constants.dart';

part 'auth_service.g.dart';

@Riverpod(keepAlive: true)
AuthService authService(Ref ref) {
  return AuthService(Dio(), const FlutterSecureStorage());
}

class AuthService {
  final Dio _dio;
  final FlutterSecureStorage _storage;

  AuthService(this._dio, this._storage);

  Future<void> sendOtp(String phone) async {
    try {
      await _dio.post(
        '${AppConstants.apiUrl}/auth/send-otp',
        data: {'phone': phone},
      );
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'OTP gönderilemedi');
    }
  }

  Future<Map<String, dynamic>> verifyOtp(String phone, String code) async {
    try {
      final response = await _dio.post(
        '${AppConstants.apiUrl}/auth/verify-otp',
        data: {
          'phone': phone,
          'code': code,
          'app_role': 'driver',
        },
      );
      
      final data = response.data;
      
      // If login successful (not new user), save token
      if (data['ok'] == true && data['is_new_user'] == false) {
        final token = data['accessToken'];
        final user = data['user'];
        await _storage.write(key: 'accessToken', value: token);
        if (user['vehicle_type'] != null) {
          await _storage.write(key: 'vehicle_type', value: user['vehicle_type']);
        }
      }
      
      return data;
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'OTP doğrulanamadı');
    }
  }

  Future<Map<String, dynamic>> register({
    required String firstName,
    required String lastName,
    required String verificationToken,
    required String vehiclePlate,
    required String vehicleBrand,
    required String vehicleModel,
    required String vehicleType,
    String? driverCardNumber,
    String? workingRegion,
    String? workingDistrict,
    dynamic photo,
    dynamic vehicleLicense,
    dynamic ibbCard,
    dynamic drivingLicense,
    dynamic identityCard,
  }) async {
    try {
      final Map<String, dynamic> dataMap = {
        'first_name': firstName,
        'last_name': lastName,
        'verification_token': verificationToken,
        'role': 'driver',
        'vehicle_plate': vehiclePlate,
        'vehicle_brand': vehicleBrand,
        'vehicle_model': vehicleModel,
        'vehicle_type': vehicleType,
        'driver_card_number': driverCardNumber,
        'working_region': workingRegion,
        'working_district': workingDistrict,
      };

      FormData formData = FormData.fromMap(dataMap);

      if (photo != null) {
        String fileName = photo.path.split('/').last;
        formData.files.add(MapEntry(
            'photo', await MultipartFile.fromFile(photo.path, filename: fileName)));
      }
      if (vehicleLicense != null) {
        String fileName = vehicleLicense.path.split('/').last;
        formData.files.add(MapEntry('vehicle_license',
            await MultipartFile.fromFile(vehicleLicense.path, filename: fileName)));
      }
      if (ibbCard != null) {
        String fileName = ibbCard.path.split('/').last;
        formData.files.add(MapEntry('ibb_card',
            await MultipartFile.fromFile(ibbCard.path, filename: fileName)));
      }
      if (drivingLicense != null) {
        String fileName = drivingLicense.path.split('/').last;
        formData.files.add(MapEntry('driving_license',
            await MultipartFile.fromFile(drivingLicense.path, filename: fileName)));
      }
      if (identityCard != null) {
        String fileName = identityCard.path.split('/').last;
        formData.files.add(MapEntry('identity_card',
            await MultipartFile.fromFile(identityCard.path, filename: fileName)));
      }

      final response = await _dio.post(
        '${AppConstants.apiUrl}/auth/register',
        data: formData,
      );

      if (response.statusCode == 201) {
        final token = response.data['accessToken'];
        final user = response.data['user'];
        await _storage.write(key: 'accessToken', value: token);
         if (user['vehicle_type'] != null) {
          await _storage.write(key: 'vehicle_type', value: user['vehicle_type']);
        }
        return response.data;
      } else {
        throw Exception('Kayıt başarısız');
      }
    } on DioException catch (e) {
      if (e.response != null && e.response!.data != null) {
        throw Exception(e.response!.data['message'] ?? 'Kayıt başarısız');
      }
      throw Exception('Kayıt hatası: ${e.message}');
    } catch (e) {
      throw Exception('Registration error: $e');
    }
  }

  Future<void> logout() async {
    try {
      final token = await getToken();
      if (token != null) {
        await _dio.post(
          '${AppConstants.apiUrl}/profile/logout',
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );
      }
    } catch (e) {
      // Ignore network errors on logout
    }
    await _storage.deleteAll();
  }

  Future<String?> getToken() async {
    return await _storage.read(key: 'accessToken');
  }

  Future<String?> getVehicleType() async {
    return await _storage.read(key: 'vehicle_type');
  }

  Future<Map<String, dynamic>> getProfile() async {
    try {
      final token = await getToken();
      if (token == null) throw Exception('No token');

      final response = await _dio.get(
        '${AppConstants.apiUrl}/profile',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.data;
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Failed to fetch profile');
    }
  }

  Future<void> updateDeviceToken(String token) async {
    try {
      final authToken = await getToken();
      if (authToken == null) return;

      await _dio.post(
        '${AppConstants.apiUrl}/auth/device-token',
        data: {'token': token},
        options: Options(headers: {'Authorization': 'Bearer $authToken'}),
      );
    } catch (e) {
      debugPrint('Failed to update device token: $e');
    }
  }

  Future<void> updateProfile({required String firstName, required String lastName}) async {
    try {
      final token = await getToken();
      if (token == null) throw Exception('No token');

      await _dio.put(
        '${AppConstants.apiUrl}/profile',
        data: {
          'first_name': firstName,
          'last_name': lastName,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Profil güncellenemedi');
    }
  }

  Future<void> changePhone(String newPhone, String code) async {
    try {
      final token = await getToken();
      if (token == null) throw Exception('No token');

      await _dio.post(
        '${AppConstants.apiUrl}/profile/change-phone',
        data: {
          'new_phone': newPhone,
          'code': code,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Telefon numarası güncellenemedi');
    }
  }



  Future<void> deleteAccount(String code) async {
    try {
      final token = await getToken();
      if (token == null) throw Exception('No token');

      await _dio.post(
        '${AppConstants.apiUrl}/profile/delete',
        data: {'code': code},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      await logout();
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Hesap silinemedi');
    }
  }

  Future<void> uploadProfilePhoto(dynamic imageFile) async {
    try {
      final token = await getToken();
      if (token == null) throw Exception('No token');

      String fileName = imageFile.path.split('/').last;
      FormData formData = FormData.fromMap({
        'photo': await MultipartFile.fromFile(imageFile.path, filename: fileName),
      });

      await _dio.post(
        '${AppConstants.apiUrl}/profile/upload-photo',
        data: formData,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Fotoğraf yüklenemedi');
    }
  }

  // TEST ACCOUNT TRIGGER
  Future<void> ackTestAccount() async {
    try {
      final token = await getToken();
      if (token == null) return;

      await _dio.post(
        '${AppConstants.apiUrl}/driver/test-approve',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } catch (e) {
      // Ignore errors, silent background call
      debugPrint('Ack test account failed: $e');
    }
  }
}
