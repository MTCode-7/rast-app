import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// خدمة المصادقة - إدارة حالة تسجيل الدخول
class AuthService {
  static const _keyToken = 'auth_token';
  static const _keyUser = 'auth_user';

  static UserModel? _currentUser;
  static String? _token;

  static UserModel? get currentUser => _currentUser;
  static String? get token => _token;
  static bool get isLoggedIn => _token != null && _currentUser != null;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_keyToken);
    final userJson = prefs.getString(_keyUser);
    if (userJson != null) {
      try {
        _currentUser = UserModel.fromJson(jsonDecode(userJson));
      } catch (_) {}
    }
  }

  static Future<void> login(String token, UserModel user) async {
    _token = token;
    _currentUser = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, token);
    await prefs.setString(_keyUser, jsonEncode(user.toJson()));
  }

  static Future<void> logout() async {
    _token = null;
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyUser);
  }

  static void updateUser(UserModel user) {
    _currentUser = user;
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(_keyUser, jsonEncode(user.toJson()));
    });
  }
}

class UserModel {
  final int id;
  final String name;
  final String email;
  final String? phone;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    return UserModel(
      id: id is int ? id : int.tryParse(id?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
      };
}
