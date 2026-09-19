import 'dart:convert';
import 'dart:js_interop';

Future<void> init(String pixelId) async {
  _initPixel(pixelId);
}

Future<void> track(String eventName, Map<String, Object?> parameters) async {
  _trackPixel(eventName, jsonEncode(parameters));
}

@JS('rastSnapPixelInit')
external void _initPixel(String pixelId);

@JS('rastSnapPixelTrack')
external void _trackPixel(String eventName, String parametersJson);
