import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import '../data/auth_service.dart';

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

part 'auth_provider.g.dart';

@riverpod
class Auth extends _$Auth {
  final _storage = const FlutterSecureStorage();

  @override
  FutureOr<Map<String, dynamic>?> build() async {
    // Check if token exists
    final token = await _storage.read(key: 'accessToken');
    if (token != null) {
      // Register Push Token
      _initPushToken();
      
      // OPTIMISTIC START: Try to load from SharedPreferences
      Map<String, dynamic>? optimisticState;
      try {
        final prefs = await SharedPreferences.getInstance();
        final userStr = prefs.getString('driverData');
        if (userStr != null) {
           optimisticState = jsonDecode(userStr);
        }
      } catch (e) {
        debugPrint('Error loading cached driver: $e');
      }

      // Fallback if no cache
      optimisticState ??= {
         'user': {'first_name': 'Sürücü', 'last_name': ''}, 
         'optimistic': true
      };
      
      // Trigger background sync
      Future.delayed(Duration.zero, () => _fetchRealProfile());
      
      return optimisticState;
    }
    
    return null;
  }

  Future<void> _fetchRealProfile() async {
    try {
        final service = ref.read(authServiceProvider);
        final profile = await service.getProfile();
        
        // Normalize data
        if (profile['driver'] != null) {
          final driverData = profile['driver'] as Map<String, dynamic>;
          final userData = Map<String, dynamic>.from(profile['user'] as Map<String, dynamic>);
          userData.addAll(driverData);
          profile['user'] = userData;
        }
        
        // Save to Cache
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('driverData', jsonEncode(profile));

        // Update state with REAL data
        state = AsyncValue.data(profile);
    } catch (e) {
        debugPrint('Optimistic Auth Failed: $e');
        // If fetch fails (e.g. 401), we must logout
        // await logout(); // Careful not to loop if it's just a network error
    }
  }

  Future<void> _initPushToken() async {
    try {
      final token = await _storage.read(key: 'accessToken');
      if (token == null) return;

      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null) {
        final service = ref.read(authServiceProvider);
        await service.updateDeviceToken(fcmToken);
      }
    } catch (e) {
      // Ignore token sync errors
    }
  }

  Future<void> sendOtp(String phone) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(authServiceProvider);
      await service.sendOtp(phone);
      return state.value;
    });
  }

  /// Returns map: { is_new_user: bool, verification_token: String?, user: Map? }
  Future<Map<String, dynamic>?> verifyOtp(String phone, String code) async {
    state = const AsyncValue.loading();
    try {
      final service = ref.read(authServiceProvider);
      final data = await service.verifyOtp(phone, code);

      if (data['is_new_user'] == true) {
        state = const AsyncValue.data(null);
        return {
          'is_new_user': true,
          'verification_token': data['verification_token']
        };
      } else {
        // Login success
        
        // We need the FULL profile structure for consistency if possible, 
        // but verifyOtp returns { accessToken, user, ok }. 
        // The 'user' object might be partial? Ideally we should fetch profile, 
        // but let's stick to what we have or do a background fetch.
        // For now, save what we have.
        
        // Register token on login
        _initPushToken();
        
        // Trigger generic profile fetch to get full data and cache it properly
        // Or construct the state manually:
        final fullState = {
           'user': data['user'],
           // 'driver': ... might be missing here. 
           // Best to just fetch profile?
        };
        
        // Let's rely on _fetchRealProfile to do the heavy lifting for cache
        // But update state immediately
        state = AsyncValue.data(fullState);
        
        // Trigger fetch to fill holes and cache
        _fetchRealProfile(); 
        
        return {
          'is_new_user': false,
          'user': data['user']
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
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(authServiceProvider);
      final data = await service.register(
        firstName: firstName,
        lastName: lastName,
        verificationToken: verificationToken,
        vehiclePlate: vehiclePlate,
        vehicleBrand: vehicleBrand,
        vehicleModel: vehicleModel,
        vehicleType: vehicleType,
        driverCardNumber: driverCardNumber,
        workingRegion: workingRegion,
        workingDistrict: workingDistrict,
        photo: photo,
        vehicleLicense: vehicleLicense,
        ibbCard: ibbCard,
        drivingLicense: drivingLicense,
        identityCard: identityCard,
      );
      
      // return full profile data as state
      
      // Register token on register
      _initPushToken();
      
      // Cache likely needs fetch
      _fetchRealProfile();

      return data;
    });
  }

  Future<void> logout() async {
    final service = ref.read(authServiceProvider);
    await service.logout();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('driverData');
    state = const AsyncValue.data(null);
  }

  Future<void> deleteAccount(String code) async {
    final service = ref.read(authServiceProvider);
    await service.deleteAccount(code);
    await logout();
  }
}
