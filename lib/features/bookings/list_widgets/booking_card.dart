import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rast/core/constants/api_config.dart';
import 'package:rast/core/constants/app_strings.dart';
import 'package:rast/core/providers/app_settings_provider.dart';
import 'package:rast/core/utils/locale_utils.dart';
import 'package:rast/core/widgets/rast_kit.dart';

/// حالة الحجز كما تُعرض للمستخدم: النص واللون والأيقونة.
/// طلب الإلغاء قيد المراجعة يتقدّم على الحالة الأصلية لأنه ما يهم المستخدم الآن.
class BookingStatusStyle {
  const BookingStatusStyle(this.label, this.color, this.icon);

  final String label;
  final Color color;
  final IconData icon;

  static const Color requested = Color(0xFF7C3AED);

  static bool cancellationPending(Map<String, dynamic> b) {
    final r = b['cancellation_request'];
    return r is Map && r['status'] == 'pending' && b['status'] != 'cancelled';
  }

  static BookingStatusStyle of(Map<String, dynamic> b, String lang) {
    if (cancellationPending(b)) {
      return BookingStatusStyle(
        L(lang, 'طلب إلغاء قيد المراجعة', 'Cancellation requested'),
        requested,
        Icons.hourglass_top_rounded,
      );
    }
    switch ((b['status'] ?? 'pending').toString()) {
      case 'confirmed':
        return BookingStatusStyle(AppStrings.t('bookingStatusConfirmed', lang), RastTokens.success, Icons.verified_rounded);
      case 'pending':
        return BookingStatusStyle(AppStrings.t('bookingStatusPending', lang), RastTokens.warning, Icons.schedule_rounded);
      case 'completed':
        return BookingStatusStyle(AppStrings.t('bookingStatusCompleted', lang), RastTokens.info, Icons.task_alt_rounded);
      case 'cancelled':
        return BookingStatusStyle(AppStrings.t('bookingStatusCancelled', lang), RastTokens.danger, Icons.cancel_rounded);
      default:
        return BookingStatusStyle(b['status'].toString(), const Color(0xFF6E6A80), Icons.info_outline_rounded);
    }
  }
}

/// «اليوم» / «غداً» / «بعد يومين» / «بعد 5 أيام» من تاريخ الحجز (إن أمكن قراءته).
String? bookingCountdown(Object? rawDate, String lang) {
  final s = rawDate?.toString().trim() ?? '';
  if (s.isEmpty) return null;
  final parsed = DateTime.tryParse(s.length >= 10 ? s.substring(0, 10) : s);
  if (parsed == null) return null;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final days = DateTime(parsed.year, parsed.month, parsed.day).difference(today).inDays;
  if (days < 0) return null;
  if (days == 0) return L(lang, 'اليوم', 'Today');
  if (days == 1) return L(lang, 'غداً', 'Tomorrow');
  if (days == 2) return L(lang, 'بعد يومين', 'In 2 days');
  if (days <= 10) return L(lang, 'بعد $days أيام', 'In $days days');
  return L(lang, 'بعد $days يوماً', 'In $days days');
}

/// بطاقة حجز في «حجوزاتي»: الحالة، التحليل، المختبر، الموعد، السعر وحالة الدفع.
class BookingCard extends StatelessWidget {
  const BookingCard({
    super.key,
    required this.booking,
    required this.scheduleLine,
    required this.onTap,
    this.isPast = false,
  });

  final Map<String, dynamic> booking;
  final String scheduleLine;
  final VoidCallback onTap;
  final bool isPast;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();
    final isArabic = settings.isArabic;
    final lang = settings.language;

    final serviceName = LocaleUtils.localizedName(booking, isArabic, arKey: 'service_name_ar', enKey: 'service_name_en');
    final providerName = LocaleUtils.localizedName(booking, isArabic, arKey: 'provider_name_ar', enKey: 'provider_name_en');
    final patient = booking['patient_name']?.toString().trim() ?? '';
    final status = BookingStatusStyle.of(booking, lang);
    final rawStatus = (booking['status'] ?? 'pending').toString();
    final active = rawStatus == 'pending' || rawStatus == 'confirmed';
    final paid = (booking['payment_status'] ?? 'pending') == 'paid';
    final isHome = booking['service_type'] == 'home_service';
    final amount = numOf(booking['total_amount']) ?? 0;
    final countdown = !isPast && active ? bookingCountdown(booking['booking_date'], lang) : null;
    final soon = countdown != null && (countdown == L(lang, 'اليوم', 'Today') || countdown == L(lang, 'غداً', 'Tomorrow'));

