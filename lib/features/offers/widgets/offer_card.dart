import 'package:flutter/material.dart';
import 'package:rast/core/widgets/rast_kit.dart';
import 'package:rast/core/widgets/rast_motion.dart';
import 'package:rast/features/loyalty/loyalty_config.dart';

/// قراءة موحّدة لبيانات العرض القادمة من /api/offers
class OfferView {
  OfferView(this.raw);

  final Map<String, dynamic> raw;

  int? get id => numOf(raw['id'])?.toInt();
  String title(String lang) => ((lang == 'en' ? raw['title_en'] : raw['title_ar']) ?? raw['title_ar'] ?? '').toString();
  String? description(String lang) => (lang == 'en' ? raw['description_en'] : raw['description_ar'])?.toString();
  String? gift(String lang) {
    final g = (lang == 'en' ? (raw['gift_en'] ?? raw['gift_ar']) : raw['gift_ar'])?.toString().trim();
    return g == null || g.isEmpty ? null : g;
  }

  String? get imageUrl => raw['image_url']?.toString();
  bool get featured => raw['is_featured'] == true;
  int get bookings => (numOf(raw['bookings_count']) ?? 0).toInt();
  int? get daysLeft => numOf(raw['days_left'])?.toInt();
  DateTime? get endsAt {
    final d = DateTime.tryParse(raw['end_date']?.toString() ?? '');
    return d == null ? null : DateTime(d.year, d.month, d.day, 23, 59, 59);
  }

  List<Map<String, dynamic>> get items =>
      (raw['items'] is List ? raw['items'] as List : const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

  Map<String, dynamic>? get provider => raw['provider'] is Map ? Map<String, dynamic>.from(raw['provider']) : null;

  String providerName(String lang) {
    final p = provider;
    if (p == null) return '';
    return ((lang == 'en' ? p['name_en'] : p['name_ar']) ?? p['name_ar'] ?? p['business_name_ar'] ?? '').toString();
  }

  String? get providerDistrict {
    final d = provider?['district']?.toString().trim();
    return d == null || d.isEmpty ? null : d;
  }

  double? get providerRating {
    final r = numOf(provider?['rating']);
    return r == null || r <= 0 ? null : r;
  }

  int get providerReviews => (numOf(provider?['reviews_count']) ?? 0).toInt();

  /// أفضل سعر (بعد الخصم) والسعر الأصلي المقابل لعرضهما على البطاقة
  ({double? price, double? old}) get bestPrice {
    if (items.isEmpty) return (price: null, old: null);
    final sorted = [...items]..sort((a, b) => (numOf(a['final_price']) ?? 0).compareTo(numOf(b['final_price']) ?? 0));
    final first = sorted.first;
    return (price: numOf(first['final_price']), old: numOf(first['price']));
  }

  int get percent {
    final p = numOf(raw['discount_percent']);
    if (p != null && p > 0) return p.round();
    final best = items.map((e) => numOf(e['discount_percentage']) ?? 0).fold<double>(0, (a, b) => a > b ? a : b);
    return best.round();
  }

  String endsLabel(String lang) {
    final d = daysLeft;
    if (d == null) return '';
    if (d <= 0) return L(lang, 'ينتهي اليوم', 'Ends today');
    if (d == 1) return L(lang, 'ينتهي غداً', 'Ends tomorrow');
    return L(lang, 'ينتهي خلال $d أيام', 'Ends in $d days');
  }
}

/// بطاقة عرض بنمطين:
/// - أفقي (بلا width): للقوائم — صورة 110 على جهة البداية، العنوان، شارة التقييم، المختبر والحي،
///   فاصل، ثم صف السعر (القديم مشطوب + نسبة الخصم) وزر السلة.
/// - عمودي (مع width): لشرائط الرئيسية وصفحة المختبر — صورة بعرض البطاقة وشارات فوقها.
class OfferCard extends StatelessWidget {
  const OfferCard({
    super.key,
    required this.offer,
    required this.lang,
    required this.onTap,
    this.width,
    this.onBook,
    this.grid = false,
  });

  final Map<String, dynamic> offer;
  final String lang;
  final VoidCallback onTap;

  /// بطاقة شبكة مدمجة (عمودان): صورة 4:3 وشارة الخصم، العنوان، المختبر، السعر. ارتفاعها من الخلية.
  final bool grid;

  /// عرض ثابت = النمط العمودي (للشرائط الأفقية)
  final double? width;

