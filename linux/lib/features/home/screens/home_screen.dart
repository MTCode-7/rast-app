import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:rast/core/constants/api_config.dart';
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
import 'package:rast/core/widgets/rating_badge.dart';
import 'package:rast/core/widgets/search_box.dart';
import 'package:shimmer/shimmer.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

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
  bool _isLoading = true;
  String? _error;

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
      // الباقات من بيانات الصفحة الرئيسية أولاً، وإلا من API الباقات
      List<dynamic> packagesList =
          (homeData['packages'] as List?)?.where((e) => e != null).toList() ??
          [];
      if (packagesList.isEmpty) {
        try {
          final packagesRes = await Api.services.getPackages(
            page: 1,
            perPage: 20,
          );
          final data = packagesRes['data'];
          if (data is List) {
            packagesList = List.from(data);
          } else if (data is Map && data['data'] is List) {
            packagesList = List.from(data['data'] as List);
          }
        } catch (_) {}
      }
      // المختبرات المميزة: من الصفحة الرئيسية، أو الأعلى تقييماً، أو الأحدث، أو حسب المسافة
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
            labsList = _extractProviderList(providersRes);
            _sortLabsByRatingThenNewest(labsList);
            if (labsList.length > 6) labsList = labsList.take(6).toList();
          } catch (_) {}
        }
        if (labsList.isEmpty) {
          try {
            final providersRes = await Api.providers.getProviders(perPage: 15);
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
      if (labsList.isEmpty) labsList = List.from(DummyData.labs);
      setState(() {
        _homeData = Map<String, dynamic>.from(homeData)
          ..['featured_providers'] = labsList;
        _packages = packagesList.isEmpty
            ? List.from(DummyData.packages)
            : packagesList;
        _isLoading = false;
      });
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
            ? 'تحقق من اتصال الإنترنت أو رابط الـ API في api_config.dart'
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

  List<dynamic> get _slides =>
      (_homeData?['carousel_slides'] as List?) ?? DummyData.carouselSlides;
  List<dynamic> get _categories =>
      (_homeData?['categories'] as List?) ?? DummyData.categories;
  List<dynamic> get _labs =>
      (_homeData?['featured_providers'] as List?) ?? DummyData.labs;

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
      slivers: [
        _buildAppBar(topPadding),
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSearchBar()
                  .animate()
                  .fadeIn(duration: 600.ms)
                  .slideY(begin: 0.05, end: 0, curve: Curves.easeOutCubic),
              SizedBox(height: Responsive.spacing(context, 12)),
              _buildCarousel()
                  .animate()
                  .fadeIn(duration: 600.ms, delay: 100.ms)
                  .slideY(begin: 0.05, end: 0, curve: Curves.easeOutCubic),
              SizedBox(height: Responsive.spacing(context, 20)),
              _buildSectionTitle(
                'الفئات',
                'عرض الكل',
                onActionTap: _navigateToAnalyses,
              ).animate().fadeIn(duration: 500.ms, delay: 250.ms),
              SizedBox(height: Responsive.spacing(context, 12)),
              _buildCategories()
                  .animate()
                  .fadeIn(duration: 600.ms, delay: 300.ms)
                  .slideX(begin: 0.03, end: 0, curve: Curves.easeOutCubic),
              SizedBox(height: Responsive.spacing(context, 24)),
              _buildSectionTitle(
                'الباقات',
                'عرض الكل',
                onActionTap: _navigateToPackages,
              ).animate().fadeIn(duration: 500.ms, delay: 350.ms),
              SizedBox(height: Responsive.spacing(context, 12)),
              _buildPackages()
                  .animate()
                  .fadeIn(duration: 600.ms, delay: 400.ms)
                  .slideX(begin: 0.03, end: 0, curve: Curves.easeOutCubic),
              SizedBox(height: Responsive.spacing(context, 24)),
              _buildSectionTitle(
                'المختبرات المميزة',
                'عرض الكل',
                onActionTap: () => _navigateToLabs(),
              ).animate().fadeIn(duration: 500.ms, delay: 450.ms),
              SizedBox(height: Responsive.spacing(context, 12)),
              _buildLabs()
                  .animate()
                  .fadeIn(duration: 600.ms, delay: 500.ms)
                  .slideY(begin: 0.02, end: 0, curve: Curves.easeOutCubic),
              SizedBox(height: Responsive.spacing(context, 32)),
            ],
          ),
        ),
      ],
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
                      baseColor: AppTheme.surfaceVariant,
                      highlightColor: Colors.white,
                      child: Container(
                        height: 70,
                        width: itemW,
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceVariant,
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
      baseColor: AppTheme.surfaceVariant,
      highlightColor: Colors.white,
      child: Container(
        height: height,
        width: width ?? double.infinity,
        margin: EdgeInsets.symmetric(
          horizontal: Responsive.spacing(context, 16),
        ),
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant,
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
                  'تعذر تحميل البيانات',
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
                FilledButton.icon(
                  onPressed: _loadData,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('إعادة المحاولة'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
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

  SliverAppBar _buildAppBar(double topPadding) {
    final parts = (AuthService.currentUser?.name ?? '').trim().split(
      RegExp(r'\s+'),
    );
    final firstName = parts.isNotEmpty ? parts.first : '';
    final greeting = firstName.isNotEmpty ? 'مرحبا، $firstName' : 'مرحبا';
    return SliverAppBar(
      floating: true,
      expandedHeight: 48 + topPadding,
      backgroundColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: EdgeInsets.only(
          right: Responsive.spacing(context, 20),
          bottom: 10,
        ),
        title: Text(
          greeting,
          style: TextStyle(
            fontSize: Responsive.fontSize(context, 14),
            fontWeight: FontWeight.w500,
            color: AppTheme.onSurface,
            letterSpacing: -0.1,
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primary.withValues(alpha: 0.12),
                  AppTheme.secondary.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.15),
                width: 1,
              ),
            ),
            child: Icon(
              Icons.notifications_outlined,
              size: 22,
              color: AppTheme.primary,
            ),
          ),
          onPressed: () {},
        ),
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primary.withValues(alpha: 0.12),
                  AppTheme.secondary.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.15),
                width: 1,
              ),
            ),
            child: Icon(
              Icons.location_on_outlined,
              size: 22,
              color: AppTheme.primary,
            ),
          ),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DefaultLocationScreen()),
          ).then((_) => _loadData()),
        ),
      ],
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
            final imageUrl = ApiConfig.resolveImageUrl(slide['image_url'], slide['image']);
            return Padding(
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.spacing(context, 10),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: AppTheme.cardShadowElevated,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.95),
                    width: 2,
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
        hintText: 'ابحث عن تحليل أو مختبر...',
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
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
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
                      'فلترة النتائج',
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
                      LocaleUtils.localizedName(opt, context.watch<AppSettingsProvider>().isArabic),
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
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.95),
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
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.spacing(context, 16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 18,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  gradient: AppTheme.auroraGradient,
                  boxShadow: AppTheme.softGlow,
                ),
              ),
              SizedBox(width: Responsive.spacing(context, 12)),
              Text(
                title,
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 13),
                  fontWeight: FontWeight.w500,
                  color: AppTheme.onSurface,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
          if (action != null)
            TextButton(
              onPressed: onActionTap,
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    action,
                    style: TextStyle(
                      fontSize: Responsive.fontSize(context, 11),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  SizedBox(width: Responsive.spacing(context, 4)),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 12,
                    color: AppTheme.primary,
                  ),
                ],
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
    final gaps = Responsive.spacing(context, 8) * 3;
    final itemWidth = (screenWidth - hPadding - gaps) / 4;
    final iconSize = (itemWidth * 0.75).clamp(44.0, 56.0);
    final rowHeight = iconSize + 40;
    const categoriesPerPage = 8;
    final pageCount = (categories.length / categoriesPerPage).ceil();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: rowHeight * 2 + Responsive.spacing(context, 8),
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
                  children: List.generate(4, (col) {
                    return Expanded(
                      child: Column(
                        children: List.generate(2, (row) {
                          final index = start + col + row * 4;
                          if (index >= categories.length)
                            return const SizedBox.shrink();
                          final cat = categories[index] is Map
                              ? categories[index] as Map<String, dynamic>
                              : <String, dynamic>{};
                          final isSelected = _selectedCategoryIndex == index;
                          final iconUrl = cat['icon_url']?.toString();
                          final icon = cat['icon']?.toString() ?? '🩸';
                          final displayName = LocaleUtils.localizedName(cat, context.watch<AppSettingsProvider>().isArabic);
                          final id = cat['id'] is int
                              ? cat['id'] as int
                              : cat['id'] is num
                              ? (cat['id'] as num).toInt()
                              : null;
                          final url = ApiConfig.resolveImageUrl(cat['image_url'], cat['image']) ?? iconUrl;
                          return Padding(
                            padding: EdgeInsets.only(
                              left: col > 0
                                  ? Responsive.spacing(context, 4)
                                  : 0,
                              right: col < 3
                                  ? Responsive.spacing(context, 4)
                                  : 0,
                              bottom: row < 1
                                  ? Responsive.spacing(context, 8)
                                  : 0,
                            ),
                            child: GestureDetector(
                              onTap: () {
                                setState(() => _selectedCategoryIndex = index);
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
                                                color: AppTheme.surfaceVariant,
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
                                    height: Responsive.spacing(context, 4),
                                  ),
                                  SizedBox(
                                    width: itemWidth,
                                    child: Text(
                                      displayName,
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: Responsive.fontSize(
                                          context,
                                          9,
                                        ),
                                        color: isSelected
                                            ? AppTheme.primary
                                            : AppTheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                ],
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
    final cardHeight = (cardWidth * 1.35).clamp(165.0, 210.0);
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
          final displayName = LocaleUtils.localizedName(pkg, context.watch<AppSettingsProvider>().isArabic);
          final price = (pkg['price'] is num ? pkg['price'] as num : 0)
              .toDouble();
          final originalPrice = pkg['original_price'] is num
              ? (pkg['original_price'] as num).toDouble()
              : null;
          final imageUrl = ApiConfig.resolveImageUrl(pkg['image_url'], pkg['image']);
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
                decoration: AppTheme.cardDecoration(),
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
                                        '$price ر.س',
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
                                        '$originalPrice ر.س',
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
                                  '$testsCount تحليل',
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
        final businessName = LocaleUtils.localizedBusinessName(lab, context.watch<AppSettingsProvider>().isArabic);
        final city = lab['city']?.toString() ?? '';
        final district = lab['district']?.toString() ?? '';
        final logoUrl = ApiConfig.resolveImageUrl(lab['logo_url'], lab['logo']);
        final avgRating =
            (lab['avg_rating'] is num ? lab['avg_rating'] as num : 0)
                .toDouble();
        final totalReviews = lab['total_reviews'] is num
            ? (lab['total_reviews'] as num).toInt()
            : 0;
        final homeService = lab['home_service_available'] == true;
        return Container(
          decoration: AppTheme.cardDecoration(),
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
                                    'منزلي',
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
