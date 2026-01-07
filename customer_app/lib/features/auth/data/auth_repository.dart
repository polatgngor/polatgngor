import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import 'user_model.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.read(apiClientProvider));
});

class AuthRepository {
  final ApiClient _apiClient;

  AuthRepository(this._apiClient);

  Future<void> sendOtp(String phone) async {
    try {
      await _apiClient.client.post('/auth/send-otp', data: {
        'phone': phone,
      });
    } on DioException catch (e) {
      throw e.response?.data['message'] ?? 'Failed to send OTP';
    }
  }

  /// Returns map with keys: ok, is_new_user, verification_token (if new), accessToken (if existing), user (if existing)
  Future<Map<String, dynamic>> verifyOtp(String phone, String code) async {
    try {
      final response = await _apiClient.client.post('/auth/verify-otp', data: {
        'phone': phone,
        'code': code,
        'app_role': 'passenger',
      });
      return response.data;
    } on DioException catch (e) {
      throw e.response?.data['message'] ?? 'Invalid OTP';
    }
  }

  Future<Map<String, dynamic>> register({
    required String firstName,
    required String lastName,
    required String verificationToken,
    String? refCode,
    File? photo,
  }) async {
    try {
      final formData = FormData.fromMap({
        'first_name': firstName,
        'last_name': lastName,
        'verification_token': verificationToken,
        'role': 'passenger',
        if (refCode != null) 'ref_code': refCode,
        if (photo != null)
          'photo': await MultipartFile.fromFile(photo.path, filename: photo.path.split('/').last),
      });

      final response = await _apiClient.client.post('/auth/register', data: formData);
      return response.data;
    } on DioException catch (e) {
      throw e.response?.data['message'] ?? 'Registration failed';
    }
  }

  Future<UserModel> getProfile() async {
    try {
      final response = await _apiClient.client.get('/profile');
      final data = response.data;
      if (data['user'] != null) {
        return UserModel.fromJson(data['user']);
      }
      return UserModel.fromJson(data); 
    } on DioException catch (e) {
      throw e.response?.data['message'] ?? 'Failed to fetch profile';
    }
  }

  Future<void> updateProfile({String? firstName, String? lastName}) async {
    try {
      await _apiClient.client.put('/profile', data: {
        if (firstName != null) 'first_name': firstName,
        if (lastName != null) 'last_name': lastName,
      });
    } on DioException catch (e) {
      throw e.response?.data['message'] ?? 'Failed to update profile';
    }
  }

  Future<void> deleteAccount(String code) async {
    try {
      await _apiClient.client.post('/profile/delete', data: {'code': code});
    } on DioException catch (e) {
      throw e.response?.data['message'] ?? 'Failed to delete account';
    }
  }

  Future<void> updateDeviceToken(String token) async {
    try {
      await _apiClient.client.post('/auth/device-token', data: {
        'token': token,
      });
    } catch (e) {
      print('Failed to update device token: $e');
    }
  }
  
  Future<String> uploadProfilePhoto(File file) async {
    try {
      String fileName = file.path.split('/').last;
      FormData formData = FormData.fromMap({
        "photo": await MultipartFile.fromFile(file.path, filename: fileName),
      });
      final response = await _apiClient.client.post('/profile/upload-photo', data: formData);
      return response.data['photo_url'];
    } on DioException catch (e) {
      throw e.response?.data['message'] ?? 'Failed to upload photo';
    }
  }
  Future<void> changePhone(String newPhone, String code) async {
    try {
      await _apiClient.client.post('/profile/change-phone', data: {
        'new_phone': newPhone,
        'code': code,
      });
    } on DioException catch (e) {
      throw e.response?.data['message'] ?? 'Failed to change phone';
    }
  }

  Future<void> logout() async {
    try {
      await _apiClient.client.post('/profile/logout');
    } catch (e) {
      // Ignore errors
    }
  }
}
