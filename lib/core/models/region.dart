import 'package:rast/core/utils/locale_utils.dart';

/// منطقة تطبيق (مدينة/نطاق جغرافي) من `GET /api/providers/cities`.
class Region {
  const Region({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.latitude,
    required this.longitude,
    required this.radiusKm,
  });

  final int id;
  final String nameAr;
  final String nameEn;
  final double latitude;
  final double longitude;
  final double radiusKm;

  String displayName(bool isArabic) => LocaleUtils.localizedName(
        {'name_ar': nameAr, 'name_en': nameEn},
        isArabic,
        arKey: 'name_ar',
        enKey: 'name_en',
      );

  factory Region.fromJson(Map<String, dynamic> json) {
    return Region(
      id: _parseInt(json['id']) ?? 0,
      nameAr: json['name_ar']?.toString().trim() ?? '',
      nameEn: json['name_en']?.toString().trim() ?? '',
      latitude: _parseDouble(json['latitude']) ?? 0,
      longitude: _parseDouble(json['longitude']) ?? 0,
      radiusKm: _parseDouble(json['radius_km']) ?? 0,
    );
  }

  static int? _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static double? _parseDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }
}
