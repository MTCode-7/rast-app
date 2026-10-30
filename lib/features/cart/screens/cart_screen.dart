import 'dart:ui' as ui show TextDirection;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rast/core/api/api_client.dart';
import 'package:rast/core/api/api_services.dart';
import 'package:rast/core/providers/app_settings_provider.dart';
import 'package:rast/core/services/cart_service.dart';
import 'package:rast/core/services/analytics_service.dart';
import 'package:rast/core/theme/app_theme.dart';
import 'package:rast/core/utils/date_formatter.dart';
import 'package:rast/core/utils/locale_utils.dart';
import 'package:rast/core/utils/responsive.dart';
import 'package:rast/core/widgets/gradient_button.dart';
import 'package:rast/core/widgets/rast_ui.dart';
import 'package:rast/features/auth/screens/login_screen.dart';
import 'package:rast/features/auth/services/auth_service.dart';
import 'package:rast/features/bookings/screens/payment_webview_screen.dart';

import '../../../core/constants/api_config.dart';
import '../../../core/constants/app_strings.dart';

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
    AnalyticsService.logScreen('cart');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final cart = context.read<CartService>();
      if (cart.hasItems) {
        AnalyticsService.logViewCart(value: cart.totalAmount, items: cart.analyticsItems);
      }
    });
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
    final cart = context.read<CartService>();
    setState(() {
      _checkingOut = true;
      _checkoutError = null;
    });
    try {
      // نحفظ عناصر السلة قبل إفراغها عند إنشاء الطلب
      final checkoutItems = cart.analyticsItems;
      await AnalyticsService.logCheckoutStarted(
        itemCount: cart.items.length,
        value: cart.totalAmount > 0 ? cart.totalAmount : null,
        items: checkoutItems,
      );
      final result = await Api.cart.checkout();
      final cartOrderId = result['id'];
      final id = cartOrderId is int
          ? cartOrderId
          : int.tryParse(cartOrderId?.toString() ?? '');
      if (id == null) throw ApiException('تعذر إنشاء طلب السلة');

      if (!mounted) return;
      // لا نفرّغ السلة هنا: تبقى محفوظة حتى ينجح الدفع (الخادم يحذف عناصرها عند الدفع فقط)

      final payRes = await Api.cart.createPaymentSession(id);
      final paymentUrl = payRes['payment_url']?.toString();
      if (paymentUrl == null || paymentUrl.isEmpty) {
        throw ApiException(
          payRes['message']?.toString() ?? 'فشل إنشاء جلسة الدفع',
        );
      }

      if (!mounted) return;
      final paid = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) =>
              PaymentWebViewScreen(paymentUrl: paymentUrl, cartOrderId: id),
        ),
      );

      if (!mounted) return;
      Map<String, dynamic>? status;
      try {
        status = await Api.cart.getPaymentStatus(id);
      } catch (_) {}

      final paymentStatus = status?['payment_status']?.toString();
      final isPaid = paid == true || paymentStatus == 'paid';

      if (isPaid) {
        final amount = _parseNum(status?['total_amount'] ?? result['total_amount']);
        await AnalyticsService.logPurchase(
          transactionId: 'cart_$id',
          value: amount > 0 ? amount : null,
          itemCount: result['items_count'] is int
              ? result['items_count'] as int
              : null,
          items: checkoutItems,
        );
      }

      if (!mounted) return;
      // نحدّث السلة من الخادم: تفرغ بعد الدفع الناجح، وتبقى كما هي إن لم يكتمل
      await context.read<CartService>().refresh(silent: true);
      if (!mounted) return;

      if (!isPaid) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لم يكتمل الدفع. سلتك محفوظة ويمكنك المحاولة مرة أخرى.')),
        );
        return;
      }

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _clearCart() async {
    final settings = context.read<AppSettingsProvider>();
    final lang = settings.language;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return Directionality(
          textDirection: settings.textDirection,
          child: AlertDialog(
            title: Text(AppStrings.t('clearCartQuestion', lang)),
            content: Text(AppStrings.t('clearCartMessage', lang)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(AppStrings.t('cancel', lang)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(AppStrings.t('clear', lang)),
              ),
            ],
          ),
        );
      },
    );

    if (ok != true || !mounted) return;

    await context.read<CartService>().clearCart();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();
    final lang = settings.language;
    final isArabic = settings.isArabic;
    if (!AuthService.isLoggedIn) {
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
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              child: Container(
                color: RastUi.screenSurface(context),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.login_rounded,
                          size: 64,
                          color: AppTheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(AppStrings.t('cartSignInPrompt', lang)),
                        const SizedBox(height: 20),
                        GradientFilledButtonIcon(
                          onPressed: () async {
                            final logged = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LoginScreen(),
                              ),
                            );
                            if (logged == true && mounted) setState(() {});
                          },
                          icon: const Icon(Icons.login),
                          label: Text(AppStrings.t('signIn', lang)),
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
    final items = cart.items;
    final summary = cart.summary;
    final provider = cart.provider;

    return Directionality(
      textDirection: settings.textDirection,
      child: Container(
        decoration: const BoxDecoration(gradient: RastUi.headerGradient),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: RastTopBar(
            title: AppStrings.t('cart', lang),
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
                              padding: EdgeInsets.all(
                                Responsive.spacing(context, 16),
                              ),
                              itemCount: items.length,
                              separatorBuilder: (_, __) => SizedBox(
                                height: Responsive.spacing(context, 10),
                              ),
                              itemBuilder: (context, index) {
                                final item = items[index] is Map
                                    ? Map<String, dynamic>.from(
                                        items[index] as Map,
                                      )
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
    final lang = context.watch<AppSettingsProvider>().language;
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
              AppStrings.t('cartEmpty', lang),
              style: TextStyle(
                fontSize: Responsive.fontSize(context, 18),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppStrings.t('cartEmptyDescription', lang),
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderHeader(Map<String, dynamic> provider, bool isArabic) {
    final lang = context.watch<AppSettingsProvider>().language;
    final name = LocaleUtils.localizedName(
      provider,
      isArabic,
      arKey: 'business_name_ar',
      enKey: 'business_name_en',
    );

    final imageUrl = ApiConfig.resolveImageUrl(
      provider['logo_url'],
      provider['logo'],
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: RastUi.cardSurface(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: RastUi.softBorder(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 18,
            spreadRadius: 0,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // LAB IMAGE
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: AppTheme.primary.withValues(alpha: 0.08),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => const Center(
                        child: Icon(
                          Icons.business_rounded,
                          color: AppTheme.primary,
                          size: 28,
                        ),
                      ),
                      errorWidget: (_, __, ___) => const Center(
                        child: Icon(
                          Icons.business_rounded,
                          color: AppTheme.primary,
                          size: 28,
                        ),
                      ),
                    )
                  : const Center(
                      child: Icon(
                        Icons.business_rounded,
                        color: AppTheme.primary,
                        size: 28,
                      ),
                    ),
            ),
          ),

          const SizedBox(width: 12),

          // LAB INFO
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: RastUi.primaryText(context),
                    fontSize: Responsive.fontSize(context, 14),
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  AppStrings.t('singleLabCart', lang),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 11),
                    color: AppTheme.onSurfaceVariant,
                  ),
                ),
              ],
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
    final lang = context.watch<AppSettingsProvider>().language;
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
            _summaryRow(
              AppStrings.t('platformDiscount', lang),
              '- ${discount.toStringAsFixed(2)} '
              '${AppStrings.t('sar', lang)}',
            ),
          if (homeFee > 0)
            _summaryRow(
              AppStrings.t('homeServiceFee', lang),
              '+ ${homeFee.toStringAsFixed(2)} '
              '${AppStrings.t('sar', lang)}',
            ),
          if (vat > 0)
            _summaryRow(
              AppStrings.t('vat', lang),
              '+ ${vat.toStringAsFixed(2)} '
              '${AppStrings.t('sar', lang)}',
            ),
          _summaryRow(
            AppStrings.t(
              'cartTotal',
              lang,
            ).replaceFirst('%d', cart.itemsCount.toString()),
            '${total.toStringAsFixed(2)} '
            '${currency == 'SAR' ? AppStrings.t('sar', lang) : currency}',
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
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(
                    color: AppTheme.error.withValues(alpha: 0.12),
                  ),
                ),
                child: IconButton(
                  onPressed: cart.isLoading ? null : _clearCart,
                  tooltip: AppStrings.t('clearCart', lang),
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppTheme.error,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: _checkingOut || cart.isLoading
                        ? null
                        : RastUi.brandGradient,
                    color: _checkingOut || cart.isLoading
                        ? AppTheme.onSurfaceVariant.withValues(alpha: 0.25)
                        : null,
                    borderRadius: BorderRadius.circular(17),
                    boxShadow: _checkingOut || cart.isLoading
                        ? null
                        : [
                            BoxShadow(
                              color: AppTheme.primary.withValues(alpha: 0.28),
                              blurRadius: 16,
                              offset: const Offset(0, 7),
                            ),
                          ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _checkingOut || cart.isLoading ? null : _checkout,
                      borderRadius: BorderRadius.circular(17),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: Center(
                          child: _checkingOut
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.3,
                                    color: Colors.white,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.lock_outline_rounded,
                                      color: Colors.white,
                                      size: 19,
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        AppStrings.t('checkoutAndPay', lang),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: Responsive.fontSize(
                                            context,
                                            14,
                                          ),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(
                                      Icons.arrow_forward_rounded,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
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
    final settings = context.watch<AppSettingsProvider>();
    final lang = settings.language;
    final service = item['service'] is Map
        ? item['service'] as Map<String, dynamic>
        : <String, dynamic>{};
    final providerService = item['provider_service'] is Map
        ? Map<String, dynamic>.from(item['provider_service'] as Map)
        : <String, dynamic>{};
    final imageUrl = ApiConfig.analysisImageUrl(service, providerService);
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
    final period = isArabic
        ? timeSlot['period_label_ar']?.toString().trim()
        : (timeSlot['period_label_en'] ?? timeSlot['period_label_ar'])
              ?.toString()
              .trim();
    final serviceType = item['service_type']?.toString() == 'home_service'
        ? AppStrings.t('homeService', lang)
        : AppStrings.t('labService', lang);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: RastUi.cardSurface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: RastUi.softBorder(context).withValues(alpha: 0.65),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.065),
            blurRadius: 18,
            spreadRadius: 0,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // TEST / PACKAGE IMAGE
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: AppTheme.primary.withValues(alpha: 0.08),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => const Center(
                        child: Icon(
                          Icons.medical_services_rounded,
                          color: AppTheme.primary,
                          size: 28,
                        ),
                      ),
                      errorWidget: (_, __, ___) => const Center(
                        child: Icon(
                          Icons.medical_services_rounded,
                          color: AppTheme.primary,
                          size: 28,
                        ),
                      ),
                    )
                  : const Center(
                      child: Icon(
                        Icons.medical_services_rounded,
                        color: AppTheme.primary,
                        size: 28,
                      ),
                    ),
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? AppStrings.t('analysis', lang) : name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                // لمن هذا التحليل (يسمح بنفس التحليل لأكثر من شخص)
                if ((item['patient_display_name']?.toString() ?? '').isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${AppStrings.t('bookingForShort', lang)} ${item['patient_display_name']}',
                    style: const TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w600),
                  ),
                ],
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
                  '${total.toStringAsFixed(2)} '
                  '${AppStrings.t('sar', lang)}',
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(50),
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.error.withValues(alpha: 0.12),
                ),
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                size: 19,
                color: AppTheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
