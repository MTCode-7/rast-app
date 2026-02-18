import 'package:rast/core/api/api_client.dart';

class HomeApi {
  final _client = ApiClient();

  /// GET /api/home - الصفحة الرئيسية (كاروسيل، فئات، مختبرات مميزة، إلخ)
  Future<Map<String, dynamic>> getHome({String platform = 'android'}) async {
    final res = await _client.get('home', queryParams: {'platform': platform});
    return res['data'] as Map<String, dynamic>;
  }

  /// GET /api/config - إعدادات التطبيق
  Future<Map<String, dynamic>> getConfig() async {
    final res = await _client.get('config');
    return res['data'] as Map<String, dynamic>;
  }
}
