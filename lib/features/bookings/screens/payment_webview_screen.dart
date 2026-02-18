import 'package:flutter/material.dart';
import 'package:rast/core/theme/app_theme.dart';
import 'package:rast/core/widgets/gradient_button.dart';
import 'package:rast/core/utils/responsive.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// شاشة الدفع داخل التطبيق - تعرض صفحة الدفع في WebView
class PaymentWebViewScreen extends StatefulWidget {
  final String paymentUrl;

  const PaymentWebViewScreen({
    super.key,
    required this.paymentUrl,
  });

  @override
  State<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<PaymentWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String? _error;

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
            onPressed: () => _showExitDialog(),
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
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.check_circle_outline, size: 20),
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
                            const CircularProgressIndicator(color: AppTheme.primary),
                            SizedBox(height: Responsive.spacing(context, 16)),
                            Text('جاري تحميل صفحة الدفع...', style: TextStyle(fontSize: Responsive.fontSize(context, 14), color: AppTheme.onSurfaceVariant)),
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
            Icon(Icons.wifi_off, size: 64, color: AppTheme.onSurfaceVariant.withValues(alpha: 0.6)),
            SizedBox(height: Responsive.spacing(context, 16)),
            Text(_error!, textAlign: TextAlign.center, style: TextStyle(fontSize: Responsive.fontSize(context, 16))),
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

  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('إغلاق صفحة الدفع؟'),
          content: const Text('إذا لم تُكمل الدفع بعد، يمكنك العودة لاحقاً من تفاصيل الحجز.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            GradientFilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context, false);
              },
              child: const Text('إغلاق'),
            ),
          ],
        ),
      ),
    );
  }
}
