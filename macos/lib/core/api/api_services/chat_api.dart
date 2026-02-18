import 'package:rast/core/api/api_client.dart';

class ChatApi {
  final _client = ApiClient();

  /// إرسال رسالة للشات بوت
  /// POST /api/chat/message
  /// Body: { message, history?: [{ role: "user"|"model", text: "..." }] }
  /// Response: { success, data: { reply, agents_results? } }
  Future<Map<String, dynamic>> sendMessage(
    String message, {
    List<Map<String, String>>? history,
  }) async {
    final body = <String, dynamic>{
      'message': message,
    };
    if (history != null && history.isNotEmpty) {
      body['history'] = history
          .map((e) => {
                'role': e['role'] ?? 'user',
                'text': e['text'] ?? '',
              })
          .toList();
    }
    final res = await _client.post('chat/message', body: body);
    return res['data'] is Map
        ? Map<String, dynamic>.from(res['data'] as Map)
        : <String, dynamic>{'reply': res['reply']?.toString() ?? ''};
  }
}
