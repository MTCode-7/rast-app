import 'package:rast/core/api/api_client.dart';

class ServicesApi {
  final _client = ApiClient();

  /// GET /api/services/categories - فئات التحاليل
  Future<List<dynamic>> getCategories() async {
    final res = await _client.get('services/categories');
    final data = res['data'];
    return data is List ? List.from(data) : [];
  }

  /// GET /api/services - قائمة التحاليل (اختياري: category_id, search, per_page)
  Future<Map<String, dynamic>> getServices({
    int? categoryId,
    String? search,
    int page = 1,
    int? perPage,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
    };
    if (perPage != null) params['per_page'] = perPage.toString();
    if (categoryId != null) params['category_id'] = categoryId.toString();
    if (search != null && search.isNotEmpty) params['search'] = search;
    final res = await _client.get('services', queryParams: params);
    return res;
  }

  /// يجمع كل صفحات GET /api/services لأن الخادم يستخدم pagination.
  Future<List<dynamic>> getAllServices({
    int? categoryId,
    String? search,
    int perPage = 100,
  }) async {
    final all = <dynamic>[];
    var page = 1;
    while (true) {
      final res = await getServices(
        categoryId: categoryId,
        search: search,
        page: page,
        perPage: perPage,
      );
      final data = res['data'];
      if (data is Map<String, dynamic>) {
        final items = data['data'];
        if (items is List) all.addAll(List.from(items));
        final lp = data['last_page'];
        final lastPage = lp is int ? lp : int.tryParse(lp?.toString() ?? '') ?? 1;
        if (page >= lastPage) break;
        page++;
      } else if (data is List) {
        all.addAll(List.from(data));
        break;
      } else {
        break;
      }
    }
    return all;
  }

  /// GET /api/services/{id} - تفاصيل تحليل
  Future<Map<String, dynamic>> getService(int id) async {
    final res = await _client.get('services/$id');
    return res['data'] as Map<String, dynamic>;
  }

  /// GET /api/services/category/{slug} - تحاليل حسب الفئة
  Future<Map<String, dynamic>> getByCategory(String slug) async {
    final res = await _client.get('services/category/$slug');
    return res['data'] as Map<String, dynamic>;
  }

  /// GET /api/services/{id} - تفاصيل باقة/تحليل (الباقات هي خدمات من نوع package)
  Future<Map<String, dynamic>> getPackage(int id) async {
    final res = await _client.get('services/$id');
    return res['data'] is Map ? res['data'] as Map<String, dynamic> : {};
  }

  /// GET /api/packages - الباقات
  Future<Map<String, dynamic>> getPackages({int? categoryId, int page = 1, int perPage = 20}) async {
    final params = <String, String>{
      'page': page.toString(),
      'per_page': perPage.toString(),
    };
    if (categoryId != null) params['category_id'] = categoryId.toString();
    final res = await _client.get('packages', queryParams: params);
    return res;
  }

  /// GET /api/offers - العروض
  Future<Map<String, dynamic>> getOffers({int? providerId, int page = 1}) async {
    final params = <String, String>{
      'page': page.toString(),
    };
    if (providerId != null) params['provider_id'] = providerId.toString();
    final res = await _client.get('offers', queryParams: params);
    return res;
  }
}
