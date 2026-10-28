import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:rast/core/services/analytics_service.dart';
import 'package:rast/core/services/review_prompt_service.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:provider/provider.dart';
import 'package:rast/core/constants/api_config.dart';
import 'package:rast/core/providers/app_settings_provider.dart';
import 'package:rast/core/utils/locale_utils.dart';
import 'package:rast/core/theme/app_theme.dart';
import 'package:rast/core/utils/date_formatter.dart';
import 'package:rast/core/widgets/gradient_button.dart';
import 'package:rast/core/api/api_services.dart';
import 'package:rast/core/api/api_client.dart';
import 'package:rast/core/utils/responsive.dart';
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

  String _statusText(String status) {
    switch (status) {
      case 'confirmed':
        return _tr('statusConfirmed');

      case 'pending':
        return _tr('statusPending');

      case 'completed':
        return _tr('statusCompleted');

      case 'cancelled':
        return _tr('statusCancelled');

      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'confirmed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'completed':
        return AppTheme.primary;
      case 'cancelled':
        return Colors.red;
      default:
        return AppTheme.onSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings =
    context.watch<AppSettingsProvider>();

    return Directionality(
      textDirection: settings.textDirection,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F7FB),

        appBar: AppBar(
          title: Text(
            AppStrings.t(
              'bookingDetailsTitle',
              settings.language,
            ),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
          centerTitle: true,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
        ),

        body: SafeArea(
          top: false,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.stretch,
              children: [
                _buildHeader(context),

                Padding(
                  padding: EdgeInsets.fromLTRB(
                    Responsive.spacing(context, 14),
                    Responsive.spacing(context, 14),
                    Responsive.spacing(context, 14),
                    Responsive.spacing(context, 28),
                  ),
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      _buildStatusCard(context),

                      _buildCancellationInfo(context),

                      SizedBox(
                        height:
                        Responsive.spacing(
                          context,
                          16,
                        ),
                      ),

                      _buildSection(
                        context,
                        _tr('bookingInformation'),
                        [
                          if (booking[
                          'booking_number'] !=
                              null)
                            _buildInfoRow(
                              _tr('bookingNumber'),
                              booking[
                              'booking_number']
                                  .toString(),
                            ),

                          _buildInfoRow(
                            _tr('test'),
                            LocaleUtils.localizedName(
                              booking,
                              settings.isArabic,
                              arKey:
                              'service_name_ar',
                              enKey:
                              'service_name_en',
                            ),
                          ),

                          if ((booking['patient_name']?.toString() ?? '').isNotEmpty)
                            _buildInfoRow(
                              _tr('bookingForTitle'),
                              booking['patient_name'].toString(),
                            ),

                          _buildInfoRow(
                            _tr('lab'),
                            LocaleUtils.localizedName(
                              booking,
                              settings.isArabic,
                              arKey:
                              'provider_name_ar',
                              enKey:
                              'provider_name_en',
                            ),
                          ),

                          _buildInfoRow(
                            _tr('date'),
                            DateFormatter
                                .formatBookingDate(
                              booking[
                              'booking_date']
                                  ?.toString(),
                            ),
                          ),

                          _buildInfoRow(
                            _tr('time'),
                            _bookingTimeLabel(
                              booking,
                            ),
                          ),

                          _buildInfoRow(
                            _tr('serviceType'),
                            booking['service_type'] ==
                                'home_service'
                                ? _tr(
                              'homeServiceLabel',
                            )
                                : _tr('inLab'),
                          ),

                          _buildInfoRow(
                            _tr('branch'),
                            _branchNameDisplay(),
                          ),
                        ],
                      ),

                      SizedBox(
                        height:
                        Responsive.spacing(
                          context,
                          16,
                        ),
                      ),

                      _buildBookingBreakdown(
                        context,
                      ),

                      SizedBox(
                        height:
                        Responsive.spacing(
                          context,
                          16,
                        ),
                      ),

                      if (booking['status'] ==
                          'pending' ||
                          booking['status'] ==
                              'confirmed')
                        _buildActions(context),

                      if (_hasReview || _canReview)
                        _buildReviewSection(
                          context,
                        ),

                      SizedBox(
                        height:
                        Responsive.spacing(
                          context,
                          24,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final logoUrl = ApiConfig.resolveImageUrl(
      booking['provider_logo_url'],
      booking['provider_logo'],
    );

    final providerName = LocaleUtils.localizedName(
      booking,
      context.watch<AppSettingsProvider>().isArabic,
      arKey: 'provider_name_ar',
      enKey: 'provider_name_en',
    );

    final serviceName = LocaleUtils.localizedName(
      booking,
      context.watch<AppSettingsProvider>().isArabic,
      arKey: 'service_name_ar',
      enKey: 'service_name_en',
    );

    return Container(
      width: double.infinity,
      margin: EdgeInsets.fromLTRB(
        Responsive.spacing(context, 14),
        Responsive.spacing(context, 14),
        Responsive.spacing(context, 14),
        0,
      ),
      constraints: const BoxConstraints(
        minHeight: 210,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.30),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            Positioned.fill(
              child: (logoUrl != null && logoUrl.isNotEmpty)
                  ? CachedNetworkImage(
                imageUrl: logoUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: AppTheme.primary,
                ),
                errorWidget: (_, __, ___) => Container(
                  color: AppTheme.primary,
                ),
              )
                  : Container(
                color: AppTheme.primary,
              ),
            ),

            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF1A0665)
                          .withValues(alpha: 0.48),
                      const Color(0xFF1A0665)
                          .withValues(alpha: 0.78),
                    ],
                  ),
                ),
              ),
            ),

            // CONTENT
            Padding(
              padding: EdgeInsets.fromLTRB(
                Responsive.spacing(context, 16),
                Responsive.spacing(context, 20),
                Responsive.spacing(context, 16),
                Responsive.spacing(context, 20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (booking['booking_number'] != null)
                    Container(
                      constraints: const BoxConstraints(
                        maxWidth: 220,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(
                          alpha: 0.16,
                        ),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withValues(
                            alpha: 0.25,
                          ),
                        ),
                      ),
                      child: Text(
                        booking['booking_number'].toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: Responsive.fontSize(
                            context,
                            12,
                          ),
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),

                  SizedBox(
                    height: Responsive.spacing(context, 18),
                  ),

                  Text(
                    providerName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: Responsive.fontSize(
                        context,
                        19,
                      ),
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.25,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(
                            alpha: 0.30,
                          ),
                          blurRadius: 5,
                        ),
                      ],
                    ),
                  ),

                  SizedBox(
                    height: Responsive.spacing(context, 6),
                  ),

                  Text(
                    serviceName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: Responsive.fontSize(
                        context,
                        13,
                      ),
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(
                        alpha: 0.92,
                      ),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context) {
    final status =
        booking['status']?.toString() ?? 'pending';

    final paymentStatus =
        booking['payment_status']?.toString() ??
            'pending';

    final paymentDone =
        paymentStatus == 'paid';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(
        Responsive.spacing(context, 16),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color:
            Colors.black.withValues(alpha: 0.09),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color:
            Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatusTile(
              context,
              title: _tr('bookingStatus'),
              value: _statusText(status),
              valueColor: _statusColor(status),
              icon:
              Icons.assignment_turned_in_outlined,
              backgroundColor:
              _statusColor(status)
                  .withValues(alpha: 0.10),
            ),
          ),

          SizedBox(
            width:
            Responsive.spacing(context, 10),
          ),

          Expanded(
            child: _buildStatusTile(
              context,
              title: _tr('paymentStatus'),
              value: paymentDone
                  ? _tr('paid')
                  : _tr('unpaid'),
              valueColor: paymentDone
                  ? Colors.green
                  : Colors.orange,
              icon: paymentDone
                  ? Icons.check_circle_rounded
                  : Icons.schedule_rounded,
              backgroundColor:
              (paymentDone
                  ? Colors.green
                  : Colors.orange)
                  .withValues(alpha: 0.10),
            ),
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
        color: Colors.orange,
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
        color: Colors.red,
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
        color: done ? Colors.green : Colors.blue,
        title: done ? _tr('refundDone') : _tr('refundInProgress'),
        body: '${_tr('refundAmount')}: ${_sar(amount)}',
      ));
    }

    if (notes.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(top: Responsive.spacing(context, 12)),
      child: Column(
        children: [
          for (int i = 0; i < notes.length; i++) ...[
            if (i > 0) SizedBox(height: Responsive.spacing(context, 8)),
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
      padding: EdgeInsets.all(Responsive.spacing(context, 14)),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          SizedBox(width: Responsive.spacing(context, 10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 13),
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                if (body != null && body.isNotEmpty) ...[
                  SizedBox(height: Responsive.spacing(context, 4)),
                  Text(
                    body,
                    style: TextStyle(
                      fontSize: Responsive.fontSize(context, 12),
                      color: const Color(0xFF4A4F5C),
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTile(
      BuildContext context, {
        required String title,
        required String value,
        required Color valueColor,
        required IconData icon,
        required Color backgroundColor,
      }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.spacing(context, 12),
        vertical: Responsive.spacing(context, 12),
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FD),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFEAECEF),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              size: 21,
              color: valueColor,
            ),
          ),
          SizedBox(width: Responsive.spacing(context, 10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 11),
                    color: const Color(0xFF7B8090),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: Responsive.spacing(context, 4)),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 13),
                    color: valueColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

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
      servicePrice =
          _parseNum(summary['service_price']);

      homeFee =
          _parseNum(
            summary['home_service_fee'],
          );

      final fromDiscount =
      _parseNum(
        summary['discount_amount'],
      );

      final fromPlatform =
      _parseNum(
        summary['platform_discount'],
      );

      discountAmount =
      fromDiscount > 0
          ? fromDiscount
          : fromPlatform;

      vatAmount =
          _parseNum(summary['vat_amount']);

      totalAmount =
          _parseNum(summary['total_amount']);
    } else {
      servicePrice =
          _parseNum(booking['service_price']);

      homeFee =
          _parseNum(
            booking['home_service_fee'],
          );

      discountAmount =
          _parseNum(
            booking['discount_amount'],
          );

      vatAmount =
          _parseNum(meta?['vat_amount']);

      if (servicePrice == 0 &&
          psMap != null) {
        servicePrice =
            ApiConfig.priceFromMap(psMap);
      }

      if (isHomeService &&
          homeFee == 0 &&
          psMap != null) {
        homeFee = _parseNum(
          psMap['home_service_price'],
        );
      }

      if (discountAmount == 0) {
        discountAmount = _parseNum(
          meta?['platform_discount'],
        );

        if (discountAmount == 0 &&
            servicePrice > 0) {
          final rate = _parseNum(
            meta?['platform_discount_rate'],
          );

          final multiplier =
          (rate > 0 && rate <= 1)
              ? rate
              : (rate > 1
              ? rate / 100
              : ApiConfig
              .globalDiscountPercent /
              100);

          discountAmount =
              (servicePrice * multiplier)
                  .roundToDouble();
        }
      }

      totalAmount =
          _parseNum(booking['total_amount']);

      if (totalAmount == 0) {
        final base =
            servicePrice +
                (isHomeService ? homeFee : 0) -
                discountAmount;

        totalAmount =
            (base + vatAmount)
                .roundToDouble();
      }
    }

    final rows = <Widget>[
      _buildInfoRow(
        _tr('testPrice'),
        _sar(servicePrice),
      ),

      if (isHomeService)
        _buildInfoRow(
          _tr('homeServiceFee'),
          '+ ${_sar(homeFee)}',
        ),

      _buildInfoRow(
        _tr('platformDiscount'),
        '- ${_sar(discountAmount)}',
      ),

      _buildInfoRow(
        _tr('vat'),
        '+ ${_sar(vatAmount)}',
      ),

      Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 6,
        ),
        child: Divider(
          height: 1,
          color: Theme.of(context)
              .colorScheme
              .outline
              .withValues(alpha: 0.5),
        ),
      ),

      _buildInfoRow(
        _tr('totalAmount'),
        _sar(totalAmount),
      ),
    ];

    return _buildSection(
      context,
      _tr('invoiceDetails'),
      rows,
    );
  }

  Widget _buildSection(
      BuildContext context,
      String title,
      List<Widget> children,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.spacing(context, 4),
          ),
          child: Text(
            title,
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 17),
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1F2333),
            ),
          ),
        ),
        SizedBox(height: Responsive.spacing(context, 10)),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(Responsive.spacing(context, 16)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.09),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(
      String label,
      String value,
      ) {
    final theme = Theme.of(context);

    return Padding(
      padding:
      const EdgeInsets.symmetric(
        vertical: 9,
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Align(
              alignment:
              AlignmentDirectional
                  .centerStart,
              child: Text(
                label,
                maxLines: 2,
                overflow:
                TextOverflow.ellipsis,
                textAlign: TextAlign.start,
                style: TextStyle(
                  color: theme
                      .colorScheme
                      .onSurfaceVariant,
                  fontSize:
                  Responsive.fontSize(
                    context,
                    13,
                  ),
                  fontWeight:
                  FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            flex: 5,
            child: Align(
              alignment:
              AlignmentDirectional
                  .centerEnd,
              child: Text(
                value,
                textAlign: TextAlign.end,
                maxLines: 3,
                overflow:
                TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight:
                  FontWeight.w700,
                  color: theme
                      .colorScheme
                      .onSurface,
                  fontSize:
                  Responsive.fontSize(
                    context,
                    13,
                  ),
                  height: 1.35,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewSection(BuildContext context) {
    final rev = booking['review'];
    final hasReview = rev is Map && rev['rating'] != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: Responsive.spacing(context, 4)),
        _buildSection(
            context,
            _tr('review'),
            [
          if (hasReview) ...[
            Row(
              children: [
                RatingBarIndicator(
                  rating: (rev['rating'] is num
                      ? rev['rating'] as num
                      : 0)
                      .toDouble()
                      .clamp(0.0, 5.0),
                  itemCount: 5,
                  itemSize: 21,
                  itemBuilder: (_, __) => const Icon(
                    Icons.star_rounded,
                    color: Colors.amber,
                  ),
                ),
                SizedBox(width: Responsive.spacing(context, 8)),
                Text(
                  '${(rev['rating'] is num ? rev['rating'] as num : 0)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: Responsive.fontSize(context, 14),
                  ),
                ),
              ],
            ),
            if (rev['comment']?.toString().trim().isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FD),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFEAECEF),
                    ),
                  ),
                  child: Text(
                    rev['comment'].toString(),
                    style: TextStyle(
                      fontSize: Responsive.fontSize(context, 13),
                      color: AppTheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            SizedBox(height: Responsive.spacing(context, 14)),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showReviewDialog(context),
                icon: const Icon(Icons.edit, size: 18),
                label: Text(
                  _tr('editReview'),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ] else
            SizedBox(
              width: double.infinity,
              child: GradientFilledButtonIcon(
                onPressed: () => _showReviewDialog(context),
                icon: const Icon(Icons.star_outline),
                label: Text(
                  _tr('addReview'),
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
        ]),
      ],
    );
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

  Widget _buildActions(BuildContext context) {
    final paymentStatus = booking['payment_status']?.toString() ?? 'pending';
    final canPay = paymentStatus != 'paid';
    final isPaid = paymentStatus == 'paid';
    // الخادم يحدد إمكانية الإلغاء (يمنعها مثلاً عند وجود طلب إلغاء قيد المراجعة)
    final canCancel = booking['can_cancel'] != false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (canPay)
          SizedBox(
            width: double.infinity,
            height: 50,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xFF1F232B),
                    Color(0xFF6A6E76),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.16),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () => _openPayment(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  surfaceTintColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.credit_card_outlined,
                      size: 18,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _tr('payNow'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: Responsive.fontSize(
                            context,
                            14,
                          ),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (canPay) SizedBox(height: Responsive.spacing(context, 12)),
        Row(
          children: [
            if (canCancel)
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withValues(alpha: 0.10),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: OutlinedButton.icon(
                  onPressed: () => _showCancelDialog(context),
                  icon: const Icon(Icons.cancel_outlined, size: 20),
                  label: Text(
                    _tr(isPaid ? 'requestCancellation' : 'cancelBooking'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    side: BorderSide(
                      color: Colors.red.withValues(alpha: 0.20),
                    ),
                  ),
                ),
              ),
            ),
            if (canCancel) SizedBox(width: Responsive.spacing(context, 12)),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.18),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: GradientFilledButtonIcon(
                  onPressed: () {},
                  icon: const Icon(Icons.directions_rounded, size: 20),
                  label: Text(
                    _tr('directions'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
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
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_tr('refreshAfterPayment'),)));
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
