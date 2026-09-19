/// إعدادات الـ API - غيّر الرابط وفقاً لسيرفرك
class ApiConfig {
  /// خصم افتراضي عند عدم توفر booking من API (يُستبدل بـ platform_discount_rate من GET /api/config)
  static const int globalDiscountPercent = 7;
  static double get globalDiscountMultiplier => 1.0 - (globalDiscountPercent / 100);

  /// اختر الرابط المناسب لبيئتك:
  static const String baseUrl = 'https://rast-labs.com/api';

  /// رابط قاعدة التخزين للصور (نفس الدومين: الصور تُبنى كـ storageBaseUrl/storage/المسار)
  /// مثال: مسار "provider_services/xxx.jpg" → https://rast-labs.com/storage/provider_services/xxx.jpg
  static const String storageBaseUrl = 'https://rast-labs.com';

  // للتطوير المحلي - أندرويد Emulator:
  // static const String baseUrl = 'http://10.0.2.2:8000/api';

  // للتطوير المحلي - جهاز حقيقي (استبدل IP بموقعك):
  // static const String baseUrl = 'http://192.168.1.100:8000/api';

  static String get apiBaseUrl => baseUrl;

  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  /// تحويل مسار الصورة من قاعدة البيانات إلى رابط كامل.
  /// إذا كان image_url أو image يحتوي على رابط كامل (يبدأ بـ http) يُعاد كما هو.
  /// وإلا: مسار مثل "provider_services/xxx.jpg" → storageBaseUrl/storage/provider_services/xxx.jpg
  static String? resolveImageUrl(Object? imageUrl, [Object? image]) {
    String? path = imageUrl?.toString().trim();
    if (path == null || path.isEmpty) path = image?.toString().trim();
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http://') || path.startsWith('https://') || path.startsWith('//')) {
      return path;
    }
    String normalized = path;
    if (!normalized.startsWith('storage/')) {
      normalized = 'storage/${normalized.startsWith('/') ? normalized.substring(1) : normalized}';
    }
    return '$storageBaseUrl/$normalized';
  }

  /// استخراج رابط صورة من خريطة (يدعم عدة مفاتيح: image_url, image, image_path, cover, photo, thumbnail, logo_url, logo)
  static String? imageFromMap(Map<String, dynamic>? map) {
    if (map == null) return null;
    final tried = [
      resolveImageUrl(map['image_url'], map['image']),
      resolveImageUrl(map['image_path'], null),
      resolveImageUrl(map['cover'], null),
      resolveImageUrl(map['photo'], null),
      resolveImageUrl(map['picture'], null),
      resolveImageUrl(map['thumbnail'], null),
      resolveImageUrl(map['logo_url'], map['logo']),
    ];
    for (final r in tried) {
      if (r != null && r.isNotEmpty) return r;
    }
    return null;
  }

  /// استخراج رابط صورة الباقة (يتحقق من provider_services عند عدم وجود صورة على الباقة)
  static String? packageImageUrl(Map<String, dynamic>? pkg) {
    final url = imageFromMap(pkg) ?? resolveImageUrl(pkg?['image_url'], pkg?['image'] ?? pkg?['image_path']);
    if (url != null && url.isNotEmpty) return url;
    final psList = pkg?['provider_services'] ?? pkg?['providerServices'];
    if (psList is List && psList.isNotEmpty) {
      final first = psList.first;
      if (first is Map<String, dynamic>) {
        return imageFromMap(first) ?? resolveImageUrl(first['image_url'], first['image'] ?? first['image_path']);
      }
    }
    return null;
  }

  /// استخراج رابط صورة التحليل (يتحقق من provider_service عند عرض من مختبر)
  static String? analysisImageUrl(Map<String, dynamic>? service, [Map<String, dynamic>? providerService]) {
    var url = imageFromMap(service) ?? resolveImageUrl(service?['image_url'], service?['image'] ?? service?['image_path'] ?? service?['thumbnail']);
    if (url != null && url.isNotEmpty) return url;
    if (providerService != null) {
      return imageFromMap(providerService) ?? resolveImageUrl(providerService['image_url'], providerService['image'] ?? providerService['image_path']);
    }
    return null;
  }

  /// استخراج السعر من خريطة (يدعم: price, final_price, base_price، ويقبل عدداً أو نصاً)
  static double priceFromMap(Map<String, dynamic>? map) {
    if (map == null) return 0.0;
    final keys = ['price', 'final_price', 'base_price', 'sale_price'];
    for (final k in keys) {
      final v = map[k];
      if (v == null) continue;
      if (v is num) return v.toDouble();
      if (v is String) {
        final parsed = double.tryParse(v.trim());
        if (parsed != null) return parsed;
      }
    }
    return 0.0;
  }
}
