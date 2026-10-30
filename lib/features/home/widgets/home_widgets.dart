import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rast/features/labs/widgets/lab_visuals.dart';
import 'package:flutter/services.dart';
import 'package:rast/core/widgets/rast_kit.dart';
import 'package:rast/core/widgets/rast_motion.dart';
import 'package:rast/features/loyalty/loyalty_config.dart';
import 'package:rast/features/offers/widgets/offer_card.dart' show OfferView;

/// قطع الصفحة الرئيسية (التصميم الاحترافي): لوحة بيضاء، صور كبيرة، بطاقات بظل ناعم،
/// والسعر واضح. كل بطاقة تضغط بإحساس زر حقيقي (Pressable).

/// التحاليل الأكثر طلباً كاختصارات تحت البحث (الاسم المعروض + نص البحث).
const homePopularTests = <({String ar, String en, String query})>[
  (ar: 'فيتامين د', en: 'Vitamin D', query: 'فيتامين د'),
  (ar: 'صورة الدم', en: 'CBC', query: 'صورة الدم'),
  (ar: 'السكر التراكمي', en: 'HbA1c', query: 'السكر التراكمي'),
  (ar: 'الغدة الدرقية', en: 'Thyroid', query: 'الغدة'),
  (ar: 'الحديد', en: 'Iron', query: 'الحديد'),
  (ar: 'الدهون', en: 'Lipids', query: 'الدهون'),
];

const _gold = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFFCD34D), Color(0xFFF59E0B)],
);

/// زر دائري صغير في رأس الصفحة (المساعد…).
class HomeHeaderButton extends StatelessWidget {
  const HomeHeaderButton({super.key, required this.child, this.onTap, this.size = 42});
  final Widget child;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onTap!();
            },
      haptic: false,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: RastTokens.card(context),
          shape: BoxShape.circle,
          boxShadow: RastTokens.shadow(context, strength: 0.8),
        ),
        child: child,
      ),
    );
  }
}

