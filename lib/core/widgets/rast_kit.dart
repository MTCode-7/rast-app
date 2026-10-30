import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:rast/core/theme/app_theme.dart';
import 'package:rast/core/widgets/rast_motion.dart';
import 'package:shimmer/shimmer.dart';

/// نظام التصميم الموحّد لتطبيق راست (الإصدار الجديد للواجهات).
/// كل الشاشات تبني من هذه القطع حتى يبقى الشكل متناسقاً:
/// ألوان وظلال ومسافات ثابتة، بطاقات، أسعار، عناوين أقسام، حالات فارغة، هياكل تحميل، شريط حجز ثابت.

/// نص بلغتين دون المرور بملف النصوص (للنصوص الجديدة في الواجهات).
String L(String lang, String ar, String en) => lang == 'en' ? en : ar;

/// تنسيق السعر: بلا كسور إن كان صحيحاً (120 بدل 120.00).
String fmtPrice(num? v) {
  if (v == null) return '—';
  final d = v.toDouble();
  if (d == d.roundToDouble()) return d.toStringAsFixed(0);
  return d.toStringAsFixed(2);
}

/// قراءة رقم من أي قيمة قادمة من الـ API.
double? numOf(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString().trim().replaceAll(',', ''));
}

class RastTokens {
  const RastTokens._();

  // الهوية
  static const Color brand = AppTheme.primary; // بنفسجي راست
  static const Color brand2 = AppTheme.secondary; // أزرق راست
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFE11D48);
  static const Color info = Color(0xFF0284C7);
  static const Color gold = Color(0xFFF5B301);

  // المسافات والزوايا
  static const double gutter = 16;
  static const double gap = 12;
  static const double radius = 20;
  static const double radiusSm = 14;

  static bool dark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;

  /// خلفية الشاشات: رمادي بنفسجي فاتح جداً حتى تبرز البطاقات البيضاء
  static Color bg(BuildContext c) => dark(c) ? const Color(0xFF07131A) : Colors.white;
  static Color card(BuildContext c) => dark(c) ? const Color(0xFF0F1D27) : Colors.white;
  static Color ink(BuildContext c) => dark(c) ? const Color(0xFFEDEFF6) : const Color(0xFF1B1530);
  static Color muted(BuildContext c) => dark(c) ? const Color(0xFFA9B3C4) : const Color(0xFF6E6A80);
  static Color line(BuildContext c) => dark(c) ? const Color(0xFF243546) : const Color(0xFFF0EEF5);
  static Color fill(BuildContext c) => dark(c) ? const Color(0xFF162533) : const Color(0xFFF6F4FA);
  static Color brandSoft(BuildContext c) =>
      dark(c) ? brand.withValues(alpha: 0.22) : brand.withValues(alpha: 0.07);

  static const LinearGradient brandGradient = LinearGradient(
    begin: AlignmentDirectional.centerStart,
    end: AlignmentDirectional.centerEnd,
    colors: [Color(0xFF6A1B68), Color(0xFF52398F), Color(0xFF395395)],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [Color(0xFF6A1B68), Color(0xFF4F3A8E), Color(0xFF2F4F8F)],
  );

  static List<BoxShadow> shadow(BuildContext c, {double strength = 1}) => dark(c)
      ? const []
      : [
          // ظل بطبقتين: قريب ناعم يحدد الحافة + بعيد واسع يعطي عمقاً (بلا حدود رمادية على الخلفية البيضاء)
          BoxShadow(
            color: const Color(0xFF2A1A4A).withValues(alpha: 0.05 * strength),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
          BoxShadow(
            color: const Color(0xFF2A1A4A).withValues(alpha: 0.08 * strength),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ];
}

/// بطاقة موحّدة: بيضاء، حد ناعم، ظل خفيف، وضغطة محسوسة عند وجود onTap.
class RastCard extends StatelessWidget {
  const RastCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(14),
    this.radius = RastTokens.radius,
    this.color,
    this.borderColor,
    this.gradient,
    this.clip = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;
  final Color? borderColor;
  final Gradient? gradient;
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    Widget body = Padding(padding: padding, child: child);
    if (onTap != null) {
      body = Material(
        color: Colors.transparent,
        child: InkWell(borderRadius: r, onTap: onTap, child: body),
      );
    }
    final box = Container(
      clipBehavior: clip ? Clip.antiAlias : Clip.none,
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? RastTokens.card(context)) : null,
        gradient: gradient,
        borderRadius: r,
        // في الوضع الفاتح لا حدود إلا إن طُلبت؛ الداكن يحتاج حداً لأن الظل لا يظهر
        border: borderColor != null
            ? Border.all(color: borderColor!)
            : (RastTokens.dark(context) ? Border.all(color: RastTokens.line(context)) : null),
        boxShadow: RastTokens.shadow(context),
      ),
      child: body,
    );
    return onTap == null ? box : Pressable(child: box);
  }
}

