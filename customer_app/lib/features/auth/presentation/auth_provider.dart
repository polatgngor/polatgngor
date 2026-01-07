import 'dart:io';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import '../data/auth_repository.dart';
import '../data/user_model.dart';
import '../../../core/api/api_client.dart';

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

part 'auth_provider.g.dart';

@riverpod
class Auth extends _$Auth {
  final _storage = const FlutterSecureStorage();

  @override
  FutureOr<UserModel?> build() async {
    // Check if token exists
    final token = await _storage.read(key: 'accessToken');
    if (token != null) {
      // Register Push Token
      _initPushToken();

      // Listen for 401 events
      final sub = apiClientUnauthorizedStream.stream.listen((_) => logout());
      ref.onDispose(sub.cancel);

      // OPTIMISTIC START: Try to load from SharedPreferences
      UserModel? optimisticUser;
      try {
        final prefs = await SharedPreferences.getInstance();
        final userStr = prefs.getString('userData');
        if (userStr != null) {
          optimisticUser = UserModel.fromJson(jsonDecode(userStr));
        }
      } catch (e) {
        debugPrint('Error loading cached user: $e');
      }

      // If no cached user, use fallback (though this should rarely happen if we save correctly)
      optimisticUser ??= UserModel(
        id: 0, 
        firstName: 'Yolcu', 
        lastName: '', 
        phone: '', 
        role: 'passenger',
        profilePhoto: null,
      );
      
      // Trigger background sync
      Future.delayed(Duration.zero, () => _fetchRealProfile());

      return optimisticUser;
    }
    
    return null;
  }

  Future<void> _fetchRealProfile() async {
    try {
      final repository = ref.read(authRepositoryProvider);
      final user = await repository.getProfile();
      
      // Update cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userData', jsonEncode(user.toJson()));

      state = AsyncValue.data(user);
    } catch (e) {
      debugPrint('Optimistic Auth Failed: $e');
      // Only logout if it's a 401, which is handled by the stream listener.
      // If it's a network error, we keep the optimistic user.
    }
  }

  Future<void> _initPushToken() async {
    try {
      final token = await _storage.read(key: 'accessToken');
      if (token == null) return;

      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null) {
        final repository = ref.read(authRepositoryProvider);
        await repository.updateDeviceToken(fcmToken);
      }
    } catch (e) {
      // Ignore token sync errors
    }
  }

  Future<void> sendOtp(String phone) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(authRepositoryProvider);
      await repository.sendOtp(phone);
      return state.value; // Keep current state (null or user)
    });
  }

  /// Returns map: { is_new_user: bool, verification_token: String?, user: UserModel? }
  Future<Map<String, dynamic>?> verifyOtp(String phone, String code) async {
    state = const AsyncValue.loading();
    
    // We handle the result manually because we might update state OR return a token for registration
    try {
      final repository = ref.read(authRepositoryProvider);
      final data = await repository.verifyOtp(phone, code);
      
      if (data['is_new_user'] == true) {
         state = const AsyncValue.data(null);
         return {
            'is_new_user': true,
            'verification_token': data['verification_token']
         };
      } else {
         // Existing user - Log them in
         final token = data['accessToken'];
         final userJson = data['user'];
         final user = UserModel.fromJson(userJson);

         await _storage.write(key: 'accessToken', value: token);
         
         // Save to SharedPreferences
         final prefs = await SharedPreferences.getInstance();
         await prefs.setString('userData', jsonEncode(user.toJson()));

         state = AsyncValue.data(user);
         
         // Register token on login
         _initPushToken();
         
         return {
            'is_new_user': false,
            'user': user
         };
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      throw e;
    }
  }

  Future<void> register({
    required String firstName,
    required String lastName,
    required String verificationToken,
    String? refCode,
    File? photo,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(authRepositoryProvider);
      final data = await repository.register(
        firstName: firstName,
        lastName: lastName,
        verificationToken: verificationToken,
        refCode: refCode,
        photo: photo,
      );
      
      // Registration returns accessToken and user immediately
      final token = data['accessToken'];
      final userJson = data['user'];
      final user = UserModel.fromJson(userJson);

      await _storage.write(key: 'accessToken', value: token);
      
      // Register token on register
      _initPushToken();
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userData', jsonEncode(user.toJson()));
      
      return user;
    });
  }

  Future<void> logout() async {
    try {
      final repository = ref.read(authRepositoryProvider);
      await repository.logout();
    } catch (_) {}
    await _storage.deleteAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userData');
    state = const AsyncValue.data(null);
  }

  Future<void> deleteAccount(String code) async {
    final repository = ref.read(authRepositoryProvider);
    await repository.deleteAccount(code);
    await logout(); // Logout ensures storage clear & state reset
  }
}
