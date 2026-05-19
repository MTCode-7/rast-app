import 'dart:math' as math;

/// سطر الموقع في بطاقة المختبر (مدينة | حي) حسب أقرب فرع للمستخدم.
class LabLocationLine {
  const LabLocationLine({required this.city, required this.district});

  final String city;
  final String district;

  String get formatted {
    final c = city.trim();
    final d = district.trim();
    if (c.isEmpty && d.isEmpty) return '';
    if (d.isEmpty) return c;
    if (c.isEmpty) return d;
    return '$c | $d';
  }

  bool get isEmpty => city.trim().isEmpty && district.trim().isEmpty;
}

class LabLocationUtils {
  LabLocationUtils._();

  static int? providerIdFrom(Map<String, dynamic> lab) {
    final id = lab['id'];
    if (id is int) return id;
    return int.tryParse(id?.toString() ?? '');
  }

  /// يختار موقع العرض: أقرب فرع/موقع بإحداثيات عند توفر موقع المستخدم، وإلا موقع المختبر الأساسي.
  /// أقرب مسافة (كم) لأي فرع/موقع للمختبر؛ null إن لا إحداثيات.
  static double? distanceKmToNearest({
    required Map<String, dynamic> lab,
    required double userLat,
    required double userLng,
    List<dynamic>? branches,
  }) {
    final candidates = _collectCandidates(lab, branches);
    double? minKm;
    for (final c in candidates) {
      if (!c.hasCoords) continue;
      final d = haversineKm(userLat, userLng, c.lat!, c.lng!);
      if (minKm == null || d < minKm) minKm = d;
    }
    return minKm;
  }

  static LabLocationLine displayLine({
    required Map<String, dynamic> lab,
    double? userLat,
    double? userLng,
    List<dynamic>? branches,
  }) {
    final candidates = _collectCandidates(lab, branches);
    if (candidates.isEmpty) {
      return LabLocationLine(
        city: lab['city']?.toString() ?? '',
        district: lab['district']?.toString() ?? '',
      );
    }

    if (userLat != null && userLng != null) {
      final withCoords = candidates.where((c) => c.hasCoords).toList();
      if (withCoords.isNotEmpty) {
        withCoords.sort((a, b) {
          final da = haversineKm(userLat, userLng, a.lat!, a.lng!);
          final db = haversineKm(userLat, userLng, b.lat!, b.lng!);
          return da.compareTo(db);
        });
        final best = withCoords.first;
        return LabLocationLine(city: best.city, district: best.district);
      }
    }

    final main = candidates.firstWhere(
      (c) => c.isMain,
      orElse: () => candidates.first,
    );
    return LabLocationLine(city: main.city, district: main.district);
  }

  static double haversineKm(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const earthRadiusKm = 6371.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLng = _degToRad(lng2 - lng1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) *
            math.cos(_degToRad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _degToRad(double degree) => degree * math.pi / 180;

  static List<_Candidate> _collectCandidates(
    Map<String, dynamic> lab,
    List<dynamic>? branches,
  ) {
    final out = <_Candidate>[];

    void add(Map<String, dynamic> map, {required bool isMain}) {
      if (map['is_active'] == false) return;
      final city = _cityFrom(map);
      final district = _districtFrom(map);
      final coords = _readLatLng(map);
      if (!isMain && city.isEmpty && district.isEmpty && coords == null) {
        return;
      }
      out.add(
        _Candidate(
          city: city.isNotEmpty ? city : (isMain ? _cityFrom(lab) : ''),
          district: district.isNotEmpty
              ? district
              : (isMain ? _districtFrom(lab) : ''),
          lat: coords?.$1,
          lng: coords?.$2,
          isMain: isMain,
        ),
      );
    }

    add(lab, isMain: true);

    final branchList = branches ?? lab['branches'];
    if (branchList is List) {
      for (final item in branchList) {
        if (item is Map) {
          add(Map<String, dynamic>.from(item), isMain: false);
        }
      }
    }

    return out;
  }

  static String _cityFrom(Map<String, dynamic> map) =>
      (map['city'] ?? map['branch_city'] ?? map['region_name'] ?? '')
          .toString()
          .trim();

  static String _districtFrom(Map<String, dynamic> map) =>
      (map['district'] ??
              map['branch_district'] ??
              map['neighborhood'] ??
              map['area'] ??
              '')
          .toString()
          .trim();

  static (double, double)? _readLatLng(Map<String, dynamic> map) {
    final lat = _firstDouble(map, const [
      'latitude',
      'lat',
      'location_lat',
      'branch_latitude',
    ]);
    final lng = _firstDouble(map, const [
      'longitude',
      'lng',
      'lon',
      'location_lng',
      'branch_longitude',
    ]);
    if (lat == null || lng == null) return null;
    return (lat, lng);
  }

  static double? _firstDouble(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is num) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }
}

class _Candidate {
  _Candidate({
    required this.city,
    required this.district,
    required this.lat,
    required this.lng,
    required this.isMain,
  });

  final String city;
  final String district;
  final double? lat;
  final double? lng;
  final bool isMain;

  bool get hasCoords => lat != null && lng != null;
}
