import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rast/core/services/favorites_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rast/core/utils/locale_utils.dart';
import 'package:rast/core/widgets/rast_kit.dart';
import 'package:rast/core/widgets/rast_motion.dart';
import 'package:rast/features/loyalty/loyalty_config.dart';

/// طريقة عرض القوائم (شبكة/قائمة) يختارها المستخدم وتُحفظ لكل شاشة.
class ViewModeStore {
  ViewModeStore._();

  static String _key(String screen) => 'view_mode_$screen';

  /// true = شبكة
  static Future<bool> isGrid(String screen, {bool defaultGrid = true}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_key(screen)) ?? defaultGrid;
    } catch (_) {
      return defaultGrid;
    }
  }

  static Future<void> setGrid(String screen, bool grid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key(screen), grid);
    } catch (_) {}
  }

  /// ارتفاع خلية الشبكة لعمودين: صورة 4:3 + منطقة النص والسعر
  static double gridExtent(double screenWidth, {double gutter = 16, double gap = 12, double body = 118}) {
    final col = (screenWidth - gutter * 2 - gap) / 2;
    return col * 0.75 + body;
  }
}

/// زرّا التبديل بين الشبكة والقائمة (يوضعان بجانب الفلترة والترتيب).
class ViewModeToggle extends StatelessWidget {
  const ViewModeToggle({super.key, required this.grid, required this.onChanged, this.height = 46});

  final bool grid;
  final ValueChanged<bool> onChanged;
  final double height;

  @override
  Widget build(BuildContext context) {
    Widget seg(bool value, IconData icon, String tip) {
      final on = grid == value;
      return Tooltip(
        message: tip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (on) return;
            HapticFeedback.selectionClick();
            onChanged(value);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: height - 10,
            height: height - 10,
            decoration: BoxDecoration(
              color: on ? RastTokens.card(context) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              boxShadow: on ? RastTokens.shadow(context, strength: 0.7) : null,
            ),
            child: Icon(icon, size: 20, color: on ? RastTokens.brand : RastTokens.muted(context)),
          ),
        ),
      );
    }

    final lang = Localizations.localeOf(context).languageCode;
    return Container(
      height: height,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: RastTokens.fill(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          seg(true, Icons.grid_view_rounded, L(lang, 'شبكة', 'Grid')),
          seg(false, Icons.view_agenda_outlined, L(lang, 'قائمة', 'List')),
        ],
      ),
    );
  }
}

/// صف تحليل في القوائم: صورة مصغّرة، الاسم بالعربي والإنجليزي، التصنيف، مدة النتيجة،
/// الحاجة للصيام، أقل سعر وعدد المختبرات، وقلب المفضلة. مصمّم ليُقرأ بنظرة واحدة.
/// [grid] = بطاقة متجر عمودية (صورة أعلى) لعرض الشبكة.
class TestRowCard extends StatefulWidget {
  const TestRowCard({
    super.key,
    required this.service,
    required this.lang,
    required this.isArabic,
    required this.categoryName,
    required this.imageUrl,
    required this.price,
    required this.onTap,
    this.labsCount,
    this.isLabView = false,
    this.grid = false,
  });

  final bool grid;

  final Map<String, dynamic> service;
  final String lang;
  final bool isArabic;
  final String categoryName;
  final String? imageUrl;
  final double price;
  final int? labsCount;
  final bool isLabView;
  final VoidCallback onTap;

  @override
  State<TestRowCard> createState() => _TestRowCardState();
}