/// عنوان قسم: عنوان عريض + سطر وصف اختياري + زر «عرض الكل».
class RastSectionHeader extends StatelessWidget {
  const RastSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.symmetric(horizontal: RastTokens.gutter),
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: RastTokens.ink(context), height: 1.3),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: TextStyle(fontSize: 12.5, color: RastTokens.muted(context), height: 1.4)),
                ],
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: RastTokens.brand,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(actionLabel!, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(width: 2),
                  Icon(
                    Directionality.of(context) == TextDirection.rtl
                        ? Icons.chevron_left_rounded
                        : Icons.chevron_right_rounded,
                    size: 18,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// شارة صغيرة (معلومة مختصرة): أيقونة + نص بلون خفيف.
class RastPill extends StatelessWidget {
  const RastPill({
    super.key,
    required this.label,
    this.icon,
    this.color,
    this.filled = false,
    this.dense = false,
  });

  final String label;
  final IconData? icon;
  final Color? color;
  final bool filled;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final c = color ?? RastTokens.brand;
    final fg = filled ? Colors.white : c;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 10, vertical: dense ? 3 : 5),
      decoration: BoxDecoration(
        color: filled ? c : c.withValues(alpha: RastTokens.dark(context) ? 0.2 : 0.09),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 12 : 14, color: fg),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: fg, fontSize: dense ? 10.5 : 11.5, fontWeight: FontWeight.w700, height: 1.2),
            ),
          ),
        ],
      ),
    );
  }
}

/// السعر بشكل موحّد: «يبدأ من» صغيرة + الرقم عريض + «ر.س».
class RastPrice extends StatelessWidget {
  const RastPrice({
    super.key,
    required this.amount,
    required this.lang,
    this.from = false,
    this.oldAmount,
    this.size = 17,
    this.color,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  final num? amount;
  final String lang;
  final bool from;
  final num? oldAmount;
  final double size;
  final Color? color;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    final c = color ?? RastTokens.brand;
    if (amount == null || amount == 0) {
      return Text(
        L(lang, 'غير متوفر حالياً', 'Not available'),
        style: TextStyle(fontSize: size * 0.72, color: RastTokens.muted(context), fontWeight: FontWeight.w600),
      );
    }
    return Column(
      crossAxisAlignment: crossAxisAlignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (from)
          Text(
            L(lang, 'يبدأ من', 'From'),
            style: TextStyle(fontSize: size * 0.62, color: RastTokens.muted(context), height: 1.1),
          ),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              fmtPrice(amount),
              style: TextStyle(fontSize: size, fontWeight: FontWeight.w900, color: c, height: 1.15),
            ),
            const SizedBox(width: 3),
            Text(
              L(lang, 'ر.س', 'SAR'),
              style: TextStyle(fontSize: size * 0.62, fontWeight: FontWeight.w700, color: c),
            ),
            if (oldAmount != null && oldAmount! > (amount ?? 0)) ...[
              const SizedBox(width: 6),
              Text(
                fmtPrice(oldAmount),
                style: TextStyle(
                  fontSize: size * 0.68,
                  color: RastTokens.muted(context),
                  decoration: TextDecoration.lineThrough,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// مربع أيقونة بخلفية خفيفة (لعناصر المعلومات والقوائم).
class RastIconBox extends StatelessWidget {
  const RastIconBox({super.key, required this.icon, this.color, this.size = 40, this.iconSize});

  final IconData icon;
  final Color? color;
  final double size;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final c = color ?? RastTokens.brand;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.withValues(alpha: RastTokens.dark(context) ? 0.22 : 0.09),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(icon, color: c, size: iconSize ?? size * 0.5),
    );
  }
}

/// صورة من الشبكة بزوايا مستديرة وخلفية لطيفة أثناء التحميل أو الفشل.
class RastNetImage extends StatelessWidget {
  const RastNetImage({
    super.key,
    required this.url,
    this.radius = 14,
    this.fit = BoxFit.cover,
    this.fallbackIcon = Icons.biotech_rounded,
    this.width,
    this.height,
  });

  final String? url;
  final double radius;
  final BoxFit fit;
  final IconData fallbackIcon;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            RastTokens.brand.withValues(alpha: 0.10),
            RastTokens.brand2.withValues(alpha: 0.10),
          ],
        ),
      ),
      child: Center(child: Icon(fallbackIcon, color: RastTokens.brand.withValues(alpha: 0.55), size: 28)),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: (url == null || url!.isEmpty)
          ? fallback
          : CachedNetworkImage(
              imageUrl: url!,
              width: width,
              height: height,
              fit: fit,
              fadeInDuration: const Duration(milliseconds: 220),
              placeholder: (_, __) => RastSkeleton(width: width, height: height, radius: 0),
              errorWidget: (_, __, ___) => fallback,
            ),
    );
  }
}

