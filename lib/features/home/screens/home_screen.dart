import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:rast/core/services/analytics_service.dart';
import 'package:rast/core/constants/api_config.dart';
import 'package:rast/core/constants/app_strings.dart';
import 'package:rast/core/providers/app_settings_provider.dart';
import 'package:rast/core/utils/locale_utils.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:rast/core/api/api_services.dart';
import 'package:rast/core/services/favorites_service.dart';
import 'package:rast/core/services/location_service.dart';
import 'package:rast/core/services/branches_index_service.dart';
import 'package:rast/core/services/catalog_cache_service.dart';
import 'package:rast/core/utils/lab_location_utils.dart';
import 'package:rast/core/theme/app_theme.dart';
import 'package:rast/core/utils/responsive.dart';
import 'package:rast/features/analyses/screens/analyses_screen.dart';
import 'package:rast/features/packages/screens/packages_screen.dart';
import 'package:rast/features/packages/screens/package_detail_screen.dart';
import 'package:rast/features/lab_details/screens/lab_details_screen.dart';
import 'package:rast/features/labs/screens/labs_screen.dart';
import 'package:rast/core/api/api_client.dart';
import 'package:rast/features/auth/services/auth_service.dart';
import 'package:rast/features/favorites/screens/favorites_screen.dart';
import 'package:rast/core/onboarding/onboarding_catalog.dart';
import 'package:rast/core/onboarding/onboarding_host.dart';
import 'package:rast/core/onboarding/onboarding_step.dart';
import 'package:rast/core/onboarding/onboarding_tour_ids.dart';
import 'package:rast/core/widgets/gradient_button.dart';
import 'package:rast/core/widgets/rast_help_button.dart';
import 'package:rast/core/widgets/search_box.dart';
import 'package:rast/core/widgets/cart_icon_button.dart';
import 'package:rast/core/widgets/rast_ui.dart';
import 'package:shimmer/shimmer.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:rast/core/services/app_events.dart';
import 'package:rast/core/widgets/city_selector.dart';
import 'package:rast/core/widgets/rast_kit.dart';
import 'package:rast/core/widgets/rast_motion.dart';
import 'package:rast/features/map/widgets/map_entry_button.dart';
import 'package:rast/features/loyalty/loyalty_config.dart';
import 'package:rast/features/loyalty/loyalty_screen.dart';
import 'package:rast/features/offers/screens/offers_screen.dart';
import 'package:rast/features/offers/screens/offer_detail_screen.dart';
import 'package:rast/features/offers/widgets/offer_card.dart';
import 'package:rast/features/home/widgets/home_widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with OnboardingTourHost {
  final _searchKey = GlobalKey();
  final _categoriesKey = GlobalKey();
  final _labsSectionKey = GlobalKey();
  bool _homeTourScheduled = false;

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
  double? _userLat;
  double? _userLng;

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
  String? get onboardingTourId => OnboardingTourIds.home;

  @override
  List<OnboardingStep> buildOnboardingSteps() => OnboardingCatalog.homeTour(
        searchKey: _searchKey,
        categoriesKey: _categoriesKey,
        labsSectionKey: _labsSectionKey,
      );

  void _maybeScheduleHomeTour() {
    if (_homeTourScheduled || _isLoading) return;
    _homeTourScheduled = true;
    scheduleOnboardingTour(delay: const Duration(milliseconds: 3200));
  }

  @override
  void initState() {
    super.initState();
    _categoriesPageController = PageController();
    _loadFromCacheThenNetwork();
    BranchesIndexService.instance.ensureLoaded();
    // تغيير المدينة من محدد المدينة يعيد ترتيب «الأقرب لك»
    AppEvents.locationChanged.addListener(_onLocationChanged);
    LoyaltyConfig.ensureLoaded();
  }

  void _onLocationChanged() {
    if (mounted) _loadData(silent: true);
  }

  Future<void> _loadFromCacheThenNetwork() async {
    await CatalogCacheService.ensureHydrated();
    final snap = CatalogCacheService.homeSnapshot;
    if (snap != null && mounted) {
      _applyHomeSnapshot(snap);
      setState(() => _isLoading = false);
      _maybeScheduleHomeTour();
    }
    await _loadData(silent: snap != null);
  }

  void _applyHomeSnapshot(HomeSnapshot snap) {
    _homeData = Map<String, dynamic>.from(snap.homeData)
      ..['featured_providers'] = snap.labs;
    _carouselSlides = snap.carouselSlides;
    _packages = snap.packages;
    _offers = snap.offers;
    _totalPackages = snap.totalPackages;
    _totalOffers = snap.totalOffers;
    _totalLabs = snap.totalLabs;
  }

  /// استخراج قائمة المختبرات من استجابة API (يدعم الترقيم)
  static List<dynamic> _extractProviderList(Map<String, dynamic> res) {
    final data = res['data'];
    if (data is List) return List.from(data);
    if (data is Map && data['data'] is List) {
      return List.from(data['data'] as List);
    }
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

  Future<({double lat, double lng, String? label})?>
  _resolveUserLocation() async {
    // المدينة/العنوان الذي اختاره المستخدم أولاً، ثم موقعه الحالي
    final chosen = await LocationService.getDefaultLocation();
    if (chosen != null) return chosen;
    try {
      return await LocationService.getCurrentLocation();
    } catch (_) {}
    return null;
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent) {
      setState(() {
        if (_homeData == null && _packages.isEmpty) _isLoading = true;
        _error = null;
      });
    } else {
      setState(() => _error = null);
    }
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
            _totalFromResponse(homeData) ??
            _intFromMap(homeData, 'packages_count');
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
      // المختبرات: الأقرب للمستخدم أولاً عند توفر الموقع، ثم المميزة أو الأعلى تقييماً.
      int? totalLabsFromApi;
      List<dynamic> labsList =
          (homeData['featured_providers'] as List?)
              ?.where((e) => e != null)
              .toList() ??
          [];
      final userLocation = await _resolveUserLocation();
      if (userLocation != null) {
        _userLat = userLocation.lat;
        _userLng = userLocation.lng;
        try {
          final res = await Api.providers.getProviders(
            perPage: 10,
            latitude: userLocation.lat,
            longitude: userLocation.lng,
            radiusKm: 50,
          );
          totalLabsFromApi = _totalFromResponse(res);
          final nearbyLabs = _extractProviderList(res);
          if (nearbyLabs.isNotEmpty) {
            labsList = nearbyLabs.length > 6
                ? nearbyLabs.take(6).toList()
                : nearbyLabs;
          }
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
      final snap = HomeSnapshot(
        homeData: Map<String, dynamic>.from(homeData)
          ..['featured_providers'] = labsList,
        // بيانات حقيقية فقط (لا شرائح أو باقات تجريبية)
        carouselSlides: slidesList,
        packages: packagesList,
        offers: offersList,
        labs: labsList,
        totalPackages: totalPackagesFromApi,
        totalOffers: totalOffersFromApi,
        totalLabs: totalLabsFromApi,
      );
      await CatalogCacheService.saveHome(snap);
      setState(() {
        _applyHomeSnapshot(snap);
        _isLoading = false;
      });
      _maybeShowPopup();
      _maybeScheduleHomeTour();
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
    AppEvents.locationChanged.removeListener(_onLocationChanged);
    _searchController.dispose();
    _categoriesPageController.dispose();
    super.dispose();
  }

  List<dynamic> get _slides => _carouselSlides.isNotEmpty
      ? _carouselSlides
      : (_homeData?['carousel_slides'] as List?) ?? const [];
  List<dynamic> get _categories =>
      (_homeData?['categories'] as List?) ?? const [];
  List<dynamic> get _labs => (_homeData?['featured_providers'] as List?) ?? [];

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
              SizedBox(height: Responsive.spacing(context, 18)),
              KeyedSubtree(
                key: _categoriesKey,
                child: _buildSectionShell(
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
                ),
              ).animate().fadeIn(duration: 500.ms, delay: 250.ms),
              if (_packages.isNotEmpty) ...[
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
              ],
              // عروض المختبرات: تظهر فقط عند وجود عروض فعلية
              if (_offers.isNotEmpty) ...[
                SizedBox(height: Responsive.spacing(context, 18)),
                _buildSectionShell(
                  L(context.watch<AppSettingsProvider>().language, 'عروض اليوم', "Today's offers"),
                  AppStrings.t(
                    'viewAll',
                    context.watch<AppSettingsProvider>().language,
                  ),
                  onActionTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const OffersScreen()),
                  ),
                  child: _buildOffers(),
                ).animate().fadeIn(duration: 500.ms, delay: 320.ms),
              ],
              // ادعُ أصدقاءك (بطاقة بسيطة)
              ValueListenableBuilder<Map<String, dynamic>?>(
                valueListenable: LoyaltyConfig.data,
                builder: (context, _, __) {
                  if (!LoyaltyConfig.enabled || LoyaltyConfig.referralBonus <= 0) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: EdgeInsets.only(top: Responsive.spacing(context, 18)),
                    child: HomeReferralCard(
                      lang: context.watch<AppSettingsProvider>().language,
                      bonus: LoyaltyConfig.referralBonus,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoyaltyScreen()),
                      ),
                    ),
                  );
                },
              ),
              SizedBox(height: Responsive.spacing(context, 18)),
              KeyedSubtree(
                key: _labsSectionKey,
                child: _buildSectionShell(
                  // عند معرفة الموقع: «الأقرب لك» (والمسافة مكان التقييم)
                  _userLat != null && _userLng != null
                      ? L(context.watch<AppSettingsProvider>().language, 'الأقرب لك', 'Nearest to you')
                      : AppStrings.t(
                          'featuredLabs',
                          context.watch<AppSettingsProvider>().language,
                        ),
                  AppStrings.t(
                    'viewAll',
                    context.watch<AppSettingsProvider>().language,
                  ),
                  onActionTap: () => _navigateToLabs(),
                  child: _buildLabs(),
                ),
              ).animate().fadeIn(duration: 500.ms, delay: 350.ms),
              SizedBox(height: Responsive.spacing(context, 110)),
            ],
          ),
        ),
      ],
    );
  }

  SliverAppBar _buildAppBar(double topPadding) {
    final settings = context.watch<AppSettingsProvider>();
    final theme = Theme.of(context);

    final userName = (AuthService.currentUser?.name ?? '').trim();
    final parts = userName
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();

    final firstName = parts.isNotEmpty ? parts.first : '';

    String initials = '';
    if (parts.isNotEmpty) {
      initials = parts.first[0].toUpperCase();

      if (parts.length > 1) {
        initials += parts.last[0].toUpperCase();
      }
    }

    return SliverAppBar(
      toolbarHeight: 0,
      pinned: false,
      floating: true,
      snap: true,
      expandedHeight: topPadding + 58,
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Padding(
          padding: EdgeInsets.fromLTRB(
            Responsive.spacing(context, 12),
            topPadding,
            Responsive.spacing(context, 12),
            0,
          ),
          child: Row(
            children: [
              // Help
              RastHelpButton(
                tourId: OnboardingTourIds.home,
                tourSteps: buildOnboardingSteps(),
              ),

              const SizedBox(width: 4),

              // Cart
              const CartIconButton(),

              const SizedBox(width: 4),

              // Favorites
              _buildHeaderAction(
                icon: Icons.favorite_border_rounded,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const FavoritesScreen(),
                    ),
                  );
                },
              ),

              const SizedBox(width: 12),

              // Greeting + user name
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      firstName.isNotEmpty
                          ? '${AppStrings.t('welcomeBack', settings.language)} $firstName'
                          : AppStrings.t('welcomeBack', settings.language),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: Responsive.fontSize(context, 15),
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                        height: 1.2,
                      ),
                    ),

                    const SizedBox(height: 2),

                    // المدينة الحالية (يمكن تغييرها) بدل السطر الثابت
                    const CitySelectorChip(),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // User avatar
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8E9ED),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.9),
                    width: 1,
                  ),
                ),
                child: Text(
                  initials.isNotEmpty ? initials : 'R',
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 12),
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBannerBar() {
    final banner = _banner!;
    final message = banner['message']?.toString();
    if (message == null || message.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
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

  Widget _buildSearchBar() {
    return Padding(
      key: _searchKey,
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.spacing(context, 16),
      ),
      child: Row(
        children: [
          Expanded(
            child: SearchBox(
              controller: _searchController,
              hintText: AppStrings.t(
                'searchHint',
                context.watch<AppSettingsProvider>().language,
              ),
              onSearchTap: _submitHomeSearch,
              onSubmitted: (v) {
                AnalyticsService.logSearch(v, area: 'home');
                _submitHomeSearch();
              },
            ),
          ),
          const SizedBox(width: 10),
          // خريطة المختبرات بجانب البحث (بدل زر الفلترة الشكلي)
          MapEntryButton(size: 52, background: Theme.of(context).cardColor),
        ],
      ),
    );
  }

  Widget _buildOffers() {
    final offers = _offers;
    if (offers.isEmpty) return const SizedBox.shrink();
    final lang = context.watch<AppSettingsProvider>().language;
    final cardWidth = (MediaQuery.sizeOf(context).width * 0.66).clamp(230.0, 280.0);
    return SizedBox(
      height: 346,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: Responsive.spacing(context, 16), vertical: 4),
        itemCount: offers.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final offer = offers[index] is Map
              ? Map<String, dynamic>.from(offers[index] as Map)
              : <String, dynamic>{};
          return OfferCard(
            offer: offer,
            lang: lang,
            width: cardWidth,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => OfferDetailScreen(offer: offer)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCategories() {
    final categories = _categories;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final hPadding = Responsive.spacing(context, 10);
    final gaps = Responsive.spacing(context, 10) * 2;
    final itemWidth = (screenWidth - hPadding - gaps) / 3;
    final iconSize = (itemWidth).clamp(80.0, 100.0);
    final textScale = MediaQuery.textScalerOf(context)
        .scale(1.0)
        .clamp(1.0, 1.5);

    final textAreaHeight = 38.0 * textScale;

    final rowHeight =
        iconSize +
            Responsive.spacing(context, 6) +
            textAreaHeight;
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
                  horizontal: Responsive.spacing(context, 10),
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
                          if (index >= categories.length) {
                            return SizedBox(height: rowHeight);
                          }
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
                                        borderRadius: BorderRadius.circular(14),
                                        color: const Color(0xFFE8E9FB),
                                        border: Border.all(
                                          color: isSelected
                                              ? AppTheme.primary
                                              : Colors.transparent,
                                          width: 2.5,
                                        ),
                                        boxShadow: [
                                          if (isSelected) ...AppTheme.softGlow,

                                          BoxShadow(
                                            color: isSelected
                                                ? AppTheme.primary.withValues(alpha: 0.25)
                                                : Colors.black.withValues(alpha: 0.18),
                                            blurRadius: isSelected ? 10 : 12,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(14),
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

  Widget _buildPackages() {
    final packages = _packages;
    final cardWidth = MediaQuery.sizeOf(context).width * 0.75;
    final textScale = MediaQuery.textScalerOf(context)
        .scale(1.0)
        .clamp(1.0, 1.4);

    final cardHeight =
    ((cardWidth * 0.48) * textScale)
        .clamp(140.0, 210.0);
    final settings = context.watch<AppSettingsProvider>();

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

          // تقييم حقيقي فقط (كان يُعرض 4.8 ثابتاً لكل باقة)
          final pkgRating = numOf(pkg['avg_rating'] ?? pkg['rating']) ?? 0;

          final displayName = LocaleUtils.localizedName(
            pkg,
            settings.isArabic,
          );

          double price = ApiConfig.priceFromMap(pkg);

          if (price == 0.0) {
            final psList =
                pkg['provider_services'] ?? pkg['providerServices'];

            if (psList is List && psList.isNotEmpty) {
              final first = psList.first;

              if (first is Map<String, dynamic>) {
                price = ApiConfig.priceFromMap(first);
              }
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
              padding: EdgeInsetsDirectional.only(
                end: Responsive.spacing(context, 12),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.16),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PackageDetailScreen(
                          package: pkg,
                        ),
                      ),
                    ),
                    borderRadius: BorderRadius.circular(18),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (imageUrl != null && imageUrl.isNotEmpty)
                          CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              color: AppTheme.surfaceVariant,
                            ),
                            errorWidget: (_, __, ___) => Container(
                              decoration: const BoxDecoration(
                                gradient: AppTheme.primaryGradient,
                              ),
                            ),
                          )
                        else
                          Container(
                            decoration: const BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                            ),
                          ),

                        Container(
                          color: Colors.black.withValues(alpha: 0.60),
                        ),

                        Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Package name
                              Text(
                                displayName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: Responsive.fontSize(
                                    context,
                                    15,
                                  ),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),

                              const SizedBox(height: 6),

                              // Number of tests
                              Row(
                                children: [
                                  const Icon(
                                    Icons.science_outlined,
                                    size: 15,
                                    color: Colors.white,
                                  ),

                                  const SizedBox(width: 5),

                                  Expanded(
                                    child: Text(
                                      testsCount > 0
                                          ? '$testsCount ${AppStrings.t(
                                        'testsCount',
                                        settings.language,
                                      )}'
                                          : AppStrings.t(
                                        'testsShownInImage',
                                        settings.language,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.start,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize:
                                        Responsive.fontSize(context, 11),
                                        fontWeight: FontWeight.w700,
                                        height: 1.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const Spacer(),

                              Row(
                                crossAxisAlignment:
                                CrossAxisAlignment.end,
                                children: [
                                  // Price
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          price > 0
                                              ? '${price.toStringAsFixed(0)} ${AppStrings.t(
                                            'sar',
                                            settings.language,
                                          )}'
                                              : AppStrings.t(
                                            'contactForPrice',
                                            settings.language,
                                          ),
                                          softWrap: true,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: Responsive.fontSize(context, 17),
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),

                                        if (originalPrice != null && originalPrice > price)
                                          Text(
                                            '${originalPrice.toStringAsFixed(0)} ${AppStrings.t(
                                              'sar',
                                              settings.language,
                                            )}',
                                            softWrap: true,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: Responsive.fontSize(context, 9),
                                              decoration: TextDecoration.lineThrough,
                                              decorationColor: Colors.white70,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),

                                  const Spacer(),

                                  // Rating
                                  if (pkgRating > 0) Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.28,
                                      ),
                                      borderRadius:
                                      BorderRadius.circular(14),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          pkgRating.toStringAsFixed(1),
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize:
                                            Responsive.fontSize(
                                              context,
                                              10,
                                            ),
                                            fontWeight:
                                            FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(width: 3),
                                        const Icon(
                                          Icons.star_rounded,
                                          color: AppTheme.accent,
                                          size: 15,
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
            60.0 *
                (MediaQuery.of(context).size.width / 375).clamp(1.0, 1.2);

        final settings = context.watch<AppSettingsProvider>();
        final isArabic = settings.isArabic;

        final businessName = LocaleUtils.localizedBusinessName(
          lab,
          isArabic,
        );

        final locationText = LabLocationUtils.displayText(
          lab: lab,
          userLat: _userLat,
          userLng: _userLng,
          branches:
          BranchesIndexService.instance.branchesFor(lab) ??
              (lab['branches'] is List
                  ? lab['branches'] as List<dynamic>
                  : null),
          isArabic: isArabic,
        );

        final logoUrl =
            ApiConfig.imageFromMap(lab) ??
                ApiConfig.resolveImageUrl(
                  lab['logo_url'],
                  lab['logo'],
                );

        final avgRating =
        (lab['avg_rating'] is num
            ? lab['avg_rating'] as num
            : 0)
            .toDouble();

        final homeService = lab['home_service_available'] == true;

        // المسافة لأقرب فرع (تُعرض مكان التقييم عند معرفة موقع المستخدم)
        final distanceKm = (_userLat != null && _userLng != null)
            ? LabLocationUtils.distanceKmToNearest(
                lab: lab,
                userLat: _userLat!,
                userLng: _userLng!,
                branches: BranchesIndexService.instance.branchesFor(lab) ??
                    (lab['branches'] is List ? lab['branches'] as List<dynamic> : null),
              )
            : null;
        final distanceText = distanceKm == null
            ? null
            : (distanceKm < 1
                ? (isArabic ? '${(distanceKm * 1000).round()} م' : '${(distanceKm * 1000).round()} m')
                : (isArabic ? '${distanceKm.toStringAsFixed(1)} كم' : '${distanceKm.toStringAsFixed(1)} km'));

        return Container(
          padding: EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: RastUi.cardSurface(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: RastUi.softBorder(context),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 7,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _navigateToLabDetails(lab),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: EdgeInsets.all(
                  Responsive.spacing(context, 12),
                ),
                child: Stack(
                  children: [
                    // MAIN CONTENT
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        end: 38,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabAvatar(logoUrl, avatarSize),

                          SizedBox(
                            width: Responsive.spacing(context, 14),
                          ),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  businessName,
                                  softWrap: true,
                                  style: TextStyle(
                                    fontSize: Responsive.fontSize(context, 12),
                                    color: RastUi.textPurple,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),

                                SizedBox(
                                  height: Responsive.spacing(context, 4),
                                ),

                                Text(
                                  locationText,
                                  softWrap: true,
                                  style: TextStyle(
                                    fontSize: Responsive.fontSize(context, 10),
                                    color: RastUi.blue,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),

                                SizedBox(
                                  height: Responsive.spacing(context, 8),
                                ),

                                Align(
                                  alignment: AlignmentDirectional.centerStart,
                                  child: Container(
                                    constraints: const BoxConstraints(
                                      minWidth: 84,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: RastUi.brandGradient,
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    child: Text(
                                      homeService
                                          ? AppStrings.t(
                                        'homeService',
                                        settings.language,
                                      )
                                          : AppStrings.t(
                                        'labService',
                                        settings.language,
                                      ),
                                      softWrap: true,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: Responsive.fontSize(context, 10),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // HEART
                    PositionedDirectional(
                      end: 0,
                      top: 0,
                      child: FutureBuilder<bool>(
                        future: FavoritesService.isLabFavorite(lab),
                        builder: (context, snapshot) {
                          final isFavorite = snapshot.data ?? false;

                          return SizedBox(
                            width: 32,
                            height: 32,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () async {
                                await FavoritesService.toggleLab(lab);

                                if (mounted) {
                                  setState(() {});
                                }
                              },
                              icon: AnimatedFavoriteIcon(
                                active: isFavorite,
                                size: Responsive.fontSize(context, 22),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // المسافة (أو التقييم الحقيقي إن لم يُعرف الموقع)
                    if (distanceText != null || avgRating > 0)
                    PositionedDirectional(
                      end: 0,
                      bottom: 0,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            distanceText ?? avgRating.toStringAsFixed(1),
                            style: TextStyle(
                              color: RastUi.textPurple,
                              fontSize: Responsive.fontSize(context, 10),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          distanceText != null
                              ? const Icon(Icons.near_me_rounded, size: 15, color: RastUi.purple)
                              : const Icon(Icons.star_rounded, size: 16, color: AppTheme.accent),
                        ],
                      ),
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

  Widget _buildSectionShell(
    String title,
    String? action, {
    required Widget child,
    VoidCallback? onActionTap,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.spacing(context, 10),
      ),
      child: Container(
        padding: EdgeInsets.only(
          top: Responsive.spacing(context, 4),
          bottom: Responsive.spacing(context, 4),
        ),
        decoration: const BoxDecoration(color: Colors.transparent),
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


  Widget _buildHeaderAction({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.transparent),
          child: Icon(icon, size: 24, color: Colors.black),
        ),
      ),
    );
  }


  Future<void> _submitHomeSearch() async {
    final query = _searchController.text.trim();

    if (query.isEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const AnalysesScreen(),
        ),
      );
      return;
    }

    try {
      final type = await Api.services.globalSearch(query);

      if (!mounted) return;

      switch (type) {
        case 'lab':
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => LabsScreen(
                showBackButton: true,
                initialSearchQuery: query,
              ),
            ),
          );
          break;

        case 'package':
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PackagesScreen(
                initialSearchQuery: query,
              ),
            ),
          );
          break;

        case 'test':
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AnalysesScreen(
                initialSearchQuery: query,
              ),
            ),
          );
          break;

        default:
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AnalysesScreen(
                initialSearchQuery: query,
              ),
            ),
          );
          break;
      }
    } catch (_) {
      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AnalysesScreen(
            initialSearchQuery: query,
          ),
        ),
      );
    }
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
      MaterialPageRoute(builder: (_) => const LabsScreen(showBackButton: true,)),
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
        borderRadius: BorderRadius.circular(13),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 14,
            spreadRadius: 1,
            offset: const Offset(0, 5),
          ),
        ],
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
                        color: primary.withValues(
                          alpha: 0.35,
                        ),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),

                SizedBox(
                  width: Responsive.spacing(context, 10),
                ),

                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize:
                      Responsive.fontSize(context, 18),
                      fontWeight: FontWeight.w700,
                      color:
                      theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (action != null) ...[
            const SizedBox(width: 8),

            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth:
                MediaQuery.sizeOf(context).width *
                    0.30,
              ),
              child: TextButton(
                onPressed: onActionTap,
                style: TextButton.styleFrom(
                  foregroundColor: primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        action,
                        maxLines: 1,
                        overflow:
                        TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize:
                          Responsive.fontSize(
                            context,
                            13,
                          ),
                          fontWeight:
                          FontWeight.w700,
                          color: primary,
                        ),
                      ),
                    ),

                    const SizedBox(width: 3),

                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: primary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
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


}
