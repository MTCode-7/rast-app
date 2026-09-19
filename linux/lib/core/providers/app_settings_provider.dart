import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// مزود إعدادات التطبيق: الوضع الداكن واللغة
class AppSettingsProvider extends ChangeNotifier {
  static const _keyDarkMode = 'app_dark_mode';
  static const _keyLanguage = 'app_language';

  bool _isDarkMode = false;
  String _language = 'ar';

  bool get isDarkMode => _isDarkMode;
  String get language => _language;
  bool get isArabic => _language == 'ar';
  Locale get locale => _language == 'ar' ? const Locale('ar') : const Locale('en');
  TextDirection get textDirection => isArabic ? TextDirection.rtl : TextDirection.ltr;

  AppSettingsProvider() {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool(_keyDarkMode) ?? false;
    _language = prefs.getString(_keyLanguage) ?? 'ar';
    notifyListeners();
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
