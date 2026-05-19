import 'package:rast/core/api/api_client.dart';
import 'package:rast/core/models/region.dart';

/// استجابة صفحة واحدة من الـ API (Paginator داخل `data`).
class PaginatedResponse {
  PaginatedResponse({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    this.total,
  });

  final List<dynamic> items;
  final int currentPage;
  final int lastPage;
  final int? total;

  bool get hasMore => currentPage < lastPage;

  factory PaginatedResponse.fromPayload(dynamic data) {
    if (data is List) {
      return PaginatedResponse(
        items: List<dynamic>.from(data),
        currentPage: 1,
        lastPage: 1,
        total: data.length,
      );
    }
    if (data is Map) {
      final inner = data['data'];
      final items = inner is List ? List<dynamic>.from(inner) : <dynamic>[];
      final cp = _parseIntStatic(data['current_page']) ?? 1;
      final lp = _parseIntStatic(data['last_page']) ?? 1;
      final tot = _parseIntStatic(data['total']);
      return PaginatedResponse(
        items: items,
        currentPage: cp,
        lastPage: lp,
        total: tot,
      );
    }
    return PaginatedResponse(items: [], currentPage: 1, lastPage: 1);
  }
}

int? _parseIntStatic(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

class ProvidersApi {
  final _client = ApiClient();

  List<dynamic> _extractItems(dynamic data) {
    if (data is List) return List.from(data);
    if (data is Map && data['data'] is List) {
      return List.from(data['data'] as List);
    }
    return [];
  }

  /// GET /api/providers - قائمة المختبرات
  /// latitude/longitude لعرض الأقرب أولاً (nearby)
  Future<Map<String, dynamic>> getProviders({
    String? city,
    int? regionId,
    bool? homeService,
    int? serviceId,
    String? sort,
    int page = 1,
    int perPage = 15,
    double? latitude,
    double? longitude,
    int? radiusKm,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'per_page': perPage.toString(),
    };
    if (regionId != null) {
      params['region_id'] = regionId.toString();
    } else {
      if (city != null && city.isNotEmpty) params['city'] = city;
      if (latitude != null) params['latitude'] = latitude.toString();
      if (longitude != null) params['longitude'] = longitude.toString();
      if (radiusKm != null) params['radius'] = radiusKm.toString();
    }
    if (homeService == true) params['home_service'] = '1';
    if (serviceId != null) params['service_id'] = serviceId.toString();
    if (sort != null && sort.isNotEmpty) params['sort'] = sort;
    final res = await _client.get('providers', queryParams: params);
    return res;
  }

  /// GET /api/providers/{id} - تفاصيل مختبر
  Future<Map<String, dynamic>> getProvider(int id) async {
    final res = await _client.get('providers/$id');
    return res['data'] as Map<String, dynamic>;
  }

  /// GET /api/providers/{id}/services — صفحة واحدة (`q` بحث، `sort`: price_asc | price_desc).
  Future<PaginatedResponse> getProviderServicesPage(
    int id, {
    int page = 1,
    int perPage = 20,
    String? q,
    String? sort,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'per_page': perPage.toString(),
    };
    final t = q?.trim();
    if (t != null && t.isNotEmpty) params['q'] = t;
    if (sort != null && sort.isNotEmpty) params['sort'] = sort;
    final res = await _client.get('providers/$id/services', queryParams: params);
    return PaginatedResponse.fromPayload(res['data']);
  }

  /// GET /api/providers/{id}/services — الصفحة الأولى فقط (توافق خلفي).
  Future<List<dynamic>> getProviderServices(int id) async {
    final page = await getProviderServicesPage(id, page: 1, perPage: 50);
    return page.items;
  }

  /// GET /api/providers/{id}/branches - فروع المختبر
  Future<List<dynamic>> getProviderBranches(int id) async {
    final res = await _client.get('providers/$id/branches');
    return _extractItems(res['data']);
  }

  /// GET /api/providers/{id}/time-slots - المواعيد المتاحة
  Future<List<dynamic>> getTimeSlots(int id, String date) async {
    final res = await _client.get('providers/$id/time-slots', queryParams: {'date': date});
    final data = res['data'];
    return data is List ? List.from(data) : [];
  }

  /// GET /api/providers/{id}/reviews — صفحات.
  Future<PaginatedResponse> getReviewsPage(
    int id, {
    int page = 1,
    int perPage = 15,
  }) async {
    try {
      final res = await _client.get(
        'providers/$id/reviews',
        queryParams: {
          'page': page.toString(),
          'per_page': perPage.toString(),
        },
      );
      return PaginatedResponse.fromPayload(res['data']);
    } catch (_) {
      return PaginatedResponse(items: [], currentPage: 1, lastPage: 1);
    }
  }

  /// GET /api/providers/{id}/reviews — الصفحة الأولى فقط (توافق خلفي).
  Future<List<dynamic>> getReviews(int id) async {
    final r = await getReviewsPage(id, page: 1, perPage: 50);
    return r.items;
  }

  /// GET /api/branches - كل الفروع (اختياري: provider_id, city)
  Future<List<dynamic>> getBranches({int? providerId, String? city}) async {
    final page = await getBranchesPage(
      providerId: providerId,
      city: city,
      page: 1,
      perPage: 50,
    );
    return page.items;
  }

  /// GET /api/branches — صفحات (للفهرس الكامل).
  Future<PaginatedResponse> getBranchesPage({
    int page = 1,
    int perPage = 50,
    int? providerId,
    String? city,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'per_page': perPage.toString(),
    };
    if (providerId != null) params['provider_id'] = providerId.toString();
    if (city != null && city.isNotEmpty) params['city'] = city;
    final res = await _client.get('branches', queryParams: params);
    return PaginatedResponse.fromPayload(res['data']);
  }

  /// GET /api/providers/cities — مناطق التطبيق (إحداثيات + نصف قطر).
  Future<List<Region>> getRegions() async {
    final res = await _client.get('providers/cities');
    return _parseRegionsPayload(res['data']);
  }

  /// alias: `GET /api/regions`
  Future<List<Region>> getRegionsAlias() async {
    final res = await _client.get('regions');
    return _parseRegionsPayload(res['data']);
  }

  List<Region> _parseRegionsPayload(dynamic data) {
    final list = data is List
        ? data
        : (data is Map && data['data'] is List ? data['data'] as List : const []);
    final regions = <Region>[];
    for (final e in list) {
      if (e is Map) {
        final region = Region.fromJson(Map<String, dynamic>.from(e));
        if (region.id > 0) regions.add(region);
      }
    }
    regions.sort((a, b) => a.nameAr.compareTo(b.nameAr));
    return regions;
  }

  @Deprecated('Use getRegions() — returns Region objects with region_id')
  Future<List<String>> getCities() async {
    final regions = await getRegions();
    return regions.map((r) => r.nameAr).where((n) => n.isNotEmpty).toList();
  }
}
