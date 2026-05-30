import 'package:shared_preferences/shared_preferences.dart';
import 'package:rast/core/onboarding/onboarding_tour_ids.dart';

class OnboardingService {
  OnboardingService._();

  static String _key(String tourId) => 'onboarding_seen_$tourId';

  static Future<bool> shouldShow(String tourId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key(tourId)) != true;
  }

  static Future<void> markSeen(String tourId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key(tourId), true);
  }

  static Future<void> resetTour(String tourId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(tourId));
  }

  /// دليل الحجز الكامل (من زر المساعدة العام).
  static Future<bool> shouldShowBookingGuide() =>
      shouldShow(OnboardingTourIds.bookingGuide);

  static Future<void> markBookingGuideSeen() =>
      markSeen(OnboardingTourIds.bookingGuide);
}
