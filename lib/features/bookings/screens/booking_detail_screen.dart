import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:rast/core/widgets/rast_kit.dart';
import 'package:rast/core/widgets/rast_ui.dart';
import 'package:rast/core/widgets/rast_motion.dart';
import 'package:rast/features/bookings/list_widgets/booking_card.dart';
import 'package:rast/core/services/analytics_service.dart';
import 'package:rast/core/services/app_events.dart';
import 'package:rast/core/services/review_prompt_service.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:provider/provider.dart';
import 'package:rast/core/constants/api_config.dart';
import 'package:rast/core/providers/app_settings_provider.dart';
import 'package:rast/core/utils/locale_utils.dart';
import 'package:rast/core/utils/date_formatter.dart';
import 'package:rast/core/api/api_services.dart';
import 'package:rast/core/api/api_client.dart';
import 'package:rast/features/bookings/screens/payment_webview_screen.dart';

import '../../../core/constants/app_strings.dart';

class BookingDetailScreen extends StatefulWidget {
  final Map<String, dynamic> booking;

  /// يفتح نافذة التقييم مباشرة (عند الضغط على إشعار تذكير التقييم)
  final bool openReview;

  const BookingDetailScreen({super.key, required this.booking, this.openReview = false});

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  String get _lang =>
      context.read<AppSettingsProvider>().language;

  bool get _isArabic =>
      context.read<AppSettingsProvider>().isArabic;

  String _tr(String key) {
    return AppStrings.t(key, _lang);
  }

  String _sar(double value) {
    return '${value.toStringAsFixed(2)} ${AppStrings.t('sar', _lang)}';
  }
  Map<String, dynamic> get booking => _booking;
  late Map<String, dynamic> _booking;

