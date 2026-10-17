import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Traqker mobile API. Override with
/// `--dart-define=API_BASE_URL=https://traqker.test/api/v1` for local dev.
const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://traqker.com/api/v1',
);

/// A failed API call, with Laravel's message (or first validation error)
/// ready to show to the user.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  bool get isUnauthorized => statusCode == 401;

  factory ApiException.from(Object error) {
    if (error is ApiException) return error;
    if (error is! DioException) return ApiException(error.toString());

    final response = error.response;
    if (response == null) {
      return ApiException("Couldn't reach Traqker. Check your connection.");
    }

    final data = response.data;
    String? message;
    if (data is Map) {
      final errors = data['errors'];
      if (errors is Map && errors.isNotEmpty) {
        final first = errors.values.first;
        message = first is List && first.isNotEmpty ? '${first.first}' : null;
      }
      message ??= data['message'] as String?;
    }
    return ApiException(
      message ?? 'Something went wrong (${response.statusCode}).',
      statusCode: response.statusCode,
    );
  }

  @override
  String toString() => message;
}

/// Thin wrapper over Dio that sends the Sanctum bearer token and turns
/// failures into [ApiException]s.
class ApiClient {
  ApiClient({Dio? dio, String baseUrl = apiBaseUrl})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 20),
              headers: {'Accept': 'application/json'},
            ),
          ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = this.token;
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) {
          if (error.response?.statusCode == 401 && token != null) {
            onUnauthorized?.call();
          }
          handler.next(error);
        },
      ),
    );
  }

  final Dio _dio;

  String? token;

  /// Called when the server rejects the token (revoked or expired).
  VoidCallback? onUnauthorized;

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => _dio.get(path, queryParameters: query));

  Future<dynamic> post(String path, {Object? data}) =>
      _send(() => _dio.post(path, data: data));

  Future<dynamic> put(String path, {Object? data}) =>
      _send(() => _dio.put(path, data: data));

  Future<dynamic> delete(String path) => _send(() => _dio.delete(path));

  /// Every page of a paginated collection's `data`.
  Future<List<Map<String, dynamic>>> getAll(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final items = <Map<String, dynamic>>[];
    var page = 1;
    while (true) {
      final body = await get(
        path,
        query: {...?query, 'per_page': 100, 'page': page},
      );
      items.addAll(dataList(body));
      final meta = body is Map ? body['meta'] : null;
      final lastPage = meta is Map ? meta['last_page'] as int? : null;
      if (lastPage == null || page >= lastPage) return items;
      page++;
    }
  }

  Future<dynamic> _send(Future<Response<dynamic>> Function() request) async {
    try {
      return (await request()).data;
    } catch (e) {
      throw ApiException.from(e);
    }
  }
}

// The server unwraps resources, so plain collections come back as bare
// arrays while paginated ones keep their `data` envelope. Accept both.

/// The items of a resource collection.
List<Map<String, dynamic>> dataList(dynamic body) {
  final list = body is Map ? body['data'] : body;
  return (list as List).cast<Map<String, dynamic>>();
}

/// A single resource.
Map<String, dynamic> dataObject(dynamic body) {
  final map = body as Map<String, dynamic>;
  final data = map['data'];
  return data is Map<String, dynamic> ? data : map;
}

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());
