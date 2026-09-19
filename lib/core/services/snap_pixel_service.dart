import 'snap_pixel_stub.dart'
    if (dart.library.js) 'snap_pixel_web.dart'
    as platform;

class SnapPixelService {
  static Future<void> init(String pixelId) => platform.init(pixelId);

  static Future<void> track(
    String eventName,
    Map<String, Object?> parameters,
  ) => platform.track(eventName, parameters);
}