    return RastCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      clip: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Thumb(booking: booking),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              RastPill(label: status.label, icon: status.icon, color: status.color, dense: true),
                              if (countdown != null)
                                RastPill(
                                  label: countdown,
                                  icon: Icons.timer_outlined,
                                  color: soon ? RastTokens.brand : RastTokens.brand2,
                                  filled: soon,
                                  dense: true,
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            serviceName.isEmpty ? AppStrings.t('booking', lang) : serviceName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: RastTokens.ink(context),
                              height: 1.3,
                            ),
                          ),
                          if (providerName.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Icon(Icons.biotech_outlined, size: 14, color: RastTokens.muted(context)),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    providerName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 12, color: RastTokens.muted(context)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // الموعد ونوع الخدمة: مربع تقويم (اليوم والشهر) + سطر الوقت
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: RastTokens.fill(context),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      _CalendarTile(rawDate: booking['booking_date'], color: status.color),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          scheduleLine,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: RastTokens.ink(context)),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(isHome ? Icons.home_rounded : Icons.apartment_rounded, size: 15, color: RastTokens.muted(context)),
                      const SizedBox(width: 3),
                      Text(
                        isHome ? AppStrings.t('homeServiceLabel', lang) : AppStrings.t('inLab', lang),
                        style: TextStyle(fontSize: 12, color: RastTokens.muted(context)),
                      ),
                    ],
                  ),
                ),
                if (patient.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.person_outline_rounded, size: 15, color: RastTokens.muted(context)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${AppStrings.t('bookingForShort', lang)} $patient',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: RastTokens.muted(context)),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                // السعر وحالة الدفع
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    RastPrice(amount: amount, lang: lang, size: 17),
                    const SizedBox(width: 8),
                    Text(
                      paid ? AppStrings.t('paid', lang) : AppStrings.t('unpaid', lang),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: paid ? RastTokens.success : RastTokens.warning,
                      ),
                    ),
                    const Spacer(),
                    if (!paid && active)
                      _PayNowChip(label: AppStrings.t('payNow', lang), onTap: onTap)
                    else
                      Icon(
                        Directionality.of(context) == TextDirection.rtl
                            ? Icons.chevron_left_rounded
                            : Icons.chevron_right_rounded,
                        color: RastTokens.muted(context),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PayNowChip extends StatelessWidget {
  const _PayNowChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          gradient: RastTokens.brandGradient,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(color: RastTokens.brand.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 3)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.credit_card_rounded, color: Colors.white, size: 15),
            const SizedBox(width: 5),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

/// صورة التحليل مع شعار المختبر في الزاوية.
class _Thumb extends StatelessWidget {
  const _Thumb({required this.booking});

  final Map<String, dynamic> booking;

  @override
  Widget build(BuildContext context) {
    final ps = booking['provider_service'] is Map
        ? Map<String, dynamic>.from(booking['provider_service'] as Map)
        : <String, dynamic>{};
    final rawService = ps['service'] ?? ps;
    final service = rawService is Map ? Map<String, dynamic>.from(rawService) : <String, dynamic>{};
    final testUrl = ApiConfig.analysisImageUrl(service, ps);
    final labUrl = ApiConfig.resolveImageUrl(booking['provider_logo_url'], booking['provider_logo']);

    return SizedBox(
      width: 84,
      height: 84,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          RastNetImage(
            url: (testUrl != null && testUrl.isNotEmpty) ? testUrl : labUrl,
            width: 78,
            height: 78,
            radius: 18,
          ),
          if (labUrl != null && labUrl.isNotEmpty && testUrl != null && testUrl.isNotEmpty)
            PositionedDirectional(
              end: -2,
              bottom: -2,
              child: Container(
                width: 30,
                height: 30,
                padding: const EdgeInsets.all(1.5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6)],
                ),
                child: ClipOval(child: RastNetImage(url: labUrl, radius: 0, fallbackIcon: Icons.apartment_rounded)),
              ),
            ),
        ],
      ),
    );
  }
}

/// هيكل تحميل لبطاقة حجز.
class BookingCardSkeleton extends StatelessWidget {
  const BookingCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return RastCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const RastSkeleton(width: 60, height: 60, radius: 16),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    RastSkeleton(width: 90, height: 18, radius: 999),
                    SizedBox(height: 8),
                    RastSkeleton(height: 16),
                    SizedBox(height: 6),
                    RastSkeleton(width: 140, height: 12),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const RastSkeleton(height: 38, radius: 12),
          const SizedBox(height: 12),
          const RastSkeleton(width: 120, height: 20),
        ],
      ),
    );
  }
}

/// مربع تقويم صغير: رقم اليوم كبير واسم الشهر تحته (أسرع للقراءة من سطر نصي)
class _CalendarTile extends StatelessWidget {
  const _CalendarTile({required this.rawDate, required this.color});

  final Object? rawDate;
  final Color color;

  static const _monthsAr = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
  static const _monthsEn = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  @override
  Widget build(BuildContext context) {
    final s = rawDate?.toString().trim() ?? '';
    final d = DateTime.tryParse(s.length >= 10 ? s.substring(0, 10) : s);
    final ar = Directionality.of(context) == TextDirection.rtl;
    return Container(
      width: 48,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: RastTokens.card(context),
        borderRadius: BorderRadius.circular(12),
        boxShadow: RastTokens.shadow(context, strength: 0.5),
      ),
      child: d == null
          ? Icon(Icons.event_rounded, color: color)
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${d.day}',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color, height: 1.1),
                ),
                Text(
                  (ar ? _monthsAr : _monthsEn)[d.month - 1],
                  maxLines: 1,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: RastTokens.muted(context)),
                ),
              ],
            ),
    );
  }
}