  /// زر السلة/الحجز في البطاقة (افتراضياً يفتح تفاصيل العرض)
  final VoidCallback? onBook;

  @override
  Widget build(BuildContext context) {
    final o = OfferView(offer);
    if (grid) return _grid(context, o);
    return width == null ? _horizontal(context, o) : _vertical(context, o);
  }

  // ---------------- نمط الشبكة ----------------

  Widget _grid(BuildContext context, OfferView o) {
    final price = o.bestPrice;
    final pct = o.percent;
    return RastCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      radius: 18,
      clip: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                RastNetImage(url: o.imageUrl, radius: 0, fallbackIcon: Icons.local_offer_rounded),
                if (pct > 0)
                  PositionedDirectional(
                    top: 8,
                    start: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: RastTokens.danger,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '-$pct%',
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    o.title(lang),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, height: 1.3, color: RastTokens.ink(context)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    o.providerName(lang),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: RastTokens.muted(context)),
                  ),
                  const Spacer(),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: AlignmentDirectional.bottomStart,
                          child: RastPrice(amount: price.price, oldAmount: price.old, lang: lang, size: 16),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Material(
                        color: RastTokens.brand,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: onBook ?? onTap,
                          child: const SizedBox(
                            width: 32,
                            height: 32,
                            child: Icon(Icons.add_shopping_cart_rounded, size: 17, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- النمط الأفقي (القوائم) ----------------

  Widget _horizontal(BuildContext context, OfferView o) {
    final price = o.bestPrice;
    final ends = o.endsLabel(lang);
    final urgent = (o.daysLeft ?? 99) <= 2;

    return RastCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 110,
                height: 110,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    RastNetImage(url: o.imageUrl, radius: 16, fallbackIcon: Icons.local_offer_rounded),
                    if (o.featured)
                      PositionedDirectional(
                        top: 6,
                        start: 6,
                        child: _featuredBadge(),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      o.title(lang),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, height: 1.4, color: RastTokens.ink(context)),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (o.providerRating != null) _ratingChip(context, o),
                        if (ends.isNotEmpty)
                          RastPill(
                            label: ends,
                            icon: Icons.timer_outlined,
                            color: urgent ? RastTokens.danger : RastTokens.info,
                            dense: true,
                          ),
                      ],
                    ),
                    if (o.gift(lang) != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.card_giftcard_rounded, size: 15, color: RastTokens.success),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              o.gift(lang)!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: RastTokens.success, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 6),
                    EarnPointsBadge(amount: price.price, lang: lang),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: RastTokens.line(context)),
          ),
          // المختبر والحي
          Row(
            children: [
              Icon(Icons.apartment_rounded, size: 15, color: RastTokens.brand.withValues(alpha: 0.8)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  o.providerName(lang),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: RastTokens.ink(context)),
                ),
              ),
              if (o.providerDistrict != null) ...[
                Text('  •  ', style: TextStyle(color: RastTokens.muted(context), fontSize: 12)),
                Flexible(
                  child: Text(
                    o.providerDistrict!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, color: RastTokens.muted(context)),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          // صف السعر
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: _priceRow(context, o, price, big: true)),
              if (o.bookings > 0) ...[
                Text(
                  L(lang, 'استفاد ${o.bookings}', '${o.bookings} booked'),
                  style: TextStyle(fontSize: 11, color: RastTokens.muted(context), fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 8),
              ],
              _cartButton(context),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------- النمط العمودي (الشرائط) ----------------

  Widget _vertical(BuildContext context, OfferView o) {
    final price = o.bestPrice;
    final ends = o.endsLabel(lang);
    final urgent = (o.daysLeft ?? 99) <= 2;

    return SizedBox(
      width: width,
      child: RastCard(
        onTap: onTap,
        padding: EdgeInsets.zero,
        clip: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              // 16:9 حتى تتسع البطاقة في الشرائط ذات الارتفاع الثابت مع عنوان بسطرين وهدية
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  RastNetImage(url: o.imageUrl, radius: 0, fallbackIcon: Icons.local_offer_rounded),
                  // تدرج سفلي خفيف لقراءة الشارات فوق الصورة
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.transparent, Color(0x66000000)],
                      ),
                    ),
                  ),
                  if (o.percent > 0)
                    PositionedDirectional(top: 10, start: 10, child: _percentBadge(o.percent)),
                  if (o.featured) PositionedDirectional(top: 10, end: 10, child: _featuredBadge()),
                  if (ends.isNotEmpty)
                    PositionedDirectional(
                      bottom: 8,
                      start: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (urgent ? RastTokens.danger : Colors.black).withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.timer_outlined, size: 12, color: Colors.white),
                            const SizedBox(width: 3),
                            Text(ends, style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    o.title(lang),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, height: 1.35, color: RastTokens.ink(context)),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Icon(Icons.apartment_rounded, size: 13, color: RastTokens.muted(context)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          [o.providerName(lang), if (o.providerDistrict != null) o.providerDistrict!].join(' • '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: RastTokens.muted(context)),
                        ),
                      ),
                      if (o.providerRating != null) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.star_rounded, size: 14, color: RastTokens.gold),
                        Text(
                          o.providerRating!.toStringAsFixed(1),
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: RastTokens.ink(context)),
                        ),
                      ],
                    ],
                  ),
                  if (o.gift(lang) != null) ...[
                    const SizedBox(height: 6),
                    RastPill(label: o.gift(lang)!, icon: Icons.card_giftcard_rounded, color: RastTokens.success, dense: true),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(child: _priceRow(context, o, price)),
                      _cartButton(context, size: 38),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(child: EarnPointsBadge(amount: price.price, lang: lang)),
                      if (o.bookings > 0)
                        Text(
                          L(lang, 'استفاد ${o.bookings}', '${o.bookings} booked'),
                          style: TextStyle(fontSize: 11, color: RastTokens.muted(context), fontWeight: FontWeight.w600),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- قطع مشتركة ----------------

  /// السعر بعد الخصم كبيراً، ثم القديم مشطوباً ونسبة الخصم بالأحمر
  Widget _priceRow(BuildContext context, OfferView o, ({double? price, double? old}) price, {bool big = false}) {
    if (price.price == null || price.price == 0) {
      return Text(
        L(lang, 'السعر عند الحجز', 'Price at booking'),
        style: TextStyle(fontSize: 12.5, color: RastTokens.muted(context), fontWeight: FontWeight.w600),
      );
    }
    final hasOld = price.old != null && price.old! > price.price!;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 2,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              fmtPrice(price.price),
              style: TextStyle(fontSize: big ? 19 : 17, fontWeight: FontWeight.w900, color: RastTokens.ink(context), height: 1.1),
            ),
            const SizedBox(width: 3),
            Text(L(lang, 'ر.س', 'SAR'),
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: RastTokens.ink(context))),
          ],
        ),
        if (hasOld)
          Text(
            fmtPrice(price.old),
            style: TextStyle(
              fontSize: 12.5,
              color: RastTokens.muted(context),
              decoration: TextDecoration.lineThrough,
              decorationColor: RastTokens.muted(context),
            ),
          ),
        if (o.percent > 0)
          Text(
            '${o.percent}%',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: RastTokens.danger),
          ),
      ],
    );
  }

  Widget _cartButton(BuildContext context, {double size = 44}) {
    return Pressable(
      onTap: onBook ?? onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: RastTokens.brandGradient,
          borderRadius: BorderRadius.circular(size * 0.32),
          boxShadow: [BoxShadow(color: RastTokens.brand.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Icon(Icons.add_shopping_cart_rounded, color: Colors.white, size: size * 0.5),
      ),
    );
  }

  Widget _ratingChip(BuildContext context, OfferView o) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: RastTokens.gold.withValues(alpha: RastTokens.dark(context) ? 0.2 : 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 13, color: RastTokens.gold),
          const SizedBox(width: 3),
          Text(
            o.providerRating!.toStringAsFixed(1),
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: RastTokens.ink(context)),
          ),
          if (o.providerReviews > 0)
            Text(
              ' (${o.providerReviews})',
              style: TextStyle(fontSize: 10.5, color: RastTokens.muted(context)),
            ),
        ],
      ),
    );
  }

  Widget _percentBadge(int percent) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: RastTokens.danger,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [BoxShadow(color: RastTokens.danger.withValues(alpha: 0.35), blurRadius: 8)],
        ),
        child: Text(L(lang, 'خصم $percent%', '$percent% OFF'),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
      );

  Widget _featuredBadge() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(color: RastTokens.gold, borderRadius: BorderRadius.circular(999)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bolt_rounded, size: 12, color: Colors.white),
            const SizedBox(width: 2),
            Text(L(lang, 'مميز', 'Hot'),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 10.5)),
          ],
        ),
      );
}
