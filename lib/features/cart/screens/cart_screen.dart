
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:rast/core/api/api_client.dart';
import 'package:rast/core/services/app_events.dart';
import 'package:rast/core/widgets/rast_motion.dart';
import 'package:rast/core/widgets/rast_kit.dart';
import 'package:rast/features/analyses/screens/analyses_screen.dart';
import 'package:rast/features/lab_details/screens/lab_details_screen.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:rast/core/api/api_services.dart';
import 'package:rast/core/providers/app_settings_provider.dart';
import 'package:rast/core/services/cart_service.dart';
import 'package:rast/core/services/analytics_service.dart';
import 'package:rast/core/utils/date_formatter.dart';
import 'package:rast/core/utils/locale_utils.dart';
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
  final Set<int?> _removingIds = {};
  final Set<String> _animatedItemIds = {};
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

      AppEvents.notifyBookingsChanged();
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

      Celebration.show(context);
      final count = status?['bookings'] is List ? (status!['bookings'] as List).length : result['items_count'] ?? '';
      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withValues(alpha: 0.45),
        transitionDuration: const Duration(milliseconds: 420),
        transitionBuilder: (_, anim, __, child) => ScaleTransition(
          scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: anim, child: child),
        ),
        pageBuilder: (ctx, _, __) => _PaymentSuccessDialog(
          message: 'تم تأكيد $count حجز/حجوزات. يمكنك متابعتها من حجوزاتي.',
          onDone: () {
            Navigator.pop(ctx);
            Navigator.pop(context);
          },
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
    if (_removingIds.contains(itemId)) return;
    HapticFeedback.lightImpact();
    // العنصر ينزلق ويختفي أولاً، ثم يُحذف من الخادم (ويعود مكانه إن فشل الحذف)
    setState(() => _removingIds.add(itemId));
    try {
      await Future.wait([
        Future<void>.delayed(const Duration(milliseconds: 280)),
        context.read<CartService>().removeItem(itemId),
      ]);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _removingIds.remove(itemId));
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
        textDirection: settings.textDirection,
        child: _shell(
          context,
          title: AppStrings.t('cart', lang),
          child: ListView(
            children: [
              const SizedBox(height: 60),
              RastEmptyState(
                icon: Icons.lock_person_rounded,
                title: AppStrings.t('cartSignInPrompt', lang),
                actionLabel: AppStrings.t('signIn', lang),
                onAction: () async {
                  final logged = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                  if (logged == true && mounted) setState(() {});
                },
              ),
            ],
          ),
        ),
      );
    }

    final cart = context.watch<CartService>();
    final items = cart.items;
    final summary = cart.summary;
    final provider = cart.provider;

    Widget body;
    if (cart.isLoading && items.isEmpty) {
      body = ListView.separated(
        padding: const EdgeInsets.all(RastTokens.gutter),
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => const _CartItemSkeleton(),
      );
    } else if (items.isEmpty) {
      body = _buildEmpty(context);
    } else {
      body = RefreshIndicator(
        color: RastTokens.brand,
        onRefresh: () => cart.refresh(),
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(RastTokens.gutter, RastTokens.gutter, RastTokens.gutter, 24),
          itemCount: items.length + (provider != null ? 1 : 0),
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, rawIndex) {
            if (provider != null && rawIndex == 0) {
              return _buildProviderHeader(provider, isArabic).entrance(0);
            }
            final index = provider != null ? rawIndex - 1 : rawIndex;
            final item = items[index] is Map
                ? Map<String, dynamic>.from(items[index] as Map)
                : <String, dynamic>{};
            final id = item['id'];
            final itemId = id is int ? id : int.tryParse(id?.toString() ?? '');
            final removing = _removingIds.contains(itemId);
            final tile = AnimatedSlide(
              offset: removing ? const Offset(0.35, 0) : Offset.zero,
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeInCubic,
              child: AnimatedOpacity(
                opacity: removing ? 0 : 1,
                duration: const Duration(milliseconds: 240),
                child: _CartItemTile(
                  item: item,
                  isArabic: isArabic,
                  onRemove: () {
                    if (itemId != null) _removeItem(itemId);
                  },
                ),
              ),
            );
            return _animatedItemIds.add('$itemId')
                ? KeyedSubtree(key: ValueKey('cart-$itemId'), child: tile.entrance(index + 1))
                : KeyedSubtree(key: ValueKey('cart-$itemId'), child: tile);
          },
        ),
      );
    }

    return Directionality(
      textDirection: settings.textDirection,
      child: _shell(
        context,
        title: AppStrings.t('cart', lang),
        subtitle: items.isEmpty
            ? null
            : AppStrings.t('cartItemsCount', lang).replaceAll('%d', '${cart.itemsCount}'),
        bottom: items.isEmpty ? null : _buildSummaryFooter(context, summary, cart),
        child: body,
      ),
    );
  }

  Widget _shell(
    BuildContext context, {
    required String title,
    String? subtitle,
    Widget? bottom,
    required Widget child,
  }) {
    return Scaffold(
      backgroundColor: RastTokens.bg(context),
      appBar: RastTopBar(
        title: title,
        onBack: () => Navigator.pop(context),
      ),
      bottomNavigationBar: bottom,
      body: Column(
        children: [
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_bag_outlined, color: RastTokens.brand, size: 16),
                  const SizedBox(width: 6),
                  Text(subtitle, style: TextStyle(color: RastTokens.muted(context), fontSize: 12.5, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    final lang = context.watch<AppSettingsProvider>().language;
    return ListView(
      children: [
        const SizedBox(height: 50),
        RastEmptyState(
          icon: Icons.shopping_cart_outlined,
          title: AppStrings.t('cartEmpty', lang),
          message: AppStrings.t('cartEmptyDescription', lang),
          actionLabel: L(lang, 'تصفّح التحاليل', 'Browse tests'),
          onAction: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AnalysesScreen()),
          ),
        ),
      ],
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
    final imageUrl = ApiConfig.resolveImageUrl(provider['logo_url'], provider['logo']);

    return RastCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          RastNetImage(url: imageUrl, width: 52, height: 52, radius: 14, fallbackIcon: Icons.apartment_rounded),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: RastTokens.ink(context), height: 1.3),
                ),
                const SizedBox(height: 4),
                RastPill(
                  label: AppStrings.t('singleLabCart', lang),
                  icon: Icons.info_outline_rounded,
                  color: RastTokens.brand2,
                  dense: true,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // إضافة تحليل آخر من نفس المختبر
          RastButton(
            label: L(lang, 'أضف', 'Add'),
            icon: Icons.add_rounded,
            secondary: true,
            expand: false,
            height: 40,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => LabDetailsScreen(lab: provider)),
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
    final subtotal = _parseNum(summary?['subtotal_amount']);
    final discount = _parseNum(summary?['discount_amount']);
    final vat = _parseNum(summary?['vat_amount']);
    final homeFee = _parseNum(summary?['home_service_fee']);
    final total = _parseNum(summary?['total_amount']);
    final currency = summary?['currency']?.toString() ?? 'SAR';
    final cur = currency == 'SAR' ? AppStrings.t('sar', lang) : currency;
    final busy = _checkingOut || cart.isLoading;

    return RastStickyBar(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (subtotal > 0 && (discount > 0 || vat > 0 || homeFee > 0))
            _summaryRow(L(lang, 'المجموع الفرعي', 'Subtotal'), '${fmtPrice(subtotal)} $cur'),
          if (discount > 0)
            _summaryRow(AppStrings.t('platformDiscount', lang), '- ${fmtPrice(discount)} $cur', color: RastTokens.success),
          if (homeFee > 0) _summaryRow(AppStrings.t('homeServiceFee', lang), '+ ${fmtPrice(homeFee)} $cur'),
          if (vat > 0) _summaryRow(AppStrings.t('vat', lang), '+ ${fmtPrice(vat)} $cur'),
          // الإجمالي يعدّ تصاعدياً/تنازلياً عند الحذف بدل أن يقفز فجأة
          TweenAnimationBuilder<double>(
            tween: Tween<double>(end: total),
            duration: const Duration(milliseconds: 650),
            curve: Curves.easeOutCubic,
            builder: (_, value, __) => Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      AppStrings.t('cartTotal', lang).replaceFirst('%d', cart.itemsCount.toString()),
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: RastTokens.ink(context)),
                    ),
                  ),
                  RastPrice(amount: double.parse(value.toStringAsFixed(2)), lang: lang, size: 20),
                ],
              ),
            ),
          ),
          if (_checkoutError != null) ...[
            const SizedBox(height: 8),
            Text(
              _checkoutError!,
              style: const TextStyle(color: RastTokens.danger, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Material(
                color: RastTokens.danger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: busy ? null : _clearCart,
                  child: Tooltip(
                    message: AppStrings.t('clearCart', lang),
                    child: const SizedBox(
                      width: 52,
                      height: 52,
                      child: Icon(Icons.delete_sweep_outlined, color: RastTokens.danger),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: RastButton(
                  label: AppStrings.t('checkoutAndPay', lang),
                  icon: Icons.lock_outline_rounded,
                  loading: _checkingOut,
                  onPressed: busy ? null : _checkout,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: RastTokens.muted(context))),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color ?? RastTokens.ink(context))),
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
    final name = LocaleUtils.localizedName(service, isArabic, arKey: 'name_ar', enKey: 'name_en');
    final total = numOf(item['line_total'] ?? item['pricing']?['total_amount']) ?? 0;
    final date = timeSlot['date']?.toString() ?? '';
    final period = isArabic
        ? timeSlot['period_label_ar']?.toString().trim()
        : (timeSlot['period_label_en'] ?? timeSlot['period_label_ar'])?.toString().trim();
    final isHome = item['service_type']?.toString() == 'home_service';
    final patient = item['patient_display_name']?.toString().trim() ?? '';
    final when = [
      DateFormatter.formatBookingDate(date),
      if (period != null && period.isNotEmpty) period,
    ].where((e) => e.isNotEmpty).join(' · ');

    return RastCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RastNetImage(url: imageUrl, width: 86, height: 86, radius: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? AppStrings.t('analysis', lang) : name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: RastTokens.ink(context), height: 1.3),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    RastPill(
                      label: isHome ? AppStrings.t('homeService', lang) : AppStrings.t('labService', lang),
                      icon: isHome ? Icons.home_rounded : Icons.apartment_rounded,
                      color: isHome ? RastTokens.success : RastTokens.brand2,
                      dense: true,
                    ),
                    // لمن هذا التحليل (يسمح بنفس التحليل لأكثر من شخص)
                    if (patient.isNotEmpty)
                      RastPill(
                        label: '${AppStrings.t('bookingForShort', lang)} $patient',
                        icon: Icons.person_outline_rounded,
                        dense: true,
                      ),
                  ],
                ),
                if (when.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.event_rounded, size: 14, color: RastTokens.muted(context)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          when,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: RastTokens.muted(context)),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                RastPrice(amount: total, lang: lang, size: 16),
              ],
            ),
          ),
          Material(
            color: RastTokens.danger.withValues(alpha: 0.08),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onRemove,
              child: const SizedBox(
                width: 36,
                height: 36,
                child: Icon(Icons.delete_outline_rounded, size: 19, color: RastTokens.danger),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CartItemSkeleton extends StatelessWidget {
  const _CartItemSkeleton();

  @override
  Widget build(BuildContext context) {
    return RastCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const RastSkeleton(width: 70, height: 70, radius: 16),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                RastSkeleton(height: 16),
                SizedBox(height: 8),
                RastSkeleton(width: 120, height: 14, radius: 999),
                SizedBox(height: 8),
                RastSkeleton(width: 80, height: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// نافذة نجاح الدفع: دائرة تنبض بعلامة صح، مع احتفال القصاصات خلفها
class _PaymentSuccessDialog extends StatelessWidget {
  const _PaymentSuccessDialog({required this.message, required this.onDone});

  final String message;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 320,
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          decoration: BoxDecoration(
            color: RastUi.cardSurface(context),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 30, offset: const Offset(0, 12)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF16A34A),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF16A34A).withValues(alpha: 0.35), blurRadius: 22, spreadRadius: 2),
                  ],
                ),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 50),
              )
                  .animate()
                  .scale(begin: const Offset(0.3, 0.3), duration: 600.ms, curve: Curves.elasticOut),
              const SizedBox(height: 18),
              Text(
                'تم الدفع بنجاح',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: RastUi.primaryText(context)),
              ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.3, end: 0),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, height: 1.6, color: RastUi.secondaryText(context)),
              ).animate().fadeIn(delay: 320.ms),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: GradientFilledButton(
                  onPressed: onDone,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('حسناً', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ).animate().fadeIn(delay: 420.ms).slideY(begin: 0.4, end: 0),
            ],
          ),
        ),
      ),
    );
  }
}
