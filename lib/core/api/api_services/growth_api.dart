import 'package:rast/core/api/api_client.dart';

/// واجهات مزايا النمو: خريطة المختبرات، العروض، عناويني، نقاط الولاء، والبحث عن العناوين.
class GrowthApi {
  final _client = ApiClient();

  List<Map<String, dynamic>> _list(dynamic data) =>
      data is List ? data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : <Map<String, dynamic>>[];

  /// GET /api/map/labs — دبابيس الفروع مع ملخص المختبر (السعر، التقييم، مفتوح الآن، عرض)
  Future<List<Map<String, dynamic>>> mapLabs({
    int? serviceId,
    bool homeService = false,
    bool hasOffer = false,
    double? minRating,
    String? query,
  }) async {
    final res = await _client.get('map/labs', queryParams: {
      if (serviceId != null) 'service_id': '$serviceId',
      if (homeService) 'home_service': '1',
      if (hasOffer) 'has_offer': '1',
      if (minRating != null) 'min_rating': '$minRating',
      if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
    });
    return _list(res['data']);
  }

  /// GET /api/offers — صفحة من العروض الفعّالة (data.data + current_page/last_page)
  Future<Map<String, dynamic>> offers({int page = 1, int? providerId, bool featured = false, String? city}) async {
    final res = await _client.get('offers', queryParams: {
      'page': '$page',
      if (providerId != null) 'provider_id': '$providerId',
      if (featured) 'featured': '1',
      if (city != null && city.isNotEmpty) 'city': city,
    });
    final data = res['data'];
    return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{'data': const []};
  }

  /// GET /api/offers/{id}
  Future<Map<String, dynamic>> offer(int id) async {
    final res = await _client.get('offers/$id');
    final data = res['data'];
    return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
  }

  /// GET /api/addresses
  Future<List<Map<String, dynamic>>> addresses() async => _list((await _client.get('addresses'))['data']);

  /// POST /api/addresses {label, city, district, address_line, latitude, longitude, notes, is_default}
  Future<Map<String, dynamic>> createAddress(Map<String, dynamic> body) async {
    final res = await _client.post('addresses', body: body);
    return res['data'] is Map ? Map<String, dynamic>.from(res['data']) : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> updateAddress(int id, Map<String, dynamic> body) async {
    final res = await _client.put('addresses/$id', body: body);
    return res['data'] is Map ? Map<String, dynamic>.from(res['data']) : <String, dynamic>{};
  }

  Future<void> deleteAddress(int id) async => _client.delete('addresses/$id');

  /// GET /api/geocode?q= أو ?lat=&lng= → [{address, city, district, latitude, longitude}]
  Future<List<Map<String, dynamic>>> geocode({String? query, double? lat, double? lng, String lang = 'ar'}) async {
    final res = await _client.get('geocode', queryParams: {
      'lang': lang,
      if (query != null) 'q': query,
      if (lat != null) 'lat': '$lat',
      if (lng != null) 'lng': '$lng',
    });
    return _list(res['data']);
  }

  /// GET /api/notifications — {data:[{id,kind,type,title,body,booking_id,created_at,read}], current_page, last_page, unread_count}
  Future<Map<String, dynamic>> notifications({int page = 1}) async {
    final res = await _client.get('notifications', queryParams: {'page': '$page'});
    return res['data'] is Map ? Map<String, dynamic>.from(res['data']) : <String, dynamic>{'data': const []};
  }

  /// GET /api/notifications/unread-count
  Future<int> unreadNotificationsCount() async {
    final res = await _client.get('notifications/unread-count');
    final data = res['data'];
    final v = data is Map ? data['unread_count'] : null;
    return v is num ? v.toInt() : int.tryParse('$v') ?? 0;
  }

  /// POST /api/notifications/read-all
  Future<void> markAllNotificationsRead() async => _client.post('notifications/read-all');

  /// POST /api/notifications/{id}/read
  Future<void> markNotificationRead(String id) async => _client.post('notifications/$id/read');

  /// GET /api/loyalty — الرصيد، المستوى، كود الدعوة، القواعد، والحركات (transactions.data)
  Future<Map<String, dynamic>> loyalty({String lang = 'ar'}) async {
    final res = await _client.get('loyalty', queryParams: {'lang': lang});
    return res['data'] is Map ? Map<String, dynamic>.from(res['data']) : <String, dynamic>{};
  }
}
