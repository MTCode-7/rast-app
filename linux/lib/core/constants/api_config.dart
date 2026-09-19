/// إعدادات الـ API - غيّر الرابط وفقاً لسيرفرك
class ApiConfig {
  /// اختر الرابط المناسب لبيئتك:
  static const String baseUrl = 'https://rast-labs.com/api';

  /// رابط قاعدة التخزين للصور (مجلد storage) - مثلاً: https://rast.sa
  static const String storageBaseUrl = 'https://rast.sa';

  // للتطوير المحلي - أندرويد Emulator:
  // static const String baseUrl = 'http://10.0.2.2:8000/api';

  // للتطوير المحلي - جهاز حقيقي (استبدل IP بموقعك):
  // static const String baseUrl = 'http://192.168.1.100:8000/api';

  static String get apiBaseUrl => baseUrl;

  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  /// تحويل مسار الصورة من قاعدة البيانات إلى رابط كامل.
  /// إذا كان image_url أو image يحتوي على رابط كامل (يبدأ بـ http) يُعاد كما هو.
  /// وإلا يُعاد: storageBaseUrl/storage/المسار
  static String? resolveImageUrl(Object? imageUrl, [Object? image]) {
    final url = imageUrl?.toString().trim();
    if (url != null && url.isNotEmpty) {
      if (url.startsWith('http://') || url.startsWith('https://') || url.startsWith('//')) {
        return url;
      }
      return '$storageBaseUrl/storage/$url';
    }
    final path = image?.toString().trim();
    if (path != null && path.isNotEmpty) {
      if (path.startsWith('http://') || path.startsWith('https://') || path.startsWith('//')) {
        return path;
      }
      return '$storageBaseUrl/storage/$path';
    }
    return null;
  }
}
