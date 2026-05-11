import 'package:rast/core/api/api_client.dart';

class AuthApi {
  final _client = ApiClient();

  /// POST /api/auth/login
  Future<Map<String, dynamic>> login(String identifier, String password) async {
    final trimmed = identifier.trim();
    final loginKey = trimmed.contains('@') ? 'email' : 'phone';
    final res = await _client.post(
      'auth/login',
      body: {loginKey: trimmed, 'password': password},
    );
    return res['data'] as Map<String, dynamic>;
  }

  /// POST /api/auth/register — رقم الهاتف اختياري
  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    String? phone,
    required String password,
    required String passwordConfirmation,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'email': email,
      'password': password,
      'password_confirmation': passwordConfirmation,
    };
    final phoneTrim = phone?.trim();
    if (phoneTrim != null && phoneTrim.isNotEmpty) body['phone'] = phoneTrim;
    final res = await _client.post('auth/register', body: body);
    return res['data'] as Map<String, dynamic>;
  }

  /// POST /api/auth/forgot-password
  Future<void> forgotPassword(String email) async {
    await _client.post('auth/forgot-password', body: {'email': email});
  }

  /// POST /api/auth/forgot-password — طلب OTP عبر واتساب (`channel` + `phone`)
  Future<void> forgotPasswordViaWhatsApp(String phone) async {
    await _client.post(
      'auth/forgot-password',
      body: {
        'channel': 'whatsapp',
        'phone': phone,
      },
    );
  }

  /// POST /api/auth/reset-password — إعادة التعيين برابط البريد (token من الإيميل)
  Future<void> resetPassword({
    required String token,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    await _client.post(
      'auth/reset-password',
      body: {
        'token': token,
        'email': email,
        'password': password,
        'password_confirmation': passwordConfirmation,
      },
    );
  }

  /// POST /api/auth/reset-password-otp — بعد استلام OTP على واتساب
  Future<void> resetPasswordOtp({
    required String phone,
    required String otp,
    required String password,
    required String passwordConfirmation,
  }) async {
    await _client.post(
      'auth/reset-password-otp',
      body: {
        'phone': phone,
        'otp': otp,
        'password': password,
        'password_confirmation': passwordConfirmation,
      },
    );
  }

  /// PUT /api/auth/password — للمستخدم المسجّل
  Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) async {
    await _client.put(
      'auth/password',
      body: {
        'current_password': currentPassword,
        'new_password': newPassword,
        'new_password_confirmation': newPasswordConfirmation,
      },
    );
  }

  /// POST /api/auth/logout
  Future<void> logout() async {
    await _client.post('auth/logout');
  }

  /// POST /api/auth/delete-account — permanently delete user account (Apple requirement)
  Future<void> deleteAccount() async {
    await _client.post('auth/delete-account');
  }

  /// GET /api/auth/me
  Future<Map<String, dynamic>> me() async {
    final res = await _client.get('auth/me');
    return res['data'] as Map<String, dynamic>;
  }

  /// PUT /api/auth/profile
  Future<Map<String, dynamic>> updateProfile({
    String? name,
    String? phone,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (phone != null) body['phone'] = phone;
    final res = await _client.put(
      'auth/profile',
      body: body.isNotEmpty ? body : null,
    );
    return res['data'] as Map<String, dynamic>;
  }
}
