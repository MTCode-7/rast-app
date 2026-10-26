import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:rast/core/services/analytics_service.dart';
import 'package:rast/core/constants/api_config.dart';
import 'package:rast/core/providers/app_settings_provider.dart';
import 'package:rast/core/services/favorites_service.dart';
import 'package:rast/core/utils/locale_utils.dart';
import 'package:provider/provider.dart';
import 'package:rast/core/theme/app_theme.dart';
import 'package:rast/core/api/api_services.dart';
import 'package:rast/core/widgets/gradient_button.dart';
import 'package:rast/core/api/api_client.dart';
import 'package:rast/core/api/api_services/providers_api.dart' show PaginatedResponse;
import 'package:rast/core/utils/responsive.dart';
import 'package:rast/core/widgets/rating_badge.dart';
import 'package:rast/core/widgets/rast_ui.dart';
import 'package:rast/core/widgets/search_box.dart';
import 'package:rast/core/widgets/zoomable_image_viewer.dart';
import 'package:rast/features/analyses/screens/analyses_screen.dart';
import 'package:rast/features/analyses/screens/service_detail_screen.dart';
import 'package:rast/features/packages/screens/package_detail_screen.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/constants/app_strings.dart';

class LabDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> lab;

  const LabDetailsScreen({super.key, required this.lab});

  @override
  State<LabDetailsScreen> createState() => _LabDetailsScreenState();
}

