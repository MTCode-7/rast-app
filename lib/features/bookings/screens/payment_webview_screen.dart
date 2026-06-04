import 'package:flutter/material.dart';
import 'package:rast/core/api/api_services.dart';
import 'package:rast/core/theme/app_theme.dart';
import 'package:rast/core/widgets/gradient_button.dart';
import 'package:rast/core/utils/responsive.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// شاشة الدفع داخل التطبيق - تعرض صفحة الدفع في WebView
class PaymentWebViewScreen extends StatefulWidget {
  final String paymentUrl;

  /// لمزامنة حالة الدفع بعد الإغلاق: `GET /api/bookings/{id}/payment/status`
  final int? bookingId;

  /// دفع طلب السلة: `GET /api/cart-orders/{id}/payment/status`
  final int? cartOrderId;

  const PaymentWebViewScreen({
    super.key,
    required this.paymentUrl,
    this.bookingId,
    this.cartOrderId,
  });

  @override
  State<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<PaymentWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String? _error;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _isLoading = true),
          onPageFinished: (_) => setState(() => _isLoading = false),
          onWebResourceError: (e) {
            if (e.errorType == WebResourceErrorType.hostLookup ||
                e.errorType == WebResourceErrorType.connect ||
                e.errorType == WebResourceErrorType.timeout) {
              setState(() => _error = 'تحقق من الاتصال بالإنترنت');
            }
          },
        ),
      );
    try {
      _controller.loadRequest(Uri.parse(widget.paymentUrl));
    } catch (e) {
      setState(() => _error = 'تعذر تحميل صفحة الدفع');
    }
  }

  Future<void> _finish({required bool userConfirmedPaid}) async {
    if (_syncing) return;
    if (widget.bookingId == null) {
      if (!mounted) return;
      Navigator.pop(context, userConfirmedPaid);
      return;
    }
    setState(() => _syncing = true);
    var paid = userConfirmedPaid;
    try {
      if (widget.cartOrderId != null) {
        final status = await Api.cart.getPaymentStatus(widget.cartOrderId!);
        if (status['payment_status']?.toString() == 'paid') {
          paid = true;
        }
      } else if (widget.bookingId != null) {
        final status = await Api.bookings.getPaymentStatus(widget.bookingId!);
        final paymentStatus = status['payment_status']?.toString();
        final bookingStatus = status['booking_status']?.toString();
        if (paymentStatus == 'paid' || bookingStatus == 'confirmed') {
          paid = true;
        }
      }
    } catch (_) {}
    if (!mounted) return;
    Navigator.pop(context, paid);
  }

  void _showExitDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إلغاء الدفع؟'),
        content: const Text('هل تريد الخروج من صفحة الدفع؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('متابعة الدفع'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _finish(userConfirmedPaid: false);
            },
            child: const Text('خروج'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          title: const Text('الدفع الإلكتروني'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new),
            onPressed: _showExitDialog,
          ),
          actions: [
            TextButton.icon(
              onPressed: () async {
                final uri = Uri.parse(widget.paymentUrl);
                try {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } catch (_) {}
              },
              icon: const Icon(Icons.open_in_browser, size: 20),
              label: const Text('المتصفح'),
            ),
            TextButton.icon(
              onPressed: _syncing
                  ? null
                  : () => _finish(userConfirmedPaid: true),
              icon: _syncing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_outline, size: 20),
              label: const Text('تم الدفع'),
            ),
          ],
        ),
        body: _error != null
            ? _buildError()
            : Stack(
                children: [
                  WebViewWidget(controller: _controller),
                  if (_isLoading)
                    Container(
                      color: Colors.white,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(
                              color: AppTheme.primary,
                            ),
                            SizedBox(
                              height: Responsive.spacing(context, 16),
                            ),
                            Text(
                              'جاري تحميل صفحة الدفع...',
                              style: TextStyle(
                                fontSize: Responsive.fontSize(context, 14),
                                color: AppTheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.wifi_off,
              size: 64,
              color: AppTheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            SizedBox(height: Responsive.spacing(context, 16)),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: Responsive.fontSize(context, 16)),
            ),
            SizedBox(height: Responsive.spacing(context, 24)),
            GradientFilledButtonIcon(
              onPressed: () {
                setState(() => _error = null);
                _controller.loadRequest(Uri.parse(widget.paymentUrl));
              },
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}
