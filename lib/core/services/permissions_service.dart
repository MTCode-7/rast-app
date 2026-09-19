import 'package:geolocator/geolocator.dart';

/// خدمة طلب الصلاحيات المطلوبة (الموقع، إلخ)
class PermissionsService {
  /// طلب صلاحيات الموقع عند بدء التطبيق
  static Future<void> requestLocationPermission() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
    } catch (_) {}
  }

  /// التحقق من حالة صلاحية الموقع
  static Future<LocationPermission> get locationPermission => Geolocator.checkPermission();

  /// هل خدمات الموقع مفعّلة؟
  static Future<bool> get isLocationServiceEnabled => Geolocator.isLocationServiceEnabled();
}
