import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_constants.dart';
import '../errors/exceptions.dart';
import 'session_expiration_provider.dart';
import 'storage_service.dart';

final dioProvider = Provider<Dio>((ref) {
  return Dio();
});

class ApiClient {
  final Dio _dio;
  final StorageService _storage;
  final void Function()? onUnauthorized;

  ApiClient({
    required Dio dio,
    required StorageService storage,
    this.onUnauthorized,
  })  : _dio = dio,
        _storage = storage {
    _dio.options = BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: const Duration(milliseconds: AppConstants.connectTimeout),
      receiveTimeout: const Duration(milliseconds: AppConstants.receiveTimeout),
      sendTimeout: const Duration(milliseconds: AppConstants.sendTimeout),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.getToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401 &&
              _requestHadAuthorization(error.requestOptions)) {
            await _storage.clearSession();
            final notify = onUnauthorized;
            if (notify != null) {
              Future.microtask(notify);
            }
          }
          return handler.next(error);
        },
      ),
    );
  }

  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.get(
        path,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('=== API POST REQUEST ===');
        debugPrint('Path: $path');
        debugPrint('Data: $data');
        debugPrint('========================');
      }

      return await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      if (kDebugMode) {
        debugPrint('=== API POST ERROR ===');
        debugPrint('Error: $e');
        debugPrint('Response: ${e.response?.data}');
        debugPrint('Status Code: ${e.response?.statusCode}');
        debugPrint('======================');
      }
      throw _handleError(e);
    }
  }

  Future<Response> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('=== API PUT REQUEST ===');
        debugPrint('Path: $path');
        debugPrint('Data: $data');
        debugPrint('========================');
      }

      return await _dio.put(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      if (kDebugMode) {
        debugPrint('=== API PUT ERROR ===');
        debugPrint('Error: $e');
        debugPrint('Response: ${e.response?.data}');
        debugPrint('Status Code: ${e.response?.statusCode}');
        debugPrint('=====================');
      }
      throw _handleError(e);
    }
  }

  Future<Response> patch(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.patch(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.delete(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  AppException _handleError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return NetworkException(
          message: 'Connection timeout. Please check your internet connection.',
          originalError: error,
        );
      case DioExceptionType.connectionError:
        return NetworkException(
          message: 'No internet connection. Please check your network.',
          originalError: error,
        );
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        final data = error.response?.data;
        String message = 'Something went wrong';

        if (data is Map<String, dynamic>) {
          message = data['message'] ?? data['error'] ?? message;
        }

        if (statusCode == 401) {
          return AuthException(
            message: message,
            statusCode: statusCode,
            originalError: error,
          );
        } else if (statusCode == 404) {
          return NotFoundException(
            message: message,
            statusCode: statusCode,
            originalError: error,
          );
        } else if (statusCode != null && statusCode >= 500) {
          return ServerException(
            message: message,
            statusCode: statusCode,
            originalError: error,
          );
        } else if (statusCode == 422 && data is Map<String, dynamic>) {
          return ValidationException(
            message: message,
            fieldErrors: _parseFieldErrors(data),
            statusCode: statusCode,
            originalError: error,
          );
        }
        return AppException(
          message: message,
          statusCode: statusCode,
          originalError: error,
        );
      case DioExceptionType.cancel:
        return AppException(message: 'Request cancelled', originalError: error);
      default:
        return AppException(
          message: 'Something went wrong',
          originalError: error,
        );
    }
  }

  static bool _requestHadAuthorization(RequestOptions options) {
    final headers = options.headers;
    final raw = headers['Authorization'] ?? headers['authorization'];
    if (raw == null) return false;
    if (raw is List) {
      return raw.isNotEmpty && raw.first.toString().trim().isNotEmpty;
    }
    return raw.toString().trim().isNotEmpty;
  }

  Map<String, String>? _parseFieldErrors(Map<String, dynamic> data) {
    if (data.containsKey('errors') && data['errors'] is Map) {
      final errors = data['errors'] as Map<String, dynamic>;
      return errors.map((key, value) {
        if (value is List && value.isNotEmpty) {
          return MapEntry(key, value.first.toString());
        }
        return MapEntry(key, value.toString());
      });
    }
    return null;
  }
}

final apiClientProvider = Provider<ApiClient>((ref) {
  final dio = ref.watch(dioProvider);
  final storage = ref.watch(storageServiceProvider);
  final sessionTick = ref.read(sessionExpirationTickProvider.notifier);
  return ApiClient(
    dio: dio,
    storage: storage,
    onUnauthorized: () => sessionTick.notifySessionExpired(),
  );
});