/// هيكل تحميل بلمعة متحركة.
class RastSkeleton extends StatelessWidget {
  const RastSkeleton({super.key, this.width, this.height = 16, this.radius = 12});

  final double? width;
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final dark = RastTokens.dark(context);
    return Shimmer.fromColors(
      baseColor: dark ? const Color(0xFF14232F) : const Color(0xFFEDEBF3),
      highlightColor: dark ? const Color(0xFF1D3040) : const Color(0xFFF9F8FC),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(radius)),
      ),
    );
  }
}

/// حالة فارغة/خطأ موحّدة: دائرة أيقونة، عنوان، وصف، وزر اختياري.
class RastEmptyState extends StatelessWidget {
  const RastEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.color,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? RastTokens.brand;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.withValues(alpha: 0.08),
            ),
            child: Center(
              child: Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RastTokens.brandGradient,
                  boxShadow: [BoxShadow(color: c.withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 6))],
                ),
                child: Icon(icon, color: Colors.white, size: 30),
              ),
            ),
          ).animate().scale(begin: const Offset(0.8, 0.8), duration: 450.ms, curve: Curves.easeOutBack).fadeIn(),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: RastTokens.ink(context)),
          ),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, height: 1.6, color: RastTokens.muted(context)),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 18),
            RastButton(label: actionLabel!, onPressed: onAction, expand: false),
          ],
        ],
      ),
    );
  }
}

/// زر أساسي بتدرج الهوية (أو ثانوي بحد) مع حالة تحميل.
class RastButton extends StatelessWidget {
  const RastButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.secondary = false,
    this.expand = true,
    this.height = 52,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool secondary;
  final bool expand;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final fg = secondary ? RastTokens.brand : Colors.white;
    final content = loading
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: fg),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, color: fg, size: 20), const SizedBox(width: 8)],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
            ],
          );
    final r = BorderRadius.circular(16);
    return Pressable(
      scale: enabled ? 0.97 : 1,
      haptic: false,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: enabled || loading ? 1 : 0.5,
        child: Container(
          height: height,
          width: expand ? double.infinity : null,
          decoration: BoxDecoration(
            gradient: secondary ? null : RastTokens.brandGradient,
            color: secondary ? RastTokens.brandSoft(context) : null,
            borderRadius: r,
            border: secondary ? Border.all(color: RastTokens.brand.withValues(alpha: 0.25)) : null,
            boxShadow: secondary || !enabled
                ? null
                : [BoxShadow(color: RastTokens.brand.withValues(alpha: 0.28), blurRadius: 14, offset: const Offset(0, 6))],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: r,
              onTap: enabled
                  ? () {
                      HapticFeedback.selectionClick();
                      onPressed!();
                    }
                  : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Center(child: content),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// شريط سفلي ثابت للحجز/الدفع: خلفية بيضاء، ظل علوي، ويحترم مساحة الجهاز السفلية.
class RastStickyBar extends StatelessWidget {
  const RastStickyBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.paddingOf(context).bottom),
      decoration: BoxDecoration(
        color: RastTokens.card(context),
        border: Border(top: BorderSide(color: RastTokens.line(context))),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, -4)),
        ],
      ),
      child: child,
    );
  }
}

