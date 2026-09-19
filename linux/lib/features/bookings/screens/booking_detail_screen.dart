import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rast/core/constants/api_config.dart';
import 'package:rast/core/providers/app_settings_provider.dart';
import 'package:rast/core/utils/locale_utils.dart';
import 'package:rast/core/theme/app_theme.dart';
import 'package:rast/core/utils/date_formatter.dart';
import 'package:rast/core/api/api_services.dart';
import 'package:rast/core/api/api_client.dart';
import 'package:rast/core/utils/responsive.dart';
import 'package:rast/features/bookings/screens/payment_webview_screen.dart';

class BookingDetailScreen extends StatelessWidget {
  final Map<String, dynamic> booking;

  const BookingDetailScreen({super.key, required this.booking});

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
        backgroundColor: AppTheme.surface,
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
                      _buildInfoRow('المبلغ', '${booking['total_amount'] ?? 0} ر.س'),
                    ]),
                    SizedBox(height: Responsive.spacing(context, 20)),
                    if (booking['status'] == 'pending' || booking['status'] == 'confirmed') _buildActions(context),
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
      decoration: AppTheme.cardDecoration(),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('حالة الحجز', style: TextStyle(fontSize: Responsive.fontSize(context, 14), color: AppTheme.onSurfaceVariant)),
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
              Text('حالة الدفع', style: TextStyle(fontSize: Responsive.fontSize(context, 14), color: AppTheme.onSurfaceVariant)),
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

  Widget _buildSection(BuildContext context, String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: Responsive.fontSize(context, 18), fontWeight: FontWeight.bold)),
        SizedBox(height: Responsive.spacing(context, 12)),
        Container(
          padding: EdgeInsets.all(Responsive.spacing(context, 18)),
          decoration: AppTheme.cardDecoration(),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 14)),
            Flexible(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600), textAlign: TextAlign.left, overflow: TextOverflow.ellipsis)),
          ],
        ),
      );

  Widget _buildActions(BuildContext context) {
    final paymentStatus = booking['payment_status']?.toString() ?? 'pending';
    final canPay = paymentStatus != 'paid';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (canPay)
          FilledButton.icon(
            onPressed: () => _openPayment(context),
            icon: const Icon(Icons.payment_rounded),
            label: const Text('ادفع الآن'),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primary,
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
              child: FilledButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.directions_rounded, size: 20),
                label: const Text('الوصول'),
                style: FilledButton.styleFrom(backgroundColor: AppTheme.primary, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
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
