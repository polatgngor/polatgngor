import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../features/auth/presentation/auth_provider.dart';
import '../constants/app_constants.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

part 'api_service.g.dart';

@Riverpod(keepAlive: true)
ApiService apiService(Ref ref) {
  final dio = Dio();
  final storage = const FlutterSecureStorage();
  
  dio.interceptors.add(
    InterceptorsWrapper(
      onError: (DioException e, ErrorInterceptorHandler handler) async {
        if (e.response?.statusCode == 401) {
          // Oturum süresi doldu
          await storage.delete(key: 'accessToken');
          // Auth provider'ı sıfırla -> Kullanıcı login'e düşer
          ref.invalidate(authProvider);
        }
        return handler.next(e);
      },
    ),
  );

  return ApiService(dio, storage);
}

class ApiService {
  final Dio _dio;
  final FlutterSecureStorage _storage;

  ApiService(this._dio, this._storage) {
    _dio.options.baseUrl = AppConstants.apiUrl;
    _dio.options.connectTimeout = const Duration(seconds: 10);
    _dio.options.receiveTimeout = const Duration(seconds: 10);
  }

  Future<String?> _getToken() async {
    return await _storage.read(key: 'accessToken');
  }

  Future<Options> _getOptions({Map<String, dynamic>? headers}) async {
    final token = await _getToken();
    final Map<String, dynamic> authHeaders = {
      if (token != null) 'Authorization': 'Bearer $token',
      ...?headers,
    };
    return Options(headers: authHeaders);
  }

  Future<Response> get(String path, {Map<String, dynamic>? queryParameters, Map<String, dynamic>? headers}) async {
    try {
      final options = await _getOptions(headers: headers);
      return await _dio.get(path, queryParameters: queryParameters, options: options);
    } on DioException catch (e) {
       if (e.response?.statusCode == 401) {
          throw _handleError(e); 
       }
       throw _handleError(e);
    }
  }

  Future<Response> post(String path, {dynamic data, Map<String, dynamic>? queryParameters, Map<String, dynamic>? headers}) async {
    try {
      final options = await _getOptions(headers: headers);
      return await _dio.post(path, data: data, queryParameters: queryParameters, options: options);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response> put(String path, {dynamic data, Map<String, dynamic>? headers}) async {
    try {
      final options = await _getOptions(headers: headers);
      return await _dio.put(path, data: data, options: options);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response> delete(String path, {dynamic data, Map<String, dynamic>? headers}) async {
    try {
      final options = await _getOptions(headers: headers);
      return await _dio.delete(path, data: data, options: options);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Exception _handleError(DioException e) {
    if (e.response?.statusCode == 401) {
       return Exception('Oturum süresi doldu. Lütfen tekrar giriş yapın.');
    }
    if (e.response != null) {
      return Exception(e.response?.data['message'] ?? 'Bir hata oluştu: ${e.response?.statusCode}');
    }
    return Exception('Bağlantı hatası: ${e.message}');
  }
}