/// كبسولة الرصيد في الرأس: عملة ذهبية + عدد النقاط.
class HomePointsPill extends StatelessWidget {
  const HomePointsPill({super.key, required this.points, required this.onTap});
  final int points;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        height: 36,
        padding: const EdgeInsetsDirectional.fromSTEB(4, 4, 12, 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7E0),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFF5C451).withValues(alpha: 0.6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(shape: BoxShape.circle, gradient: _gold),
              child: const Icon(Icons.stars_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 6),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: points.toDouble()),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (_, v, __) => Text(
                '${v.round()}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF8A5A00)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// بانر عروض بعرض الشاشة يتحرك تلقائياً، مع نقاط الصفحات وتكبير خفيف للشريحة الحالية.
class HomeBannerCarousel extends StatefulWidget {
  const HomeBannerCarousel({super.key, required this.slides, required this.onTap});

  /// كل شريحة: {image_url, title?, subtitle?, link?, ...}
  final List<Map<String, dynamic>> slides;
  final ValueChanged<Map<String, dynamic>> onTap;

  @override
  State<HomeBannerCarousel> createState() => _HomeBannerCarouselState();
}

class _HomeBannerCarouselState extends State<HomeBannerCarousel> {
  late final PageController _controller = PageController(viewportFraction: 0.92);
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _restartTimer();
  }

  void _restartTimer() {
    _timer?.cancel();
    if (widget.slides.length < 2) return;
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_controller.hasClients) return;
      final next = (_page + 1) % widget.slides.length;
      _controller.animateToPage(next, duration: const Duration(milliseconds: 650), curve: Curves.easeInOutCubic);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final height = (width * 0.92) * 7 / 16;
    return Column(
      children: [
        SizedBox(
          height: height,
          child: NotificationListener<ScrollStartNotification>(
            // لمس المستخدم يوقف الحركة التلقائية مؤقتاً
            onNotification: (n) {
              if (n.dragDetails != null) _restartTimer();
              return false;
            },
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.slides.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (context, i) {
                final s = widget.slides[i];
                final title = (s['title'] ?? '').toString().trim();
                final subtitle = (s['subtitle'] ?? '').toString().trim();
                return AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    double delta = 0;
                    if (_controller.hasClients && _controller.position.haveDimensions) {
                      delta = (_controller.page ?? _page.toDouble()) - i;
                    } else {
                      delta = (_page - i).toDouble();
                    }
                    final scale = 1 - (delta.abs() * 0.06).clamp(0.0, 0.06);
                    return Transform.scale(scale: scale, child: child);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Pressable(
                      onTap: () => widget.onTap(s),
                      child: Container(
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: RastTokens.shadow(context, strength: 1.2),
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            RastNetImage(
                              url: (s['image_url'] ?? s['image'])?.toString(),
                              radius: 0,
                              fallbackIcon: Icons.local_offer_rounded,
                            ),
                            if (title.isNotEmpty || subtitle.isNotEmpty) ...[
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: AlignmentDirectional.centerStart,
                                    end: AlignmentDirectional.centerEnd,
                                    colors: [Colors.black.withValues(alpha: 0.55), Colors.transparent],
                                  ),
                                ),
                              ),
                              PositionedDirectional(
                                start: 16,
                                end: 90,
                                bottom: 16,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (title.isNotEmpty)
                                      Text(
                                        title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, height: 1.25),
                                      ),
                                    if (subtitle.isNotEmpty)
                                      Text(
                                        subtitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12.5),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        if (widget.slides.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < widget.slides.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _page ? 20 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    gradient: i == _page ? RastTokens.brandGradient : null,
                    color: i == _page ? null : RastTokens.line(context),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// تصنيف: صورة دائرية بحلقة رفيعة بلون الهوية + الاسم تحتها.
class HomeCategoryAvatar extends StatelessWidget {
  const HomeCategoryAvatar({super.key, required this.name, required this.imageUrl, required this.onTap, this.icon});

  final String name;
  final String? imageUrl;
  final VoidCallback onTap;

  /// لعنصر «الكل» (بدل الصورة)
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: SizedBox(
        width: 80,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 70,
              height: 70,
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [RastTokens.brand.withValues(alpha: 0.55), RastTokens.brand2.withValues(alpha: 0.45)],
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(shape: BoxShape.circle, color: RastTokens.card(context)),
                child: icon != null
                    ? Container(
                        decoration: BoxDecoration(shape: BoxShape.circle, color: RastTokens.brandSoft(context)),
                        child: Icon(icon, color: RastTokens.brand, size: 26),
                      )
                    : ClipOval(
                        child: RastNetImage(url: imageUrl, radius: 0, fallbackIcon: Icons.medical_services_outlined),
                      ),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, height: 1.3, fontWeight: FontWeight.w700, color: RastTokens.ink(context)),
            ),
          ],
        ),
      ),
    );
  }
}

/// بطاقة «عروض اليوم»: صورة 16:10 بشارة الخصم والمدة، العنوان، المختبر بشعاره،
/// السعر قبل/بعد، «اربح X نقطة» وزر سلة سريع.
class HomeDealCard extends StatelessWidget {
  const HomeDealCard({super.key, required this.offer, required this.lang, required this.onTap, this.width = 272});

  final Map<String, dynamic> offer;
  final String lang;
  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    final o = OfferView(offer);
    final price = o.bestPrice;
    final percent = o.percent;
    final ends = o.endsLabel(lang);
    final urgent = (o.daysLeft ?? 99) <= 2;
    final provider = o.provider;
    final logo = provider?['logo_url']?.toString();
    final gift = o.gift(lang);

    return SizedBox(
      width: width,
      child: RastCard(
        onTap: onTap,
        padding: EdgeInsets.zero,
        clip: true,
        radius: 22,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 10,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  RastNetImage(url: o.imageUrl, radius: 0, fallbackIcon: Icons.local_offer_rounded),
                  if (percent > 0)
                    PositionedDirectional(
                      top: 10,
                      start: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: RastTokens.danger,
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: [BoxShadow(color: RastTokens.danger.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 3))],
                        ),
                        child: Text(
                          L(lang, 'خصم $percent%', '$percent% off'),
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  if (ends.isNotEmpty)
                    PositionedDirectional(
                      bottom: 10,
                      start: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.schedule_rounded, size: 13, color: urgent ? const Color(0xFFFFB4B4) : Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              ends,
                              style: TextStyle(
                                color: urgent ? const Color(0xFFFFB4B4) : Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
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
                    o.title(lang),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, height: 1.35, color: RastTokens.ink(context)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: RastTokens.shadow(context, strength: 0.6),
                        ),
                        child: ClipOval(child: RastNetImage(url: logo, radius: 0, fallbackIcon: Icons.business_rounded)),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          o.providerName(lang),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: RastTokens.muted(context), fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  if (gift != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.card_giftcard_rounded, size: 14, color: Color(0xFFD97706)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            gift,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFFB45309), fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            RastPrice(amount: price.price, oldAmount: price.old, lang: lang, size: 19),
                            if (LoyaltyConfig.enabled && (price.price ?? 0) > 0) ...[
                              const SizedBox(height: 4),
                              EarnPointsBadge(amount: price.price, lang: lang),
                            ],
                          ],
                        ),
                      ),
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          gradient: RastTokens.brandGradient,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [BoxShadow(color: RastTokens.brand.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: const Icon(Icons.add_shopping_cart_rounded, color: Colors.white, size: 20),
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
}

/// بطاقة «الأقرب لك»: صورة الغلاف (أو تدرج الهوية) والشعار متداخل معها، الاسم، التقييم، المسافة، السحب المنزلي.
class HomeNearLabCard extends StatelessWidget {
  const HomeNearLabCard({
    super.key,
    required this.lang,
    required this.name,
    required this.location,
    required this.logoUrl,
    required this.coverUrl,
    required this.rating,
    required this.reviews,
    required this.homeService,
    required this.distanceKm,
    required this.favorite,
    required this.onTap,
    this.width = 264,
  });

  final String lang;
  final String name;
  final String location;
  final String? logoUrl;
  final String? coverUrl;
  final double rating;
  final int reviews;
  final bool homeService;
  final double? distanceKm;
  final Widget favorite;
  final VoidCallback onTap;
  final double width;

  String _distance() {
    final d = distanceKm;
    if (d == null) return '';
    if (d < 1) return L(lang, '${(d * 1000).round()} م', '${(d * 1000).round()} m');
    return L(lang, '${d.toStringAsFixed(1)} كم', '${d.toStringAsFixed(1)} km');
  }

  @override
  Widget build(BuildContext context) {
    final dist = _distance();
    const coverH = 112.0;
    return SizedBox(
      width: width,
      child: RastCard(
        onTap: onTap,
        padding: EdgeInsets.zero,
        clip: true,
        radius: 22,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: coverH + 26,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  SizedBox(
                    height: coverH,
                    width: double.infinity,
                    child: coverUrl != null && coverUrl!.isNotEmpty
                        ? RastNetImage(url: coverUrl, radius: 0, fallbackIcon: Icons.apartment_rounded)
                        // بلا غلاف: شعار المختبر نفسه بدل خلفية بنفسجية فارغة
                        : LabCoverFallback(logoUrl: logoUrl),
                  ),
                  PositionedDirectional(top: 8, end: 8, child: favorite),
                  if (dist.isNotEmpty)
                    PositionedDirectional(
                      top: 10,
                      start: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.94),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.near_me_rounded, size: 13, color: RastTokens.brand),
                            const SizedBox(width: 3),
                            Text(dist, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: RastTokens.brand)),
                          ],
                        ),
                      ),
                    ),
                  // الشعار متداخل مع حافة الغلاف
                  PositionedDirectional(
                    start: 14,
                    bottom: 0,
                    child: Container(
                      width: 56,
                      height: 56,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(17),
                        boxShadow: RastTokens.shadow(context, strength: 1.2),
                      ),
                      child: RastNetImage(url: logoUrl, radius: 14, fallbackIcon: Icons.business_rounded, fit: BoxFit.contain),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: RastTokens.ink(context)),
                  ),
                  if (location.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 14, color: RastTokens.muted(context)),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: RastTokens.muted(context)),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      if (rating > 0) ...[
                        const Icon(Icons.star_rounded, size: 17, color: Color(0xFFF5B301)),
                        const SizedBox(width: 2),
                        Text(
                          rating.toStringAsFixed(1),
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: RastTokens.ink(context)),
                        ),
                        if (reviews > 0)
                          Text(' ($reviews)', style: TextStyle(fontSize: 11.5, color: RastTokens.muted(context))),
                        const SizedBox(width: 8),
                      ],
                      const Spacer(),
                      RastPill(
                        dense: true,
                        icon: homeService ? Icons.home_rounded : Icons.apartment_rounded,
                        color: homeService ? RastTokens.success : RastTokens.brand2,
                        label: homeService ? L(lang, 'سحب منزلي', 'Home visit') : L(lang, 'في المختبر', 'In lab'),
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
}

