import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
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

  bool _packageBelongsToLab(dynamic item) {
    if (item is! Map) return false;
    final pkg = Map<String, dynamic>.from(item);
    final provider = pkg['provider'];
    if (provider is Map && provider['id']?.toString() == _labId.toString()) {
      return true;
    }
    final providerServices =
        pkg['provider_services'] ?? pkg['providerServices'];
    if (providerServices is List) {
      for (final ps in providerServices) {
        if (ps is! Map) continue;
        if (ps['provider_id']?.toString() == _labId.toString()) return true;
        final psProvider = ps['provider'];
        if (psProvider is Map &&
            psProvider['id']?.toString() == _labId.toString()) {
          return true;
        }
      }
    }
    return false;
  }

  Future<void> _loadPackagesInternal({bool reset = false}) async {
    if (_loadingMorePackages && !reset) return;
    if (!reset && !_hasMorePackages) return;
    final nextPage = reset ? 1 : _packagesPage + 1;
    setState(() {
      if (reset) {
        _packages = [];
        _packagesPage = 0;
        _hasMorePackages = true;
      }
      _loadingMorePackages = true;
    });
    try {
      final res = await Api.services.getPackages(page: nextPage, perPage: 20);
      final page = PaginatedResponse.fromPayload(res['data']);
      final matched =
          page.items.where((e) => _packageBelongsToLab(e)).toList();
      if (!mounted) return;
      setState(() {
        if (reset) {
          _packages = matched;
        } else {
          _packages.addAll(matched);
        }
        _packagesPage = page.currentPage;
        _hasMorePackages = page.hasMore;
        _loadingMorePackages = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMorePackages = false);
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
      setState(() => _labMap = {..._labMap, ...provider});
      await Future.wait([
        _loadServicesInternal(reset: true),
        _loadPackagesInternal(reset: true),
        _loadReviewsInternal(reset: true),
      ]);
      if (!mounted) return;
      setState(() => _providerLoading = false);
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _providerLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _providerLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: _providerLoading
            ? _buildLoading()
            : _error != null
            ? _buildError()
            : CustomScrollView(
                controller: _scrollController,
                slivers: [
                  SliverAppBar(
                    expandedHeight: 260,
                    pinned: true,
                    stretch: true,
                    backgroundColor: AppTheme.primary,
                    leading: IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    actions: [
                      IconButton(
                        onPressed: _toggleFavorite,
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _isFavorite
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: const Color(0xFFFF4D61),
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                    flexibleSpace: FlexibleSpaceBar(
                      stretchModes: const [StretchMode.zoomBackground],
                      background: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (logoUrl != null && logoUrl.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ZoomableImageViewer(
                                      imageUrl: logoUrl,
                                    ),
                                  ),
                                );
                              },
                              child: CachedNetworkImage(
                                imageUrl: logoUrl,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => _buildPlaceholder(),
                                errorWidget: (_, __, ___) =>
                                    _buildPlaceholder(),
                              ),
                            )
                          else
                            _buildPlaceholder(),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.6),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: Padding(
                              padding: EdgeInsets.all(
                                Responsive.spacing(context, 20),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    name,
                                    style: TextStyle(
                                      fontSize: Responsive.fontSize(
                                        context,
                                        22,
                                      ),
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black54,
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.location_on_rounded,
                                        size: 16,
                                        color: Colors.white.withValues(
                                          alpha: 0.9,
                                        ),
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        '$city${district.isNotEmpty ? ' - $district' : ''}',
                                        style: TextStyle(
                                          fontSize: Responsive.fontSize(
                                            context,
                                            13,
                                          ),
                                          color: Colors.white.withValues(
                                            alpha: 0.95,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 12),
                                  Row(
                                    children: [
                                      RatingBadge(
                                        rating:
                                            (lab['avg_rating'] is num
                                                    ? lab['avg_rating'] as num
                                                    : 0)
                                                .toDouble(),
                                        reviewCount: lab['total_reviews'] is num
                                            ? (lab['total_reviews'] as num)
                                                  .toInt()
                                            : 0,
                                        size: RatingBadgeSize.medium,
                                        showLabel: true,
                                      ),
                                      if (lab['home_service_available'] ==
                                          true) ...[
                                        SizedBox(width: 12),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(
                                              alpha: 0.25,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.home_rounded,
                                                size: 14,
                                                color: Colors.white,
                                              ),
                                              SizedBox(width: 5),
                                              Text(
                                                'خدمة منزلية',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Transform.translate(
                      offset: const Offset(0, -28),
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
                            _buildLabServicesAndPackagesTabs(context),
                            SizedBox(height: Responsive.spacing(context, 24)),
                            _buildSection(
                              'التقييمات',
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
                                                      ? 'جاري التحميل...'
                                                      : 'تحميل المزيد من التقييمات',
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                            ),
                            SizedBox(height: 100),
                          ],
                        ),
                      ),
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
                      'احجز تحليل',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 20, color: AppTheme.primary),
            ),
            SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: Responsive.fontSize(context, 16),
                fontWeight: FontWeight.w500,
                color: AppTheme.onSurface,
              ),
            ),
          ],
        ),
        SizedBox(height: 14),
        content,
      ],
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
            label: const Text('إعادة المحاولة'),
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
          'لا توجد تقييمات بعد',
          style: TextStyle(
            fontSize: Responsive.fontSize(context, 14),
            color: AppTheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );

  Widget _buildLabServicesAndPackagesTabs(BuildContext context) {
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
                hintText: 'ابحث داخل تحاليل أو باقات المختبر',
                onSearchTap: () {
                  if (_tabController.index == 0) {
                    unawaited(_loadServicesInternal(reset: true));
                  } else {
                    setState(() {});
                  }
                },
                onSubmitted: (_) {
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
            tabs: const [
              Tab(text: 'التحاليل'),
              Tab(text: 'الباقات'),
            ],
          ),
        ),
        SizedBox(height: Responsive.spacing(context, 14)),
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
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_services.isEmpty) {
      return _buildEmptySection('لا توجد تحاليل');
    }
    if (allVisible.isEmpty) {
      return _buildEmptySection('لا توجد نتائج مطابقة للفلترة');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: allVisible.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.70,
            crossAxisSpacing: Responsive.spacing(context, 10),
            mainAxisSpacing: Responsive.spacing(context, 10),
          ),
          itemBuilder: (context, index) =>
              _buildServiceGridItem(context, allVisible[index]),
        ),
        if (_loadingMoreServices && _hasMoreServices)
          Padding(
            padding: EdgeInsets.only(top: Responsive.spacing(context, 16)),
            child: const Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2),
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
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_packages.isEmpty) {
      return _buildEmptySection('لا توجد باقات');
    }
    if (allVisible.isEmpty) {
      return _buildEmptySection('لا توجد نتائج مطابقة للبحث');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: allVisible.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.70,
            crossAxisSpacing: Responsive.spacing(context, 10),
            mainAxisSpacing: Responsive.spacing(context, 10),
          ),
          itemBuilder: (context, index) =>
              _buildPackageGridItem(context, allVisible[index]),
        ),
        if (_loadingMorePackages && _hasMorePackages)
          Padding(
            padding: EdgeInsets.only(top: Responsive.spacing(context, 16)),
            child: const Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPackageGridItem(BuildContext context, dynamic item) {
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
          decoration: AppTheme.cardDecorationFor(context),
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
                '$testsCount تحليل',
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 10),
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Text(
                price > 0 ? '${price.toStringAsFixed(2)} ر.س' : 'اتصل لمعرفة السعر',
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
    final chips = <Widget>[
      _miniInfoChip('$count نتيجة', Icons.fact_check_outlined),
    ];
    if (_servicesHomeOnly) {
      chips.add(_miniInfoChip('خدمة منزلية', Icons.home_rounded));
    }
    if (_servicesMinPrice != null || _servicesMaxPrice != null) {
      chips.add(
        _miniInfoChip(
          '${_servicesMinPrice?.toStringAsFixed(0) ?? '0'} - ${_servicesMaxPrice?.toStringAsFixed(0) ?? '∞'} ر.س',
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
          textDirection: TextDirection.rtl,
          child: _filterSheetShell(
            title: 'فلترة تحاليل المختبر',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sheetLabel('الترتيب'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _sheetChoice('الافتراضي', 'default', sort, (value) {
                      setSheetState(() => sort = value);
                    }),
                    _sheetChoice('الأقل سعراً', 'price_low', sort, (value) {
                      setSheetState(() => sort = value);
                    }),
                    _sheetChoice('الأعلى سعراً', 'price_high', sort, (value) {
                      setSheetState(() => sort = value);
                    }),
                    _sheetChoice('الاسم', 'name', sort, (value) {
                      setSheetState(() => sort = value);
                    }),
                  ],
                ),
                SizedBox(height: Responsive.spacing(context, 18)),
                SwitchListTile(
                  value: homeOnly,
                  onChanged: (value) => setSheetState(() => homeOnly = value),
                  title: const Text('إظهار التحاليل المتاحة منزلياً فقط'),
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
                        child: const Text('مسح'),
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
                        child: const Text('تطبيق'),
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
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: minController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'أقل سعر',
              prefixIcon: Icon(Icons.payments_outlined),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: maxController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'أعلى سعر',
              prefixIcon: Icon(Icons.payments_outlined),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildServiceGridItem(BuildContext context, dynamic s) {
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
      decoration: AppTheme.cardDecorationFor(context),
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
                  '${price is num ? price.toStringAsFixed(2) : price} ر.س',
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
    final userName = review['user_name'] ?? review['user']?['name'] ?? 'مستخدم';
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
