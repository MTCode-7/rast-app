import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
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

class BookingDetailScreen extends StatefulWidget {
  final Map<String, dynamic> booking;

  const BookingDetailScreen({super.key, required this.booking});

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  Map<String, dynamic> get booking => _booking;
  late Map<String, dynamic> _booking;

  @override
  void initState() {
    super.initState();
    _booking = Map<String, dynamic>.from(widget.booking);
    _loadFreshBooking();
  }

  double _parseNum(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  Future<void> _loadFreshBooking() async {
    final id = _booking['id'];
    if (id == null) return;
    if (_parseNum(_booking['service_price']) != 0 && _parseNum(_booking['total_amount']) != 0) return;
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

  String _statusText(String status) {
    switch (status) {
      case 'confirmed':
        return 'مؤكد';
      case 'pending':
        return 'قيد الانتظار';
      case 'completed':
        return 'مكتمل';
      case 'cancelled':
        return 'ملغي';
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
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          title: const Text('تفاصيل الحجز'),
          elevation: 0,
          scrolledUnderElevation: 2,
        ),
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context),
              Padding(
                padding: EdgeInsets.all(Responsive.spacing(context, 16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatusCard(context),
                    SizedBox(height: Responsive.spacing(context, 20)),
                    _buildSection(context, 'معلومات الحجز', [
                      if (booking['booking_number'] != null) _buildInfoRow('رقم الحجز', booking['booking_number'].toString()),
                      _buildInfoRow('التحليل', LocaleUtils.localizedName(booking, context.watch<AppSettingsProvider>().isArabic, arKey: 'service_name_ar', enKey: 'service_name_en')),
                      _buildInfoRow('المختبر', LocaleUtils.localizedName(booking, context.watch<AppSettingsProvider>().isArabic, arKey: 'provider_name_ar', enKey: 'provider_name_en')),
                      _buildInfoRow('التاريخ', DateFormatter.formatBookingDate(booking['booking_date']?.toString())),
                      _buildInfoRow('الوقت', DateFormatter.formatBookingTime(booking['booking_time']?.toString())),
                      _buildInfoRow('نوع الخدمة', booking['service_type'] == 'home_service' ? 'منزلي' : 'في المختبر'),
                      _buildInfoRow('الفرع', booking['branch_name']?.toString() ?? ''),
                    ]),
                    SizedBox(height: Responsive.spacing(context, 20)),
                    _buildBookingBreakdown(context),
                    SizedBox(height: Responsive.spacing(context, 20)),
                    if (booking['status'] == 'pending' || booking['status'] == 'confirmed') _buildActions(context),
                    if (booking['status'] == 'completed') _buildReviewSection(context),
                    SizedBox(height: Responsive.spacing(context, 40)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final logoUrl = ApiConfig.resolveImageUrl(booking['provider_logo_url'], booking['provider_logo']);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(Responsive.spacing(context, 16), Responsive.spacing(context, 20), Responsive.spacing(context, 16), Responsive.spacing(context, 24)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppTheme.primary.withValues(alpha: 0.85), AppTheme.primary],
        ),
      ),
      child: Column(
        children: [
          if (booking['booking_number'] != null)
            Text(
              booking['booking_number'].toString(),
              style: TextStyle(
                fontSize: Responsive.fontSize(context, 22),
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          SizedBox(height: Responsive.spacing(context, 12)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: (logoUrl != null && logoUrl.isNotEmpty)
                      ? CachedNetworkImage(
                          imageUrl: logoUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Icon(Icons.business_rounded, color: Colors.white, size: 28),
                          errorWidget: (_, __, ___) => Icon(Icons.business_rounded, color: Colors.white, size: 28),
                        )
                      : Icon(Icons.medical_services_rounded, color: Colors.white, size: 28),
                ),
              ),
              SizedBox(width: Responsive.spacing(context, 12)),
              Flexible(
                child: Text(
                  LocaleUtils.localizedName(booking, context.watch<AppSettingsProvider>().isArabic, arKey: 'provider_name_ar', enKey: 'provider_name_en'),
                  style: TextStyle(fontSize: Responsive.fontSize(context, 16), fontWeight: FontWeight.w600, color: Colors.white),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context) {
    final status = booking['status']?.toString() ?? 'pending';
    final paymentStatus = booking['payment_status']?.toString() ?? 'pending';
    return Container(
      padding: EdgeInsets.all(Responsive.spacing(context, 20)),
      decoration: AppTheme.cardDecorationFor(context),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('حالة الحجز', style: TextStyle(fontSize: Responsive.fontSize(context, 14), color: Theme.of(context).colorScheme.onSurfaceVariant)),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _statusColor(status).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(_statusText(status), style: TextStyle(color: _statusColor(status), fontWeight: FontWeight.bold, fontSize: Responsive.fontSize(context, 13))),
              ),
            ],
          ),
          SizedBox(height: Responsive.spacing(context, 14)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('حالة الدفع', style: TextStyle(fontSize: Responsive.fontSize(context, 14), color: Theme.of(context).colorScheme.onSurfaceVariant)),
              Row(
                children: [
                  Icon(
                    paymentStatus == 'paid' ? Icons.check_circle : Icons.schedule,
                    size: 18,
                    color: paymentStatus == 'paid' ? Colors.green : Colors.orange,
                  ),
                  SizedBox(width: 6),
                  Text(
                    paymentStatus == 'paid' ? 'مدفوع' : 'غير مدفوع',
                    style: TextStyle(color: paymentStatus == 'paid' ? Colors.green : Colors.orange, fontWeight: FontWeight.w600, fontSize: Responsive.fontSize(context, 13)),
                  ),
                ],
              ),
            ],
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

  Widget _buildBookingBreakdown(BuildContext context) {
    final summary = booking['summary'] is Map ? booking['summary'] as Map<String, dynamic> : null;
    final ps = booking['provider_service'];
    final psMap = ps is Map ? ps as Map<String, dynamic> : null;
    final isHomeService = booking['service_type'] == 'home_service';
    final meta = _parseMetadata(booking['metadata']);

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
      if (servicePrice == 0 && psMap != null) servicePrice = ApiConfig.priceFromMap(psMap);
      if (isHomeService && homeFee == 0 && psMap != null) homeFee = _parseNum(psMap['home_service_price']);
      if (discountAmount == 0) {
        discountAmount = _parseNum(meta?['platform_discount']);
        if (discountAmount == 0 && servicePrice > 0) {
          final rate = _parseNum(meta?['platform_discount_rate']);
          final multiplier = (rate > 0 && rate <= 1) ? rate : (rate > 1 ? rate / 100 : ApiConfig.globalDiscountPercent / 100);
          discountAmount = (servicePrice * multiplier).roundToDouble();
        }
      }
      totalAmount = _parseNum(booking['total_amount']);
      if (totalAmount == 0) {
        final base = servicePrice + (isHomeService ? homeFee : 0) - discountAmount;
        totalAmount = (base + vatAmount).roundToDouble();
      }
    }

    final rows = <Widget>[
      _buildInfoRow('سعر التحليل (في المختبر)', '${servicePrice.toStringAsFixed(2)} ر.س'),
      if (isHomeService) _buildInfoRow('رسوم الخدمة المنزلية (إضافي)', '+ ${homeFee.toStringAsFixed(2)} ر.س'),
      _buildInfoRow('خصم المنصة', '- ${discountAmount.toStringAsFixed(2)} ر.س'),
      _buildInfoRow('ضريبة القيمة المضافة', '+ ${vatAmount.toStringAsFixed(2)} ر.س'),
      Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Divider(height: 1, color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5))),
      _buildInfoRow('المبلغ الإجمالي', '${totalAmount.toStringAsFixed(2)} ر.س'),
    ];

    return _buildSection(context, 'تفاصيل الفاتورة', rows);
  }

  Widget _buildSection(BuildContext context, String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: Responsive.fontSize(context, 18), fontWeight: FontWeight.bold)),
        SizedBox(height: Responsive.spacing(context, 12)),
        Container(
          padding: EdgeInsets.all(Responsive.spacing(context, 18)),
          decoration: AppTheme.cardDecorationFor(context),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 14)),
          Flexible(child: Text(value, style: TextStyle(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface), textAlign: TextAlign.left, overflow: TextOverflow.ellipsis)),
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
        SizedBox(height: Responsive.spacing(context, 20)),
        _buildSection(context, 'التقييم', [
          if (hasReview) ...[
            Row(
              children: [
                RatingBarIndicator(
                  rating: (rev['rating'] is num ? rev['rating'] as num : 0).toDouble().clamp(0.0, 5.0),
                  itemCount: 5,
                  itemSize: 22,
                  itemBuilder: (_, __) => Icon(Icons.star_rounded, color: Colors.amber),
                ),
                SizedBox(width: 8),
                Text('${(rev['rating'] is num ? rev['rating'] as num : 0)}', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            if (rev['comment']?.toString().trim().isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(rev['comment'].toString(), style: TextStyle(fontSize: 14, color: AppTheme.onSurfaceVariant, height: 1.4)),
              ),
            SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _showReviewDialog(context),
              icon: Icon(Icons.edit, size: 18),
              label: Text('تعديل التقييم'),
              style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primary),
            ),
          ] else
            GradientFilledButtonIcon(
              onPressed: () => _showReviewDialog(context),
              icon: Icon(Icons.star_outline),
              label: Text('أضف تقييمك'),
              style: FilledButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 14)),
            ),
        ]),
      ],
    );
  }

  Future<void> _showReviewDialog(BuildContext context) async {
    final existingReview = booking['review'] is Map ? booking['review'] as Map<String, dynamic> : null;
    final initialRating = existingReview != null && existingReview['rating'] != null
        ? (existingReview['rating'] is num ? (existingReview['rating'] as num).toDouble() : 5.0).clamp(1.0, 5.0)
        : 5.0;
    var rating = initialRating.round();
    final commentText = existingReview?['comment']?.toString().trim() ?? '';
    final controller = TextEditingController(text: commentText);
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          decoration: BoxDecoration(
            color: Theme.of(ctx).colorScheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('تقييم الخدمة', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              SizedBox(height: 16),
              Center(
                child: RatingBar.builder(
                  initialRating: initialRating,
                  minRating: 1,
                  direction: Axis.horizontal,
                  allowHalfRating: false,
                  itemCount: 5,
                  itemSize: 40,
                  itemPadding: EdgeInsets.symmetric(horizontal: 4),
                  itemBuilder: (context, _) => Icon(Icons.star_rounded, color: Colors.amber),
                  onRatingUpdate: (v) => rating = v.round(),
                ),
              ),
              SizedBox(height: 20),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: 'تعليقك (اختياري)',
                  hintText: 'اكتب تجربتك...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                maxLines: 3,
              ),
              SizedBox(height: 24),
              GradientFilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 14)),
                child: Text('إرسال التقييم'),
              ),
            ],
          ),
        ),
      ),
    );
    final commentToSend = controller.text.trim().isEmpty ? null : controller.text.trim();
    controller.dispose();
    if (result != true || !mounted) return;
    final bid = booking['id'];
    if (bid == null) return;
    final bookingId = bid is int ? bid : int.parse(bid.toString());
    try {
      final reviewData = await Api.bookings.submitReview(bookingId, rating, comment: commentToSend);
      if (mounted) {
        final updated = Map<String, dynamic>.from(_booking);
        if (reviewData.isNotEmpty && reviewData['rating'] != null) {
          updated['review'] = reviewData;
        }
        try {
          final fresh = await Api.bookings.getBooking(bookingId);
          setState(() => _booking = _mergeBooking(updated, fresh));
        } catch (_) {
          if (updated['review'] != null) setState(() => _booking = updated);
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم إضافة التقييم بنجاح')));
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر إرسال التقييم')));
    }
  }

  Widget _buildActions(BuildContext context) {
    final paymentStatus = booking['payment_status']?.toString() ?? 'pending';
    final canPay = paymentStatus != 'paid';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (canPay)
          GradientFilledButtonIcon(
            onPressed: () => _openPayment(context),
            icon: const Icon(Icons.payment_rounded),
            label: const Text('ادفع الآن'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        if (canPay) SizedBox(height: Responsive.spacing(context, 10)),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _showCancelDialog(context),
                icon: const Icon(Icons.cancel_outlined, size: 20),
                label: const Text('إلغاء الحجز'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              ),
            ),
            SizedBox(width: Responsive.spacing(context, 12)),
            Expanded(
              child: GradientFilledButtonIcon(
                onPressed: () {},
                icon: const Icon(Icons.directions_rounded, size: 20),
                label: const Text('الوصول'),
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
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
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentWebViewScreen(paymentUrl: paymentUrl),
          ),
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('بعد إتمام الدفع حدّث الصفحة لرؤية حالة الدفع')));
        }
      } else {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? 'فشل إنشاء جلسة الدفع')));
      }
    } on ApiException catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر فتح الدفع: ${e.toString().split('\n').first}')));
    }
  }

  void _showCancelDialog(BuildContext context) {
    final reasonController = TextEditingController(text: 'إلغاء من المستخدم');
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('إلغاء الحجز'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('هل أنت متأكد من إلغاء هذا الحجز؟'),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                decoration: InputDecoration(
                  labelText: 'سبب الإلغاء (اختياري)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('لا')),
            TextButton(
              onPressed: () async {
                final id = booking['id'];
                final reason = reasonController.text.trim().isEmpty ? 'إلغاء من المستخدم' : reasonController.text.trim();
                Navigator.pop(ctx);
                try {
                  if (id != null) {
                    await Api.bookings.cancel(id is int ? id : int.parse(id.toString()), reason);
                  }
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إلغاء الحجز')));
                  }
                } on ApiException catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                }
              },
              child: const Text('نعم، إلغاء', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }
}
