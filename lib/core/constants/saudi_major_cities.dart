/// مدن رئيسية في السعودية للفلترة (قائمة ثابتة + أي مدن إضافية من الـ API عند الحاجة).
class SaudiMajorCities {
  SaudiMajorCities._();

  static const List<String> names = [
    'الرياض',
    'جدة',
    'مكة المكرمة',
    'المدينة المنورة',
    'الدمام',
    'الخبر',
    'الظهران',
    'القطيف',
    'بريدة',
    'عنيزة',
    'تبوك',
    'حائل',
    'أبها',
    'خميس مشيط',
    'نجران',
    'جازان',
    'ينبع',
    'الأحساء',
    'الجبيل',
    'رابغ',
    'الطائف',
    'الباحة',
    'عرعر',
    'سكاكا',
    'القريات',
  ];

  /// بدون تكرار مع الحفاظ على ترتيب معقول
  static List<String> uniqueSorted() {
    final set = <String>{};
    final out = <String>[];
    for (final c in names) {
      final t = c.trim();
      if (t.isEmpty || set.contains(t)) continue;
      set.add(t);
      out.add(t);
    }
    return out;
  }
}