/// حقل بحث موحّد. إن مُرّر onTap يصبح زراً يفتح شاشة البحث.
class RastSearchField extends StatelessWidget {
  const RastSearchField({
    super.key,
    required this.hint,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.trailing,
    this.autofocus = false,
    this.onDark = false,
  });

  final String hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool autofocus;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final field = Container(
      height: 52,
      decoration: BoxDecoration(
        color: RastTokens.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: onDark ? Colors.transparent : RastTokens.line(context)),
        boxShadow: onDark
            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 18, offset: const Offset(0, 8))]
            : RastTokens.shadow(context, strength: 0.6),
      ),
      padding: const EdgeInsetsDirectional.only(start: 14, end: 6),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: RastTokens.brand, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: onTap != null
                ? Text(hint, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: RastTokens.muted(context), fontSize: 14))
                : TextField(
                    controller: controller,
                    autofocus: autofocus,
                    onChanged: onChanged,
                    onSubmitted: onSubmitted,
                    textInputAction: TextInputAction.search,
                    style: TextStyle(color: RastTokens.ink(context), fontSize: 14.5),
                    decoration: InputDecoration(
                      hintText: hint,
                      hintStyle: TextStyle(color: RastTokens.muted(context), fontSize: 14),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
    if (onTap == null) return field;
    return GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: AbsorbPointer(child: field));
  }
}

/// شرائح اختيار أفقية بتحريك ناعم للمختار (تصنيفات، ترتيب، فلاتر).
class RastChoiceChips<T> extends StatelessWidget {
  const RastChoiceChips({
    super.key,
    required this.items,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
    this.iconOf,
    this.padding = const EdgeInsets.symmetric(horizontal: RastTokens.gutter),
  });

  final List<T> items;
  final T? selected;
  final String Function(T) labelOf;
  final IconData? Function(T)? iconOf;
  final ValueChanged<T> onSelected;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        padding: padding,
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final item = items[i];
          final on = item == selected;
          final icon = iconOf?.call(item);
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onSelected(item);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                gradient: on ? RastTokens.brandGradient : null,
                color: on ? null : RastTokens.card(context),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: on ? Colors.transparent : RastTokens.line(context)),
                boxShadow: on
                    ? [BoxShadow(color: RastTokens.brand.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 4))]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 16, color: on ? Colors.white : RastTokens.brand),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    labelOf(item),
                    style: TextStyle(
                      color: on ? Colors.white : RastTokens.ink(context),
                      fontWeight: on ? FontWeight.w800 : FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// صف معلومة: أيقونة في مربع + عنوان صغير + قيمة (للمواصفات: مدة النتيجة، التحضير…).
class RastInfoRow extends StatelessWidget {
  const RastInfoRow({super.key, required this.icon, required this.label, required this.value, this.color});

  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        RastIconBox(icon: icon, color: color, size: 38),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11.5, color: RastTokens.muted(context))),
              const SizedBox(height: 1),
              Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: RastTokens.ink(context))),
            ],
          ),
        ),
      ],
    );
  }
}

/// عدد تحاليل الباقة بصياغة عربية صحيحة. إن لم تُضف تحاليل للباقة (0) نقول
/// «التحاليل موضحة في الصورة» بدل «0 تحاليل» حتى لا يظن العميل أنها فارغة.
String testsCountLabel(String lang, int n) {
  if (n <= 0) return L(lang, 'التحاليل موضحة في الصورة', 'Tests shown in the image');
  if (lang == 'en') return n == 1 ? '1 test' : '$n tests';
  if (n == 1) return 'تحليل واحد';
  if (n == 2) return 'تحليلان';
  if (n <= 10) return '$n تحاليل';
  return '$n تحليلاً';
}
