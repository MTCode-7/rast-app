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

  /// GET /api/mobile/slides - شرائح الموبايل (بانر/كاروسيل)
  Future<List<dynamic>> getMobileSlides() async {
    final res = await _client.get('mobile/slides');
    final data = res['data'];
    return data is List ? List.from(data) : [];
  }

  /// GET /api/popup - النافذة المنبثقة النشطة (للعرض عند فتح التطبيق)
  Future<Map<String, dynamic>?> getPopup({String platform = 'android'}) async {
    final res = await _client.get('popup', queryParams: {'platform': platform});
    final data = res['data'];
    if (data == null) return null;
    return data is Map ? Map<String, dynamic>.from(data) : null;
  }
}
