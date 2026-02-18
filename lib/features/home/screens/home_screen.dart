import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:rast/core/constants/api_config.dart';
import 'package:rast/core/constants/app_strings.dart';
import 'package:rast/core/providers/app_settings_provider.dart';
import 'package:rast/core/utils/locale_utils.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:geolocator/geolocator.dart';
import 'package:rast/core/api/api_services.dart';
import 'package:rast/core/constants/dummy_data.dart';
import 'package:rast/core/services/location_service.dart';
import 'package:rast/core/theme/app_theme.dart';
import 'package:rast/core/utils/responsive.dart';
import 'package:rast/features/analyses/screens/analyses_screen.dart';
import 'package:rast/features/packages/screens/packages_screen.dart';
import 'package:rast/features/packages/screens/package_detail_screen.dart';
import 'package:rast/features/lab_details/screens/lab_details_screen.dart';
import 'package:rast/features/labs/screens/labs_screen.dart';
import 'package:rast/features/settings/screens/default_location_screen.dart';
import 'package:rast/core/api/api_client.dart';
import 'package:rast/features/auth/services/auth_service.dart';
import 'package:rast/core/widgets/gradient_button.dart';
import 'package:rast/core/widgets/rating_badge.dart';
import 'package:rast/core/widgets/search_box.dart';
import 'package:shimmer/shimmer.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _carouselIndex = 0;
  int _selectedCategoryIndex = 0;
  int _categoriesPageIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  late PageController _categoriesPageController;

  Map<String, dynamic>? _homeData;
  List<dynamic> _packages = [];
  List<dynamic> _offers = [];
  List<dynamic> _carouselSlides = [];
  int? _totalPackages;
  int? _totalOffers;
  int? _totalLabs;
  bool _isLoading = true;
  String? _error;

  /// استخراج العدد الكلي من استجابة API (meta.total أو total)
  static int? _totalFromResponse(Map<String, dynamic>? res) {
    if (res == null) return null;
    final meta = res['meta'];
    if (meta is Map && meta['total'] != null) {
      final t = meta['total'];
      if (t is num) return t.toInt();
      if (t is String) return int.tryParse(t);
    }
    final t = res['total'];
    if (t is num) return t.toInt();
    if (t is String) return int.tryParse(t);
    return null;
  }

  static int? _intFromMap(Map<String, dynamic>? m, String key) {
    if (m == null) return null;
    final v = m[key];
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  /// العدد المعروض للإحصائية: نأخذ الأكبر بين total من API وطول القائمة
  /// (لتجنب نقص واحد إن كان الخادم يعيد عداً يبدأ من الصفر أو يعيد صفحة واحدة فقط)
  int _statCount(int? totalFromApi, int listLength) {
    if (totalFromApi == null) return listLength;
    return totalFromApi > listLength ? totalFromApi : listLength;
  }

  @override
  void initState() {
    super.initState();
    _categoriesPageController = PageController();
    _loadData();
  }

  /// استخراج قائمة المختبرات من استجابة API (يدعم الترقيم)
  static List<dynamic> _extractProviderList(Map<String, dynamic> res) {
    final data = res['data'];
    if (data is List) return List.from(data);
    if (data is Map && data['data'] is List)
      return List.from(data['data'] as List);
    return [];
  }

  /// عرض المختبرات المفعلة والنشطة فقط
  static List<dynamic> _filterActiveLabs(List<dynamic> list) {
    return list.where((e) {
      if (e is! Map) return false;
      final active = e['is_active'];
      return active == null || active == true;
    }).toList();
  }

  /// ترتيب المختبرات: الأعلى تقييماً أولاً، ثم الأحدث (id)، ثم المسافة إن وُجدت
  static void _sortLabsByRatingThenNewest(List<dynamic> list) {
    list.sort((a, b) {
      final am = a is Map ? a as Map<String, dynamic> : <String, dynamic>{};
      final bm = b is Map ? b as Map<String, dynamic> : <String, dynamic>{};
      final aRating = (am['avg_rating'] is num ? am['avg_rating'] as num : 0)
          .toDouble();
      final bRating = (bm['avg_rating'] is num ? bm['avg_rating'] as num : 0)
          .toDouble();
      if (bRating != aRating) return bRating.compareTo(aRating);
      final aReviews = am['total_reviews'] is num
          ? (am['total_reviews'] as num).toInt()
          : 0;
      final bReviews = bm['total_reviews'] is num
          ? (bm['total_reviews'] as num).toInt()
          : 0;
      if (bReviews != aReviews) return bReviews.compareTo(aReviews);
      final aId = am['id'] is num ? (am['id'] as num).toInt() : 0;
      final bId = bm['id'] is num ? (bm['id'] as num).toInt() : 0;
      return bId.compareTo(aId);
    });
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final homeData = await Api.home.getHome();
      // شرائح الكاروسيل: من الصفحة الرئيسية أولاً، وإلا من /mobile/slides
      List<dynamic> slidesList =
          (homeData['carousel_slides'] as List?)
              ?.where((e) => e != null)
              .toList() ??
          [];
      if (slidesList.isEmpty) {
        try {
          slidesList = await Api.home.getMobileSlides();
        } catch (_) {}
      }
      // الباقات من بيانات الصفحة الرئيسية أولاً، وإلا من API الباقات
      int? totalPackagesFromApi;
      List<dynamic> packagesList =
          (homeData['packages'] as List?)?.where((e) => e != null).toList() ??
          [];
      if (packagesList.isEmpty) {
        try {
          final packagesRes = await Api.services.getPackages(
            page: 1,
            perPage: 20,
          );
          totalPackagesFromApi = _totalFromResponse(packagesRes);
          final data = packagesRes['data'];
          if (data is List) {
            packagesList = List.from(data);
          } else if (data is Map && data['data'] is List) {
            packagesList = List.from(data['data'] as List);
          }
        } catch (_) {}
      } else {
        totalPackagesFromApi =
            _totalFromResponse(homeData) ?? _intFromMap(homeData, 'packages_count');
      }
      // العروض من API
      int? totalOffersFromApi;
      List<dynamic> offersList = [];
      try {
        final offersRes = await Api.services.getOffers(page: 1);
        totalOffersFromApi = _totalFromResponse(offersRes);
        final data = offersRes['data'];
        if (data is List) {
          offersList = List.from(data);
        } else if (data is Map && data['data'] is List) {
          offersList = List.from(data['data'] as List);
        }
      } catch (_) {}
      // المختبرات المميزة: من الصفحة الرئيسية، أو الأعلى تقييماً، أو الأحدث، أو حسب المسافة
      int? totalLabsFromApi;
      List<dynamic> labsList =
          (homeData['featured_providers'] as List?)
              ?.where((e) => e != null)
              .toList() ??
          [];
      if (labsList.isEmpty) {
        double? lat;
        double? lng;
        try {
          final permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied)
            await Geolocator.requestPermission();
          if (await Geolocator.isLocationServiceEnabled()) {
            final pos = await Geolocator.getCurrentPosition();
            lat = pos.latitude;
            lng = pos.longitude;
          }
        } catch (_) {}
        if (lat == null || lng == null) {
          final saved = await LocationService.getDefaultLocation();
          if (saved != null) {
            lat = saved.lat;
            lng = saved.lng;
          }
        }
        if (lat != null && lng != null) {
          try {
            final res = await Api.providers.getProviders(
              perPage: 10,
              latitude: lat,
              longitude: lng,
            );
            totalLabsFromApi = _totalFromResponse(res);
            labsList = _extractProviderList(res);
            if (labsList.length > 6) labsList = labsList.take(6).toList();
          } catch (_) {}
        }
        if (labsList.isEmpty) {
          try {
            final providersRes = await Api.providers.getProviders(
              sort: 'rating',
              perPage: 15,
            );
            totalLabsFromApi ??= _totalFromResponse(providersRes);
            labsList = _extractProviderList(providersRes);
            _sortLabsByRatingThenNewest(labsList);
            if (labsList.length > 6) labsList = labsList.take(6).toList();
          } catch (_) {}
        }
        if (labsList.isEmpty) {
          try {
            final providersRes = await Api.providers.getProviders(perPage: 15);
            totalLabsFromApi ??= _totalFromResponse(providersRes);
            labsList = _extractProviderList(providersRes);
            labsList.sort((a, b) {
              final aId = (a is Map && a['id'] != null)
                  ? (a['id'] as num).toInt()
                  : 0;
              final bId = (b is Map && b['id'] != null)
                  ? (b['id'] as num).toInt()
                  : 0;
              return bId.compareTo(aId);
            });
            if (labsList.length > 6) labsList = labsList.take(6).toList();
          } catch (_) {}
        }
      }
      labsList = _filterActiveLabs(labsList);
      setState(() {
        _homeData = Map<String, dynamic>.from(homeData)
          ..['featured_providers'] = labsList;
        _carouselSlides = slidesList.isNotEmpty
            ? slidesList
            : DummyData.carouselSlides;
        _packages = packagesList.isEmpty
            ? List.from(DummyData.packages)
            : packagesList;
        _offers = offersList;
        _totalPackages = totalPackagesFromApi;
        _totalOffers = totalOffersFromApi;
        _totalLabs = totalLabsFromApi;
        _isLoading = false;
      });
      _maybeShowPopup();
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error =
            e.toString().contains('SocketException') ||
                e.toString().contains('Failed host')
            ? AppStrings.t('checkConnection', 'ar')
            : e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _categoriesPageController.dispose();
    super.dispose();
  }

  List<dynamic> get _slides => _carouselSlides.isNotEmpty
      ? _carouselSlides
      : (_homeData?['carousel_slides'] as List?) ?? DummyData.carouselSlides;
  List<dynamic> get _categories =>
      (_homeData?['categories'] as List?) ?? DummyData.categories;
  List<dynamic> get _labs =>
      (_homeData?['featured_providers'] as List?) ?? [];

  Map<String, dynamic>? get _banner {
    final b = _homeData?['banner'];
    if (b is Map) return Map<String, dynamic>.from(b);
    return null;
  }

  Future<void> _maybeShowPopup() async {
    try {
      final popup = await Api.home.getPopup();
      if (popup == null || !mounted) return;
      final id = popup['id']?.toString();
      final showOnce = popup['show_once_per_user'] == true;
      if (showOnce && id != null) {
        final prefs = await SharedPreferences.getInstance();
        if (prefs.getBool('popup_shown_$id') == true) return;
        prefs.setBool('popup_shown_$id', true);
      }
      if (!mounted) return;
      _showPopupDialog(popup);
    } catch (_) {}
  }

  void _showPopupDialog(Map<String, dynamic> popup) {
    final title = popup['title']?.toString() ?? '';
    final body = popup['body']?.toString() ?? '';
    final imageUrl = popup['image_url']?.toString();
    final link = popup['link']?.toString();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (imageUrl != null && imageUrl.isNotEmpty)
                  Stack(
                    children: [
                      InkWell(
                        onTap: () {
                          if (link != null && link.isNotEmpty) {
                            final uri = Uri.tryParse(link);
                            if (uri != null) {
                              launchUrl(
                                uri,
                                mode: LaunchMode.externalApplication,
                              );
                            }
                          }
                          Navigator.pop(ctx);
                        },
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          height: 210,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            height: 210,
                            color: AppTheme.surfaceVariant,
                          ),
                          errorWidget: (_, __, ___) => Container(
                            height: 210,
                            color: AppTheme.surfaceVariant,
                            child: const Icon(Icons.image_not_supported),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Material(
                          color: Colors.black.withValues(alpha: 0.45),
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => Navigator.pop(ctx),
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                if (title.isNotEmpty || body.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (title.isNotEmpty)
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        if (title.isNotEmpty && body.isNotEmpty)
                          const SizedBox(height: 6),
                        if (body.isNotEmpty)
                          Text(body, style: const TextStyle(height: 1.45)),
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

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    if (_isLoading) {
      return _buildLoadingState(topPadding);
    }
    if (_error != null) {
      return _buildErrorState(topPadding);
    }

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        _buildAppBar(topPadding),
        if (_banner != null && _banner!['active'] == true) _buildBannerBar(),
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: Responsive.spacing(context, 8)),
              _buildSearchBar()
                  .animate()
                  .fadeIn(duration: 600.ms)
                  .slideY(begin: 0.05, end: 0, curve: Curves.easeOutCubic),
              SizedBox(height: Responsive.spacing(context, 14)),
              _buildShowcaseHero()
                  .animate()
                  .fadeIn(duration: 600.ms, delay: 100.ms)
                  .slideY(begin: 0.05, end: 0, curve: Curves.easeOutCubic),
              if (_offers.isNotEmpty) ...[
                SizedBox(height: Responsive.spacing(context, 18)),
                _buildSectionShell(
                  AppStrings.t(
                    'offers',
                    context.watch<AppSettingsProvider>().language,
                  ),
                  AppStrings.t(
                    'viewAll',
                    context.watch<AppSettingsProvider>().language,
                  ),
                  onActionTap: _navigateToAnalyses,
                  child: _buildOffers(),
                ).animate().fadeIn(duration: 500.ms, delay: 200.ms),
              ],
              SizedBox(height: Responsive.spacing(context, 18)),
              _buildSectionShell(
                AppStrings.t(
                  'categories',
                  context.watch<AppSettingsProvider>().language,
                ),
                AppStrings.t(
                  'viewAll',
                  context.watch<AppSettingsProvider>().language,
                ),
                onActionTap: _navigateToAnalyses,
                child: _buildCategories(),
              ).animate().fadeIn(duration: 500.ms, delay: 250.ms),
              SizedBox(height: Responsive.spacing(context, 18)),
              _buildSectionShell(
                AppStrings.t(
                  'packages',
                  context.watch<AppSettingsProvider>().language,
                ),
                AppStrings.t(
                  'viewAll',
                  context.watch<AppSettingsProvider>().language,
                ),
                onActionTap: _navigateToPackages,
                child: _buildPackages(),
              ).animate().fadeIn(duration: 500.ms, delay: 300.ms),
              SizedBox(height: Responsive.spacing(context, 18)),
              _buildSectionShell(
                AppStrings.t(
                  'featuredLabs',
                  context.watch<AppSettingsProvider>().language,
                ),
                AppStrings.t(
                  'viewAll',
                  context.watch<AppSettingsProvider>().language,
                ),
                onActionTap: () => _navigateToLabs(),
                child: _buildLabs(),
              ).animate().fadeIn(duration: 500.ms, delay: 350.ms),
              SizedBox(height: Responsive.spacing(context, 110)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildShowcaseHero() {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.spacing(context, 16),
      ),
      child: Container(
        padding: EdgeInsets.all(Responsive.spacing(context, 14)),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              theme.colorScheme.primary.withValues(alpha: 0.18),
              theme.colorScheme.secondary.withValues(alpha: 0.10),
              theme.colorScheme.surface.withValues(alpha: 0.92),
            ],
          ),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.16),
          ),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.10),
              blurRadius: 24,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.t(
                'bookNowInMinute',
                context.watch<AppSettingsProvider>().language,
              ),
              style: TextStyle(
                fontSize: Responsive.fontSize(context, 17),
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
            SizedBox(height: Responsive.spacing(context, 10)),
            _buildCarousel(),
            SizedBox(height: Responsive.spacing(context, 12)),
            _buildHeroMetricsStrip(),
            SizedBox(height: Responsive.spacing(context, 10)),
            Row(
              children: [
                Expanded(
                  child: GradientFilledButton(
                    onPressed: _navigateToAnalyses,
                    child: Text(
                      AppStrings.t(
                        'bookTest',
                        context.watch<AppSettingsProvider>().language,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: Responsive.spacing(context, 10)),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _navigateToPackages,
                    child: Text(
                      AppStrings.t(
                        'browsePackages',
                        context.watch<AppSettingsProvider>().language,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroMetricsStrip() {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: _buildMetricTile(
            label: AppStrings.t(
              'offers',
              context.watch<AppSettingsProvider>().language,
            ),
            value: _statCount(_totalOffers, _offers.length).toString(),
            icon: Icons.local_offer_rounded,
            color: theme.colorScheme.secondary,
          ),
        ),
        SizedBox(width: Responsive.spacing(context, 8)),
        Expanded(
          child: _buildMetricTile(
            label: AppStrings.t(
              'packages',
              context.watch<AppSettingsProvider>().language,
            ),
            value: _statCount(_totalPackages, _packages.length).toString(),
            icon: Icons.inventory_2_rounded,
            color: theme.colorScheme.primary,
          ),
        ),
        SizedBox(width: Responsive.spacing(context, 8)),
        Expanded(
          child: _buildMetricTile(
            label: AppStrings.t(
              'labs',
              context.watch<AppSettingsProvider>().language,
            ),
            value: _statCount(_totalLabs, _labs.length).toString(),
            icon: Icons.verified_user_rounded,
            color: AppTheme.success,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 14),
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 10),
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionShell(
    String title,
    String? action, {
    required Widget child,
    VoidCallback? onActionTap,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.spacing(context, 16),
      ),
      child: Container(
        padding: EdgeInsets.only(
          top: Responsive.spacing(context, 12),
          bottom: Responsive.spacing(context, 8),
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.90),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.12),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildSectionTitle(title, action, onActionTap: onActionTap),
            SizedBox(height: Responsive.spacing(context, 8)),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState(double topPadding) {
    return CustomScrollView(
      slivers: [
        _buildAppBar(topPadding),
        SliverToBoxAdapter(
          child: Column(
            children: [
              SizedBox(height: Responsive.spacing(context, 16)),
              _buildShimmerBox(50),
              SizedBox(height: Responsive.spacing(context, 12)),
              _buildShimmerBox(Responsive.carouselHeight(context)),
              SizedBox(height: Responsive.spacing(context, 20)),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: Responsive.spacing(context, 16),
                ),
                child: Wrap(
                  spacing: Responsive.spacing(context, 8),
                  runSpacing: Responsive.spacing(context, 8),
                  children: List.generate(8, (_) {
                    final w = MediaQuery.sizeOf(context).width;
                    final itemW = (w - 32 - 24) / 4;
                    return Shimmer.fromColors(
                      baseColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      highlightColor: Theme.of(context).colorScheme.surface,
                      child: Container(
                        height: 70,
                        width: itemW,
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              SizedBox(height: Responsive.spacing(context, 32)),
              _buildShimmerBox(100, width: double.infinity),
              SizedBox(height: Responsive.spacing(context, 32)),
              _buildShimmerBox(180, width: double.infinity),
              SizedBox(height: Responsive.spacing(context, 32)),
              _buildShimmerBox(200, width: double.infinity),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildShimmerBox(double height, {double? width}) {
    return Shimmer.fromColors(
      baseColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      highlightColor: Theme.of(context).colorScheme.surface,
      child: Container(
        height: height,
        width: width ?? double.infinity,
        margin: EdgeInsets.symmetric(
          horizontal: Responsive.spacing(context, 16),
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(24),
        ),
      ),
    );
  }

  Widget _buildErrorState(double topPadding) {
    return CustomScrollView(
      slivers: [
        _buildAppBar(topPadding),
        SliverFillRemaining(
          child: Padding(
            padding: EdgeInsets.all(Responsive.spacing(context, 24)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.cloud_off_rounded,
                  size: 64,
                  color: AppTheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
                SizedBox(height: Responsive.spacing(context, 16)),
                Text(
                  AppStrings.t(
                    'loadError',
                    context.watch<AppSettingsProvider>().language,
                  ),
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 18),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: Responsive.spacing(context, 8)),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 14),
                    color: AppTheme.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: Responsive.spacing(context, 24)),
                GradientFilledButtonIcon(
                  onPressed: _loadData,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(
                    AppStrings.t(
                      'retry',
                      context.watch<AppSettingsProvider>().language,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBannerBar() {
    final banner = _banner!;
    final message = banner['message']?.toString();
    if (message == null || message.isEmpty)
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    Color bgColor;
    try {
      final hex = (banner['bg_color'] ?? '#ffc107').toString().replaceFirst(
        '#',
        '',
      );
      bgColor = Color(int.parse(hex.length == 6 ? 'FF$hex' : hex, radix: 16));
    } catch (_) {
      bgColor = AppTheme.warning;
    }
    Color textColor;
    try {
      final hex = (banner['text_color'] ?? '#212529').toString().replaceFirst(
        '#',
        '',
      );
      textColor = Color(int.parse(hex.length == 6 ? 'FF$hex' : hex, radix: 16));
    } catch (_) {
      textColor = AppTheme.onSurface;
    }
    return SliverToBoxAdapter(
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: Responsive.spacing(context, 16),
          vertical: Responsive.spacing(context, 10),
        ),
        color: bgColor,
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: textColor,
            fontSize: Responsive.fontSize(context, 14),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  SliverAppBar _buildAppBar(double topPadding) {
    final settings = context.watch<AppSettingsProvider>();
    final lang = settings.language;
    final theme = Theme.of(context);
    final parts = (AuthService.currentUser?.name ?? '').trim().split(
      RegExp(r'\s+'),
    );
    final firstName = parts.isNotEmpty ? parts.first : '';
    final greeting = firstName.isNotEmpty
        ? AppStrings.tParam('greetingWithName', lang, firstName)
        : AppStrings.t('greeting', lang);
    final subtitle = AppStrings.t('homeSubtitle', lang);

    return SliverAppBar(
      toolbarHeight: 0,
      pinned: false,
      floating: true,
      snap: true,
      expandedHeight: topPadding + 146,
      backgroundColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        background: Padding(
          padding: EdgeInsets.fromLTRB(
            Responsive.spacing(context, 16),
            topPadding + 10,
            Responsive.spacing(context, 16),
            8,
          ),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.spacing(context, 16),
              vertical: Responsive.spacing(context, 14),
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  theme.colorScheme.primary.withValues(alpha: 0.16),
                  theme.colorScheme.secondary.withValues(alpha: 0.12),
                ],
              ),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.15),
              ),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        greeting,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: Responsive.fontSize(context, 20),
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                          letterSpacing: -0.2,
                        ),
                      ),
                      SizedBox(height: Responsive.spacing(context, 4)),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: Responsive.fontSize(context, 12),
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildHeaderAction(
                      icon: Icons.notifications_outlined,
                      onTap: () {},
                    ),
                    SizedBox(width: Responsive.spacing(context, 8)),
                    _buildHeaderAction(
                      icon: Icons.location_on_outlined,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DefaultLocationScreen(),
                        ),
                      ).then((_) => _loadData()),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderAction({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.18),
            ),
          ),
          child: Icon(icon, size: 22, color: theme.colorScheme.primary),
        ),
      ),
    );
  }

  Widget _buildCarousel() {
    final height = Responsive.carouselHeight(context);
    final slides = _slides;
    if (slides.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        CarouselSlider.builder(
          itemCount: slides.length,
          itemBuilder: (context, index, realIndex) {
            final slide = slides[index] is Map
                ? slides[index] as Map<String, dynamic>
                : <String, dynamic>{};
            final imageUrl = ApiConfig.resolveImageUrl(
              slide['image_url'],
              slide['image'],
            );
            return Padding(
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.spacing(context, 10),
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: AppTheme.cardShadowElevated,
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Theme.of(
                            context,
                          ).colorScheme.outline.withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.98),
                    width: 1.5,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (imageUrl != null && imageUrl.isNotEmpty)
                      CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            Container(color: AppTheme.surfaceVariant),
                        errorWidget: (_, __, ___) => Container(
                          color: AppTheme.primary.withValues(alpha: 0.2),
                          child: Icon(
                            Icons.image_not_supported,
                            size: 48,
                            color: AppTheme.primary,
                          ),
                        ),
                      )
                    else
                      Container(
                        color: AppTheme.primary.withValues(alpha: 0.2),
                        child: Icon(
                          Icons.image,
                          size: 48,
                          color: AppTheme.primary,
                        ),
                      ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: EdgeInsets.all(
                          Responsive.spacing(context, 14),
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.75),
                            ],
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              slide['title']?.toString() ?? '',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: Responsive.fontSize(context, 12),
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (slide['subtitle'] != null)
                              Text(
                                slide['subtitle'].toString(),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: Responsive.fontSize(context, 10),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          options: CarouselOptions(
            height: height,
            viewportFraction: 0.88,
            enlargeCenterPage: true,
            autoPlay: slides.length > 1,
            autoPlayInterval: const Duration(seconds: 4),
            onPageChanged: (index, _) => setState(() => _carouselIndex = index),
          ),
        ),
        SizedBox(height: Responsive.spacing(context, 10)),
        AnimatedSmoothIndicator(
          activeIndex: _carouselIndex,
          count: slides.length,
          effect: WormEffect(
            dotWidth: 12,
            dotHeight: 12,
            activeDotColor: AppTheme.primary,
            dotColor: AppTheme.onSurfaceVariant.withValues(alpha: 0.3),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.spacing(context, 16),
      ),
      child: SearchBox(
        controller: _searchController,
        hintText: AppStrings.t(
          'searchHint',
          context.watch<AppSettingsProvider>().language,
        ),
        onFilterTap: _showFilterBottomSheet,
      ),
    );
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          padding: EdgeInsets.all(Responsive.spacing(context, 24)),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: AppTheme.cardShadowElevated,
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                SizedBox(height: Responsive.spacing(context, 20)),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.tune_rounded,
                        color: AppTheme.primary,
                        size: 22,
                      ),
                    ),
                    SizedBox(width: Responsive.spacing(context, 12)),
                    Text(
                      AppStrings.t(
                        'filterResults',
                        context.watch<AppSettingsProvider>().language,
                      ),
                      style: TextStyle(
                        fontSize: Responsive.fontSize(context, 15),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: Responsive.spacing(context, 20)),
                ...DummyData.filterOptions.map(
                  (opt) => ListTile(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 0,
                      vertical: 4,
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.filter_list_rounded,
                        size: 20,
                        color: AppTheme.primary,
                      ),
                    ),
                    title: Text(
                      LocaleUtils.localizedName(
                        opt,
                        context.watch<AppSettingsProvider>().isArabic,
                      ),
                      style: TextStyle(
                        fontSize: Responsive.fontSize(context, 13),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: AppTheme.onSurfaceVariant,
                    ),
                    onTap: () => Navigator.pop(ctx),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToAnalyses() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AnalysesScreen()),
    );
  }

  void _navigateToPackages() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PackagesScreen()),
    );
  }

  void _navigateToLabs() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LabsScreen()),
    );
  }

  void _navigateToLabDetails(Map<String, dynamic> lab) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LabDetailsScreen(lab: lab)),
    );
  }

  Widget _buildLabAvatar(String? logoUrl, double size) {
    final theme = Theme.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(
          color: theme.brightness == Brightness.dark
              ? theme.colorScheme.outline.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.95),
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: (logoUrl != null && logoUrl.isNotEmpty)
            ? CachedNetworkImage(
                imageUrl: logoUrl,
                width: size,
                height: size,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: AppTheme.surfaceVariant,
                  child: Icon(
                    Icons.business_rounded,
                    size: size * 0.45,
                    color: AppTheme.primary,
                  ),
                ),
                errorWidget: (_, __, ___) => Container(
                  color: AppTheme.surfaceVariant,
                  child: Icon(
                    Icons.business_rounded,
                    size: size * 0.45,
                    color: AppTheme.primary,
                  ),
                ),
              )
            : Container(
                color: AppTheme.surfaceVariant,
                child: Icon(
                  Icons.business_rounded,
                  size: size * 0.45,
                  color: AppTheme.primary,
                ),
              ),
      ),
    );
  }

  Widget _buildSectionTitle(
    String title,
    String? action, {
    VoidCallback? onActionTap,
  }) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.spacing(context, 16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: primary,
                    boxShadow: [
                      BoxShadow(
                        color: primary.withValues(alpha: 0.35),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: Responsive.spacing(context, 10)),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: Responsive.fontSize(context, 18),
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (action != null)
            TextButton.icon(
              onPressed: onActionTap,
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
              ),
              icon: Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              label: Text(
                action,
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 13),
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCategories() {
    final categories = _categories;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final hPadding = Responsive.spacing(context, 16) * 2;
    final gaps = Responsive.spacing(context, 10) * 2;
    final itemWidth = (screenWidth - hPadding - gaps) / 3;
    final iconSize = (itemWidth * 0.82).clamp(52.0, 68.0);
    const textAreaHeight = 38.0;
    final rowHeight =
        iconSize + Responsive.spacing(context, 6) + textAreaHeight;
    const categoriesPerPage = 6;
    final pageCount = (categories.length / categoriesPerPage).ceil();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: rowHeight * 2 + Responsive.spacing(context, 10),
          child: PageView.builder(
            controller: _categoriesPageController,
            onPageChanged: (i) => setState(() => _categoriesPageIndex = i),
            padEnds: false,
            itemCount: pageCount,
            itemBuilder: (context, pageIndex) {
              final start = pageIndex * categoriesPerPage;
              return Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: Responsive.spacing(context, 16),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(3, (col) {
                    return Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: List.generate(2, (row) {
                          final index = start + col + row * 3;
                          if (index >= categories.length)
                            return SizedBox(height: rowHeight);
                          final cat = categories[index] is Map
                              ? categories[index] as Map<String, dynamic>
                              : <String, dynamic>{};
                          final isSelected = _selectedCategoryIndex == index;
                          final iconUrl = cat['icon_url']?.toString();
                          final icon = cat['icon']?.toString() ?? '🩸';
                          final displayName = LocaleUtils.localizedName(
                            cat,
                            context.watch<AppSettingsProvider>().isArabic,
                          );
                          final id = cat['id'] is int
                              ? cat['id'] as int
                              : cat['id'] is num
                              ? (cat['id'] as num).toInt()
                              : null;
                          final url =
                              ApiConfig.resolveImageUrl(
                                cat['image_url'],
                                cat['image'],
                              ) ??
                              iconUrl;
                          return Padding(
                            padding: EdgeInsets.only(
                              left: col > 0
                                  ? Responsive.spacing(context, 5)
                                  : 0,
                              right: col < 2
                                  ? Responsive.spacing(context, 5)
                                  : 0,
                              bottom: row < 1
                                  ? Responsive.spacing(context, 10)
                                  : 0,
                            ),
                            child: SizedBox(
                              height: rowHeight,
                              child: GestureDetector(
                                onTap: () {
                                  setState(
                                    () => _selectedCategoryIndex = index,
                                  );
                                  if (id != null) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            AnalysesScreen(categoryId: id),
                                      ),
                                    );
                                  } else {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const AnalysesScreen(),
                                      ),
                                    );
                                  }
                                },
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: iconSize,
                                      height: iconSize,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isSelected
                                              ? AppTheme.primary
                                              : Colors.transparent,
                                          width: 2.5,
                                        ),
                                        boxShadow: [
                                          if (isSelected) ...AppTheme.softGlow,
                                          BoxShadow(
                                            color: AppTheme.primary.withValues(
                                              alpha: isSelected ? 0.15 : 0.04,
                                            ),
                                            blurRadius: 10,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: ClipOval(
                                        child: (url != null && url.isNotEmpty)
                                            ? CachedNetworkImage(
                                                imageUrl: url,
                                                fit: BoxFit.cover,
                                                width: iconSize,
                                                height: iconSize,
                                                placeholder: (_, __) => Container(
                                                  color:
                                                      AppTheme.surfaceVariant,
                                                  child: Icon(
                                                    Icons
                                                        .medical_services_outlined,
                                                    color: AppTheme.primary,
                                                    size: iconSize * 0.5,
                                                  ),
                                                ),
                                                errorWidget: (_, __, ___) =>
                                                    _buildCategoryIconFallback(
                                                      icon,
                                                      iconSize,
                                                      isSelected,
                                                    ),
                                              )
                                            : _buildCategoryIconFallback(
                                                icon,
                                                iconSize,
                                                isSelected,
                                              ),
                                      ),
                                    ),
                                    SizedBox(
                                      height: Responsive.spacing(context, 6),
                                    ),
                                    SizedBox(
                                      height: textAreaHeight,
                                      width: itemWidth,
                                      child: Center(
                                        child: Text(
                                          displayName,
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: Responsive.fontSize(
                                              context,
                                              11.5,
                                            ),
                                            color: isSelected
                                                ? AppTheme.primary
                                                : AppTheme.onSurfaceVariant,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    );
                  }),
                ),
              );
            },
          ),
        ),
        if (pageCount > 1) ...[
          SizedBox(height: Responsive.spacing(context, 8)),
          AnimatedSmoothIndicator(
            activeIndex: _categoriesPageIndex,
            count: pageCount,
            effect: WormEffect(
              dotWidth: 6,
              dotHeight: 6,
              activeDotColor: AppTheme.primary,
              dotColor: AppTheme.onSurfaceVariant.withValues(alpha: 0.3),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCategoryIconFallback(String icon, double size, bool isSelected) {
    final isEmoji = icon.length <= 2 || icon.runes.length <= 2;
    return Container(
      width: size,
      height: size,
      color: isSelected
          ? AppTheme.primary.withValues(alpha: 0.12)
          : AppTheme.surfaceVariant,
      child: Center(
        child: isEmoji
            ? Text(icon, style: TextStyle(fontSize: size * 0.45))
            : Icon(
                Icons.medical_services_outlined,
                size: size * 0.5,
                color: AppTheme.primary,
              ),
      ),
    );
  }

  Widget _buildPackages() {
    final packages = _packages.isEmpty ? DummyData.packages : _packages;
    final cardWidth = Responsive.packageCardWidth(context);
    final cardHeight = (cardWidth * 1.25).clamp(200.0, 280.0);
    return SizedBox(
      height: cardHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(
          horizontal: Responsive.spacing(context, 16),
        ),
        itemCount: packages.length,
        itemBuilder: (context, index) {
          final pkg = packages[index] is Map
              ? packages[index] as Map<String, dynamic>
              : <String, dynamic>{};
          final displayName = LocaleUtils.localizedName(
            pkg,
            context.watch<AppSettingsProvider>().isArabic,
          );
          double price = ApiConfig.priceFromMap(pkg);
          if (price == 0.0) {
            final psList = pkg['provider_services'] ?? pkg['providerServices'];
            if (psList is List && psList.isNotEmpty) {
              final first = psList.first;
              if (first is Map<String, dynamic>)
                price = ApiConfig.priceFromMap(first);
            }
          }
          final orig = pkg['original_price'];
          final originalPrice = (orig is num)
              ? orig.toDouble()
              : ((orig is String) ? double.tryParse(orig) : null);
          final imageUrl = ApiConfig.packageImageUrl(pkg);
          final testsCount =
              pkg['tests_count'] ??
              (pkg['package_items'] is List
                  ? (pkg['package_items'] as List).length
                  : 0);
          return SizedBox(
            width: cardWidth,
            child: Padding(
              padding: EdgeInsets.only(left: Responsive.spacing(context, 12)),
              child: Container(
                decoration: AppTheme.cardDecorationFor(context),
                clipBehavior: Clip.antiAlias,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PackageDetailScreen(package: pkg),
                      ),
                    ),
                    borderRadius: BorderRadius.circular(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 5,
                          child: imageUrl != null && imageUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  placeholder: (_, __) =>
                                      Container(color: AppTheme.surfaceVariant),
                                  errorWidget: (_, __, ___) => Container(
                                    color: AppTheme.primary.withValues(
                                      alpha: 0.12,
                                    ),
                                    child: Icon(
                                      Icons.medical_services,
                                      size: 40,
                                      color: AppTheme.primary,
                                    ),
                                  ),
                                )
                              : Container(
                                  color: AppTheme.primary.withValues(
                                    alpha: 0.12,
                                  ),
                                  child: Icon(
                                    Icons.medical_services,
                                    size: 40,
                                    color: AppTheme.primary,
                                  ),
                                ),
                        ),
                        Expanded(
                          flex: 4,
                          child: Padding(
                            padding: EdgeInsets.all(
                              Responsive.spacing(context, 8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  displayName,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: Responsive.fontSize(context, 11),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: AppTheme.auroraGradient,
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: AppTheme.softGlow,
                                      ),
                                      child: Text(
                                        price > 0
                                            ? '${price.toStringAsFixed(2)} ${AppStrings.t('sar', context.watch<AppSettingsProvider>().language)}'
                                            : AppStrings.t(
                                                'contactForPrice',
                                                context
                                                    .watch<
                                                      AppSettingsProvider
                                                    >()
                                                    .language,
                                              ),
                                        style: TextStyle(
                                          fontSize: Responsive.fontSize(
                                            context,
                                            11,
                                          ),
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    if (originalPrice != null) ...[
                                      SizedBox(
                                        width: Responsive.spacing(context, 6),
                                      ),
                                      Text(
                                        '${originalPrice.toStringAsFixed(2)} ${AppStrings.t('sar', context.watch<AppSettingsProvider>().language)}',
                                        style: TextStyle(
                                          decoration:
                                              TextDecoration.lineThrough,
                                          fontSize: Responsive.fontSize(
                                            context,
                                            10,
                                          ),
                                          color: AppTheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                Text(
                                  '$testsCount ${AppStrings.t('testsCount', context.watch<AppSettingsProvider>().language)}',
                                  style: TextStyle(
                                    fontSize: Responsive.fontSize(context, 10),
                                    color: AppTheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOffers() {
    final offers = _offers;
    if (offers.isEmpty) return const SizedBox.shrink();
    final cardWidth = Responsive.packageCardWidth(context) * 0.95;
    final cardHeight = (cardWidth * 0.85).clamp(120.0, 160.0);
    return SizedBox(
      height: cardHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(
          horizontal: Responsive.spacing(context, 16),
        ),
        itemCount: offers.length,
        itemBuilder: (context, index) {
          final offer = offers[index] is Map
              ? offers[index] as Map<String, dynamic>
              : <String, dynamic>{};
          final displayName = LocaleUtils.localizedName(
            offer,
            context.watch<AppSettingsProvider>().isArabic,
          );
          final imageUrl = ApiConfig.resolveImageUrl(
            offer['image_url'],
            offer['image'],
          );
          final discount = offer['discount_percent'] ?? offer['discount'];
          final discountStr = discount != null
              ? '${discount is num ? discount.toInt() : discount}%'
              : null;
          return SizedBox(
            width: cardWidth,
            child: Padding(
              padding: EdgeInsets.only(left: Responsive.spacing(context, 12)),
              child: Container(
                decoration: AppTheme.cardDecorationFor(context),
                clipBehavior: Clip.antiAlias,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _navigateToAnalyses(),
                    borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (imageUrl != null && imageUrl.isNotEmpty)
                          CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            placeholder: (_, __) =>
                                Container(color: AppTheme.surfaceVariant),
                            errorWidget: (_, __, ___) => Container(
                              color: AppTheme.primary.withValues(alpha: 0.12),
                              child: Icon(
                                Icons.local_offer_rounded,
                                size: 40,
                                color: AppTheme.primary,
                              ),
                            ),
                          )
                        else
                          Container(
                            color: AppTheme.accent.withValues(alpha: 0.15),
                            child: Icon(
                              Icons.local_offer_rounded,
                              size: 40,
                              color: AppTheme.accent,
                            ),
                          ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: EdgeInsets.all(
                              Responsive.spacing(context, 10),
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.8),
                                ],
                              ),
                            ),
                            child: Text(
                              displayName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: Responsive.fontSize(context, 12),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        if (discountStr != null)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                gradient: AppTheme.accentGradient,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: AppTheme.goldGlow,
                              ),
                              child: Text(
                                AppStrings.tParam(
                                  'discountPercent',
                                  context.watch<AppSettingsProvider>().language,
                                  discountStr,
                                ),
                                style: TextStyle(
                                  fontSize: Responsive.fontSize(context, 10),
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLabs() {
    final labs = _labs;
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.spacing(context, 16),
      ),
      itemCount: labs.length,
      separatorBuilder: (_, __) =>
          SizedBox(height: Responsive.spacing(context, 12)),
      itemBuilder: (context, index) {
        final lab = labs[index] is Map
            ? labs[index] as Map<String, dynamic>
            : <String, dynamic>{};
        final avatarSize =
            56.0 * (MediaQuery.of(context).size.width / 375).clamp(1.0, 1.2);
        final businessName = LocaleUtils.localizedBusinessName(
          lab,
          context.watch<AppSettingsProvider>().isArabic,
        );
        final city = lab['city']?.toString() ?? '';
        final district = lab['district']?.toString() ?? '';
        final logoUrl =
            ApiConfig.imageFromMap(lab) ??
            ApiConfig.resolveImageUrl(lab['logo_url'], lab['logo']);
        final avgRating =
            (lab['avg_rating'] is num ? lab['avg_rating'] as num : 0)
                .toDouble();
        final totalReviews = lab['total_reviews'] is num
            ? (lab['total_reviews'] as num).toInt()
            : 0;
        final homeService = lab['home_service_available'] == true;
        return Container(
          decoration: AppTheme.cardDecorationFor(context),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _navigateToLabDetails(lab),
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: EdgeInsets.all(Responsive.spacing(context, 12)),
                child: Row(
                  children: [
                    _buildLabAvatar(logoUrl, avatarSize),
                    SizedBox(width: Responsive.spacing(context, 14)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            businessName,
                            style: TextStyle(
                              fontSize: Responsive.fontSize(context, 12),
                              fontWeight: FontWeight.w400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: Responsive.spacing(context, 4)),
                          Text(
                            '$city - $district',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: Responsive.fontSize(context, 9),
                              color: AppTheme.onSurfaceVariant,
                            ),
                          ),
                          SizedBox(height: Responsive.spacing(context, 6)),
                          Row(
                            children: [
                              RatingBadge(
                                rating: avgRating,
                                reviewCount: totalReviews,
                                size: RatingBadgeSize.small,
                                showLabel: true,
                              ),
                              if (homeService) ...[
                                SizedBox(width: Responsive.spacing(context, 8)),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    AppStrings.t(
                                      'homeService',
                                      context
                                          .watch<AppSettingsProvider>()
                                          .language,
                                    ),
                                    style: TextStyle(
                                      fontSize: Responsive.fontSize(context, 8),
                                      color: AppTheme.primary,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: AppTheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
