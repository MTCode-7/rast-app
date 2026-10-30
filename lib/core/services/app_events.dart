import 'package:flutter/foundation.dart';

/// إشارات بسيطة بين الشاشات: صفحة الحجوزات تبقى حيّة داخل التبويبات (IndexedStack)
/// فلا تُعاد بناؤها، لذا نخبرها صراحة متى تغيّرت الحجوزات.
class AppEvents {
  AppEvents._();

  /// يزيد بعد إنشاء حجز، أو دفع، أو إلغاء، أو وصول إشعار حجز، أو تسجيل الدخول.
  static final ValueNotifier<int> bookingsChanged = ValueNotifier<int>(0);

  static void notifyBookingsChanged() => bookingsChanged.value++;

  /// يزيد عند تغيير المدينة/الموقع المعتمد (من محدد المدينة أو عناويني):
  /// الرئيسية والمختبرات والخريطة تعيد الترتيب حسب الموقع الجديد.
  static final ValueNotifier<int> locationChanged = ValueNotifier<int>(0);

  static void notifyLocationChanged() => locationChanged.value++;

  /// يزيد عند وصول إشعار جديد أو قراءة الإشعارات: يحدّث عدّاد الجرس في «حسابي»
  static final ValueNotifier<int> notificationsChanged = ValueNotifier<int>(0);

  static void notifyNotificationsChanged() => notificationsChanged.value++;
}
