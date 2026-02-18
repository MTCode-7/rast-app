/// مساعد لاختيار النص حسب لغة التطبيق (العربية أو الإنجليزية)
class LocaleUtils {
  /// يُرجع الاسم المناسب للغة الحالية.
  /// [map] خريطة البيانات (من الـ API)
  /// [isArabic] true للعربية، false للإنجليزية
  /// [arKey] مفتاح النص العربي (افتراضي: name_ar)
  /// [enKey] مفتاح النص الإنجليزي (افتراضي: name_en)
  static String localizedName(
    Map<String, dynamic>? map,
    bool isArabic, {
    String arKey = 'name_ar',
    String enKey = 'name_en',
  }) {
    if (map == null) return '';
    final ar = map[arKey]?.toString().trim() ?? '';
    final en = map[enKey]?.toString().trim() ?? '';
    if (isArabic) return ar.isNotEmpty ? ar : en;
    return en.isNotEmpty ? en : ar;
  }

  /// اسم المختبر (business_name_ar / business_name_en)
  static String localizedBusinessName(Map<String, dynamic>? map, bool isArabic) {
    return localizedName(map, isArabic, arKey: 'business_name_ar', enKey: 'business_name_en');
  }
}
