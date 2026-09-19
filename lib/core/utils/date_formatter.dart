import 'package:intl/intl.dart';

/// تنسيق التواريخ بشكل طبيعي للعرض
class DateFormatter {
  static const List<String> _arMonths = [
    'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
  ];

  /// تنسيق DateTime للعرض - مثل "12 فبراير 2024"
  static String formatDate(DateTime date) {
    return '${date.day} ${_arMonths[date.month - 1]} ${date.year}';
  }

  /// تنسيق تاريخ الحجز للعرض - مثل "12 فبراير 2024"
  static String formatBookingDate(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return '';
    final parsed = _tryParse(dateStr.trim());
    if (parsed == null) return _cleanRawDate(dateStr);
    return '${parsed.day} ${_arMonths[parsed.month - 1]} ${parsed.year}';
  }

  /// تنسيق الوقت للعرض - مثل "09:00"
  static String formatBookingTime(String? timeStr) {
    if (timeStr == null || timeStr.trim().isEmpty) return '';
    final s = timeStr.trim();
    if (RegExp(r'^\d{1,2}:\d{2}').hasMatch(s)) {
      final parts = s.split(':');
      final h = parts[0].padLeft(2, '0');
      final m = parts.length > 1 ? parts[1].substring(0, 2) : '00';
      return '$h:$m';
    }
    return s;
  }

  static DateTime? _tryParse(String s) {
    final patterns = [
      'yyyy-MM-dd',
      'yyyy-MM-ddTHH:mm:ss',
      'yyyy-MM-ddTHH:mm:ss.SSS',
      'yyyy-MM-ddTHH:mm:ss.SSSZ',
      'yyyy-MM-dd HH:mm:ss',
      'yyyy/MM/dd',
      'dd/MM/yyyy',
    ];
    for (final p in patterns) {
      try {
        return DateFormat(p).parse(s);
      } catch (_) {}
    }
    try {
      return DateTime.parse(s);
    } catch (_) {}
    return null;
  }

  static String _cleanRawDate(String s) {
    if (s.length > 10 && s.contains('T')) return s.substring(0, 10);
    return s;
  }
}
