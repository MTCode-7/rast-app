import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

enum FavoriteKind { lab, analysis }

class FavoritesService {
  static const _labsKey = 'favorite_labs_local';
  static const _analysesKey = 'favorite_analyses_local';

  static Future<List<Map<String, dynamic>>> getLabs() => _read(_labsKey);

  static Future<List<Map<String, dynamic>>> getAnalyses() =>
      _read(_analysesKey);

  static Future<bool> isLabFavorite(Map<String, dynamic> lab) =>
      _contains(_labsKey, itemId(lab));

  static Future<bool> isAnalysisFavorite(Map<String, dynamic> analysis) =>
      _contains(_analysesKey, itemId(analysis));

  static Future<bool> toggleLab(Map<String, dynamic> lab) =>
      _toggle(_labsKey, lab);

  static Future<bool> toggleAnalysis(Map<String, dynamic> analysis) =>
      _toggle(_analysesKey, analysis);

  static Future<void> removeLab(String id) => _remove(_labsKey, id);

  static Future<void> removeAnalysis(String id) => _remove(_analysesKey, id);

  static String itemId(Map<String, dynamic> item) {
    final id =
        item['id'] ??
        item['provider_service_id'] ??
        item['service_id'] ??
        item['slug'];
    if (id != null && id.toString().trim().isNotEmpty) {
      return id.toString();
    }

    final fallback =
        item['name_ar'] ??
        item['name_en'] ??
        item['name'] ??
        item['business_name_ar'] ??
        item['business_name_en'] ??
        item['business_name'];
    return fallback?.toString().trim() ?? '';
  }

  static Future<List<Map<String, dynamic>>> _read(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _write(
    String key,
    List<Map<String, dynamic>> items,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(items));
  }

  static Future<bool> _contains(String key, String id) async {
    if (id.isEmpty) return false;
    final items = await _read(key);
    return items.any((item) => itemId(item) == id);
  }

  static Future<bool> _toggle(String key, Map<String, dynamic> item) async {
    final id = itemId(item);
    if (id.isEmpty) return false;

    final items = await _read(key);
    final index = items.indexWhere((saved) => itemId(saved) == id);
    if (index >= 0) {
      items.removeAt(index);
      await _write(key, items);
      return false;
    }

    items.insert(0, Map<String, dynamic>.from(item));
    await _write(key, items);
    return true;
  }

  static Future<void> _remove(String key, String id) async {
    final items = await _read(key);
    items.removeWhere((item) => itemId(item) == id);
    await _write(key, items);
  }
}
