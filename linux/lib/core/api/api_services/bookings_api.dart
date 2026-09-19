import 'package:rast/core/api/api_client.dart';

class BookingsApi {
  final _client = ApiClient();

  /// GET /api/bookings - كل الحجوزات
  Future<Map<String, dynamic>> getBookings({int page = 1}) async {
    final res = await _client.get('bookings', queryParams: {'page': page.toString()});
    return res;
  }

  /// GET /api/bookings/upcoming - الحجوزات القادمة
  Future<List<dynamic>> getUpcoming() async {
    final res = await _client.get('bookings/upcoming');
    final data = res['data'];
    return data is List ? List.from(data) : [];
  }

  /// GET /api/bookings/past - الحجوزات السابقة
  Future<Map<String, dynamic>> getPast({int page = 1}) async {
    final res = await _client.get('bookings/past', queryParams: {'page': page.toString()});
    return res;
  }

  /// GET /api/bookings/{id} - تفاصيل حجز
  Future<Map<String, dynamic>> getBooking(int id) async {
    final res = await _client.get('bookings/$id');
    return res['data'] as Map<String, dynamic>;
  }

  /// POST /api/bookings - إنشاء حجز
  Future<Map<String, dynamic>> create(Map<String, dynamic> body) async {
    final res = await _client.post('bookings', body: body);
    return res['data'] as Map<String, dynamic>;
  }

  /// POST /api/bookings/{id}/cancel - إلغاء حجز
  Future<Map<String, dynamic>> cancel(int id, String reason) async {
    final res = await _client.post('bookings/$id/cancel', body: {'reason': reason});
    return res['data'] as Map<String, dynamic>;
  }

  /// POST /api/bookings/{id}/payment/session - إنشاء جلسة دفع (رابط الدفع)
  Future<Map<String, dynamic>> createPaymentSession(int bookingId, {String? returnUrl}) async {
    final body = returnUrl != null ? {'return_url': returnUrl} : null;
    final res = await _client.post('bookings/$bookingId/payment/session', body: body);
    return res;
  }

  /// GET /api/bookings/{id}/payment/status - حالة الدفع
  Future<Map<String, dynamic>> getPaymentStatus(int bookingId) async {
    final res = await _client.get('bookings/$bookingId/payment/status');
    return res['data'] as Map<String, dynamic>;
  }
}
