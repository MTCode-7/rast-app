import 'package:rast/core/api/api_client.dart';

class AuthApi {
  final _client = ApiClient();

  /// POST /api/auth/login
  Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await _client.post('auth/login', body: {
      'email': email,
      'password': password,
    });
    return res['data'] as Map<String, dynamic>;
  }

  /// POST /api/auth/register
  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String passwordConfirmation,
  }) async {
    final res = await _client.post('auth/register', body: {
      'name': name,
      'email': email,
      'phone': phone,
      'password': password,
      'password_confirmation': passwordConfirmation,
    });
    return res['data'] as Map<String, dynamic>;
  }

  /// POST /api/auth/forgot-password
  Future<void> forgotPassword(String email) async {
    await _client.post('auth/forgot-password', body: {'email': email});
  }

  /// POST /api/auth/logout
  Future<void> logout() async {
    await _client.post('auth/logout');
  }

  /// GET /api/auth/me
  Future<Map<String, dynamic>> me() async {
    final res = await _client.get('auth/me');
    return res['data'] as Map<String, dynamic>;
  }

  /// PUT /api/auth/profile
  Future<Map<String, dynamic>> updateProfile({String? name, String? phone}) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (phone != null) body['phone'] = phone;
    final res = await _client.put('auth/profile', body: body.isNotEmpty ? body : null);
    return res['data'] as Map<String, dynamic>;
  }
}