class _TestRowCardState extends State<TestRowCard> {
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _loadFavorite();
  }

  @override
  void didUpdateWidget(covariant TestRowCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (FavoritesService.itemId(oldWidget.service) != FavoritesService.itemId(widget.service)) {
      _loadFavorite();
    }
  }

  Future<void> _loadFavorite() async {
    final value = await FavoritesService.isAnalysisFavorite(widget.service);
    if (mounted) setState(() => _isFavorite = value);
  }

  Future<void> _toggleFavorite() async {
    final value = await FavoritesService.toggleAnalysis(widget.service);
    if (mounted) setState(() => _isFavorite = value);
  }

  String? _durationLabel() {
    final d = numOf(widget.service['default_duration'] ?? widget.service['duration'])?.round();
    if (d == null || d <= 0) return null;
    final lang = widget.lang;
    if (lang == 'en') return d == 1 ? 'Result in 1 day' : 'Result in $d days';
    if (d == 1) return 'النتيجة خلال يوم';
    if (d == 2) return 'النتيجة خلال يومين';
    if (d <= 10) return 'النتيجة خلال $d أيام';
    return 'النتيجة خلال $d يوماً';
  }

  bool get _needsPrep {
    final v = widget.service['requires_preparation'];
    return v == true || v == 1 || v == '1' || v == 'true';
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.service;
    final lang = widget.lang;
    final available = widget.price > 0;
    final name = LocaleUtils.localizedName(s, widget.isArabic);
    final en = (s['name_en'] ?? '').toString().trim();
    final showEn = widget.isArabic && en.isNotEmpty && en != name;
    final duration = _durationLabel();
    final labs = widget.labsCount;

    final meta = [
      if (widget.categoryName.isNotEmpty) widget.categoryName,
      ?duration,
    ].join('  •  ');
    final labsLabel = (labs == null || labs <= 0)
        ? null
        : (labs == 1
            ? L(lang, 'مختبر واحد', '1 lab')
            : (lang == 'en' ? '$labs labs' : (labs == 2 ? 'مختبران' : '$labs ${labs <= 10 ? 'مختبرات' : 'مختبراً'}')));

    if (widget.grid) {
      return _buildGrid(context, name: name, available: available, labsLabel: labsLabel, labs: labs);
    }

    return RastCard(
      onTap: widget.onTap,
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // الصورة البطلة مع القلب فوقها
          SizedBox(
            width: 96,
            height: 96,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Opacity(
                  opacity: available ? 1 : 0.5,
                  child: RastNetImage(url: widget.imageUrl, radius: 18),
                ),
                PositionedDirectional(
                  top: 5,
                  end: 5,
                  child: Material(
                    color: Colors.white.withValues(alpha: 0.92),
                    shape: const CircleBorder(),
                    elevation: 0,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _toggleFavorite,
                      child: Padding(
                        padding: const EdgeInsets.all(5),
                        child: AnimatedFavoriteIcon(
                          active: _isFavorite,
                          size: 17,
                          inactiveColor: const Color(0xFF6E6A80),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 96),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      height: 1.35,
                      color: available ? RastTokens.ink(context) : RastTokens.muted(context),
                    ),
                  ),
                  if (showEn)
                    Text(
                      en,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textDirection: TextDirection.ltr,
                      style: TextStyle(fontSize: 11.5, color: RastTokens.muted(context)),
                    ),
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: RastTokens.muted(context), fontWeight: FontWeight.w500),
                    ),
                  ],
                  if (_needsPrep) ...[
                    const SizedBox(height: 6),
                    RastPill(
                      label: L(lang, 'يحتاج صيام/تحضير', 'Fasting/prep'),
                      icon: Icons.no_food_outlined,
                      dense: true,
                      color: RastTokens.warning,
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
                            RastPrice(
                              amount: available ? widget.price : null,
                              lang: lang,
                              from: available && !widget.isLabView && (labs == null || labs > 1),
                              size: 18,
                            ),
                            if (available && labsLabel != null) ...[
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(Icons.apartment_rounded, size: 13, color: RastTokens.success),
                                  const SizedBox(width: 3),
                                  Flexible(
                                    child: Text(
                                      labsLabel,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: RastTokens.success,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      // زر متدرج صغير: يفتح المقارنة والحجز
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          gradient: available ? RastTokens.brandGradient : null,
                          color: available ? null : RastTokens.fill(context),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: available
                              ? [
                                  BoxShadow(
                                    color: RastTokens.brand.withValues(alpha: 0.28),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                        child: Icon(
                          Directionality.of(context) == TextDirection.rtl
                              ? Icons.arrow_back_rounded
                              : Icons.arrow_forward_rounded,
                          size: 19,
                          color: available ? Colors.white : RastTokens.muted(context),
                        ),
                      ),
                    ],
                  ),
                  if (available)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: EarnPointsBadge(amount: widget.price, lang: lang),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// بطاقة الشبكة: صورة 4:3 بالأعلى، الاسم سطرين، سطر وصف، ثم السعر وزر صغير.
  /// ارتفاعها ثابت ليتساوى الصف (ViewModeStore.gridExtent).
  Widget _buildGrid(
    BuildContext context, {
    required String name,
    required bool available,
    required String? labsLabel,
    required int? labs,
  }) {
    final lang = widget.lang;
    final sub = labsLabel ?? widget.categoryName;
    return RastCard(
      onTap: widget.onTap,
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
                Opacity(
                  opacity: available ? 1 : 0.5,
                  child: RastNetImage(url: widget.imageUrl, radius: 0),
                ),
                PositionedDirectional(
                  top: 8,
                  end: 8,
                  child: Material(
                    color: Colors.white.withValues(alpha: 0.94),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _toggleFavorite,
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: AnimatedFavoriteIcon(
                          active: _isFavorite,
                          size: 16,
                          inactiveColor: const Color(0xFF6E6A80),
                        ),
                      ),
                    ),
                  ),
                ),
                if (!available)
                  PositionedDirectional(
                    bottom: 8,
                    start: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        L(lang, 'غير متوفر', 'Unavailable'),
                        style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700),
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
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      height: 1.3,
                      color: available ? RastTokens.ink(context) : RastTokens.muted(context),
                    ),
                  ),
                  if (sub.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: RastTokens.muted(context)),
                    ),
                  ],
                  const Spacer(),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: AlignmentDirectional.bottomStart,
                          child: RastPrice(
                            amount: available ? widget.price : null,
                            lang: lang,
                            from: available && !widget.isLabView && (labs == null || labs > 1),
                            size: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: available ? RastTokens.brand : RastTokens.fill(context),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Directionality.of(context) == TextDirection.rtl
                              ? Icons.arrow_back_rounded
                              : Icons.arrow_forward_rounded,
                          size: 17,
                          color: available ? Colors.white : RastTokens.muted(context),
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
}
