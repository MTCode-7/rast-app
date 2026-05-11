import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// خدمة حفظ واسترجاع الموقع الافتراضي للمستخدم (للعثور على المختبرات القريبة)
class LocationService {
  static const _keyLat = 'user_default_lat';
  static const _keyLng = 'user_default_lng';
  static const _keyLabel = 'user_default_location_label';

  static Future<void> setDefaultLocation({
    required double latitude,
    required double longitude,
    String? label,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyLat, latitude);
    await prefs.setDouble(_keyLng, longitude);
    if (label != null) {
      await prefs.setString(_keyLabel, label);
    }
  }

  static Future<({double lat, double lng, String? label})?> getCurrentLocation({
    bool saveAsDefault = true,
  }) async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }
    if (!await Geolocator.isLocationServiceEnabled()) return null;

    final position = await Geolocator.getCurrentPosition();
    const label = 'موقعي الحالي';
    if (saveAsDefault) {
      await setDefaultLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        label: label,
      );
    }
    return (lat: position.latitude, lng: position.longitude, label: label);
  }

  static Future<void> clearDefaultLocation() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyLat);
    await prefs.remove(_keyLng);
    await prefs.remove(_keyLabel);
  }

  static Future<({double lat, double lng, String? label})?> getDefaultLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble(_keyLat);
    final lng = prefs.getDouble(_keyLng);
    if (lat == null || lng == null) return null;
    final label = prefs.getString(_keyLabel);
    return (lat: lat, lng: lng, label: label);
  }

  static Future<bool> hasDefaultLocation() async {
    final loc = await getDefaultLocation();
    return loc != null;
  }
}