  @override
  void initState() {
    super.initState();
    AnalyticsService.logScreen('booking_details');
    _booking = Map<String, dynamic>.from(widget.booking);
    _loadFreshBooking();
    if (widget.openReview && _canReview) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showReviewDialog(context);
      });
    }
  }

  bool get _hasReview => _booking['review'] is Map && _booking['review']['rating'] != null;

  // الخادم يحدد الإمكانية (بعد الاكتمال أو بعد مرور موعد الحجز المدفوع)
  bool get _canReview => !_hasReview && (_booking['can_review'] == true || _booking['status'] == 'completed');

  double _parseNum(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  Future<void> _loadFreshBooking() async {
    final id = _booking['id'];
    if (id == null) return;
    // نحدّث دائماً لعرض حالة طلب الإلغاء والاسترداد الحالية
    try {
      final fresh = await Api.bookings.getBooking(id is int ? id : int.parse(id.toString()));
      if (mounted) {
        setState(() => _booking = _mergeBooking(_booking, fresh));
      }
    } catch (_) {}
  }

  Map<String, dynamic> _mergeBooking(Map<String, dynamic> current, Map<String, dynamic> fresh) {
    final merged = Map<String, dynamic>.from(fresh);
    for (final k in current.keys) {
      if (merged[k] == null && current[k] != null) merged[k] = current[k];
    }
    return merged;
  }

  String _bookingTimeLabel(Map<String, dynamic> b) {
    final direct = _isArabic
        ? b['booking_period_label_ar']?.toString().trim()
        : b['booking_period_label_en']?.toString().trim();

    if (direct != null && direct.isNotEmpty) {
      return direct;
    }

    final ts = b['time_slot'];

    if (ts is Map) {
      final period = _isArabic
          ? ts['period_label_ar']?.toString().trim()
          : ts['period_label_en']?.toString().trim();

      if (period != null && period.isNotEmpty) {
        return period;
      }
    }

    return DateFormatter.formatBookingTime(
      b['booking_time']?.toString(),
    );
  }

  String _branchNameDisplay() {
    final branch = booking['branch'];

    if (branch is Map) {
      final map = Map<String, dynamic>.from(branch);

      final name = LocaleUtils.localizedName(
        map,
        _isArabic,
        arKey: 'name_ar',
        enKey: 'name_en',
      );

      final city = map['city']?.toString().trim() ?? '';
      final district =
          map['district']?.toString().trim() ?? '';

      final location = [
        city,
        district,
      ].where((e) => e.isNotEmpty).join(' · ');

      if (name.isNotEmpty && location.isNotEmpty) {
        return '$name · $location';
      }

      if (name.isNotEmpty) return name;

      if (location.isNotEmpty) return location;
    }

    return booking['branch_name']?.toString() ?? '';
  }


  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();
    final lang = settings.language;
    final status = booking['status']?.toString() ?? 'pending';
    final showActions = status == 'pending' || status == 'confirmed';

    return Directionality(
      textDirection: settings.textDirection,
      child: Scaffold(
        backgroundColor: RastTokens.bg(context),
        appBar: RastTopBar(title: AppStrings.t('bookingDetailsTitle', lang), showMenu: false),
        bottomNavigationBar: showActions ? _buildActions(context) : null,
        body: RefreshIndicator(
          color: RastTokens.brand,
          onRefresh: _loadFreshBooking,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.fromLTRB(RastTokens.gutter, 16, RastTokens.gutter, 32),
            children: [
              _buildTicket(context).entrance(0),
              const SizedBox(height: 14),
              _buildTimeline(context).entrance(1),
              _buildCancellationInfo(context),
              const SizedBox(height: 14),
              _buildDetailsCard(context).entrance(2),
              _buildPreparation(context),
              const SizedBox(height: 14),
              _buildBookingBreakdown(context).entrance(3),
              if (_hasReview || _canReview) ...[
                const SizedBox(height: 14),
                _buildReviewSection(context),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- التذكرة ----------------

  Widget _buildTicket(BuildContext context) {
    final lang = _lang;
    final isArabic = context.watch<AppSettingsProvider>().isArabic;
    final logoUrl = ApiConfig.resolveImageUrl(booking['provider_logo_url'], booking['provider_logo']);
    final providerName = LocaleUtils.localizedName(booking, isArabic, arKey: 'provider_name_ar', enKey: 'provider_name_en');
    final serviceName = LocaleUtils.localizedName(booking, isArabic, arKey: 'service_name_ar', enKey: 'service_name_en');
    final status = BookingStatusStyle.of(booking, lang);
    final number = booking['booking_number']?.toString();
    final countdown = (booking['status'] == 'pending' || booking['status'] == 'confirmed')
        ? bookingCountdown(booking['booking_date'], lang)
        : null;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(RastTokens.radius),
        boxShadow: RastTokens.shadow(context, strength: 1.4),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(RastTokens.radius),
        child: Column(
          children: [
            // الجزء العلوي بلون الهوية
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
              decoration: const BoxDecoration(gradient: RastTokens.heroGradient),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(status.icon, size: 14, color: status.color),
                            const SizedBox(width: 4),
                            Text(status.label,
                                style: TextStyle(color: status.color, fontWeight: FontWeight.w800, fontSize: 12)),
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (countdown != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.timer_outlined, size: 14, color: Colors.white),
                              const SizedBox(width: 4),
                              Text(countdown,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                        child: RastNetImage(url: logoUrl, radius: 13, fallbackIcon: Icons.apartment_rounded),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              serviceName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900, height: 1.3),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              providerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // خط التذكرة المثقّب
            Container(
              color: RastTokens.card(context),
              height: 18,
              child: Row(
                children: [
                  _ticketNotch(context, start: true),
                  Expanded(child: CustomPaint(painter: _DashPainter(RastTokens.line(context)))),
                  _ticketNotch(context, start: false),
                ],
              ),
            ),
            // الجزء السفلي: رقم الحجز والموعد
            Container(
              color: RastTokens.card(context),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Column(
                children: [
                  if (number != null)
                    Row(
                      children: [
                        Icon(Icons.confirmation_number_outlined, size: 18, color: RastTokens.muted(context)),
                        const SizedBox(width: 6),
                        Text(_tr('bookingNumber'),
                            style: TextStyle(fontSize: 12.5, color: RastTokens.muted(context))),
                        const Spacer(),
                        Text(
                          number,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            letterSpacing: 0.5,
                            color: RastTokens.ink(context),
                          ),
                        ),
                        const SizedBox(width: 4),
                        InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: number));
                            HapticFeedback.selectionClick();
                            ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(SnackBar(content: Text(_tr('copied'))));
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Icon(Icons.copy_rounded, size: 17, color: RastTokens.brand),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _ticketFact(
                          context,
                          icon: Icons.calendar_month_rounded,
                          label: _tr('date'),
                          value: DateFormatter.formatBookingDate(booking['booking_date']?.toString()),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ticketFact(
                          context,
                          icon: Icons.schedule_rounded,
                          label: _tr('time'),
                          value: _bookingTimeLabel(booking),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ticketNotch(BuildContext context, {required bool start}) {
    final r = const Radius.circular(9);
    return Container(
      width: 9,
      height: 18,
      decoration: BoxDecoration(
        color: RastTokens.bg(context),
        borderRadius: start
            ? BorderRadiusDirectional.only(topEnd: r, bottomEnd: r)
            : BorderRadiusDirectional.only(topStart: r, bottomStart: r),
      ),
    );
  }

  Widget _ticketFact(BuildContext context, {required IconData icon, required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: RastTokens.fill(context), borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Icon(icon, size: 18, color: RastTokens.brand),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: RastTokens.muted(context))),
                Text(
                  value.isEmpty ? '—' : value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: RastTokens.ink(context)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- مراحل الحجز ----------------

  /// المراحل مشتقة فقط من الحقول الموجودة: الإنشاء، الدفع، التأكيد، الاكتمال (أو الإلغاء).
  Widget _buildTimeline(BuildContext context) {
    final lang = _lang;
    final status = booking['status']?.toString() ?? 'pending';
    final paid = booking['payment_status']?.toString() == 'paid';
    final cancelled = status == 'cancelled';
    final confirmed = status == 'confirmed' || status == 'completed';
    final completed = status == 'completed';

    final steps = <(String, IconData, bool)>[
      (L(lang, 'تم إنشاء الحجز', 'Booking created'), Icons.edit_calendar_rounded, true),
      (L(lang, 'تم الدفع', 'Payment received'), Icons.credit_card_rounded, paid),
      if (!cancelled) (L(lang, 'تأكيد المختبر', 'Confirmed by lab'), Icons.verified_rounded, confirmed),
      if (!cancelled) (L(lang, 'اكتمل الفحص', 'Test completed'), Icons.task_alt_rounded, completed),
      if (cancelled) (AppStrings.t('bookingStatusCancelled', lang), Icons.cancel_rounded, true),
    ];
    final current = steps.indexWhere((s) => !s.$3);

    return RastCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            L(lang, 'مراحل الحجز', 'Booking progress'),
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: RastTokens.ink(context)),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < steps.length; i++)
            _timelineRow(
              context,
              label: steps[i].$1,
              icon: steps[i].$2,
              done: steps[i].$3,
              isCurrent: i == current,
              isLast: i == steps.length - 1,
              color: cancelled && i == steps.length - 1 ? RastTokens.danger : RastTokens.success,
            ),
        ],
      ),
    );
  }

  Widget _timelineRow(
    BuildContext context, {
    required String label,
    required IconData icon,
    required bool done,
    required bool isCurrent,
    required bool isLast,
    required Color color,
  }) {
    final c = done ? color : (isCurrent ? RastTokens.brand : RastTokens.muted(context));
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 30,
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done ? c : c.withValues(alpha: 0.1),
                    border: isCurrent ? Border.all(color: c, width: 2) : null,
                  ),
                  child: Icon(done ? Icons.check_rounded : icon, size: 16, color: done ? Colors.white : c),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2.5,
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      decoration: BoxDecoration(
                        color: done ? c.withValues(alpha: 0.5) : RastTokens.line(context),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 5, bottom: isLast ? 8 : 18),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: done || isCurrent ? FontWeight.w800 : FontWeight.w500,
                  color: done || isCurrent ? RastTokens.ink(context) : RastTokens.muted(context),
                ),
              ),
            ),
          ),
          if (isCurrent)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: RastPill(label: L(_lang, 'الحالية', 'Current'), dense: true),
            ),
        ],
      ),
    );
  }

  /// حالة طلب الإلغاء (قيد المراجعة / مرفوض) وحالة استرداد المبلغ
  Widget _buildCancellationInfo(BuildContext context) {
    final request = booking['cancellation_request'] is Map
        ? Map<String, dynamic>.from(booking['cancellation_request'])
        : null;
    final refund = booking['refund'] is Map
        ? Map<String, dynamic>.from(booking['refund'])
        : null;

    final notes = <Widget>[];

    if (request != null && request['status'] == 'pending') {
      notes.add(_infoNote(
        context,
        icon: Icons.hourglass_top_rounded,
        color: BookingStatusStyle.requested,
        title: _tr('cancelRequestPending'),
        body: _tr('cancelRequestPendingHint'),
      ));
    } else if (request != null &&
        request['status'] == 'rejected' &&
        booking['status'] != 'cancelled') {
      final note = request['admin_note']?.toString().trim() ?? '';
      notes.add(_infoNote(
        context,
        icon: Icons.block_rounded,
        color: RastTokens.danger,
        title: _tr('cancelRequestRejected'),
        body: note.isNotEmpty ? note : null,
      ));
    }

    if (refund != null) {
      final done = refund['status'] == 'processed';
      final amount = _parseNum(refund['amount']);
      notes.add(_infoNote(
        context,
        icon: done ? Icons.check_circle_rounded : Icons.currency_exchange_rounded,
        color: done ? RastTokens.success : RastTokens.info,
        title: done ? _tr('refundDone') : _tr('refundInProgress'),
        body: '${_tr('refundAmount')}: ${_sar(amount)}',
      ));
    }

    if (notes.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        children: [
          for (int i = 0; i < notes.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            notes[i],
          ],
        ],
      ),
    );
  }

  Widget _infoNote(
      BuildContext context, {
        required IconData icon,
        required Color color,
        required String title,
        String? body,
      }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: RastTokens.dark(context) ? 0.16 : 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RastIconBox(icon: icon, color: color, size: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: color)),
                if (body != null && body.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(body, style: TextStyle(fontSize: 12.5, color: RastTokens.ink(context), height: 1.5)),
                ],
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0);
  }

  // ---------------- التفاصيل ----------------

  Widget _buildDetailsCard(BuildContext context) {
    final isArabic = context.watch<AppSettingsProvider>().isArabic;
    final patient = booking['patient_name']?.toString().trim() ?? '';
    final isHome = booking['service_type'] == 'home_service';
    final branch = _branchNameDisplay();
    final providerName = LocaleUtils.localizedName(booking, isArabic, arKey: 'provider_name_ar', enKey: 'provider_name_en');

    final rows = <Widget>[
      RastInfoRow(
        icon: Icons.biotech_rounded,
        label: _tr('test'),
        value: LocaleUtils.localizedName(booking, isArabic, arKey: 'service_name_ar', enKey: 'service_name_en'),
      ),
      if (patient.isNotEmpty)
        RastInfoRow(icon: Icons.person_rounded, label: _tr('bookingForTitle'), value: patient, color: RastTokens.brand2),
      RastInfoRow(
        icon: isHome ? Icons.home_rounded : Icons.apartment_rounded,
        label: _tr('serviceType'),
        value: isHome ? _tr('homeServiceLabel') : _tr('inLab'),
        color: isHome ? RastTokens.success : RastTokens.brand2,
      ),
      RastInfoRow(icon: Icons.local_hospital_rounded, label: _tr('lab'), value: providerName),
      if (branch.isNotEmpty) RastInfoRow(icon: Icons.place_rounded, label: _tr('branch'), value: branch, color: RastTokens.danger),
    ];

    return RastCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _tr('bookingInformation'),
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: RastTokens.ink(context)),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            rows[i],
          ],
          if (!isHome) ...[
            const SizedBox(height: 16),
            RastButton(
              label: _tr('directions'),
              icon: Icons.directions_rounded,
              secondary: true,
              height: 46,
              onPressed: _openDirections,
            ),
          ],
        ],
      ),
    );
  }

  /// الاتجاهات إلى الفرع/المختبر: بالإحداثيات إن وُجدت، وإلا بالبحث بالاسم والمدينة.
  Future<void> _openDirections() async {
    Map<String, dynamic> mapOf(Object? v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
    final branch = mapOf(booking['branch']);
    final provider = mapOf(booking['provider']);
    double? lat;
    double? lng;
    for (final m in [branch, provider]) {
      lat ??= numOf(m['latitude'] ?? m['lat']);
      lng ??= numOf(m['longitude'] ?? m['lng']);
    }
    final Uri uri;
    if (lat != null && lng != null && lat != 0 && lng != 0) {
      uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
    } else {
      final name = LocaleUtils.localizedName(booking, true, arKey: 'provider_name_ar', enKey: 'provider_name_en');
      final query = [name, _branchNameDisplay()].where((e) => e.trim().isNotEmpty).join(' ');
      uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}');
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L(_lang, 'تعذّر فتح الخرائط', 'Could not open maps'))),
      );
    }
  }

  /// تعليمات التحضير للتحليل (صيام…) إن وُجدت في بيانات الخدمة.
  Widget _buildPreparation(BuildContext context) {
    final ps = booking['provider_service'];
    final service = ps is Map ? (ps['service'] is Map ? ps['service'] as Map : ps) : booking['service'];
    if (service is! Map) return const SizedBox.shrink();
    final text = (_isArabic
                ? (service['preparation_instructions_ar'] ?? service['preparation_instructions'])
                : (service['preparation_instructions_en'] ?? service['preparation_instructions']))
            ?.toString()
            .trim() ??
        '';
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: _infoNote(
        context,
        icon: Icons.no_food_rounded,
        color: RastTokens.warning,
        title: L(_lang, 'قبل موعدك', 'Before your visit'),
        body: text,
      ),
    );
  }

  // ---------------- الفاتورة ----------------

  Map<String, dynamic>? _parseMetadata(dynamic meta) {
    if (meta == null) return null;
    if (meta is Map) return Map<String, dynamic>.from(meta);
    if (meta is String) {
      try {
        final decoded = jsonDecode(meta);
        return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
      } catch (_) {}
    }
    return null;
  }

  Widget _buildBookingBreakdown(
      BuildContext context,
      ) {
    final summary = booking['summary'] is Map
        ? booking['summary']
    as Map<String, dynamic>
        : null;

    final ps = booking['provider_service'];

    final psMap = ps is Map
        ? ps as Map<String, dynamic>
        : null;

    final isHomeService =
        booking['service_type'] ==
            'home_service';

    final meta =
    _parseMetadata(booking['metadata']);

    double servicePrice;
    double homeFee;
    double discountAmount;
    double vatAmount;
    double totalAmount;

    if (summary != null) {
      servicePrice = _parseNum(summary['service_price']);
      homeFee = _parseNum(summary['home_service_fee']);
      final fromDiscount = _parseNum(summary['discount_amount']);
      final fromPlatform = _parseNum(summary['platform_discount']);
      discountAmount = fromDiscount > 0 ? fromDiscount : fromPlatform;
      vatAmount = _parseNum(summary['vat_amount']);
      totalAmount = _parseNum(summary['total_amount']);
    } else {
      servicePrice = _parseNum(booking['service_price']);
      homeFee = _parseNum(booking['home_service_fee']);
      discountAmount = _parseNum(booking['discount_amount']);
      vatAmount = _parseNum(meta?['vat_amount']);

      if (servicePrice == 0 && psMap != null) {
        servicePrice = ApiConfig.priceFromMap(psMap);
      }

      if (isHomeService && homeFee == 0 && psMap != null) {
        homeFee = _parseNum(psMap['home_service_price']);
      }

      if (discountAmount == 0) {
        discountAmount = _parseNum(meta?['platform_discount']);

        if (discountAmount == 0 && servicePrice > 0) {
          final rate = _parseNum(meta?['platform_discount_rate']);

          final multiplier = (rate > 0 && rate <= 1)
              ? rate
              : (rate > 1 ? rate / 100 : ApiConfig.globalDiscountPercent / 100);

          discountAmount = (servicePrice * multiplier).roundToDouble();
        }
      }

      totalAmount = _parseNum(booking['total_amount']);

      if (totalAmount == 0) {
        final base = servicePrice + (isHomeService ? homeFee : 0) - discountAmount;
        totalAmount = (base + vatAmount).roundToDouble();
      }
    }

    final paid = booking['payment_status']?.toString() == 'paid';

    return RastCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _tr('invoiceDetails'),
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: RastTokens.ink(context)),
                ),
              ),
              RastPill(
                label: paid ? _tr('paid') : _tr('unpaid'),
                icon: paid ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                color: paid ? RastTokens.success : RastTokens.warning,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _moneyRow(_tr('testPrice'), _sar(servicePrice)),
          if (isHomeService) _moneyRow(_tr('homeServiceFee'), '+ ${_sar(homeFee)}'),
          if (discountAmount > 0)
            _moneyRow(_tr('platformDiscount'), '- ${_sar(discountAmount)}', color: RastTokens.success),
          if (vatAmount > 0) _moneyRow(_tr('vat'), '+ ${_sar(vatAmount)}'),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: CustomPaint(size: const Size(double.infinity, 1), painter: _DashPainter(RastTokens.line(context))),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  _tr('totalAmount'),
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: RastTokens.ink(context)),
                ),
              ),
              RastPrice(amount: totalAmount, lang: _lang, size: 19),
            ],
          ),
        ],
      ),
    );
  }

  Widget _moneyRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: RastTokens.muted(context)))),
          Text(
            value,
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: color ?? RastTokens.ink(context)),
          ),
        ],
      ),
    );
  }

  // ---------------- التقييم ----------------

  Widget _buildReviewSection(BuildContext context) {
    final rev = booking['review'];
    final hasReview = rev is Map && rev['rating'] != null;
    final rating = hasReview ? numOf(rev['rating']) ?? 0 : 0.0;

    return RastCard(
      padding: const EdgeInsets.all(16),
      gradient: hasReview
          ? null
          : LinearGradient(
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
              colors: [
                RastTokens.gold.withValues(alpha: 0.12),
                RastTokens.card(context),
              ],
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const RastIconBox(icon: Icons.star_rounded, color: RastTokens.gold, size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  hasReview ? _tr('review') : L(_lang, 'كيف كانت تجربتك؟', 'How was your visit?'),
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: RastTokens.ink(context)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (hasReview) ...[
            Row(
              children: [
                RatingBarIndicator(
                  rating: rating.toDouble().clamp(0.0, 5.0),
                  itemCount: 5,
                  itemSize: 22,
                  itemBuilder: (_, __) => const Icon(Icons.star_rounded, color: RastTokens.gold),
                ),
                const SizedBox(width: 8),
                Text(fmtPrice(rating),
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: RastTokens.ink(context))),
              ],
            ),
            if (rev['comment']?.toString().trim().isNotEmpty == true) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: RastTokens.fill(context), borderRadius: BorderRadius.circular(14)),
                child: Text(
                  rev['comment'].toString(),
                  style: TextStyle(fontSize: 13, color: RastTokens.ink(context), height: 1.5),
                ),
              ),
            ],
            const SizedBox(height: 12),
            RastButton(
              label: _tr('editReview'),
              icon: Icons.edit_rounded,
              secondary: true,
              height: 46,
              onPressed: () => _showReviewDialog(context),
            ),
          ] else ...[
            Text(
              L(_lang, 'رأيك يساعد غيرك على اختيار المختبر المناسب.', 'Your rating helps others choose the right lab.'),
              style: TextStyle(fontSize: 12.5, color: RastTokens.muted(context), height: 1.5),
            ),
            const SizedBox(height: 12),
            RastButton(
              label: _tr('addReview'),
              icon: Icons.star_outline_rounded,
              height: 48,
              onPressed: () => _showReviewDialog(context),
            ),
          ],
        ],
      ),
    ).entrance(4);
  }

  Future<void> _showReviewDialog(BuildContext context) async {
    final review = await ReviewPromptService.rateBooking(context, Map<String, dynamic>.from(_booking));
    if (review == null || !mounted) return;
    final updated = Map<String, dynamic>.from(_booking)
      ..['review'] = review
      ..['can_review'] = false;
    setState(() => _booking = updated);
    final bookingId = int.tryParse(_booking['id']?.toString() ?? '');
    if (bookingId == null) return;
    try {
      final fresh = await Api.bookings.getBooking(bookingId);
      if (mounted) setState(() => _booking = _mergeBooking(updated, fresh));
    } catch (_) {}
  }

  // ---------------- الإجراءات ----------------

  Widget _buildActions(BuildContext context) {
    final paymentStatus = booking['payment_status']?.toString() ?? 'pending';
    final canPay = paymentStatus != 'paid';
    final isPaid = paymentStatus == 'paid';
    // الخادم يحدد إمكانية الإلغاء (يمنعها مثلاً عند وجود طلب إلغاء قيد المراجعة)
    final canCancel = booking['can_cancel'] != false;
    final total = _parseNum(booking['summary'] is Map ? booking['summary']['total_amount'] : booking['total_amount']);

    if (!canPay && !canCancel) return const SizedBox.shrink();

    // غير المدفوع: الدفع هو الإجراء الأساسي، والإلغاء زر نصي واضح تحته (أيقونة وحدها كانت تُفوَّت)
    if (canPay && canCancel) {
      return RastStickyBar(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_tr('totalAmount'), style: TextStyle(fontSize: 11.5, color: RastTokens.muted(context))),
                    RastPrice(amount: total, lang: _lang, size: 18),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: RastButton(
                    label: _tr('payNow'),
                    icon: Icons.credit_card_rounded,
                    onPressed: () => _openPayment(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: () => _showCancelDialog(context),
              icon: const Icon(Icons.event_busy_rounded, size: 18),
              label: Text(_tr(isPaid ? 'requestCancellation' : 'cancelBooking')),
              style: TextButton.styleFrom(foregroundColor: RastTokens.danger),
            ),
          ],
        ),
      );
    }

    return RastStickyBar(
      child: Row(
        children: [
          if (canPay) ...[
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_tr('totalAmount'), style: TextStyle(fontSize: 11.5, color: RastTokens.muted(context))),
                RastPrice(amount: total, lang: _lang, size: 18),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: RastButton(
                label: _tr('payNow'),
                icon: Icons.credit_card_rounded,
                onPressed: () => _openPayment(context),
              ),
            ),
          ],
          if (canCancel) ...[
            if (canPay) const SizedBox(width: 8),
            canPay
                ? Tooltip(
                    message: _tr(isPaid ? 'requestCancellation' : 'cancelBooking'),
                    child: _cancelIconButton(context),
                  )
                : Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showCancelDialog(context),
                      icon: const Icon(Icons.cancel_outlined, size: 20),
                      label: Text(
                        _tr(isPaid ? 'requestCancellation' : 'cancelBooking'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: RastTokens.danger,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        side: BorderSide(color: RastTokens.danger.withValues(alpha: 0.3)),
                      ),
                    ),
                  ),
          ],
        ],
      ),
    );
  }

  Widget _cancelIconButton(BuildContext context) {
    return Material(
      color: RastTokens.danger.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showCancelDialog(context),
        child: const SizedBox(
          width: 52,
          height: 52,
          child: Icon(Icons.event_busy_rounded, color: RastTokens.danger),
        ),
      ),
    );
  }

  Future<void> _openPayment(BuildContext context) async {
    final id = booking['id'];
    if (id == null) return;
    try {
      final res = await Api.bookings.createPaymentSession(id is int ? id : int.parse(id.toString()));
      final success = res['success'] == true;
      final paymentUrl = res['payment_url']?.toString();

      if (success && paymentUrl != null && paymentUrl.isNotEmpty) {
        if (!context.mounted) return;
        final bookingId = id is int ? id : int.parse(id.toString());
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentWebViewScreen(
              paymentUrl: paymentUrl,
              bookingId: bookingId,
            ),
          ),
        );
        // بعد الرجوع من صفحة الدفع: نقرأ الحالة الحقيقية من الخادم ونحدّث «حجوزاتي»
        await _loadFreshBooking();
        AppEvents.notifyBookingsChanged();
        if (context.mounted) {
          final paidNow = _booking['payment_status']?.toString() == 'paid';
          if (paidNow) Celebration.show(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(paidNow ? _tr('paymentSuccess') : _tr('refreshAfterPayment'))),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']?.toString() ??
            _tr('paymentSessionFailed'))));
        }
      }
    } on ApiException catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          '${_tr('unableOpenPayment')}: '
              '${e.toString().split('\n').first}',
        ),
      ));
      }
    }
  }

  /// غير المدفوع: إلغاء فوري. المدفوع: طلب إلغاء بسبب إلزامي تراجعه الإدارة.
  void _showCancelDialog(
      BuildContext context,
      ) {
    final settings =
    context.read<AppSettingsProvider>();

    final isPaid = booking['payment_status']?.toString() == 'paid';

    final reasonController = TextEditingController(
      text: isPaid ? '' : _tr('userCancellationReason'),
    );
    String? reasonError;
    bool submitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Directionality(
          textDirection: settings.textDirection,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              _tr(isPaid ? 'requestCancellation' : 'cancelBooking'),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _tr(isPaid ? 'cancelRequestExplain' : 'cancelBookingConfirm'),
                    textAlign: TextAlign.start,
                    style: const TextStyle(height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: reasonController,
                    textAlign: TextAlign.start,
                    minLines: isPaid ? 3 : 1,
                    maxLines: isPaid ? 5 : 1,
                    decoration: InputDecoration(
                      labelText: _tr(isPaid ? 'cancelReasonRequired' : 'cancelReasonOptional'),
                      errorText: reasonError,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: submitting ? null : () => Navigator.pop(ctx),
                child: Text(_tr('no')),
              ),
              TextButton(
                onPressed: submitting
                    ? null
                    : () async {
                  final id = booking['id'];
                  final typed = reasonController.text.trim();

                  if (isPaid && typed.length < 5) {
                    setDialogState(() => reasonError = _tr('cancelReasonRequiredError'));
                    return;
                  }

                  final reason = typed.isEmpty ? _tr('userCancellationReason') : typed;
                  setDialogState(() => submitting = true);

                  try {
                    if (id == null) return;
                    final res = await Api.bookings.cancel(
                      id is int ? id : int.parse(id.toString()),
                      reason,
                    );
                    final requested = res['cancellation_status'] == 'requested';
                    AnalyticsService.logEvent(requested ? 'cancel_booking_request' : 'cancel_booking', {
                      'booking_id': id,
                      'value': _parseNum(booking['total_amount']),
                      'currency': 'SAR',
                    });
                    AppEvents.notifyBookingsChanged();

                    if (ctx.mounted) Navigator.pop(ctx);
                    if (!context.mounted) return;

                    if (requested) {
                      // يبقى الحجز قائماً حتى قرار الإدارة: نعرض حالة الطلب في نفس الصفحة
                      final data = res['data'];
                      if (data is Map) {
                        setState(() => _booking = _mergeBooking(_booking, Map<String, dynamic>.from(data)));
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(_tr('cancelRequestSent'))),
                      );
                    } else {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(_tr('bookingCancelled'))),
                      );
                    }
                  } on ApiException catch (e) {
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.message)),
                      );
                    }
                  } catch (e) {
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.toString())),
                      );
                    }
                  }
                },
                child: submitting
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : Text(
                  _tr(isPaid ? 'sendCancelRequest' : 'yesCancel'),
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// خط متقطع (تذكرة الحجز وخط الإجمالي في الفاتورة)
class _DashPainter extends CustomPainter {
  _DashPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1.4;
    final y = size.height / 2;
    for (double x = 0; x < size.width; x += 9) {
      canvas.drawLine(Offset(x, y), Offset((x + 5).clamp(0, size.width).toDouble(), y), p);
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color;
}
