import 'dart:ui' as ui show TextDirection;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rast/core/api/api_client.dart';
import 'package:rast/core/api/api_services.dart';
import 'package:rast/core/providers/app_settings_provider.dart';
import 'package:rast/core/services/cart_service.dart';
import 'package:rast/core/theme/app_theme.dart';
import 'package:rast/core/utils/date_formatter.dart';
import 'package:rast/core/utils/locale_utils.dart';
import 'package:rast/core/utils/responsive.dart';
import 'package:rast/core/widgets/gradient_button.dart';
import 'package:rast/core/widgets/rast_ui.dart';
import 'package:rast/features/auth/screens/login_screen.dart';
import 'package:rast/features/auth/services/auth_service.dart';
import 'package:rast/features/bookings/screens/payment_webview_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  bool _checkingOut = false;
  String? _checkoutError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (AuthService.isLoggedIn) {
        context.read<CartService>().refresh();
      }
    });
  }

  double _parseNum(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  Future<void> _checkout() async {
    setState(() {
      _checkingOut = true;
      _checkoutError = null;
    });
    try {
      final result = await Api.cart.checkout();
      final cartOrderId = result['id'];
      final id = cartOrderId is int
          ? cartOrderId
          : int.tryParse(cartOrderId?.toString() ?? '');
      if (id == null) throw ApiException('تعذر إنشاء طلب السلة');

      if (!mounted) return;
      context.read<CartService>().clearLocal();

      final payRes = await Api.cart.createPaymentSession(id);
      final paymentUrl = payRes['payment_url']?.toString();
      if (paymentUrl == null || paymentUrl.isEmpty) {
        throw ApiException(payRes['message']?.toString() ?? 'فشل إنشاء جلسة الدفع');
      }

      if (!mounted) return;
      final paid = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentWebViewScreen(
            paymentUrl: paymentUrl,
            cartOrderId: id,
          ),
        ),
      );

      if (!mounted) return;
      Map<String, dynamic>? status;
      try {
        status = await Api.cart.getPaymentStatus(id);
      } catch (_) {}

      final paymentStatus = status?['payment_status']?.toString();
      final isPaid = paid == true || paymentStatus == 'paid';

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(isPaid ? 'تم الدفع بنجاح' : 'طلب السلة'),
          content: Text(
            isPaid
                ? 'تم تأكيد ${status?['bookings'] is List ? (status!['bookings'] as List).length : result['items_count'] ?? ''} حجز/حجوزات. يمكنك متابعتها من حجوزاتي.'
                : 'بعد إتمام الدفع راجع حجوزاتي لتأكيد الحجوزات.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: const Text('حسناً'),
            ),
          ],
        ),
      );
    } on ApiException catch (e) {
      setState(() => _checkoutError = e.message);
    } catch (e) {
      setState(() => _checkoutError = e.toString());
    } finally {
      if (mounted) setState(() => _checkingOut = false);
    }
  }

  Future<void> _removeItem(int itemId) async {
    try {
      await context.read<CartService>().removeItem(itemId);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  Future<void> _clearCart() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إفراغ السلة؟'),
        content: const Text('سيتم حذف جميع التحاليل من السلة.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('إفراغ'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await context.read<CartService>().clearCart();
  }

  @override
  Widget build(BuildContext context) {
    if (!AuthService.isLoggedIn) {
      return Directionality(
        textDirection: ui.TextDirection.rtl,
        child: Container(
          decoration: const BoxDecoration(gradient: RastUi.headerGradient),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: RastTopBar(title: 'السلة', onBack: () => Navigator.pop(context)),
            body: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              child: Container(
                color: RastUi.screenSurface(context),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.login_rounded, size: 64, color: AppTheme.primary),
                        const SizedBox(height: 16),
                        const Text('سجّل الدخول لعرض السلة'),
                        const SizedBox(height: 20),
                        GradientFilledButtonIcon(
                          onPressed: () async {
                            final logged = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(builder: (_) => const LoginScreen()),
                            );
                            if (logged == true && mounted) setState(() {});
                          },
                          icon: const Icon(Icons.login),
                          label: const Text('تسجيل الدخول'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final cart = context.watch<CartService>();
    final isArabic = context.watch<AppSettingsProvider>().isArabic;
    final items = cart.items;
    final summary = cart.summary;
    final provider = cart.provider;

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Container(
        decoration: const BoxDecoration(gradient: RastUi.headerGradient),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: RastTopBar(
            title: 'السلة',
            onBack: () => Navigator.pop(context),
          ),
          body: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: Container(
              color: RastUi.screenSurface(context),
              child: cart.isLoading && items.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : items.isEmpty
                  ? _buildEmpty(context)
                  : Column(
                      children: [
                        if (provider != null)
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              Responsive.spacing(context, 16),
                              Responsive.spacing(context, 16),
                              Responsive.spacing(context, 16),
                              0,
                            ),
                            child: _buildProviderHeader(provider, isArabic),
                          ),
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: () => cart.refresh(),
                            child: ListView.separated(
                              padding: EdgeInsets.all(Responsive.spacing(context, 16)),
                              itemCount: items.length,
                              separatorBuilder: (_, __) =>
                                  SizedBox(height: Responsive.spacing(context, 10)),
                              itemBuilder: (context, index) {
                                final item = items[index] is Map
                                    ? Map<String, dynamic>.from(items[index] as Map)
                                    : <String, dynamic>{};
                                return _CartItemTile(
                                  item: item,
                                  isArabic: isArabic,
                                  onRemove: () {
                                    final id = item['id'];
                                    final itemId = id is int
                                        ? id
                                        : int.tryParse(id?.toString() ?? '');
                                    if (itemId != null) _removeItem(itemId);
                                  },
                                );
                              },
                            ),
                          ),
                        ),
                        _buildSummaryFooter(context, summary, cart),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 72,
              color: AppTheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'السلة فارغة',
              style: TextStyle(
                fontSize: Responsive.fontSize(context, 18),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'أضف تحاليل من صفحة المختبر ثم أكمل الدفع مرة واحدة',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderHeader(Map<String, dynamic> provider, bool isArabic) {
    final name = LocaleUtils.localizedName(
      provider,
      isArabic,
      arKey: 'business_name_ar',
      enKey: 'business_name_en',
    );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: RastUi.cardSurface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: RastUi.softBorder(context)),
      ),
      child: Row(
        children: [
          const Icon(Icons.business_rounded, color: AppTheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            'مختبر واحد للسلة',
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryFooter(
    BuildContext context,
    Map<String, dynamic>? summary,
    CartService cart,
  ) {
    final discount = _parseNum(summary?['discount_amount']);
    final vat = _parseNum(summary?['vat_amount']);
    final homeFee = _parseNum(summary?['home_service_fee']);
    final total = _parseNum(summary?['total_amount']);
    final currency = summary?['currency']?.toString() ?? 'SAR';

    return Container(
      padding: EdgeInsets.fromLTRB(
        Responsive.spacing(context, 16),
        Responsive.spacing(context, 12),
        Responsive.spacing(context, 16),
        Responsive.spacing(context, 16) + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: RastUi.cardSurface(context),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (discount > 0)
            _summaryRow('خصم المنصة', '- ${discount.toStringAsFixed(2)} ر.س'),
          if (homeFee > 0)
            _summaryRow('رسوم المنزل', '+ ${homeFee.toStringAsFixed(2)} ر.س'),
          if (vat > 0)
            _summaryRow('الضريبة', '+ ${vat.toStringAsFixed(2)} ر.س'),
          _summaryRow(
            'المجموع (${cart.itemsCount} تحليل)',
            '${total.toStringAsFixed(2)} ${currency == 'SAR' ? 'ر.س' : currency}',
            bold: true,
          ),
          if (_checkoutError != null) ...[
            const SizedBox(height: 8),
            Text(
              _checkoutError!,
              style: const TextStyle(color: AppTheme.error, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
          SizedBox(height: Responsive.spacing(context, 10)),
          Row(
            children: [
              IconButton(
                onPressed: cart.isLoading ? null : _clearCart,
                icon: const Icon(Icons.delete_outline),
                tooltip: 'إفراغ السلة',
              ),
              Expanded(
                child: GradientFilledButton(
                  onPressed: _checkingOut || cart.isLoading ? null : _checkout,
                  child: _checkingOut
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('إتمام الطلب والدفع'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppTheme.onSurfaceVariant,
              fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
              color: bold ? AppTheme.primary : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _CartItemTile extends StatelessWidget {
  const _CartItemTile({
    required this.item,
    required this.isArabic,
    required this.onRemove,
  });

  final Map<String, dynamic> item;
  final bool isArabic;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final service = item['service'] is Map
        ? item['service'] as Map<String, dynamic>
        : <String, dynamic>{};
    final timeSlot = item['time_slot'] is Map
        ? item['time_slot'] as Map<String, dynamic>
        : <String, dynamic>{};
    final name = LocaleUtils.localizedName(
      service,
      isArabic,
      arKey: 'name_ar',
      enKey: 'name_en',
    );
    final lineTotal = item['line_total'] ?? item['pricing']?['total_amount'];
    final total = lineTotal is num
        ? lineTotal.toDouble()
        : double.tryParse(lineTotal?.toString() ?? '') ?? 0;
    final date = timeSlot['date']?.toString() ?? '';
    final period = timeSlot['period_label_ar']?.toString().trim();
    final serviceType = item['service_type']?.toString() == 'home_service'
        ? 'منزلية'
        : 'في المختبر';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: RastUi.cardSurface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: RastUi.softBorder(context)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? 'تحليل' : name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  '$serviceType · ${DateFormatter.formatBookingDate(date)}${period != null && period.isNotEmpty ? ' · $period' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${total.toStringAsFixed(2)} ر.س',
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded, size: 20),
            color: AppTheme.error,
          ),
        ],
      ),
    );
  }
}
