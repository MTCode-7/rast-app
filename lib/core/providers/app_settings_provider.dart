import 'package:flutter/material.dart';
import 'package:rast/core/api/api_services.dart';
import 'package:rast/core/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// مزود إعدادات التطبيق: الوضع الداكن واللغة والألوان من الـ API
class AppSettingsProvider extends ChangeNotifier {
  static const _keyDarkMode = 'app_dark_mode';
  static const _keyLanguage = 'app_language';
  static const _keyPrimaryColor = 'app_primary_color';
  static const _keySecondaryColor = 'app_secondary_color';

  bool _isDarkMode = false;
  String _language = 'ar';
  Color? _primaryColor;
  Color? _secondaryColor;

  bool get isDarkMode => _isDarkMode;
  String get language => _language;
  bool get isArabic => _language == 'ar';
  Locale get locale => _language == 'ar' ? const Locale('ar') : const Locale('en');
  TextDirection get textDirection => isArabic ? TextDirection.rtl : TextDirection.ltr;

  Color get primaryColor => _primaryColor ?? AppTheme.primary;
  Color get secondaryColor => _secondaryColor ?? AppTheme.secondary;

  /// تدرج لوني من اللونين في الإعدادات (لخلفيات التسجيل والدخول)
  LinearGradient get primaryGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [primaryColor, secondaryColor],
        stops: const [0.0, 1.0],
      );

  AppSettingsProvider() {
    _loadFromPrefs();
    _loadThemeColors();
  }

  static Color? _parseColor(dynamic value) {
    if (value == null) return null;
    final s = value.toString().trim();
    if (s.isEmpty) return null;
    final hex = s.startsWith('#') ? s : '#$s';
    if (hex.length == 7 && RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(hex)) {
      return Color(int.parse(hex.substring(1), radix: 16) + 0xFF000000);
    }
    return null;
  }

  Future<void> _loadThemeColors() async {
    try {
      final config = await Api.home.getConfig();
      final site = config['site'];
      if (site is Map) {
        final c1 = _parseColor(site['color1']);
        final c2 = _parseColor(site['color2']);
        if (c1 != null || c2 != null) {
          _primaryColor = c1;
          _secondaryColor = c2;
          final prefs = await SharedPreferences.getInstance();
          if (c1 != null) await prefs.setString(_keyPrimaryColor, '#${c1.value.toRadixString(16).substring(2)}');
          if (c2 != null) await prefs.setString(_keySecondaryColor, '#${c2.value.toRadixString(16).substring(2)}');
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool(_keyDarkMode) ?? false;
    _language = prefs.getString(_keyLanguage) ?? 'ar';
    final saved1 = prefs.getString(_keyPrimaryColor);
    final saved2 = prefs.getString(_keySecondaryColor);
    if (saved1 != null) _primaryColor = _parseColor(saved1);
    if (saved2 != null) _secondaryColor = _parseColor(saved2);
    notifyListeners();
  }

  /// إعادة جلب الألوان من الـ API (مثلاً من الإعدادات)
  Future<void> refreshThemeColors() async {
    await _loadThemeColors();
  }

  Future<void> setDarkMode(bool value) async {
    if (_isDarkMode == value) return;
    _isDarkMode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDarkMode, value);
  }

  Future<void> setLanguage(String lang) async {
    if (_language == lang) return;
    _language = lang;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLanguage, lang);
  }

  Future<void> toggleDarkMode() async {
    await setDarkMode(!_isDarkMode);
  }
}