/// بطاقة باقة بأسلوب التطبيق الأول: الصورة تملأ البطاقة بتعتيم متدرّج،
/// والاسم والسعر وعدد التحاليل مكتوبة فوق الصورة.
class HomePackageCard extends StatelessWidget {
  const HomePackageCard({
    super.key,
    required this.lang,
    required this.name,
    required this.imageUrl,
    required this.testsCount,
    required this.price,
    this.originalPrice,
    this.rating,
    required this.onTap,
    this.width = 280,
  });

  final String lang;
  final String name;
  final String? imageUrl;
  final int testsCount;
  final double price;
  final double? originalPrice;
  final double? rating;
  final VoidCallback onTap;
  final double width;

  static const _shadow = [Shadow(color: Color(0x66000000), blurRadius: 6, offset: Offset(0, 1))];

  @override
  Widget build(BuildContext context) {
    final hasOld = originalPrice != null && originalPrice! > price && price > 0;
    return SizedBox(
      width: width,
      child: Pressable(
        onTap: onTap,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: RastTokens.shadow(context),
          ),
          child: AspectRatio(
            aspectRatio: 16 / 10,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColorFiltered(
                  // تعتيم رمادي خفيف حتى تُقرأ الكتابة فوق أي صورة
                  colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.12), BlendMode.darken),
                  child: RastNetImage(url: imageUrl, radius: 0, fallbackIcon: Icons.inventory_2_rounded),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.25, 1],
                      colors: [Color(0x00000000), Color(0xD9140A1E)],
                    ),
                  ),
                ),
                if (rating != null && rating! > 0)
                  PositionedDirectional(
                    top: 10,
                    end: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded, size: 14, color: Color(0xFFFFC83D)),
                          const SizedBox(width: 2),
                          Text(
                            rating!.toStringAsFixed(1),
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                  ),
                PositionedDirectional(
                  start: 14,
                  end: 14,
                  bottom: 14,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          height: 1.3,
                          shadows: _shadow,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.science_outlined, size: 15, color: Colors.white70),
                          const SizedBox(width: 4),
                          Text(
                            testsCount > 0
                                ? L(lang, 'تشمل ${testsCountLabel(lang, testsCount)}', 'Includes ${testsCountLabel(lang, testsCount)}')
                                : testsCountLabel(lang, 0),
                            style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600, shadows: _shadow),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          if (price > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                L(lang, '${fmtPrice(price)} ر.س', '${fmtPrice(price)} SAR'),
                                style: const TextStyle(color: RastTokens.brand, fontSize: 15, fontWeight: FontWeight.w900),
                              ),
                            ),
                          if (hasOld) ...[
                            const SizedBox(width: 8),
                            Text(
                              fmtPrice(originalPrice),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                decoration: TextDecoration.lineThrough,
                                decorationColor: Colors.white70,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// بطاقة «ادعُ أصدقاءك»: بيضاء هادئة بأيقونة هدية ونص مباشر.
class HomeReferralCard extends StatelessWidget {
  const HomeReferralCard({super.key, required this.lang, required this.bonus, required this.onTap});
  final String lang;
  final int bonus;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: RastTokens.gutter),
      child: RastCard(
        onTap: onTap,
        radius: 18,
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Row(
          children: [
            const RastIconBox(icon: Icons.card_giftcard_rounded, color: Color(0xFFD97706), size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    L(lang, 'ادعُ أصدقاءك', 'Invite friends'),
                    style: TextStyle(color: RastTokens.ink(context), fontWeight: FontWeight.w800, fontSize: 14.5),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    L(lang, 'لك ولصديقك $bonus نقطة بعد أول حجز له', '$bonus points each after their first booking'),
                    style: TextStyle(color: RastTokens.muted(context), fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(
              Directionality.of(context) == TextDirection.rtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
              color: RastTokens.muted(context),
            ),
          ],
        ),
      ),
    );
  }
}

/// هيكل تحميل يطابق التخطيط: بحث، بانر، تصنيفات دائرية، بطاقات أفقية.
class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    const g = RastTokens.gutter;
    final w = MediaQuery.sizeOf(context).width;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(padding: EdgeInsets.symmetric(horizontal: g), child: RastSkeleton(height: 54, radius: 18)),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: g),
          child: RastSkeleton(height: (w - 2 * g) * 7 / 16, radius: 22),
        ),
        const SizedBox(height: 26),
        const Padding(padding: EdgeInsets.symmetric(horizontal: g), child: RastSkeleton(width: 120, height: 18)),
        const SizedBox(height: 14),
        SizedBox(
          height: 100,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: g),
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 5,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, __) => const Column(
              children: [
                RastSkeleton(width: 70, height: 70, radius: 35),
                SizedBox(height: 8),
                RastSkeleton(width: 56, height: 10),
              ],
            ),
          ),
        ),
        const SizedBox(height: 26),
        const Padding(padding: EdgeInsets.symmetric(horizontal: g), child: RastSkeleton(width: 140, height: 18)),
        const SizedBox(height: 14),
        SizedBox(
          height: 250,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: g),
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 3,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, __) => const RastSkeleton(width: 260, height: 250, radius: 22),
          ),
        ),
      ],
    );
  }
}
