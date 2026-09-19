import 'package:rast/core/api/api_client.dart';

class ProvidersApi {
  final _client = ApiClient();

  /// GET /api/providers - قائمة المختبرات
  /// latitude/longitude لعرض الأقرب أولاً (nearby)
  Future<Map<String, dynamic>> getProviders({
    String? city,
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
    if (city != null && city.isNotEmpty) params['city'] = city;
    if (homeService == true) params['home_service'] = '1';
    if (serviceId != null) params['service_id'] = serviceId.toString();
    if (sort != null && sort.isNotEmpty) params['sort'] = sort;
    if (latitude != null) params['latitude'] = latitude.toString();
    if (longitude != null) params['longitude'] = longitude.toString();
    if (radiusKm != null) params['radius'] = radiusKm.toString();
    final res = await _client.get('providers', queryParams: params);
    return res;
  }

  /// GET /api/providers/{id} - تفاصيل مختبر
  Future<Map<String, dynamic>> getProvider(int id) async {
    final res = await _client.get('providers/$id');
    return res['data'] as Map<String, dynamic>;
  }

  /// GET /api/providers/{id}/services - خدمات المختبر
  Future<List<dynamic>> getProviderServices(int id) async {
    final res = await _client.get('providers/$id/services');
    final data = res['data'];
    return data is List ? List.from(data) : [];
  }

  /// GET /api/providers/{id}/branches - فروع المختبر
  Future<List<dynamic>> getProviderBranches(int id) async {
    final res = await _client.get('providers/$id/branches');
    final data = res['data'];
    return data is List ? List.from(data) : [];
  }

  /// GET /api/providers/{id}/time-slots - المواعيد المتاحة
  Future<List<dynamic>> getTimeSlots(int id, String date) async {
    final res = await _client.get('providers/$id/time-slots', queryParams: {'date': date});
    final data = res['data'];
    return data is List ? List.from(data) : [];
  }

  /// GET /api/providers/{id}/reviews - التقييمات
  Future<List<dynamic>> getReviews(int id) async {
    try {
      final res = await _client.get('providers/$id/reviews');
      final data = res['data'];
      return data is List ? List.from(data) : [];
    } catch (_) {
      return [];
    }
  }

  /// GET /api/branches - كل الفروع (اختياري: provider_id, city)
  Future<List<dynamic>> getBranches({int? providerId, String? city}) async {
    final params = <String, String>{};
    if (providerId != null) params['provider_id'] = providerId.toString();
    if (city != null) params['city'] = city;
    final res = await _client.get('branches', queryParams: params.isEmpty ? null : params);
    final data = res['data'];
    return data is List ? List.from(data) : [];
  }
}
