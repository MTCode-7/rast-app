import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:provider/provider.dart';
import 'package:rast/core/api/api_client.dart';
import 'package:rast/core/api/api_services.dart';
import 'package:rast/core/constants/app_strings.dart';
import 'package:rast/core/providers/app_settings_provider.dart';
import 'package:rast/core/services/analytics_service.dart';
import 'package:rast/core/widgets/gradient_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// تقييم الزيارات وتقييم التطبيق في المتجر:
/// - نافذة تقييم الحجز (من صفحة الحجز، أو إشعار التذكير، أو عند فتح التطبيق)
/// - عند فتح التطبيق: يُعرض تقييم آخر زيارة مرة واحدة فقط لكل حجز
/// - بعد تقييم 4-5 نجوم: نافذة تقييم المتجر الرسمية، مرة كل 90 يوماً كحد أقصى
class ReviewPromptService {
  static const _askedKey = 'review_prompt_asked_ids';
  static const _storeAskedKey = 'store_review_last_asked';
  static const _storeInterval = Duration(days: 90);
  static bool _checkedThisSession = false;

  /// يعرض نافذة التقييم ويرسله. يعيد بيانات التقييم عند النجاح، أو null عند الإلغاء/الفشل.
  static Future<Map<String, dynamic>?> rateBooking(
    BuildContext context,
    Map<String, dynamic> booking, {
    String source = 'booking_detail',
  }) async {
    final settings = context.read<AppSettingsProvider>();
    final lang = settings.language;
    String tr(String key) => AppStrings.t(key, lang);

    final bookingId = int.tryParse(booking['id']?.toString() ?? '');
    if (bookingId == null) return null;

    final existing = booking['review'] is Map ? booking['review'] as Map : null;
    final initialRating = ((existing?['rating'] as num?)?.toDouble() ?? 5.0).clamp(1.0, 5.0);
    var rating = initialRating.round();
    final controller = TextEditingController(text: existing?['comment']?.toString().trim() ?? '');
    final labName = (booking['provider'] is Map ? booking['provider']['business_name_ar'] : null)?.toString();
    final serviceName = (booking['provider_service'] is Map && booking['provider_service']['service'] is Map
            ? booking['provider_service']['service']['name_ar']
            : null)
        ?.toString();

    AnalyticsService.logEvent('review_prompt_shown', {'source': source});

    final submit = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: settings.textDirection,
        child: Container(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          decoration: BoxDecoration(
            color: Theme.of(ctx).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                labName != null ? AppStrings.tParam('howWasVisit', lang, labName) : tr('rateService'),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              if (serviceName != null) ...[
                const SizedBox(height: 4),
                Text(serviceName, style: TextStyle(color: Theme.of(ctx).hintColor)),
              ],
              const SizedBox(height: 16),
              Center(
                child: RatingBar.builder(
                  initialRating: initialRating,
                  minRating: 1,
                  direction: Axis.horizontal,
                  allowHalfRating: false,
                  itemCount: 5,
                  itemSize: 40,
                  itemPadding: const EdgeInsets.symmetric(horizontal: 4),
                  itemBuilder: (context, _) => const Icon(Icons.star_rounded, color: Colors.amber),
                  onRatingUpdate: (v) => rating = v.round(),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: tr('reviewCommentOptional'),
                  hintText: tr('reviewCommentHint'),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              GradientFilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                child: Text(tr('submitReview')),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(tr('later')),
              ),
            ],
          ),
        ),
      ),
    );

    final comment = controller.text.trim().isEmpty ? null : controller.text.trim();
    controller.dispose();
    if (submit != true) return null;

    final messenger = context.mounted ? ScaffoldMessenger.of(context) : null;
    try {
      final review = await Api.bookings.submitReview(bookingId, rating, comment: comment);
      AnalyticsService.logEvent('review_submitted', {'rating': rating, 'source': source});
      messenger?.showSnackBar(SnackBar(content: Text(tr('reviewAddedSuccess'))));
      if (rating >= 4) {
        // لحظة رضا: نطلب تقييم المتجر بعد إغلاق النافذة بقليل
        Future<void>.delayed(const Duration(milliseconds: 1200), maybeAskStoreReview);
      }
      return review.isNotEmpty ? review : {'rating': rating, 'comment': comment};
    } on ApiException catch (e) {
      messenger?.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger?.showSnackBar(SnackBar(content: Text(tr('reviewSendFailed'))));
    }
    return null;
  }

  /// عند فتح التطبيق: يعرض تقييم أحدث زيارة لم تُقيَّم، مرة واحدة لكل حجز.
  static Future<void> checkPendingOnLaunch(BuildContext context) async {
    if (_checkedThisSession || kIsWeb) return;
    _checkedThisSession = true;
    try {
      final pending = await Api.bookings.getPendingReview();
      if (pending.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      final asked = prefs.getStringList(_askedKey) ?? <String>[];
      final booking = pending
          .whereType<Map<String, dynamic>>()
          .firstWhere((b) => !asked.contains(b['id'].toString()), orElse: () => <String, dynamic>{});
      if (booking.isEmpty || !context.mounted) return;

      // نسجّل قبل العرض: لا نكرر السؤال عن نفس الحجز حتى لو أُغلقت النافذة
      asked.add(booking['id'].toString());
      await prefs.setStringList(_askedKey, asked.length > 50 ? asked.sublist(asked.length - 50) : asked);
      if (!context.mounted) return;

      await rateBooking(context, booking, source: 'app_open');
    } catch (e) {
      debugPrint('Pending review check skipped: $e');
    }
  }

  /// نافذة تقييم المتجر الرسمية (جوجل بلاي / آب ستور) بحد أقصى مرة كل 90 يوماً.
  static Future<void> maybeAskStoreReview() async {
    if (kIsWeb) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final last = prefs.getInt(_storeAskedKey);
      if (last != null &&
          DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(last)) < _storeInterval) {
        return;
      }
      final inAppReview = InAppReview.instance;
      if (!await inAppReview.isAvailable()) return;
      await prefs.setInt(_storeAskedKey, DateTime.now().millisecondsSinceEpoch);
      AnalyticsService.logEvent('store_review_requested', {});
      await inAppReview.requestReview();
    } catch (e) {
      debugPrint('Store review skipped: $e');
    }
  }

  /// زر «قيّم التطبيق» في الملف الشخصي: يفتح صفحة التطبيق في المتجر.
  static Future<void> openStore() async {
    if (kIsWeb) return;
    AnalyticsService.logEvent('store_review_opened', {});
    final inAppReview = InAppReview.instance;
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        await inAppReview.openStoreListing();
      } else if (await inAppReview.isAvailable()) {
        // آيفون: فتح صفحة المتجر يحتاج معرّف التطبيق في App Store؛ حتى إضافته نستخدم النافذة الرسمية
        await inAppReview.requestReview();
      }
    } catch (e) {
      debugPrint('Open store failed: $e');
    }
  }
}
