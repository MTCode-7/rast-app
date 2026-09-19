import 'package:rast/core/api/api_client.dart';

class CartApi {
  final _client = ApiClient();

  /// GET /api/cart
  Future<Map<String, dynamic>> getCart() async {
    final res = await _client.get('cart');
    final data = res['data'];
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  /// POST /api/cart/items
  Future<Map<String, dynamic>> addItem(Map<String, dynamic> body) async {
    final res = await _client.post('cart/items', body: body);
    final data = res['data'];
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  /// DELETE /api/cart/items/{id}
  Future<Map<String, dynamic>> removeItem(int itemId) async {
    final res = await _client.delete('cart/items/$itemId');
    final data = res['data'];
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  /// DELETE /api/cart
  Future<Map<String, dynamic>> clearCart() async {
    final res = await _client.delete('cart');
    final data = res['data'];
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  /// POST /api/cart/checkout
  Future<Map<String, dynamic>> checkout({String? nationality}) async {
    final body = nationality != null ? {'nationality': nationality} : null;
    final res = await _client.post('cart/checkout', body: body);
    final data = res['data'];
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  /// GET /api/cart-orders/{id}
  Future<Map<String, dynamic>> getCartOrder(int cartOrderId) async {
    final res = await _client.get('cart-orders/$cartOrderId');
    final data = res['data'];
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  /// POST /api/cart-orders/{id}/payment/session
  Future<Map<String, dynamic>> createPaymentSession(
    int cartOrderId, {
    String? returnUrl,
  }) async {
    final body = returnUrl != null ? {'return_url': returnUrl} : null;
    final res = await _client.post(
      'cart-orders/$cartOrderId/payment/session',
      body: body,
    );
    return res;
  }

  /// GET /api/cart-orders/{id}/payment/status
  Future<Map<String, dynamic>> getPaymentStatus(int cartOrderId) async {
    final res = await _client.get('cart-orders/$cartOrderId/payment/status');
    final data = res['data'];
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }
}
