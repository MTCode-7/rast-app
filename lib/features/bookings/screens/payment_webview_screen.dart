import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:rast/core/providers/app_settings_provider.dart';
import 'package:rast/core/services/analytics_service.dart';
import 'package:rast/core/api/api_services.dart';
import 'package:rast/core/widgets/rast_kit.dart';
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
  int _progress = 0;
  String? _error;
  bool _syncing = false;

  String get _lang => context.read<AppSettingsProvider>().language;

  /// البوابة تعيد المستخدم إلى `.../payment/return` بعد إتمام الدفع أو فشله
  bool _isReturnUrl(String url) => url.contains('/payment/return');

  @override
  void initState() {
    super.initState();
    AnalyticsService.logScreen('payment');
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            if (_isReturnUrl(request.url)) {
              _finish();
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onPageStarted: (url) {
            if (_isReturnUrl(url)) {
              _finish();
              return;
            }
            setState(() => _isLoading = true);
          },
          onProgress: (p) {
            if (mounted) setState(() => _progress = p);
          },
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

  /// يعيد true فقط إذا أكّد الخادم الدفع (لا نعتمد على ضغط المستخدم «تم الدفع»)
  Future<bool> _serverConfirmsPaid() async {
    try {
      if (widget.cartOrderId != null) {
        final status = await Api.cart.getPaymentStatus(widget.cartOrderId!);
        return status['payment_status']?.toString() == 'paid';
      }
      if (widget.bookingId != null) {
        final status = await Api.bookings.getPaymentStatus(widget.bookingId!);
        return status['payment_status']?.toString() == 'paid' ||
            status['booking_status']?.toString() == 'confirmed';
      }
    } catch (_) {}
    return false;
  }

  Future<void> _finish({bool retry = true}) async {
    if (_syncing) return;
    setState(() => _syncing = true);
    // إشعار البوابة قد يتأخر ثوانٍ عن عودة المستخدم، فنعيد التحقق قليلاً
    var paid = await _serverConfirmsPaid();
    for (var i = 0; !paid && retry && i < 2; i++) {
      await Future<void>.delayed(const Duration(seconds: 2));
      paid = await _serverConfirmsPaid();
    }
    if (!mounted) return;
    Navigator.pop(context, paid);
  }

  /// تأكيد لطيف قبل الخروج من منتصف الدفع (زر الرجوع في الشاشة أو في الجهاز)
  void _showExitDialog() {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: context.read<AppSettingsProvider>().textDirection,
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: EdgeInsets.fromLTRB(20, 22, 20, 16 + MediaQuery.paddingOf(ctx).bottom),
          decoration: BoxDecoration(
            color: RastTokens.card(ctx),
            borderRadius: BorderRadius.circular(26),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const RastIconBox(icon: Icons.payments_outlined, size: 56, color: RastTokens.warning),
              const SizedBox(height: 14),
              Text(
                L(_lang, 'الخروج من صفحة الدفع؟', 'Leave the payment page?'),
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: RastTokens.ink(ctx)),
              ),
              const SizedBox(height: 6),
              Text(
                L(
                  _lang,
                  'حجزك محفوظ، ويمكنك إكمال الدفع لاحقاً من «حجوزاتي». إن كنت أتممت الدفع سنتحقق منه تلقائياً.',
                  'Your booking is saved; you can pay later from My bookings. If you already paid, we will verify it automatically.',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, height: 1.6, color: RastTokens.muted(ctx)),
              ),
              const SizedBox(height: 18),
              RastButton(
                label: L(_lang, 'متابعة الدفع', 'Continue payment'),
                icon: Icons.lock_rounded,
                onPressed: () => Navigator.pop(ctx),
              ),
              const SizedBox(height: 10),
              RastButton(
                label: L(_lang, 'خروج', 'Leave'),
                secondary: true,
                onPressed: () {
                  Navigator.pop(ctx);
                  _finish(retry: false);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();
    final lang = settings.language;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_syncing) _showExitDialog();
      },
      child: Directionality(
        textDirection: settings.textDirection,
        child: Scaffold(
          backgroundColor: RastTokens.bg(context),
          appBar: AppBar(
            backgroundColor: RastTokens.card(context),
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            titleSpacing: 0,
            leading: IconButton(
              icon: Icon(Icons.close_rounded, color: RastTokens.ink(context)),
              tooltip: L(lang, 'إغلاق', 'Close'),
              onPressed: _syncing ? null : _showExitDialog,
            ),
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_rounded, size: 18, color: RastTokens.success),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    L(lang, 'الدفع', 'Payment'),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: RastTokens.ink(context)),
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: L(lang, 'فتح في المتصفح', 'Open in browser'),
                icon: Icon(Icons.open_in_browser_rounded, color: RastTokens.muted(context)),
                onPressed: () async {
                  final uri = Uri.parse(widget.paymentUrl);
                  try {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } catch (_) {}
                },
              ),
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: RastTokens.success,
                    backgroundColor: RastTokens.success.withValues(alpha: 0.1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  onPressed: _syncing ? null : () => _finish(),
                  icon: _syncing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle_rounded, size: 18),
                  label: Text(
                    L(lang, 'تم الدفع', 'I paid'),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(3),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: _isLoading || _syncing ? 1 : 0,
                child: LinearProgressIndicator(
                  minHeight: 3,
                  value: _syncing || _progress == 0 || _progress == 100 ? null : _progress / 100,
                  color: RastTokens.brand,
                  backgroundColor: RastTokens.brand.withValues(alpha: 0.08),
                ),
              ),
            ),
          ),
          body: _error != null
              ? _buildError()
              : Stack(
                  children: [
                    WebViewWidget(controller: _controller),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _isLoading && _progress < 60
                          ? Container(
                              key: const ValueKey('loading'),
                              color: RastTokens.bg(context),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 76,
                                      height: 76,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: RastTokens.success.withValues(alpha: 0.1),
                                      ),
                                      child: const Icon(Icons.shield_rounded, size: 38, color: RastTokens.success),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      L(lang, 'جاري تجهيز صفحة الدفع الآمنة…', 'Preparing the secure payment page…'),
                                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: RastTokens.ink(context)),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      L(lang, 'مدى · فيزا · ماستركارد · Apple Pay', 'mada · Visa · Mastercard · Apple Pay'),
                                      style: TextStyle(fontSize: 12, color: RastTokens.muted(context)),
                                    ),
                                    const SizedBox(height: 18),
                                    const SizedBox(
                                      width: 26,
                                      height: 26,
                                      child: CircularProgressIndicator(strokeWidth: 2.6, color: RastTokens.brand),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : const SizedBox.shrink(key: ValueKey('done')),
                    ),
                    if (_syncing)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.35),
                          child: Center(
                            child: RastCard(
                              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2.4, color: RastTokens.brand),
                                  ),
                                  const SizedBox(width: 14),
                                  Text(
                                    L(lang, 'نتحقق من حالة الدفع…', 'Verifying your payment…'),
                                    style: TextStyle(fontWeight: FontWeight.w700, color: RastTokens.ink(context)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: SingleChildScrollView(
        child: RastEmptyState(
          icon: Icons.wifi_off_rounded,
          color: RastTokens.danger,
          title: _error!,
          message: L(
            _lang,
            'حجزك محفوظ. تأكد من اتصالك بالإنترنت ثم أعد المحاولة.',
            'Your booking is saved. Check your connection and try again.',
          ),
          actionLabel: L(_lang, 'إعادة المحاولة', 'Try again'),
          onAction: () {
            setState(() => _error = null);
            _controller.loadRequest(Uri.parse(widget.paymentUrl));
          },
        ),
      ),
    );
  }
}
