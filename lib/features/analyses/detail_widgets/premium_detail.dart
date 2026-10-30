import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rast/core/widgets/cart_icon_button.dart';
import 'package:rast/core/widgets/rast_kit.dart';
import 'package:rast/core/widgets/rast_motion.dart';
import 'package:url_launcher/url_launcher.dart';

/// قطع صفحات التفاصيل الفاخرة (تحليل، باقة، عرض):
/// صورة كاملة العرض بتأثير المنظور، أزرار شفافة فوقها، حافة بيضاء دائرية تتداخل مع الصورة،
/// وشريط تبويبات مثبّت.

/// زر دائري: شفاف داكن فوق الصورة، وفاتح عند طي الرأس.
class DetailCircleButton extends StatelessWidget {
  const DetailCircleButton({super.key, required this.child, this.onTap, required this.overImage});

  final Widget child;
  final VoidCallback? onTap;
  final bool overImage;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: overImage ? Colors.black.withValues(alpha: 0.32) : RastTokens.fill(context),
        border: Border.all(color: overImage ? Colors.white.withValues(alpha: 0.22) : RastTokens.line(context)),
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onTap!();
                },
          child: Center(child: child),
        ),
      ),
    );
  }
}

/// رأس الصفحة: صورة 300px تتمدد عند السحب وتتحرك أبطأ من المحتوى، مع تدرج داكن أعلاها
/// لوضوح الأزرار، وعند الطي يصبح شريطاً أبيض فيه العنوان.
class PremiumHeroAppBar extends StatelessWidget {
  const PremiumHeroAppBar({
    super.key,
    required this.title,
    required this.collapsed,
    required this.image,
    required this.onBack,
    this.favorite,
    this.onFavorite,
    this.onShare,
    this.expandedHeight = 300,
    this.onImageTap,
    this.overlay,
  });

  final String title;
  final bool collapsed;
  final Widget image;
  final VoidCallback onBack;
  final Widget? favorite;
  final VoidCallback? onFavorite;
  final VoidCallback? onShare;
  final double expandedHeight;
  final VoidCallback? onImageTap;

  /// عناصر إضافية فوق الصورة (شارة خصم، تلميح التكبير…)
  final Widget? overlay;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final iconColor = collapsed ? RastTokens.ink(context) : Colors.white;

    return SliverAppBar(
      pinned: true,
      stretch: true,
      expandedHeight: expandedHeight,
      automaticallyImplyLeading: false,
      backgroundColor: RastTokens.card(context),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 64,
      titleSpacing: 0,
      systemOverlayStyle: collapsed && !RastTokens.dark(context)
          ? SystemUiOverlayStyle.dark
          : SystemUiOverlayStyle.light,
      title: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            DetailCircleButton(
              overImage: !collapsed,
              onTap: onBack,
              child: Icon(
                rtl ? Icons.arrow_forward_ios_rounded : Icons.arrow_back_ios_new_rounded,
                textDirection: TextDirection.ltr,
                color: iconColor,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AnimatedOpacity(
                opacity: collapsed ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: RastTokens.ink(context)),
                ),
              ),
            ),
            if (onShare != null) ...[
              DetailCircleButton(
                overImage: !collapsed,
                onTap: onShare,
                child: Icon(Icons.ios_share_rounded, color: iconColor, size: 19),
              ),
              const SizedBox(width: 8),
            ],
            if (favorite != null) ...[
              DetailCircleButton(overImage: !collapsed, onTap: onFavorite, child: favorite!),
              const SizedBox(width: 8),
            ],
            // السلة: هدف حركة «طيران العنصر إلى السلة» بعد الإضافة — تبقى ظاهرة دائماً
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: collapsed ? RastTokens.fill(context) : Colors.black.withValues(alpha: 0.32),
                border: Border.all(
                  color: collapsed ? RastTokens.line(context) : Colors.white.withValues(alpha: 0.22),
                ),
              ),
              alignment: Alignment.center,
              child: CartIconButton(size: 40, iconColor: iconColor, backgroundColor: Colors.transparent),
            ),
          ],
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        stretchModes: const [StretchMode.zoomBackground],
        background: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(onTap: onImageTap, child: image),
            // تدرج أعلى الصورة لوضوح الأزرار، وأسفلها خفيف ليندمج مع الحافة البيضاء
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0, 0.35, 0.75, 1],
                    colors: [
                      Colors.black.withValues(alpha: 0.45),
                      Colors.black.withValues(alpha: 0.0),
                      Colors.black.withValues(alpha: 0.0),
                      Colors.black.withValues(alpha: 0.18),
                    ],
                  ),
                ),
              ),
            ),
            if (overlay != null) overlay!,
          ],
        ),
      ),
      // الحافة البيضاء الدائرية التي «تصعد» فوق الصورة
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(26),
        child: Container(
          height: 26,
          width: double.infinity,
          decoration: BoxDecoration(
            color: RastTokens.bg(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          alignment: Alignment.topCenter,
          child: Container(
            margin: const EdgeInsets.only(top: 8),
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: collapsed ? Colors.transparent : RastTokens.line(context),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    );
  }
}

/// صورة الرأس أو بديل جميل بتدرج الهوية عند غيابها.
class PremiumHeroImage extends StatelessWidget {
  const PremiumHeroImage({super.key, required this.url, this.fallbackIcon = Icons.biotech_rounded});

  final String? url;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    if (url != null && url!.trim().isNotEmpty) {
      return RastNetImage(url: url, radius: 0, fallbackIcon: fallbackIcon);
    }
    return Container(
      decoration: const BoxDecoration(gradient: RastTokens.heroGradient),
      child: Stack(
        children: [
          PositionedDirectional(
            end: -40,
            top: 40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.06)),
            ),
          ),
          Center(child: Icon(fallbackIcon, size: 88, color: Colors.white.withValues(alpha: 0.8))),
        ],
      ),
    );
  }
}

