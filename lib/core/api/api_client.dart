import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:rast/core/constants/api_config.dart';
import 'package:rast/features/auth/services/auth_service.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}

class ApiClient {
  static final ApiClient _instance = ApiClient._();
  factory ApiClient() => _instance;

  late final String _baseUrl;
  final Map<String, String> _headers = {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  ApiClient._() {
    _baseUrl = ApiConfig.apiBaseUrl.endsWith('/') ? ApiConfig.apiBaseUrl : '${ApiConfig.apiBaseUrl}/';
  }

  void setToken(String? token) {
    if (token != null) {
      _headers['Authorization'] = 'Bearer $token';
    } else {
      _headers.remove('Authorization');
    }
  }

  void _updateAuthHeader() {
    final token = AuthService.token;
    if (token != null) {
      _headers['Authorization'] = 'Bearer $token';
    } else {
      _headers.remove('Authorization');
    }
  }

  Future<Map<String, dynamic>> _handleResponse(http.Response response) async {
    final raw = response.body.trim();
    if (raw.isNotEmpty && (raw.startsWith('<') || !raw.startsWith('{') && !raw.startsWith('['))) {
      throw ApiException(
        'الخادم أعاد استجابة غير صالحة (ليست JSON). تحقق من السيرفر أو سجلات الأخطاء.',
        response.statusCode,
      );
    }
    Object? body;
    try {
      body = raw.isEmpty ? null : jsonDecode(response.body);
    } on FormatException catch (_) {
      throw ApiException(
        'تعذر قراءة استجابة الخادم. قد يكون هناك خطأ في السيرفر.',
        response.statusCode,
      );
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body is Map<String, dynamic> ? body : {'data': body};
    }
    final msg = body is Map ? (body['message'] ?? body['error'] ?? response.reasonPhrase ?? 'حدث خطأ') : response.reasonPhrase ?? 'حدث خطأ';
    throw ApiException(msg.toString(), response.statusCode);
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? queryParams,
  }) async {
    _updateAuthHeader();
    final p = path.startsWith('/') ? path.substring(1) : path;
    final uri = Uri.parse('$_baseUrl$p').replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: _headers).timeout(ApiConfig.receiveTimeout);
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> post(String path, {Map<String, dynamic>? body}) async {
    _updateAuthHeader();
    final p = path.startsWith('/') ? path.substring(1) : path;
    final uri = Uri.parse('$_baseUrl$p');
    final response = await http
        .post(uri, headers: _headers, body: body != null ? jsonEncode(body) : null)
        .timeout(ApiConfig.connectTimeout);
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> put(String path, {Map<String, dynamic>? body}) async {
    _updateAuthHeader();
    final p = path.startsWith('/') ? path.substring(1) : path;
    final uri = Uri.parse('$_baseUrl$p');
    final response = await http
        .put(uri, headers: _headers, body: body != null ? jsonEncode(body) : null)
        .timeout(ApiConfig.connectTimeout);
    return _handleResponse(response);
  }
}