class _LabDetailsScreenState extends State<LabDetailsScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _servicesSearchController =
      TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounce;

  Map<String, dynamic> _labMap = {};
  bool _providerLoading = true;

  List<dynamic> _services = [];
  int _servicesPage = 0;
  bool _hasMoreServices = true;
  bool _loadingMoreServices = false;

  List<dynamic> _packages = [];
  int _packagesPage = 0;
  bool _hasMorePackages = true;
  bool _loadingMorePackages = false;

  List<dynamic> _reviews = [];
  int _reviewsPage = 0;
  bool _hasMoreReviews = true;
  bool _loadingMoreReviews = false;

  String? _error;
  bool _isFavorite = false;
  String _servicesSort = 'default';
  bool _servicesHomeOnly = false;
  double? _servicesMinPrice;
  double? _servicesMaxPrice;
  late TabController _tabController;

  int get _labId => widget.lab['id'] is int
      ? widget.lab['id'] as int
      : int.tryParse(widget.lab['id']?.toString() ?? '0') ?? 0;

  @override
  void initState() {
    super.initState();
    AnalyticsService.logScreen('lab_details');
    AnalyticsService.logEvent('view_lab', {
      'lab_id': widget.lab['id'],
      'lab_name': widget.lab['business_name_ar'] ?? widget.lab['business_name_en'],
      'city': widget.lab['city'],
    });
    _labMap = Map<String, dynamic>.from(widget.lab);
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && mounted) {
        setState(() {});
      }
    });
    _scrollController.addListener(_onScrollNearEnd);
    _servicesSearchController.addListener(_onSearchTextChanged);
    _loadFavorite();
    _loadData();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController.removeListener(_onScrollNearEnd);
    _scrollController.dispose();
    _tabController.dispose();
    _servicesSearchController.dispose();
    super.dispose();
  }

  void _onSearchTextChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 420), () {
      if (!mounted) return;
      if (_tabController.index == 0) {
        unawaited(_loadServicesInternal(reset: true));
      } else {
        setState(() {});
      }
    });
  }

  void _onScrollNearEnd() {
    if (!_scrollController.hasClients) return;
    final p = _scrollController.position;
    if (p.pixels < p.maxScrollExtent - 480) return;
    if (_tabController.index == 0) {
      if (_hasMoreServices && !_loadingMoreServices) {
        unawaited(_loadServicesInternal(reset: false));
      }
    } else {
      if (_hasMorePackages && !_loadingMorePackages) {
        unawaited(_loadPackagesInternal(reset: false));
      }
    }
  }

  String? _apiSortForProviderServices() {
    switch (_servicesSort) {
      case 'price_low':
        return 'price_asc';
      case 'price_high':
        return 'price_desc';
      default:
        return null;
    }
  }

  Future<void> _loadServicesInternal({bool reset = false}) async {
    if (_loadingMoreServices && !reset) return;
    if (!reset && !_hasMoreServices) return;
    final nextPage = reset ? 1 : _servicesPage + 1;
    setState(() {
      if (reset) {
        _services = [];
        _servicesPage = 0;
        _hasMoreServices = true;
      }
      _loadingMoreServices = true;
    });
    try {
      final q = _servicesSearchController.text.trim();
      final page = await Api.providers.getProviderServicesPage(
        _labId,
        page: nextPage,
        perPage: 20,
        q: q.isEmpty ? null : q,
        sort: _apiSortForProviderServices(),
      );
      if (!mounted) return;
      setState(() {
        if (reset) {
          _services = List.from(page.items);
        } else {
          _services.addAll(page.items);
        }
        _servicesPage = page.currentPage;
        _hasMoreServices = page.hasMore;
        _loadingMoreServices = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMoreServices = false);
    }
  }


  Future<void> _loadPackagesInternal({
    bool reset = false,
  }) async {
    if (_loadingMorePackages) return;

    setState(() {
      _loadingMorePackages = true;

      if (reset) {
        _packages = [];
        _packagesPage = 0;
        _hasMorePackages = true;
      }
    });

    try {
      final packages = await Api.services.getProviderPackages(
        _labId,
      );

      if (!mounted) return;

      setState(() {
        _packages = List<dynamic>.from(packages);

        // This endpoint returns all packages at once.
        _packagesPage = 1;
        _hasMorePackages = false;
        _loadingMorePackages = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loadingMorePackages = false;
      });
    }
  }

  Future<void> _loadReviewsInternal({bool reset = false}) async {
    if (_loadingMoreReviews && !reset) return;
    if (!reset && !_hasMoreReviews) return;
    final nextPage = reset ? 1 : _reviewsPage + 1;
    setState(() {
      if (reset) {
        _reviews = [];
        _reviewsPage = 0;
        _hasMoreReviews = true;
      }
      _loadingMoreReviews = true;
    });
    try {
      final page = await Api.providers.getReviewsPage(
        _labId,
        page: nextPage,
        perPage: 15,
      );
      if (!mounted) return;
      setState(() {
        if (reset) {
          _reviews = List.from(page.items);
        } else {
          _reviews.addAll(page.items);
        }
        _reviewsPage = page.currentPage;
        _hasMoreReviews = page.hasMore;
        _loadingMoreReviews = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMoreReviews = false);
    }
  }

  Future<void> _loadFavorite() async {
    final value = await FavoritesService.isLabFavorite(widget.lab);
    if (mounted) setState(() => _isFavorite = value);
  }

  Future<void> _toggleFavorite() async {
    final value = await FavoritesService.toggleLab(widget.lab);
    if (!mounted) return;
    setState(() => _isFavorite = value);
  }

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value != null) {
      return double.tryParse(value.toString().replaceAll(',', '').trim()) ??
          0.0;
    }
    return 0.0;
  }

  Map<String, dynamic> _serviceMapFromProviderService(dynamic item) {
    final providerService = item is Map
        ? Map<String, dynamic>.from(item)
        : <String, dynamic>{};
    final rawService = providerService['service'] ?? providerService;
    final service = rawService is Map
        ? Map<String, dynamic>.from(rawService)
        : <String, dynamic>{};
    service['price'] =
        providerService['final_price'] ??
        providerService['price'] ??
        service['price'];
    service['home_price'] =
        providerService['home_service_price'] ??
        providerService['home_price'] ??
        _labMap['home_service_fee'];
    service['provider_service_id'] = providerService['id'];
    final psImg = providerService['image']?.toString().trim();
    if (psImg != null && psImg.isNotEmpty) service['image'] = psImg;
    return service;
  }

  double _servicePrice(dynamic item) {
    final providerService = item is Map ? item : const {};
    final rawService = providerService['service'];
    final service = rawService is Map ? rawService : providerService;
    return _asDouble(
      providerService['final_price'] ??
          providerService['price'] ??
          service['price'],
    );
  }

  double? _serviceHomePrice(dynamic item) {
    final providerService = item is Map ? item : const {};
    final value =
        providerService['home_service_price'] ?? providerService['home_price'];
    if (value != null) return _asDouble(value);
    final labFee = _labMap['home_service_fee'];
    if (labFee != null) return _asDouble(labFee);
    return null;
  }

  String _serviceDisplayName(dynamic item) {
    final service = _serviceMapFromProviderService(item);
    return LocaleUtils.localizedName(
      service,
      context.read<AppSettingsProvider>().isArabic,
    );
  }

  String _packageDisplayName(dynamic item) {
    final pkg = item is Map ? item as Map<String, dynamic> : <String, dynamic>{};
    return LocaleUtils.localizedName(
      pkg,
      context.read<AppSettingsProvider>().isArabic,
    );
  }

  List<dynamic> _visibleLabPackages() {
    final q = _servicesSearchController.text.trim().toLowerCase();
    final visible = _packages.where((item) {
      final pkg = item is Map ? item as Map<String, dynamic> : <String, dynamic>{};
      if (q.isEmpty) return true;
      final n1 = (pkg['name_ar'] ?? '').toString().toLowerCase();
      final n2 = (pkg['name_en'] ?? '').toString().toLowerCase();
      final n3 = (pkg['name'] ?? '').toString().toLowerCase();
      return n1.contains(q) || n2.contains(q) || n3.contains(q);
    }).toList();
    visible.sort((a, b) {
      if (_servicesSort == 'name') {
        return _packageDisplayName(a).compareTo(_packageDisplayName(b));
      }
      if (_servicesSort == 'price_low' || _servicesSort == 'price_high') {
        final pa = ApiConfig.priceFromMap(
          a is Map ? Map<String, dynamic>.from(a) : <String, dynamic>{},
        );
        final pb = ApiConfig.priceFromMap(
          b is Map ? Map<String, dynamic>.from(b) : <String, dynamic>{},
        );
        return _servicesSort == 'price_low'
            ? pa.compareTo(pb)
            : pb.compareTo(pa);
      }
      return 0;
    });
    return visible;
  }

  List<dynamic> _visibleLabServices() {
    final visible = _services.where((item) {
      if (item is! Map) return false;
      final price = _servicePrice(item);
      if (_servicesMinPrice != null && price < _servicesMinPrice!) {
        return false;
      }
      if (_servicesMaxPrice != null && price > _servicesMaxPrice!) {
        return false;
      }
      if (_servicesHomeOnly && _serviceHomePrice(item) == null) {
        return false;
      }
      return true;
    }).toList();

    if (_servicesSort == 'name') {
      visible.sort(
        (a, b) =>
            _serviceDisplayName(a).compareTo(_serviceDisplayName(b)),
      );
    }
    return visible;
  }

  Future<void> _loadData() async {
    setState(() {
      _error = null;
      _providerLoading = true;
    });

    try {
      final provider = await Api.providers.getProvider(_labId);

      if (!mounted) return;

      setState(() {
        _labMap = {
          ..._labMap,
          ...provider,
        };

        // SHOW THE SCREEN NOW
        _providerLoading = false;
      });

      // Load these in the background.
      unawaited(_loadServicesInternal(reset: true));
      unawaited(_loadPackagesInternal(reset: true));
      unawaited(_loadReviewsInternal(reset: true));
    } on ApiException catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.message;
        _providerLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _providerLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();
    final lang = settings.language;
    final lab = _labMap;
    final logoUrl =
        ApiConfig.imageFromMap(lab) ??
        ApiConfig.resolveImageUrl(lab['logo_url'], lab['logo']);
    final name = LocaleUtils.localizedBusinessName(
      lab,
      context.watch<AppSettingsProvider>().isArabic,
    );
    final city = lab['city']?.toString() ?? '';
    final district = lab['district']?.toString() ?? '';

    return Directionality(
      textDirection: settings.textDirection,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: Column(
          children: [
            Container(
              height: MediaQuery.of(context).padding.top + 56,
              width: double.infinity,
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top,
                left: 16,
                right: 16,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.30),
                    blurRadius: 12,
                    spreadRadius: 1,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // BACK
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F7F8),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFE4E4E7),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        textDirection: settings.textDirection,
                        size: 18,
                        color: RastUi.purple,
                      ),
                    ),
                  ),

                  // LAB NAME
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: Responsive.fontSize(context, 17),
                          fontWeight: FontWeight.w800,
                          color: RastUi.primaryText(context),
                          height: 1.2,
                        ),
                      ),
                    ),
                  ),

                  // FAVORITE
                  InkWell(
                    onTap: _toggleFavorite,
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F7F8),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFE4E4E7),
                        ),
                      ),
                      child: Icon(
                        _isFavorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        size: 19,
                        color: _isFavorite
                            ? const Color(0xFFFF4D61)
                            : const Color(0xFF374151),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: _providerLoading
                  ? _buildLoading()
                  : _error != null
                  ? _buildError()
                  : CustomScrollView(
                controller: _scrollController,
                slivers: [

                  SliverToBoxAdapter(
                    child: SizedBox(
                      width: double.infinity,
                      height: 260,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          GestureDetector(
                            onTap: () {
                              if (logoUrl != null && logoUrl.isNotEmpty) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ZoomableImageViewer(
                                      imageUrl: logoUrl,
                                    ),
                                  ),
                                );
                              }
                            },
                            child: logoUrl != null && logoUrl.isNotEmpty
                                ? CachedNetworkImage(
                              imageUrl: logoUrl,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => _buildPlaceholder(),
                              errorWidget: (_, __, ___) => _buildPlaceholder(),
                            )
                                : _buildPlaceholder(),
                          ),

                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.05),
                                  Colors.black.withValues(alpha: 0.15),
                                  Colors.black.withValues(alpha: 0.65),
                                ],
                                stops: const [
                                  0.0,
                                  0.45,
                                  1.0,
                                ],
                              ),
                            ),
                          ),

                          Positioned(
                            left: 18,
                            right: 18,
                            bottom: 18,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [

                                const SizedBox(height: 12),

                                // INFO ROW
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    // LOCATION
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 7,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: const Color(0xFFE5E7EB),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.location_on_outlined,
                                            color: Color(0xFF374151),
                                            size: 17,
                                          ),

                                          const SizedBox(width: 5),

                                          ConstrainedBox(
                                            constraints: BoxConstraints(
                                              maxWidth: MediaQuery.sizeOf(context).width * 0.42,
                                            ),
                                            child: Text(
                                              '$city${district.isNotEmpty ? ' - $district' : ''}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: Responsive.fontSize(context, 11),
                                                color: const Color(0xFF374151),
                                                fontWeight: FontWeight.w600,
                                                height: 1.2,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // HOME SERVICE
                                    if (lab['home_service_available'] == true)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 7,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: const Color(0xFFE5E7EB),
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.home_outlined,
                                              color: Color(0xFF374151),
                                              size: 16,
                                            ),
                                            const SizedBox(width: 5),
                                            Text(
                                              AppStrings.t('homeService', lang),
                                              style: const TextStyle(
                                                color: Color(0xFF374151),
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                height: 1.2,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                    // RATING
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.94),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: RatingBadge(
                                        rating:
                                        (lab['avg_rating'] is num
                                            ? lab['avg_rating'] as num
                                            : 0)
                                            .toDouble(),
                                        reviewCount: lab['total_reviews'] is num
                                            ? (lab['total_reviews'] as num).toInt()
                                            : 0,
                                        size: RatingBadgeSize.medium,
                                        showLabel: true,
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

                  SliverToBoxAdapter(
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(28),
                          ),
                          boxShadow: AppTheme.cardShadowElevated,
                        ),
                        padding: EdgeInsets.all(
                          Responsive.spacing(context, 20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSection(
                              AppStrings.t('ratings', lang),
                              Icons.star_rounded,
                              _reviews.isEmpty && !_loadingMoreReviews
                                  ? _buildEmptyReviews()
                                  : Column(
                                children: [
                                  ..._reviews.map(
                                        (r) => _buildReviewItem(r),
                                  ),
                                  if (_hasMoreReviews)
                                    Padding(
                                      padding: EdgeInsets.only(
                                        top: Responsive.spacing(
                                          context,
                                          12,
                                        ),
                                      ),
                                      child: Center(
                                        child: TextButton(
                                          onPressed:
                                          _loadingMoreReviews
                                              ? null
                                              : () => _loadReviewsInternal(
                                            reset: false,
                                          ),
                                          child: Text(
                                              _loadingMoreReviews
                                                  ? AppStrings.t('loading', lang)
                                                  : AppStrings.t('loadMoreReviews', lang)
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            SizedBox(height: Responsive.spacing(context, 24)),

                            _buildLabServicesAndPackagesTabs(context),
                          ],
                        ),
                      ),
                  ),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: _error == null
            ? SafeArea(
                child: Padding(
                  padding: EdgeInsets.all(Responsive.spacing(context, 16)),
                  child: GradientFilledButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AnalysesScreen(
                          labId: _labId,
                          labName: LocaleUtils.localizedBusinessName(
                            lab,
                            context.watch<AppSettingsProvider>().isArabic,
                          ),
                        ),
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        vertical: Responsive.spacing(context, 14),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      AppStrings.t('bookAnalysis', lang),
                      style: TextStyle(
                        fontSize: Responsive.fontSize(context, 15),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, Widget content) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 2,
        vertical: 4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // ICON
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.10),
                  ),
                ),
                child: Icon(
                  icon,
                  size: 19,
                  color: AppTheme.primary,
                ),
              ),

              const SizedBox(width: 10),

              // TITLE
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 16),
                    fontWeight: FontWeight.w700,
                    color: RastUi.primaryText(context),
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Container(
            height: 1,
            width: double.infinity,
            color: RastUi.softBorder(context).withValues(alpha: 0.65),
          ),

          const SizedBox(height: 14),

          content,
        ],
      ),
    );
  }

  Widget _buildEmptySection(String text) => Padding(
    padding: EdgeInsets.symmetric(vertical: 20),
    child: Center(
      child: Text(
        text,
        style: TextStyle(
          fontSize: Responsive.fontSize(context, 13),
          color: AppTheme.onSurfaceVariant,
        ),
      ),
    ),
  );

  Widget _buildPlaceholder() => Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [AppTheme.primary, AppTheme.primaryDark],
      ),
    ),
    child: Center(
      child: Icon(
        Icons.business_rounded,
        size: 90,
        color: Colors.white.withValues(alpha: 0.5),
      ),
    ),
  );

  /// صورة بعرض البطاقة للشبكة (بدل المصغّر الثابت الذي يظهر صغيراً على جانب RTL).
  Widget _buildGridCoverImage(
    BuildContext context,
    String? imageUrl, {
    IconData placeholderIcon = Icons.medical_services_rounded,
    double height = 112,
  }) {
    final bg = AppTheme.primary.withValues(alpha: 0.08);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: (imageUrl != null && imageUrl.isNotEmpty)
            ? CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                width: double.infinity,
                height: double.infinity,
                placeholder: (_, __) => ColoredBox(
                  color: bg,
                  child: Center(
                    child: Icon(
                      placeholderIcon,
                      color: AppTheme.primary,
                      size: 36,
                    ),
                  ),
                ),
                errorWidget: (_, __, ___) => ColoredBox(
                  color: bg,
                  child: Center(
                    child: Icon(
                      placeholderIcon,
                      color: AppTheme.primary,
                      size: 36,
                    ),
                  ),
                ),
              )
            : ColoredBox(
                color: bg,
                child: Center(
                  child: Icon(
                    placeholderIcon,
                    color: AppTheme.primary,
                    size: 36,
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildLoading() => CustomScrollView(
    slivers: [
      SliverAppBar(
        expandedHeight: 240,
        pinned: true,
        flexibleSpace: FlexibleSpaceBar(background: _buildPlaceholder()),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(Responsive.spacing(context, 20)),
          child: Shimmer.fromColors(
            baseColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            highlightColor: Theme.of(context).colorScheme.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 28,
                  width: 180,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                SizedBox(height: 20),
                ...List.generate(
                  4,
                  (_) => Container(
                    margin: EdgeInsets.only(bottom: 12),
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );

  Widget _buildError() => Center(
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
          SizedBox(height: 16),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 14),
              color: AppTheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: 24),
          GradientFilledButtonIcon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh_rounded, size: 20),
            label: Text(
              AppStrings.t(
                'retry',
                context.read<AppSettingsProvider>().language,
              ),
            ),
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildEmptyReviews() => Container(
    padding: EdgeInsets.symmetric(
      vertical: Responsive.spacing(context, 28),
      horizontal: Responsive.spacing(context, 20),
    ),
    decoration: AppTheme.cardDecorationFor(context),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.rate_review_outlined,
          size: 28,
          color: AppTheme.onSurfaceVariant.withValues(alpha: 0.5),
        ),
        SizedBox(width: 12),
        Text(
          AppStrings.t(
            'noReviewsYet',
            context.read<AppSettingsProvider>().language,
          ),
          style: TextStyle(
            fontSize: Responsive.fontSize(context, 14),
            color: AppTheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );

  Widget _buildLabServicesAndPackagesTabs(BuildContext context) {
    final lang =
        context.watch<AppSettingsProvider>().language;
    final svcAll = _visibleLabServices();
    final pkgAll = _visibleLabPackages();
    final filteredCount =
        _tabController.index == 0 ? svcAll.length : pkgAll.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: SearchBox(
                controller: _servicesSearchController,
                hintText: AppStrings.t(
                  'searchLabServicesPackages',
                  lang,
                ),
                onSearchTap: () {
                  if (_tabController.index == 0) {
                    unawaited(_loadServicesInternal(reset: true));
                  } else {
                    setState(() {});
                  }
                },
                onSubmitted: (v) {
 AnalyticsService.logSearch(v, area: 'lab_details');
                  if (_tabController.index == 0) {
                    unawaited(_loadServicesInternal(reset: true));
                  } else {
                    setState(() {});
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            _filterSquareButton(_showServicesFilterSheet),
          ],
        ),
        SizedBox(height: Responsive.spacing(context, 10)),
        _activeServicesFilters(filteredCount),
        SizedBox(height: Responsive.spacing(context, 12)),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              color: RastUi.purple,
              borderRadius: BorderRadius.circular(12),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelColor: Colors.white,
            unselectedLabelColor: RastUi.textPurple,
            tabs: [
              Tab(
                text: AppStrings.t('analyses', lang),
              ),
              Tab(
                text: AppStrings.t('packages', lang),
              ),
            ],
          ),
        ),
        IndexedStack(
          index: _tabController.index,
          alignment: Alignment.topCenter,
          children: [
            _buildLabServicesGridBody(context, svcAll),
            _buildLabPackagesGridBody(context, pkgAll),
          ],
        ),
      ],
    );
  }

  Widget _buildLabServicesGridBody(
      BuildContext context,
      List<dynamic> allVisible,
      ) {
    if (_services.isEmpty && _loadingMoreServices) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Center(
          child: SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
            ),
          ),
        ),
      );
    }

    if (_services.isEmpty) {
      return _buildEmptySection(
        AppStrings.t(
          'noAnalyses',
          context.read<AppSettingsProvider>().language,
        ),
      );
    }

    if (allVisible.isEmpty) {
      return _buildEmptySection(
          AppStrings.t(
            'noFilterResults',
            context.read<AppSettingsProvider>().language,
          )
      );
    }

    final screenWidth = MediaQuery.sizeOf(context).width;

    final crossSpacing = Responsive.spacing(context, 12);
    final mainSpacing = Responsive.spacing(context, 14);

    final aspectRatio = screenWidth < 360
        ? 0.62
        : screenWidth < 400
        ? 0.66
        : 0.70;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.only(top: 30),
          itemCount: allVisible.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: aspectRatio,
            crossAxisSpacing: crossSpacing,
            mainAxisSpacing: mainSpacing,
          ),
          itemBuilder: (context, index) {
            return _buildServiceGridItem(
              context,
              allVisible[index],
            );
          },
        ),

        if (_loadingMoreServices && _hasMoreServices)
          Padding(
            padding: EdgeInsets.only(
              top: Responsive.spacing(context, 18),
              bottom: Responsive.spacing(context, 6),
            ),
            child: const Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLabPackagesGridBody(
      BuildContext context,
      List<dynamic> allVisible,
      ) {
    if (_packages.isEmpty && _loadingMorePackages) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Center(
          child: SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
            ),
          ),
        ),
      );
    }

    if (_packages.isEmpty) {
      return _buildEmptySection(
        AppStrings.t(
          'noPackages',
          context.read<AppSettingsProvider>().language,
        ),
      );
    }

    if (allVisible.isEmpty) {
      return _buildEmptySection(
        AppStrings.t(
          'noSearchResults',
          context.read<AppSettingsProvider>().language,
        ),
      );
    }

    final screenWidth = MediaQuery.sizeOf(context).width;

    final crossSpacing = Responsive.spacing(context, 12);
    final mainSpacing = Responsive.spacing(context, 14);

    final aspectRatio = screenWidth < 360
        ? 0.62
        : screenWidth < 400
        ? 0.66
        : 0.70;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.only(top: 30),
          itemCount: allVisible.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: aspectRatio,
            crossAxisSpacing: crossSpacing,
            mainAxisSpacing: mainSpacing,
          ),
          itemBuilder: (context, index) {
            return _buildPackageGridItem(
              context,
              allVisible[index],
            );
          },
        ),

        if (_loadingMorePackages && _hasMorePackages)
          Padding(
            padding: EdgeInsets.only(
              top: Responsive.spacing(context, 18),
              bottom: Responsive.spacing(context, 6),
            ),
            child: const Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPackageGridItem(BuildContext context, dynamic item) {
    final lang =
        context.watch<AppSettingsProvider>().language;
    final pkg = item is Map ? item as Map<String, dynamic> : <String, dynamic>{};
    final displayName = LocaleUtils.localizedName(
      pkg,
      context.watch<AppSettingsProvider>().isArabic,
    );
    final price = ApiConfig.priceFromMap(pkg);
    final testsCount = pkg['tests_count'] ??
        (pkg['package_items'] is List ? (pkg['package_items'] as List).length : 0);
    final imageUrl = ApiConfig.packageImageUrl(pkg);
    final labLine = LocaleUtils.localizedBusinessName(
      _labMap,
      context.watch<AppSettingsProvider>().isArabic,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => PackageDetailScreen(package: pkg),
          ),
        ),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            color: RastUi.cardSurface(context),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: RastUi.softBorder(context).withValues(alpha: 0.7),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 14,
                spreadRadius: 1,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: EdgeInsets.all(Responsive.spacing(context, 10)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildGridCoverImage(
                context,
                imageUrl,
                placeholderIcon: Icons.inventory_2_rounded,
              ),
              SizedBox(height: Responsive.spacing(context, 8)),
              Text(
                displayName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 12),
                  fontWeight: FontWeight.w700,
                  color: RastUi.primaryText(context),
                ),
              ),
              if (labLine.trim().isNotEmpty) ...[
                SizedBox(height: Responsive.spacing(context, 4)),
                Text(
                  labLine,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 10),
                    color: AppTheme.primary.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              SizedBox(height: Responsive.spacing(context, 4)),
              Text(
                '$testsCount ${AppStrings.t('analysisCount', lang)}',
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 10),
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Text(
              price > 0
              ? '${price.toStringAsFixed(2)} ${AppStrings.t('sar', lang)}'
                  : AppStrings.t('callForPrice', lang),
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 11),
                  color: RastUi.purple,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterSquareButton(VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: RastUi.cardSurface(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: RastUi.softBorder(context)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(Icons.tune_rounded, color: RastUi.purple, size: 22),
      ),
    );
  }

  Widget _activeServicesFilters(int count) {
    final lang =
        context.watch<AppSettingsProvider>().language;
    final chips = <Widget>[
      _miniInfoChip(
        '$count ${AppStrings.t('result', lang)}',
        Icons.fact_check_outlined,
      ),
    ];
    if (_servicesHomeOnly) {
      chips.add(_miniInfoChip(AppStrings.t('homeService', lang), Icons.home_rounded));
    }
    if (_servicesMinPrice != null || _servicesMaxPrice != null) {
      chips.add(
        _miniInfoChip(
          '${_servicesMinPrice?.toStringAsFixed(0) ?? '0'} - ${_servicesMaxPrice?.toStringAsFixed(0) ?? '∞'}' '${AppStrings.t('sar', lang)}',
          Icons.payments_outlined,
        ),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: chips
            .map(
              (chip) => Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: chip,
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _miniInfoChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.primary),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: AppTheme.primary,
              fontSize: Responsive.fontSize(context, 11),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _showServicesFilterSheet() {
    final settings = context.read<AppSettingsProvider>();
    final lang = settings.language;
    final minController = TextEditingController(
      text: _servicesMinPrice?.toStringAsFixed(0) ?? '',
    );
    final maxController = TextEditingController(
      text: _servicesMaxPrice?.toStringAsFixed(0) ?? '',
    );
    var sort = _servicesSort;
    var homeOnly = _servicesHomeOnly;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Directionality(
          textDirection: settings.textDirection,
          child: _filterSheetShell(
            title: AppStrings.t('filterLabAnalyses', lang),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sheetLabel(
                  AppStrings.t('sort', lang),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _sheetChoice(AppStrings.t('defaultSort', lang), 'default', sort, (value) {
                      setSheetState(() => sort = value);
                    }),
                    _sheetChoice(AppStrings.t('priceLow', lang), 'price_low', sort, (value) {
                      setSheetState(() => sort = value);
                    }),
                    _sheetChoice(AppStrings.t('priceHigh', lang), 'price_high', sort, (value) {
                      setSheetState(() => sort = value);
                    }),
                    _sheetChoice(AppStrings.t('nameSort', lang), 'name', sort, (value) {
                      setSheetState(() => sort = value);
                    }),
                  ],
                ),
                SizedBox(height: Responsive.spacing(context, 18)),
                SwitchListTile(
                  value: homeOnly,
                  onChanged: (value) => setSheetState(() => homeOnly = value),
                  title: Text(
                    AppStrings.t('homeAnalysesOnly', lang),
                  ),
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: RastUi.purple,
                ),
                SizedBox(height: Responsive.spacing(context, 10)),
                _priceFields(minController, maxController),
                SizedBox(height: Responsive.spacing(context, 20)),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _servicesSort = 'default';
                            _servicesHomeOnly = false;
                            _servicesMinPrice = null;
                            _servicesMaxPrice = null;
                          });
                          Navigator.pop(ctx);
                          unawaited(_loadServicesInternal(reset: true));
                        },
                        child: Text(
                          AppStrings.t('clear', lang),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          setState(() {
                            _servicesSort = sort;
                            _servicesHomeOnly = homeOnly;
                            _servicesMinPrice = double.tryParse(
                              minController.text.trim(),
                            );
                            _servicesMaxPrice = double.tryParse(
                              maxController.text.trim(),
                            );
                          });
                          Navigator.pop(ctx);
                          unawaited(_loadServicesInternal(reset: true));
                        },
                        child: Text(
                          AppStrings.t('apply', lang),
                        ),
                      ),
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

  Widget _filterSheetShell({required String title, required Widget child}) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        Responsive.spacing(context, 20),
        10,
        Responsive.spacing(context, 20),
        Responsive.spacing(context, 20) + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: RastUi.cardSurface(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        boxShadow: AppTheme.cardShadowElevated,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.onSurfaceVariant.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: Responsive.spacing(context, 16)),
              Text(
                title,
                style: TextStyle(
                  color: RastUi.primaryText(context),
                  fontSize: Responsive.fontSize(context, 18),
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: Responsive.spacing(context, 18)),
              child,
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          color: RastUi.textPurple,
          fontSize: Responsive.fontSize(context, 13),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _sheetChoice(
    String label,
    String value,
    String selected,
    ValueChanged<String> onSelected,
  ) {
    return ChoiceChip(
      label: Text(label),
      selected: selected == value,
      showCheckmark: false,
      selectedColor: RastUi.purple,
      labelStyle: TextStyle(
        color: selected == value ? Colors.white : RastUi.textPurple,
        fontWeight: FontWeight.w600,
      ),
      onSelected: (_) => onSelected(value),
    );
  }

  Widget _priceFields(
    TextEditingController minController,
    TextEditingController maxController,
  ) {
    final lang =
        context.watch<AppSettingsProvider>().language;
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: minController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: AppStrings.t('minPrice', lang),
              prefixIcon: const Icon(Icons.payments_outlined),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: maxController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: AppStrings.t('maxPrice', lang),
              prefixIcon: const Icon(Icons.payments_outlined),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildServiceGridItem(BuildContext context, dynamic s) {
    final lang =
        context.watch<AppSettingsProvider>().language;
    final svc = s is Map ? s as Map<String, dynamic> : <String, dynamic>{};
    final service = svc['service'] ?? svc;
    final displayName = LocaleUtils.localizedName(
      service is Map ? service as Map<String, dynamic> : svc,
      context.watch<AppSettingsProvider>().isArabic,
    );
    final price = svc['final_price'] ?? svc['price'] ?? service['price'] ?? 0;
    final homePrice = svc['home_service_price'] ?? svc['home_price'];
    final serviceMap = service is Map
        ? Map<String, dynamic>.from(service)
        : <String, dynamic>{};
    serviceMap['price'] = price;
    serviceMap['home_price'] = homePrice;
    serviceMap['provider_service_id'] = svc['id'];
    final psImg = svc['image']?.toString().trim();
    if (psImg != null && psImg.isNotEmpty) serviceMap['image'] = psImg;
    final imageUrl = ApiConfig.analysisImageUrl(serviceMap, svc);

    return Container(
      decoration: BoxDecoration(
        color: RastUi.cardSurface(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: RastUi.softBorder(context).withValues(alpha: 0.7),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 14,
            spreadRadius: 1,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ServiceDetailScreen(
                service: serviceMap,
                labId: _labId,
                labName: LocaleUtils.localizedBusinessName(
                  _labMap,
                  context.watch<AppSettingsProvider>().isArabic,
                ),
                lab: _labMap,
              ),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(Responsive.spacing(context, 10)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildGridCoverImage(context, imageUrl),
                SizedBox(height: Responsive.spacing(context, 8)),
                Text(
                  displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 12),
                    fontWeight: FontWeight.w700,
                    color: RastUi.primaryText(context),
                  ),
                ),
                const Spacer(),
                Text(
                  '${price is num ? price.toStringAsFixed(2) : price} '
                      '${AppStrings.t('sar', lang)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 11),
                    color: RastUi.purple,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReviewItem(dynamic r) {
    final review = r is Map ? r as Map<String, dynamic> : <String, dynamic>{};
    final lang =
        context.read<AppSettingsProvider>().language;

    final userName =
        review['user_name'] ??
            review['user']?['name'] ??
            AppStrings.t('user', lang);
    final rating = (review['rating'] is num ? review['rating'] as num : 0)
        .toDouble();
    final comment = review['comment']?.toString() ?? '';
    final date = review['date'] ?? review['created_at'] ?? '';
    final dateStr = date.toString().length > 10
        ? date.toString().substring(0, 10)
        : date.toString();

    return Container(
      margin: EdgeInsets.only(bottom: Responsive.spacing(context, 12)),
      decoration: AppTheme.cardDecorationFor(context),
      child: Padding(
        padding: EdgeInsets.all(Responsive.spacing(context, 16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                  child: Text(
                    userName.isNotEmpty ? userName[0].toUpperCase() : '؟',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: TextStyle(
                          fontSize: Responsive.fontSize(context, 14),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Row(
                        children: [
                          RatingBadge(
                            rating: rating,
                            size: RatingBadgeSize.small,
                            showLabel: false,
                          ),
                          SizedBox(width: 8),
                          Text(
                            dateStr,
                            style: TextStyle(
                              fontSize: Responsive.fontSize(context, 11),
                              color: AppTheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (comment.isNotEmpty) ...[
              SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(Responsive.spacing(context, 12)),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceVariant.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  comment,
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 13),
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}