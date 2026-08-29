import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rast/core/constants/app_strings.dart';
import 'package:rast/core/providers/app_settings_provider.dart';
import 'package:rast/core/services/favorites_service.dart';
import 'package:rast/core/utils/locale_utils.dart';
import 'package:rast/core/utils/responsive.dart';
import 'package:rast/core/widgets/rast_ui.dart';
import 'package:rast/features/analyses/screens/service_detail_screen.dart';
import 'package:rast/features/lab_details/screens/lab_details_screen.dart';

import '../../../core/constants/api_config.dart';
import '../../../core/theme/app_theme.dart';

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
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
      child: Container(
        decoration: const BoxDecoration(gradient: RastUi.headerGradient),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: RastTopBar(
            title: AppStrings.t('favorites', lang),
            showCart: false,
            iconColor: Colors.white,
          ),
          body: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: Container(
              color: RastUi.screenSurface(context),
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      Responsive.spacing(context, 18),
                      Responsive.spacing(context, 18),
                      Responsive.spacing(context, 18),
                      0,
                    ),
                    child: Container(
                      height: 54,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: RastUi.cardSurface(context),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: RastUi.softBorder(context),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TabBar(
                        controller: _tabController,
                        indicatorSize: TabBarIndicatorSize.tab,
                        dividerColor: Colors.transparent,
                        splashBorderRadius: BorderRadius.circular(14),
                        overlayColor: WidgetStateProperty.all(
                          Colors.transparent,
                        ),
                        indicator: BoxDecoration(
                          gradient: RastUi.brandGradient,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: RastUi.purple.withValues(alpha: 0.22),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        labelColor: Colors.white,
                        unselectedLabelColor: RastUi.textPurple,
                        labelStyle: TextStyle(
                          fontSize: Responsive.fontSize(context, 13),
                          fontWeight: FontWeight.w700,
                        ),
                        unselectedLabelStyle: TextStyle(
                          fontSize: Responsive.fontSize(context, 13),
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

    return ListView.separated(
      padding: EdgeInsets.all(
        Responsive.spacing(context, 18),
      ),
      itemCount: _labs.length,
      separatorBuilder: (_, __) =>
      const SizedBox(height: 14),
      itemBuilder: (context, index) {
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

        return _favoriteCard(
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
        );
      },
    );
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

    return ListView.separated(
      padding: EdgeInsets.all(
        Responsive.spacing(context, 18),
      ),
      itemCount: _analyses.length,
      separatorBuilder: (_, __) =>
      const SizedBox(height: 14),
      itemBuilder: (context, index) {
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

        return _favoriteCard(
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
        );
      },
    );
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
    final settings =
    context.watch<AppSettingsProvider>();

    final lang = settings.language;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: RastUi.cardSurface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: RastUi.softBorder(context)
              .withValues(alpha: 0.7),
        ),
        boxShadow: [
          BoxShadow(
            color:
            Colors.black.withValues(alpha: 0.10),
            blurRadius: 16,
            spreadRadius: 1,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: EdgeInsets.all(
              Responsive.spacing(context, 12),
            ),
            child: Row(
              crossAxisAlignment:
              CrossAxisAlignment.center,
              children: [
                // IMAGE
                ClipRRect(
                  borderRadius:
                  BorderRadius.circular(16),
                  child: SizedBox(
                    width: 82,
                    height: 82,
                    child: imageUrl != null &&
                        imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          _favoritePlaceholder(
                            placeholderIcon,
                          ),
                      errorWidget:
                          (_, __, ___) =>
                          _favoritePlaceholder(
                            placeholderIcon,
                          ),
                    )
                        : _favoritePlaceholder(
                      placeholderIcon,
                    ),
                  ),
                ),

                SizedBox(
                  width: Responsive.spacing(
                    context,
                    12,
                  ),
                ),

                // INFO
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        textAlign: TextAlign.start,
                        maxLines: 2,
                        overflow:
                        TextOverflow.ellipsis,
                        style: TextStyle(
                          color:
                          RastUi.primaryText(
                            context,
                          ),
                          fontSize:
                          Responsive.fontSize(
                            context,
                            14,
                          ),
                          height: 1.3,
                          fontWeight:
                          FontWeight.w700,
                        ),
                      ),

                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 5),

                        Row(
                          children: [
                            Icon(
                              placeholderIcon ==
                                  Icons
                                      .business_rounded
                                  ? Icons
                                  .location_on_outlined
                                  : Icons
                                  .category_outlined,
                              size: 14,
                              color: AppTheme
                                  .onSurfaceVariant,
                            ),

                            const SizedBox(width: 4),

                            Expanded(
                              child: Text(
                                subtitle,
                                textAlign:
                                TextAlign.start,
                                maxLines: 1,
                                overflow:
                                TextOverflow
                                    .ellipsis,
                                style: TextStyle(
                                  color: AppTheme
                                      .onSurfaceVariant,
                                  fontSize:
                                  Responsive
                                      .fontSize(
                                    context,
                                    11,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 10),

                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment:
                        WrapCrossAlignment.center,
                        children: [
                          if (badge != null)
                            Container(
                              padding:
                              const EdgeInsets
                                  .symmetric(
                                horizontal: 9,
                                vertical: 5,
                              ),
                              decoration:
                              BoxDecoration(
                                color: RastUi.purple
                                    .withValues(
                                  alpha: 0.08,
                                ),
                                borderRadius:
                                BorderRadius
                                    .circular(9),
                              ),
                              child: Text(
                                badge,
                                maxLines: 1,
                                overflow:
                                TextOverflow
                                    .ellipsis,
                                style: TextStyle(
                                  color:
                                  RastUi.purple,
                                  fontSize:
                                  Responsive
                                      .fontSize(
                                    context,
                                    10,
                                  ),
                                  fontWeight:
                                  FontWeight
                                      .w600,
                                ),
                              ),
                            ),

                          if (rating != null)
                            Row(
                              mainAxisSize:
                              MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  size: 16,
                                  color:
                                  AppTheme.accent,
                                ),
                                const SizedBox(
                                  width: 3,
                                ),
                                Text(
                                  rating
                                      .toStringAsFixed(
                                    1,
                                  ),
                                  style: TextStyle(
                                    color: RastUi
                                        .primaryText(
                                      context,
                                    ),
                                    fontSize:
                                    Responsive
                                        .fontSize(
                                      context,
                                      11,
                                    ),
                                    fontWeight:
                                    FontWeight
                                        .w700,
                                  ),
                                ),
                              ],
                            ),

                          if (price != null)
                            Text(
                              '${price.toStringAsFixed(2)} '
                                  '${AppStrings.t('sar', lang)}',
                              maxLines: 1,
                              overflow:
                              TextOverflow
                                  .ellipsis,
                              style: TextStyle(
                                color:
                                RastUi.purple,
                                fontSize:
                                Responsive
                                    .fontSize(
                                  context,
                                  11,
                                ),
                                fontWeight:
                                FontWeight
                                    .w700,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                SizedBox(
                  width:
                  Responsive.spacing(
                    context,
                    6,
                  ),
                ),

                // REMOVE FAVORITE
                InkWell(
                  onTap: onRemove,
                  customBorder:
                  const CircleBorder(),
                  child: Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color:
                      const Color(0xFFFFF1F3),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color:
                        const Color(0xFFFFD9DF),
                      ),
                    ),
                    child: const Icon(
                      Icons.favorite_rounded,
                      color:
                      Color(0xFFFF4D61),
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _favoritePlaceholder(
      IconData icon,
      ) {
    return Container(
      color: AppTheme.primary.withValues(
        alpha: 0.08,
      ),
      alignment: Alignment.center,
      child: Icon(
        icon,
        size: 32,
        color: AppTheme.primary,
      ),
    );
  }

  Widget _empty(String text) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal:
          Responsive.spacing(context, 24),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: RastUi.mutedText,
            fontSize:
            Responsive.fontSize(
              context,
              14,
            ),
            height: 1.5,
          ),
        ),
      ),
    );
  }
}