/// شريط تبويبات مثبّت تحت الرأس (يتغير المحتوى أسفله دون تمرير متداخل).
class PremiumTabsHeader extends SliverPersistentHeaderDelegate {
  PremiumTabsHeader({required this.tabs, required this.index, required this.onChanged, required this.dark});

  final List<String> tabs;
  final int index;
  final ValueChanged<int> onChanged;
  final bool dark;

  @override
  double get minExtent => 58;
  @override
  double get maxExtent => 58;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: RastTokens.bg(context),
      padding: const EdgeInsets.fromLTRB(RastTokens.gutter, 6, RastTokens.gutter, 6),
      child: Container(
        decoration: BoxDecoration(
          color: RastTokens.fill(context),
          borderRadius: BorderRadius.circular(16),
          boxShadow: overlapsContent || shrinkOffset > 0 ? RastTokens.shadow(context, strength: 0.6) : null,
        ),
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            for (var i = 0; i < tabs.length; i++)
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (i == index) return;
                    HapticFeedback.selectionClick();
                    onChanged(i);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                    decoration: BoxDecoration(
                      color: i == index ? RastTokens.card(context) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: i == index ? RastTokens.shadow(context, strength: 0.7) : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      tabs[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: i == index ? FontWeight.w800 : FontWeight.w600,
                        color: i == index ? RastTokens.brand : RastTokens.muted(context),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(PremiumTabsHeader old) =>
      old.index != index || old.tabs.join() != tabs.join() || old.dark != dark;
}

/// كتلة السعر الكبيرة في رأس اللوحة البيضاء.
class PremiumPriceBlock extends StatelessWidget {
  const PremiumPriceBlock({
    super.key,
    required this.amount,
    required this.lang,
    this.from = false,
    this.oldAmount,
    this.trailing,
  });

  final num? amount;
  final String lang;
  final bool from;
  final num? oldAmount;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: RastPrice(amount: amount, lang: lang, from: from, oldAmount: oldAmount, size: 28)),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// محتوى نصي داخل تبويب (الوصف/التحضير) بعرض الصفحة.
class PremiumTextBlock extends StatelessWidget {
  const PremiumTextBlock({super.key, required this.icon, required this.title, required this.text, this.color});

  final IconData icon;
  final String title;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return RastCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              RastIconBox(icon: icon, size: 36, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: RastTokens.ink(context)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(text, style: TextStyle(fontSize: 14, height: 1.8, color: RastTokens.muted(context))),
        ],
      ),
    ).entrance(0);
  }
}

/// مشاركة رابط عبر واتساب (لا توجد حزمة مشاركة في التطبيق).
Future<void> shareViaWhatsApp(String text) async {
  final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}
