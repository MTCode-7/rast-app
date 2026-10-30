import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:rast/core/api/api_services.dart';
import 'package:rast/core/providers/app_settings_provider.dart';
import 'package:rast/features/analyses/detail_widgets/premium_detail.dart';
import 'package:rast/core/widgets/rast_kit.dart';
import 'package:rast/core/widgets/rast_motion.dart';
import 'package:rast/features/analyses/screens/service_detail_screen.dart';
import 'package:rast/features/lab_details/screens/lab_details_screen.dart';
import 'package:rast/features/loyalty/loyalty_config.dart';
import 'package:rast/features/offers/widgets/offer_card.dart';

/// تفاصيل العرض: صورة كبيرة، نسبة الخصم، عدّاد تنازلي حي حتى نهاية العرض، الهدية،
/// عدد المستفيدين، بطاقة المختبر، والتحاليل المشمولة مع زر حجز لكل منها.
class OfferDetailScreen extends StatefulWidget {
  const OfferDetailScreen({super.key, required this.offer});

  final Map<String, dynamic> offer;

  @override
  State<OfferDetailScreen> createState() => _OfferDetailScreenState();
}

class _OfferDetailScreenState extends State<OfferDetailScreen> {
  late Map<String, dynamic> _offer = widget.offer;
  Timer? _timer;
  Duration _left = Duration.zero;
  int _tab = 0;
  bool _collapsed = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      final c = _scrollController.offset > 205;
      if (c != _collapsed) setState(() => _collapsed = c);
    });
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _refresh();
  }

  Future<void> _refresh() async {
    final id = numOf(_offer['id'])?.toInt();
    if (id == null) return;
    try {
      final fresh = await Api.growth.offer(id);
      if (mounted && fresh.isNotEmpty) setState(() => _offer = fresh);
    } catch (_) {}
  }

  void _tick() {
    final end = OfferView(_offer).endsAt;
    if (end == null || !mounted) return;
    final left = end.difference(DateTime.now());
    setState(() => _left = left.isNegative ? Duration.zero : left);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _book(Map<String, dynamic> item) {
    final o = OfferView(_offer);
    final p = o.provider;
    final lang = context.read<AppSettingsProvider>().language;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ServiceDetailScreen(
          service: {
            'id': item['service_id'],
            'name_ar': item['name_ar'],
            'name_en': item['name_en'],
            'image_url': item['image_url'],
            'service_type': item['is_package'] == true ? 'package' : 'single',
          },
          labId: numOf(p?['id'])?.toInt(),
          labName: o.providerName(lang),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();
    final lang = settings.language;
    final o = OfferView(_offer);
    final items = o.items;
    final best = o.bestPrice;
    final description = o.description(lang)?.trim() ?? '';
    final cheapestItem = items.isEmpty
        ? null
        : ([...items]..sort((a, b) => (numOf(a['final_price']) ?? 0).compareTo(numOf(b['final_price']) ?? 0))).first;

    return Directionality(
      textDirection: settings.textDirection,
      child: Scaffold(
        backgroundColor: RastTokens.bg(context),
        bottomNavigationBar: cheapestItem == null
            ? null
            : RastStickyBar(
                child: Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RastPrice(amount: best.price, oldAmount: best.old, lang: lang, size: 19, from: items.length > 1),
                          if (o.provider != null)
                            Text(
                              o.providerName(lang),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11.5, color: RastTokens.muted(context), fontWeight: FontWeight.w600),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 6,
                      child: RastButton(
                        label: L(lang, 'احجز العرض', 'Book this deal'),
                        icon: Icons.event_available_rounded,
                        onPressed: () => _book(cheapestItem),
                      ),
                    ),
                  ],
                ),
              ),
        body: CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            PremiumHeroAppBar(
              title: o.title(lang),
              collapsed: _collapsed,
              onBack: () => Navigator.pop(context),
              image: PremiumHeroImage(url: o.imageUrl, fallbackIcon: Icons.local_offer_rounded),
              onShare: numOf(_offer['id']) == null
                  ? null
                  : () => shareViaWhatsApp(
                        '${o.title(lang)} — ${L(lang, 'عرض على راست لابس', 'Deal on Rast Labs')}\n'
                        'https://rast-labs.com/offers/${numOf(_offer['id'])!.toInt()}',
                      ),
              overlay: o.percent > 0
                  ? PositionedDirectional(
                      bottom: 42,
                      start: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: RastTokens.danger,
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: [
                            BoxShadow(color: RastTokens.danger.withValues(alpha: 0.4), blurRadius: 14, offset: const Offset(0, 6)),
                          ],
                        ),
                        child: Text(
                          L(lang, 'وفّر ${o.percent}%', 'Save ${o.percent}%'),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
                        ),
                      ).animate().scale(begin: const Offset(0.6, 0.6), curve: Curves.elasticOut, duration: 700.ms),
                    )
                  : null,
            ),
            // رأس اللوحة: العنوان، السعر الكبير، الشارات، العدّاد، الهدية، والمختبر
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(RastTokens.gutter, 2, RastTokens.gutter, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        RastPill(label: L(lang, 'عرض', 'Deal'), icon: Icons.local_offer_rounded, color: RastTokens.danger, dense: true),
                        if (o.featured) ...[
                          const SizedBox(width: 6),
                          RastPill(icon: Icons.bolt_rounded, label: L(lang, 'مميز', 'Hot'), color: RastTokens.gold, dense: true),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      o.title(lang),
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, height: 1.3, color: RastTokens.ink(context)),
                    ),
                    const SizedBox(height: 16),
                    PremiumPriceBlock(
                      amount: best.price,
                      oldAmount: best.old,
                      lang: lang,
                      from: items.length > 1,
                      trailing: o.bookings > 0
                          ? RastPill(
                              icon: Icons.groups_rounded,
                              label: L(lang, 'استفاد ${o.bookings}', '${o.bookings} booked'),
                              color: RastTokens.info,
                            )
                          : null,
                    ),
                    const SizedBox(height: 10),
                    EarnPointsBadge(amount: best.price, lang: lang, dense: false),
                    const SizedBox(height: 16),
                    _countdown(lang).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),
                    if (o.gift(lang) != null) ...[
                      const SizedBox(height: 12),
                      RastCard(
                        color: RastTokens.success.withValues(alpha: RastTokens.dark(context) ? 0.14 : 0.07),
                        child: Row(
                          children: [
                            const RastIconBox(icon: Icons.card_giftcard_rounded, color: RastTokens.success),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(L(lang, 'هدية مع العرض', 'Free gift'),
                                      style: const TextStyle(fontSize: 12, color: RastTokens.success, fontWeight: FontWeight.w700)),
                                  Text(o.gift(lang)!,
                                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: RastTokens.ink(context))),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (o.provider != null) ...[
                      const SizedBox(height: 12),
                      _labCard(o, lang),
                    ],
                  ],
                ),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: PremiumTabsHeader(
                tabs: [
                  items.length > 1
                      ? L(lang, 'الخدمات (${items.length})', 'Services (${items.length})')
                      : L(lang, 'الخدمة المشمولة', 'Included service'),
                  L(lang, 'التفاصيل', 'Details'),
                ],
                index: _tab,
                dark: RastTokens.dark(context),
                onChanged: (i) => setState(() => _tab = i),
              ),
            ),
            SliverToBoxAdapter(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
                child: KeyedSubtree(
                  key: ValueKey('otab-$_tab'),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(RastTokens.gutter, 10, RastTokens.gutter, 24),
                    child: _tab == 0
                        ? Column(
                            children: [
                              for (var i = 0; i < items.length; i++)
                                Padding(padding: const EdgeInsets.only(bottom: 10), child: _itemRow(items[i], lang).entrance(i)),
                            ],
                          )
                        : _detailsTab(o, description, lang),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// تبويب «التفاصيل»: وصف العرض ومدته
  Widget _detailsTab(OfferView o, String description, String lang) {
    final start = _offer['start_date']?.toString();
    final end = _offer['end_date']?.toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (description.isNotEmpty)
          PremiumTextBlock(icon: Icons.description_rounded, title: L(lang, 'تفاصيل العرض', 'About this deal'), text: description),
        if (start != null || end != null) ...[
          if (description.isNotEmpty) const SizedBox(height: 12),
          RastCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (start != null)
                  RastInfoRow(icon: Icons.play_circle_outline_rounded, label: L(lang, 'يبدأ', 'Starts'), value: start, color: RastTokens.success),
                if (start != null && end != null) Divider(height: 22, color: RastTokens.line(context)),
                if (end != null)
                  RastInfoRow(icon: Icons.event_busy_rounded, label: L(lang, 'ينتهي', 'Ends'), value: end, color: RastTokens.danger),
              ],
            ),
          ).entrance(1),
        ],
      ],
    );
  }

  Widget _countdown(String lang) {
    final d = _left;
    if (OfferView(_offer).endsAt == null) return const SizedBox.shrink();
    final urgent = d.inHours < 48;
    Widget box(int v, String label) => Expanded(
          child: Column(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (c, a) => SlideTransition(
                  position: Tween(begin: const Offset(0, -0.4), end: Offset.zero).animate(a),
                  child: FadeTransition(opacity: a, child: c),
                ),
                child: Text(v.toString().padLeft(2, '0'),
                    key: ValueKey(v),
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
              ),
              Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11)),
            ],
          ),
        );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: urgent
            ? const LinearGradient(colors: [Color(0xFFE11D48), Color(0xFFF97316)])
            : RastTokens.brandGradient,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, color: Colors.white, size: 22),
          const SizedBox(width: 8),
          Text(L(lang, 'ينتهي خلال', 'Ends in'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          Expanded(
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Row(
                children: [
                  box(d.inDays, L(lang, 'يوم', 'd')),
                  box(d.inHours % 24, L(lang, 'ساعة', 'h')),
                  box(d.inMinutes % 60, L(lang, 'دقيقة', 'm')),
                  box(d.inSeconds % 60, L(lang, 'ثانية', 's')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _labCard(OfferView o, String lang) {
    final p = o.provider!;
    final rating = numOf(p['rating']) ?? 0;
    final area = [p['district'], p['city']].where((e) => (e?.toString() ?? '').isNotEmpty).join('، ');
    return RastCard(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LabDetailsScreen(lab: {
            'id': p['id'],
            'business_name_ar': p['name_ar'],
            'business_name_en': p['name_en'],
            'logo_url': p['logo_url'],
            'city': p['city'],
            'district': p['district'],
            'avg_rating': p['rating'],
            'total_reviews': p['reviews_count'],
            'home_service_available': p['home_service'],
          }),
        ),
      ),
      child: Row(
        children: [
          SizedBox(width: 54, height: 54, child: RastNetImage(url: p['logo_url']?.toString(), radius: 14, fit: BoxFit.contain, fallbackIcon: Icons.apartment_rounded)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(o.providerName(lang),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: RastTokens.ink(context))),
                const SizedBox(height: 3),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (rating > 0)
                      RastPill(icon: Icons.star_rounded, label: '${rating.toStringAsFixed(1)} (${p['reviews_count'] ?? 0})', color: RastTokens.gold, dense: true),
                    if (area.isNotEmpty) RastPill(icon: Icons.location_on_rounded, label: area, color: RastTokens.brand2, dense: true),
                    if (p['home_service'] == true)
                      RastPill(icon: Icons.home_rounded, label: L(lang, 'سحب منزلي', 'Home visit'), color: RastTokens.success, dense: true),
                  ],
                ),
              ],
            ),
          ),
          Icon(Directionality.of(context) == TextDirection.rtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
              color: RastTokens.muted(context)),
        ],
      ),
    );
  }

  Widget _itemRow(Map<String, dynamic> item, String lang) {
    final name = (lang == 'en' ? (item['name_en'] ?? item['name_ar']) : item['name_ar'])?.toString() ?? '';
    final pct = (numOf(item['discount_percentage']) ?? 0).round();
    return RastCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          SizedBox(width: 56, height: 56, child: RastNetImage(url: item['image_url']?.toString(), radius: 14)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: RastTokens.ink(context))),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Flexible(child: RastPrice(amount: numOf(item['final_price']), oldAmount: numOf(item['price']), lang: lang, size: 15)),
                    if (pct > 0) ...[
                      const SizedBox(width: 6),
                      RastPill(label: '-$pct%', color: RastTokens.danger, dense: true),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 76,
            child: RastButton(label: L(lang, 'احجز', 'Book'), height: 40, onPressed: () => _book(item)),
          ),
        ],
      ),
    );
  }
}
