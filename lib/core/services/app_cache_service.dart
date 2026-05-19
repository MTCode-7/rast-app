import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// تخزين JSON محلي مع طابع زمني (للكاش السريع).
class AppCacheService {
  AppCacheService._();
  static final AppCacheService instance = AppCacheService._();

  Future<void> write(String key, dynamic payload) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      key,
      jsonEncode({
        'savedAt': DateTime.now().millisecondsSinceEpoch,
        'payload': payload,
      }),
    );
  }

  Future<dynamic> readPayload(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw);
      if (map is Map && map.containsKey('payload')) return map['payload'];
    } catch (_) {}
    return null;
  }

  Future<void> remove(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }
}
