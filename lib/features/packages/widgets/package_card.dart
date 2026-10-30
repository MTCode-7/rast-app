import 'package:flutter/material.dart';
import 'package:rast/core/constants/api_config.dart';
import 'package:rast/core/utils/locale_utils.dart';
import 'package:rast/core/widgets/rast_kit.dart';

/// بطاقة باقة: صورة عريضة مع شارة الخصم، الاسم، عدد التحاليل، المختبر (إن وُجد)، السعر وزر التفاصيل.
class PackageCard extends StatelessWidget {
  const PackageCard({
    super.key,
    required this.package,
    required this.lang,
    required this.isArabic,
    required this.onTap,
    this.grid = false,
  });

  final Map<String, dynamic> package;
  final String lang;
  final bool isArabic;
  final VoidCallback onTap;

  /// بطاقة شبكة مدمجة (عمودان): صورة 4:3 وشارة الخصم، الاسم، عدد التحاليل، السعر.
  final bool grid;

  Map<String, dynamic>? get _firstOffer {
    final ps = package['provider_services'];
    if (ps is List && ps.isNotEmpty && ps.first is Map) return Map<String, dynamic>.from(ps.first as Map);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final name = LocaleUtils.localizedName(package, isArabic);
    final other = (isArabic ? package['name_en'] : package['name_ar'])?.toString().trim() ?? '';
    final offer = _firstOffer;
    final price = numOf(package['final_price']) ?? ApiConfig.priceFromMap(package);

    // السعر قبل الخصم: من الباقة نفسها أو من عرض المختبر
    double? oldPrice = numOf(package['original_price']);
    if (oldPrice == null && offer != null) {
      final base = numOf(offer['price']);
      final fin = numOf(offer['final_price']);
      if (base != null && fin != null && base > fin) oldPrice = base;
    }
    final discount = (oldPrice != null && price > 0 && oldPrice > price)
        ? ((1 - price / oldPrice) * 100).round()
        : (numOf(offer?['discount_percentage'])?.round() ?? 0);

    final items = package['package_items'];
    final testsCount = numOf(package['tests_count'])?.round() ?? (items is List ? items.length : 0);

    final provider = package['provider'] is Map
        ? package['provider'] as Map
        : (offer?['provider'] is Map ? offer!['provider'] as Map : null);
    final labName = provider == null
        ? ''
        : (isArabic ? provider['business_name_ar'] : provider['business_name_en'] ?? provider['business_name_ar'])
                ?.toString()
                .trim() ??
            '';

    if (grid) {
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
                  RastNetImage(url: ApiConfig.packageImageUrl(package), radius: 0, fallbackIcon: Icons.inventory_2_outlined),
                  if (discount > 0)
                    PositionedDirectional(
                      top: 8,
                      start: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(color: RastTokens.danger, borderRadius: BorderRadius.circular(8)),
                        child: Text(
                          '-$discount%',
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
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, height: 1.3, color: RastTokens.ink(context)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        testsCountLabel(lang, testsCount),
                        if (labName.isNotEmpty) labName,
                      ].join(' · '),
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
                            child: RastPrice(amount: price > 0 ? price : null, oldAmount: oldPrice, lang: lang, size: 16),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(color: RastTokens.brand, borderRadius: BorderRadius.circular(10)),
                          child: Icon(
                            Directionality.of(context) == TextDirection.rtl ? Icons.arrow_back_rounded : Icons.arrow_forward_rounded,
                            size: 17,
                            color: Colors.white,
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

    return RastCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      clip: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 16 / 10,
            child: Stack(
              fit: StackFit.expand,
              children: [
                RastNetImage(
                  url: ApiConfig.packageImageUrl(package),
                  radius: 0,
                  fallbackIcon: Icons.inventory_2_outlined,
                ),
                // تدرّج خفيف أسفل الصورة حتى تبرز الشارات
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withValues(alpha: 0.25)],
                      stops: const [0.6, 1],
                    ),
                  ),
                ),
                if (discount > 0)
                  PositionedDirectional(
                    top: 10,
                    start: 10,
                    child: RastPill(
                      label: L(lang, 'خصم $discount%', '$discount% off'),
                      icon: Icons.local_offer_rounded,
                      color: RastTokens.danger,
                      filled: true,
                    ),
                  ),
                if (testsCount > 0)
                  PositionedDirectional(
                    bottom: 10,
                    start: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.biotech_rounded, size: 14, color: RastTokens.brand),
                          const SizedBox(width: 4),
                          Text(
                            testsCountLabel(lang, testsCount),
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: RastTokens.brand,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, height: 1.3, color: RastTokens.ink(context)),
                ),
                if (other.isNotEmpty && other != name)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      other,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: RastTokens.muted(context)),
                    ),
                  ),
                const SizedBox(height: 8),
                // معلومات هادئة كنص (بدل كومة شارات): المختبر • سحب عينة واحدة
                Row(
                  children: [
                    Icon(
                      labName.isNotEmpty ? Icons.apartment_rounded : Icons.water_drop_outlined,
                      size: 15,
                      color: RastTokens.brand.withValues(alpha: 0.8),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        [
                          if (labName.isNotEmpty) labName,
                          L(lang, 'سحب عينة واحدة', 'One sample'),
                          if (testsCount == 0) testsCountLabel(lang, 0),
                        ].join('  •  '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, color: RastTokens.muted(context), fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1, color: RastTokens.line(context)),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: price <= 0
                          ? RastPrice(amount: null, lang: lang, size: 19)
                          : Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 6,
                              runSpacing: 2,
                              children: [
                                RastPrice(amount: price, lang: lang, size: 20, color: RastTokens.ink(context)),
                                if (oldPrice != null && oldPrice > price)
                                  Text(
                                    fmtPrice(oldPrice),
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: RastTokens.muted(context),
                                      decoration: TextDecoration.lineThrough,
                                      decorationColor: RastTokens.muted(context),
                                    ),
                                  ),
                                if (discount > 0)
                                  Text(
                                    '$discount%',
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w900,
                                      color: RastTokens.danger,
                                    ),
                                  ),
                              ],
                            ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        gradient: RastTokens.brandGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            L(lang, 'التفاصيل والحجز', 'Details & book'),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Directionality.of(context) == TextDirection.rtl
                                ? Icons.arrow_back_rounded
                                : Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PackageCardSkeleton extends StatelessWidget {
  const PackageCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return RastCard(
      padding: EdgeInsets.zero,
      clip: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          AspectRatio(aspectRatio: 16 / 9, child: RastSkeleton(radius: 0)),
          Padding(
            padding: EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RastSkeleton(width: 180, height: 16),
                SizedBox(height: 10),
                RastSkeleton(width: 120, height: 12),
                SizedBox(height: 14),
                RastSkeleton(width: 90, height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
