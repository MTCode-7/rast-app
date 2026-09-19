import 'dart:math' as math;

import 'package:rast/core/utils/locale_utils.dart';

/// أقرب فرع/موقع لمختبر (للعرض والحجز).
class NearestBranchInfo {
  const NearestBranchInfo({
    this.branchId,
    required this.nameAr,
    required this.nameEn,
    required this.city,
    required this.district,
    this.distanceKm,
    this.isMainProvider = false,
  });

  final int? branchId;
  final String nameAr;
  final String nameEn;
  final String city;
  final String district;
  final double? distanceKm;
  final bool isMainProvider;

  String displayLine(bool isArabic) {
    final name = LocaleUtils.localizedName(
      {'name_ar': nameAr, 'name_en': nameEn},
      isArabic,
    );
    final loc = LabLocationLine(city: city, district: district).formatted;
    if (name.isNotEmpty && loc.isNotEmpty) return '$name · $loc';
    if (name.isNotEmpty) return name;
    return loc;
  }

  bool get hasBranchId => branchId != null && branchId! > 0;
}

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

  /// من `GET /api/providers` عند إرسال GPS أو `region_id`.
  static NearestBranchInfo? nearestFromApi(Map<String, dynamic> lab) {
    final raw = lab['nearest_branch'];
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final id = m['id'];
    final branchId = id is int ? id : int.tryParse(id?.toString() ?? '');
    return NearestBranchInfo(
      branchId: branchId,
      nameAr: m['name_ar']?.toString() ?? '',
      nameEn: m['name_en']?.toString() ?? '',
      city: m['city']?.toString() ?? '',
      district: m['district']?.toString() ?? '',
      distanceKm: m['distance_km'] is num
          ? (m['distance_km'] as num).toDouble()
          : double.tryParse(m['distance_km']?.toString() ?? ''),
      isMainProvider: false,
    );
  }

  /// أقرب فرع للعرض/الحجز: API أولاً ثم حساب محلي.
  static NearestBranchInfo? resolveForDisplay({
    required Map<String, dynamic> lab,
    double? userLat,
    double? userLng,
    List<dynamic>? branches,
  }) {
    final fromApi = nearestFromApi(lab);
    if (fromApi != null && (fromApi.hasBranchId || fromApi.city.isNotEmpty)) {
      return fromApi;
    }
    return resolveNearest(
      lab: lab,
      userLat: userLat,
      userLng: userLng,
      branches: branches,
    );
  }

  static NearestBranchInfo? resolveNearest({
    required Map<String, dynamic> lab,
    double? userLat,
    double? userLng,
    List<dynamic>? branches,
  }) {
    final candidates = _collectCandidates(lab, branches);
    if (candidates.isEmpty) {
      final city = lab['city']?.toString() ?? '';
      final district = lab['district']?.toString() ?? '';
      if (city.isEmpty && district.isEmpty) return null;
      return NearestBranchInfo(
        nameAr: lab['business_name_ar']?.toString() ?? '',
        nameEn: lab['business_name_en']?.toString() ?? '',
        city: city,
        district: district,
        isMainProvider: true,
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
        return _toInfo(withCoords.first, userLat, userLng);
      }
    }

    final main = candidates.firstWhere(
      (c) => c.isMain,
      orElse: () => candidates.first,
    );
    return _toInfo(main, userLat, userLng);
  }

  static NearestBranchInfo _toInfo(
    _Candidate c,
    double? userLat,
    double? userLng,
  ) {
    double? dist;
    if (userLat != null && userLng != null && c.hasCoords) {
      dist = haversineKm(userLat, userLng, c.lat!, c.lng!);
    }
    return NearestBranchInfo(
      branchId: c.branchId,
      nameAr: c.nameAr,
      nameEn: c.nameEn,
      city: c.city,
      district: c.district,
      distanceKm: dist,
      isMainProvider: c.isMain && c.branchId == null,
    );
  }

  static LabLocationLine displayLine({
    required Map<String, dynamic> lab,
    double? userLat,
    double? userLng,
    List<dynamic>? branches,
    bool isArabic = true,
  }) {
    final nearest = resolveNearest(
      lab: lab,
      userLat: userLat,
      userLng: userLng,
      branches: branches,
    );
    if (nearest == null) {
      return LabLocationLine(
        city: lab['city']?.toString() ?? '',
        district: lab['district']?.toString() ?? '',
      );
    }
    final text = nearest.displayLine(isArabic);
    if (text.isEmpty) {
      return LabLocationLine(city: nearest.city, district: nearest.district);
    }
    // للتوافق مع LabLocationLine نفصل city|district؛ العرض الكامل عبر displayText
    return LabLocationLine(city: nearest.city, district: nearest.district);
  }

  /// نص العرض الكامل (اسم الفرع · مدينة | حي).
  static String displayText({
    required Map<String, dynamic> lab,
    double? userLat,
    double? userLng,
    List<dynamic>? branches,
    required bool isArabic,
  }) {
    final nearest = resolveForDisplay(
      lab: lab,
      userLat: userLat,
      userLng: userLng,
      branches: branches,
    );
    if (nearest == null) {
      return LabLocationLine(
        city: lab['city']?.toString() ?? '',
        district: lab['district']?.toString() ?? '',
      ).formatted;
    }
    return nearest.displayLine(isArabic);
  }

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
          branchId: isMain ? null : _branchIdFrom(map),
          nameAr: _nameArFrom(map, isMain: isMain, lab: lab),
          nameEn: _nameEnFrom(map, isMain: isMain, lab: lab),
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

  static int? _branchIdFrom(Map<String, dynamic> map) {
    final id = map['id'] ?? map['branch_id'];
    if (id is int) return id;
    return int.tryParse(id?.toString() ?? '');
  }

  static String _nameArFrom(
    Map<String, dynamic> map, {
    required bool isMain,
    required Map<String, dynamic> lab,
  }) =>
      (map['name_ar'] ??
              map['branch_name_ar'] ??
              map['branch_name'] ??
              (isMain ? lab['business_name_ar'] : null) ??
              '')
          .toString()
          .trim();

  static String _nameEnFrom(
    Map<String, dynamic> map, {
    required bool isMain,
    required Map<String, dynamic> lab,
  }) =>
      (map['name_en'] ??
              map['branch_name_en'] ??
              (isMain ? lab['business_name_en'] : null) ??
              '')
          .toString()
          .trim();

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
    required this.branchId,
    required this.nameAr,
    required this.nameEn,
    required this.city,
    required this.district,
    required this.lat,
    required this.lng,
    required this.isMain,
  });

  final int? branchId;
  final String nameAr;
  final String nameEn;
  final String city;
  final String district;
  final double? lat;
  final double? lng;
  final bool isMain;

  bool get hasCoords => lat != null && lng != null;
}
