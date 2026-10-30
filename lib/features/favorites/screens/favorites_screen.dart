import 'package:flutter/material.dart';
import 'package:rast/core/widgets/rast_motion.dart';
import 'package:rast/core/widgets/rast_kit.dart';
import 'package:rast/core/services/analytics_service.dart';
import 'package:provider/provider.dart';
import 'package:rast/core/constants/app_strings.dart';
import 'package:rast/core/providers/app_settings_provider.dart';
import 'package:rast/core/services/favorites_service.dart';
import 'package:rast/core/utils/locale_utils.dart';
import 'package:rast/core/utils/responsive.dart';
import 'package:rast/core/widgets/rast_ui.dart';
import 'package:rast/features/analyses/screens/service_detail_screen.dart';
import 'package:rast/features/lab_details/screens/lab_details_screen.dart';
import 'package:rast/features/analyses/widgets/test_row_card.dart' show ViewModeStore, ViewModeToggle;

import '../../../core/constants/api_config.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  List<Map<String, dynamic>> _labs = [];
  List<Map<String, dynamic>> _analyses = [];
  bool _isLoading = true;
  bool _grid = true;

  @override
  void initState() {
    super.initState();
    AnalyticsService.logScreen('favorites');
    _tabController = TabController(length: 2, vsync: this);
    ViewModeStore.isGrid('favorites').then((g) {
      if (mounted && g != _grid) setState(() => _grid = g);
    });
    _load();
  }

  /// شبكة (عمودان بارتفاع ثابت) أو قائمة حسب اختيار المستخدم
  Widget _collection(int count, Widget Function(int index) item) {
    final pad = EdgeInsets.all(Responsive.spacing(context, 16));
    if (_grid) {
      return GridView.builder(
        padding: pad,
        itemCount: count,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          mainAxisExtent: ViewModeStore.gridExtent(MediaQuery.sizeOf(context).width, body: 96),
        ),
        itemBuilder: (_, i) => item(i),
      );
    }
    return ListView.separated(
      padding: pad,
      itemCount: count,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (_, i) => item(i),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final labs = await FavoritesService.getLabs();
    final analyses = await FavoritesService.getAnalyses();
    if (!mounted) return;
    setState(() {
      _labs = labs;
      _analyses = analyses;
      _isLoading = false;
    });
  }

  Future<void> _removeLab(Map<String, dynamic> lab) async {
    await FavoritesService.removeLab(FavoritesService.itemId(lab));
    await _load();
  }

  Future<void> _removeAnalysis(Map<String, dynamic> analysis) async {
    await FavoritesService.removeAnalysis(FavoritesService.itemId(analysis));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();
    final lang = settings.language;

    return Directionality(
      textDirection: settings.textDirection,
      child: Scaffold(
          backgroundColor: RastTokens.bg(context),
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(kToolbarHeight + 8),
            child: Container(
              color: RastTokens.card(context),
              child: SafeArea(
                bottom: false,
                child: RastTopBar(
                  title: AppStrings.t('favorites', lang),
                  showCart: true,
                  useWhiteBackground: true,
                  backgroundColor: RastTokens.card(context),
                ),
              ),
            ),
          ),
          body: Container(
              color: RastTokens.bg(context),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    // تبويب مقسّم أنيق: خلفية رمادية فاتحة ومؤشر أبيض بظل + تبديل الشبكة/القائمة
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                      height: 48,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: RastTokens.fill(context),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        indicatorSize: TabBarIndicatorSize.tab,
                        dividerColor: Colors.transparent,
                        splashBorderRadius: BorderRadius.circular(11),
                        overlayColor: WidgetStateProperty.all(
                          Colors.transparent,
                        ),
                        indicator: BoxDecoration(
                          color: RastTokens.card(context),
                          borderRadius: BorderRadius.circular(11),
                          boxShadow: RastTokens.shadow(context, strength: 0.8),
                        ),
                        labelColor: RastTokens.brand,
                        unselectedLabelColor: RastTokens.muted(context),
                        labelStyle: TextStyle(
                          fontSize: Responsive.fontSize(context, 13.5),
                          fontWeight: FontWeight.w800,
                        ),
                        unselectedLabelStyle: TextStyle(
                          fontSize: Responsive.fontSize(context, 13.5),
                          fontWeight: FontWeight.w600,
                        ),
                        tabs: [
                          Tab(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.business_rounded,
                                  size: 17,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    AppStrings.t('labs', lang),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Tab(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.biotech_rounded,
                                  size: 17,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    AppStrings.t('analyses', lang),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ViewModeToggle(
                          grid: _grid,
                          height: 48,
                          onChanged: (g) {
                            setState(() => _grid = g);
                            ViewModeStore.setGrid('favorites', g);
                          },
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : TabBarView(
                            controller: _tabController,
                            children: [_buildLabsList(), _buildAnalysesList()],
                          ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildLabsList() {
    if (_labs.isEmpty) {
      final lang =
          context.read<AppSettingsProvider>().language;

      return _empty(
        AppStrings.t(
          'noFavoriteLabs',
          lang,
        ),
      );
    }

    final settings = context.watch<AppSettingsProvider>();
    final isArabic = settings.isArabic;
    final lang = settings.language;

    return _collection(_labs.length, (index) {
        final lab = _labs[index];

        final name = LocaleUtils.localizedBusinessName(
          lab,
          isArabic,
        );

        final imageUrl = ApiConfig.resolveImageUrl(
          lab['logo_url'],
          lab['logo'],
        );

        final city = lab['city']?.toString() ?? '';
        final district =
            lab['district']?.toString() ?? '';

        final location = [
          city,
          district,
        ].where((e) => e.trim().isNotEmpty).join(' · ');

        final homeService =
            lab['home_service_available'] == true;

        final rating = lab['avg_rating'] is num
            ? (lab['avg_rating'] as num).toDouble()
            : 0.0;

        return Pressable(child: _favoriteCard(
          imageUrl: imageUrl,
          placeholderIcon: Icons.business_rounded,
          title: name.isEmpty
              ? AppStrings.t('labs', lang)
              : name,
          subtitle: location,
          badge: homeService
              ? AppStrings.t('homeService', lang)
              : null,
          rating: rating > 0 ? rating : null,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => LabDetailsScreen(
                lab: lab,
              ),
            ),
          ).then((_) => _load()),
          onRemove: () => _removeLab(lab),
        )).entrance(index);
    });
  }

  Widget _buildAnalysesList() {
    if (_analyses.isEmpty) {
      final lang =
          context.read<AppSettingsProvider>().language;

      return _empty(
        AppStrings.t(
          'noFavoriteAnalyses',
          lang,
        ),
      );
    }

    final settings = context.watch<AppSettingsProvider>();
    final isArabic = settings.isArabic;
    final lang = settings.language;

    return _collection(_analyses.length, (index) {
        final analysis = _analyses[index];

        final name = LocaleUtils.localizedName(
          analysis,
          isArabic,
        );

        final category = analysis['category'] is Map
            ? LocaleUtils.localizedName(
          Map<String, dynamic>.from(
            analysis['category'] as Map,
          ),
          isArabic,
        )
            : '';

        final imageUrl = ApiConfig.analysisImageUrl(
          analysis,
          analysis,
        );

        final priceRaw =
            analysis['final_price'] ??
                analysis['price'];

        final price = priceRaw is num
            ? priceRaw.toDouble()
            : double.tryParse(
          priceRaw?.toString() ?? '',
        );

        final homeAvailable =
            analysis['home_service_available'] == true ||
                analysis['home_price'] != null ||
                analysis['home_service_price'] != null;

        return Pressable(child: _favoriteCard(
          imageUrl: imageUrl,
          placeholderIcon:
          Icons.medical_services_rounded,
          title: name.isEmpty
              ? AppStrings.t('analyses', lang)
              : name,
          subtitle: category,
          badge: homeAvailable
              ? AppStrings.t('homeService', lang)
              : null,
          price: price,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ServiceDetailScreen(
                service: analysis,
              ),
            ),
          ).then((_) => _load()),
          onRemove: () =>
              _removeAnalysis(analysis),
        )).entrance(index);
    });
  }

  Widget _favoriteCard({
    required String? imageUrl,
    required IconData placeholderIcon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required VoidCallback onRemove,
    String? badge,
    double? rating,
    double? price,
  }) {
    final lang = context.watch<AppSettingsProvider>().language;
    final isLab = placeholderIcon == Icons.business_rounded;

    final removeButton = Tooltip(
      message: L(lang, 'إزالة من المفضلة', 'Remove from favorites'),
      child: Material(
        color: Colors.white.withValues(alpha: 0.94),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onRemove,
          child: const Padding(
            padding: EdgeInsets.all(6),
            child: AnimatedFavoriteIcon(active: true, size: 16),
          ),
        ),
      ),
    );

    if (_grid) {
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
                  Container(
                    color: isLab ? RastTokens.fill(context) : null,
                    padding: isLab ? const EdgeInsets.all(18) : EdgeInsets.zero,
                    child: RastNetImage(
                      url: imageUrl,
                      radius: isLab ? 10 : 0,
                      fit: isLab ? BoxFit.contain : BoxFit.cover,
                      fallbackIcon: placeholderIcon,
                    ),
                  ),
                  PositionedDirectional(top: 8, end: 8, child: removeButton),
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
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: RastTokens.ink(context), fontSize: 13.5, height: 1.3, fontWeight: FontWeight.w800),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: RastTokens.muted(context), fontSize: 11),
                      ),
                    ],
                    const Spacer(),
                    if (price != null && price > 0)
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: RastPrice(amount: price, lang: lang, size: 16),
                      )
                    else if (rating != null)
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, size: 15, color: RastTokens.gold),
                          const SizedBox(width: 3),
                          Text(
                            rating.toStringAsFixed(1),
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: RastTokens.ink(context)),
                          ),
                        ],
                      )
                    else if (badge != null)
                      Text(
                        badge,
                        style: const TextStyle(fontSize: 11, color: RastTokens.success, fontWeight: FontWeight.w700),
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
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // الصورة البطلة والقلب فوقها (إزالة من المفضلة)
          SizedBox(
            width: 96,
            height: 96,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: isLab ? RastTokens.fill(context) : null,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  padding: isLab ? const EdgeInsets.all(10) : EdgeInsets.zero,
                  child: RastNetImage(
                    url: imageUrl,
                    radius: isLab ? 10 : 18,
                    fit: isLab ? BoxFit.contain : BoxFit.cover,
                    fallbackIcon: placeholderIcon,
                  ),
                ),
                PositionedDirectional(
                  top: 5,
                  end: 5,
                  child: Tooltip(
                    message: L(lang, 'إزالة من المفضلة', 'Remove from favorites'),
                    child: Material(
                      color: Colors.white.withValues(alpha: 0.94),
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: onRemove,
                        child: const Padding(
                          padding: EdgeInsets.all(5),
                          child: AnimatedFavoriteIcon(active: true, size: 17),
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: RastTokens.ink(context),
                      fontSize: 15,
                      height: 1.35,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          isLab ? Icons.location_on_outlined : Icons.category_outlined,
                          size: 14,
                          color: RastTokens.muted(context),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: RastTokens.muted(context), fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (price != null && price > 0)
                        RastPrice(amount: price, lang: lang, size: 18)
                      else if (rating != null) ...[
                        const Icon(Icons.star_rounded, size: 17, color: RastTokens.gold),
                        const SizedBox(width: 3),
                        Text(
                          rating.toStringAsFixed(1),
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: RastTokens.ink(context)),
                        ),
                      ],
                      const Spacer(),
                      if (badge != null)
                        RastPill(label: badge, icon: Icons.home_rounded, dense: true, color: RastTokens.success),
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

  Widget _empty(String text) {
    final lang = context.read<AppSettingsProvider>().language;
    return Center(
      child: SingleChildScrollView(
        child: RastEmptyState(
          icon: Icons.favorite_rounded,
          title: text,
          message: L(
            lang,
            'اضغط على القلب في أي تحليل أو مختبر ليظهر هنا، وتعود إليه بسرعة وقت الحجز.',
            'Tap the heart on any test or lab to save it here for quick booking.',
          ),
        ),
      ),
    );
  }
}
