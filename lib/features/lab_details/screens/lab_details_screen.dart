import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rast/core/widgets/rast_motion.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:rast/core/widgets/rast_kit.dart';
import 'package:rast/features/offers/screens/offer_detail_screen.dart';
import 'package:rast/features/offers/screens/offers_screen.dart';
import 'package:rast/features/offers/widgets/offer_card.dart';
import 'package:rast/core/widgets/cart_icon_button.dart';
import 'package:rast/core/services/branches_index_service.dart';
import 'package:rast/features/bookings/screens/book_flow_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:rast/core/services/analytics_service.dart';
import 'package:rast/core/constants/api_config.dart';
import 'package:rast/core/providers/app_settings_provider.dart';
import 'package:rast/core/services/favorites_service.dart';
import 'package:rast/core/utils/locale_utils.dart';
import 'package:provider/provider.dart';
import 'package:rast/core/api/api_services.dart';
import 'package:rast/core/api/api_client.dart';
import 'package:rast/core/widgets/zoomable_image_viewer.dart';
import 'package:rast/features/analyses/screens/analyses_screen.dart';
import 'package:rast/features/analyses/screens/service_detail_screen.dart';
import 'package:rast/features/packages/screens/package_detail_screen.dart';
import 'package:rast/core/services/location_service.dart';
import 'package:rast/core/utils/lab_location_utils.dart';
import 'package:rast/features/labs/widgets/lab_visuals.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

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
    // التبويبات: 0 العروض، 1 التحاليل (الافتراضي)، 2 الباقات، 3 التقييمات، 4 عن المختبر
    _tabController = TabController(length: 5, initialIndex: _tabTests, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && mounted) {
        setState(() {});
      }
    });
    _scrollController.addListener(_onScrollNearEnd);
    _servicesSearchController.addListener(_onSearchTextChanged);
    _loadFavorite();
    _loadUserLocation();
    _loadData();
  }

  static const int _tabOffers = 0;
  static const int _tabTests = 1;
  static const int _tabPackages = 2;
  static const int _tabReviews = 3;
  static const int _tabAbout = 4;

  /// موقع المستخدم المعتمد (لحساب المسافة لأقرب فرع)
  (double, double)? _userLoc;

  Future<void> _loadUserLocation() async {
    try {
      final loc = await LocationService.getDefaultLocation();
      if (loc != null && mounted) setState(() => _userLoc = (loc.lat, loc.lng));
    } catch (_) {}
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
      if (_tabController.index == _tabTests) {
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
    if (_tabController.index == _tabTests) {
      if (_hasMoreServices && !_loadingMoreServices) {
        unawaited(_loadServicesInternal(reset: false));
      }
    } else if (_tabController.index == _tabPackages) {
      if (_hasMorePackages && !_loadingMorePackages) {
        unawaited(_loadPackagesInternal(reset: false));
      }
    } else if (_tabController.index == _tabReviews) {
      // تبويب التقييمات: تحميل المزيد تلقائياً عند الوصول للنهاية
      if (_hasMoreReviews && !_loadingMoreReviews) {
        unawaited(_loadReviewsInternal(reset: false));
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
      unawaited(_loadOffers());
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

  /// العروض الفعّالة لهذا المختبر (بنفس شكل /api/offers)
  List<Map<String, dynamic>> _labOffers = const [];

  Future<void> _loadOffers() async {
    try {
      final res = await Api.growth.offers(page: 1, providerId: _labId);
      final rows = (res['data'] is List ? res['data'] as List : const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      if (mounted) setState(() => _labOffers = rows);
    } catch (_) {}
  }

  // ===================== الواجهة =====================

  static const double _heroMax = 270;

  String get _lang => context.read<AppSettingsProvider>().language;

  String get _labName => LocaleUtils.localizedBusinessName(
        _labMap,
        context.read<AppSettingsProvider>().isArabic,
      );

  List<dynamic> get _branches {
    final fromIndex = BranchesIndexService.instance.branchesFor(_labMap);
    if (fromIndex != null && fromIndex.isNotEmpty) return fromIndex;
    final raw = _labMap['branches'];
    return raw is List ? raw : const [];
  }

  (double, double)? _latLngOf(Map<dynamic, dynamic> m) {
    final lat = numOf(m['latitude'] ?? m['lat']);
    final lng = numOf(m['longitude'] ?? m['lng']);
    if (lat == null || lng == null || (lat == 0 && lng == 0)) return null;
    return (lat, lng);
  }

  /// موقع للاتجاهات والخريطة: المختبر نفسه أو أول فرع له إحداثيات
  Map<dynamic, dynamic>? get _mainPlace {
    if (_latLngOf(_labMap) != null) return _labMap;
    for (final b in _branches) {
      if (b is Map && _latLngOf(b) != null) return b;
    }
    return null;
  }

  double? get _distanceKm {
    final u = _userLoc;
    if (u == null) return null;
    return LabLocationUtils.distanceKmToNearest(
      lab: _labMap,
      userLat: u.$1,
      userLng: u.$2,
      branches: _branches,
    );
  }

  Future<void> _openDirections(Map<dynamic, dynamic> place) async {
    final ll = _latLngOf(place);
    if (ll == null) return;
    final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${ll.$1},${ll.$2}');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  /// مشاركة صفحة المختبر عبر واتساب (لا توجد حزمة مشاركة في التطبيق)
  Future<void> _share() async {
    final url = 'https://rast-labs.com/user/providers/$_labId';
    final text = L(_lang, '$_labName على راست لابس:\n$url', '$_labName on Rast Labs:\n$url');
    try {
      await launchUrl(Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}'), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  void _openServiceDetail(dynamic item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ServiceDetailScreen(
          service: _serviceMapFromProviderService(item),
          labId: _labId,
          labName: _labName,
          lab: _labMap,
        ),
      ),
    );
  }

  /// «احجز» مباشرة من صف التحليل: يفتح خطوات الحجز لهذا المختبر دون المرور بصفحة التحليل.
  void _openBookFlow(dynamic item) {
    if (item is! Map) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookFlowScreen(
          labId: _labId,
          labName: _labName,
          lab: _labMap,
          providerService: Map<String, dynamic>.from(item),
        ),
      ),
    );
  }

  void _openAllAnalyses() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AnalysesScreen(labId: _labId, labName: _labName),
      ),
    );
  }

  bool get _tabHasSearch => _tabController.index == _tabTests || _tabController.index == _tabPackages;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();
    final lang = settings.language;

    return Directionality(
      textDirection: settings.textDirection,
      child: Scaffold(
        backgroundColor: RastTokens.bg(context),
        body: _providerLoading
            ? _buildLoading()
            : _error != null
                ? _buildError()
                : RefreshIndicator(
                    color: RastTokens.brand,
                    edgeOffset: _heroMax * 0.4,
                    onRefresh: _loadData,
                    child: CustomScrollView(
                      controller: _scrollController,
                      slivers: [
                        _buildHeroAppBar(context),
                        SliverToBoxAdapter(child: _buildInfoCard(context)),
                        SliverPersistentHeader(
                          pinned: true,
                          delegate: _TabsHeaderDelegate(
                            extent: _tabHasSearch ? 122 : 58,
                            child: _buildTabsHeader(context),
                          ),
                        ),
                        ..._buildActiveTabSlivers(context),
                        const SliverToBoxAdapter(child: SizedBox(height: 28)),
                      ],
                    ),
                  ),
        bottomNavigationBar: _error == null && !_providerLoading
            ? RastStickyBar(
                child: Row(
                  children: [
                    if (_mainPlace != null) ...[
                      SizedBox(
                        width: 54,
                        height: 52,
                        child: Material(
                          color: RastTokens.brandSoft(context),
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => _openDirections(_mainPlace!),
                            child: const Icon(Icons.directions_rounded, color: RastTokens.brand),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: RastButton(
                        icon: Icons.biotech_rounded,
                        label: AppStrings.t('bookAnalysis', lang),
                        onPressed: _openAllAnalyses,
                      ),
                    ),
                  ],
                ),
              )
            : null,
      ),
    );
  }

  // ---------- الغلاف: صورة كاملة العرض بأزرار عائمة ----------

  Widget _buildHeroAppBar(BuildContext context) {
    final lab = _labMap;
    final isArabic = context.watch<AppSettingsProvider>().isArabic;
    final cover = labCoverUrl(lab);
    final gallery = (lab['gallery'] is List ? lab['gallery'] as List : const [])
        .map((e) => e?.toString() ?? '')
        .where((e) => e.isNotEmpty)
        .toList();
    final topPad = MediaQuery.paddingOf(context).top;
    final ink = RastTokens.ink(context);

    return SliverAppBar(
      pinned: true,
      expandedHeight: _heroMax,
      automaticallyImplyLeading: false,
      backgroundColor: RastTokens.card(context),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      toolbarHeight: 64,
      titleSpacing: 12,
      title: Row(
        children: [
          GlassCircleButton(
            onTap: () => Navigator.pop(context),
            child: Icon(
              isArabic ? Icons.arrow_forward_ios_rounded : Icons.arrow_back_ios_new_rounded,
              textDirection: TextDirection.ltr,
              color: ink,
              size: 18,
            ),
          ),
          const Spacer(),
          GlassCircleButton(onTap: _share, child: Icon(Icons.ios_share_rounded, color: ink, size: 20)),
          const SizedBox(width: 8),
          GlassCircleButton(
            onTap: _toggleFavorite,
            child: AnimatedFavoriteIcon(active: _isFavorite, size: 21, inactiveColor: ink),
          ),
          const SizedBox(width: 8),
          GlassCircleButton(
            child: CartIconButton(size: 40, iconColor: ink, backgroundColor: Colors.transparent),
          ),
        ],
      ),
      flexibleSpace: LayoutBuilder(
        builder: (context, c) {
          final minH = 64 + topPad;
          final t = ((c.maxHeight - minH) / (_heroMax + topPad - minH)).clamp(0.0, 1.0);
          return Stack(
            fit: StackFit.expand,
            children: [
              // الصورة تختفي تدريجياً عند الطي ويبقى شريط أبيض فيه اسم المختبر
              Opacity(
                opacity: Curves.easeOut.transform(t),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (cover != null)
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ZoomableImageViewer(
                              imageUrl: cover,
                              imageUrls: gallery.isNotEmpty ? gallery : null,
                            ),
                          ),
                        ),
                        child: RastNetImage(url: cover, radius: 0),
                      )
                    else
                      LabCoverFallback(logoUrl: labLogoUrl(lab)),
                    // تظليل علوي خفيف لتبقى الأزرار واضحة فوق أي صورة
                    IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.black.withValues(alpha: 0.28), Colors.transparent, Colors.black.withValues(alpha: 0.12)],
                            stops: const [0, 0.45, 1],
                          ),
                        ),
                      ),
                    ),
                    if (gallery.length > 1)
                      PositionedDirectional(
                        bottom: 40,
                        end: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.photo_library_outlined, color: Colors.white, size: 14),
                              const SizedBox(width: 4),
                              Text('${gallery.length}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // حافة بيضاء دائرية يبدأ منها المحتوى (تمنح إحساس «الورقة» فوق الصورة)
              Positioned(
                left: 0,
                right: 0,
                bottom: -1,
                height: 26,
                child: Opacity(
                  opacity: t,
                  child: Container(
                    decoration: BoxDecoration(
                      color: RastTokens.bg(context),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
                    ),
                  ),
                ),
              ),
              // اسم المختبر في الشريط بعد الطي
              Positioned(
                top: topPad,
                left: 70,
                right: 160,
                height: 64,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: (1 - t * 3).clamp(0.0, 1.0),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        _labName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: ink, fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ---------- بطاقة المعلومات: الشعار، الاسم، التقييم، الدوام، أقرب موعد ----------

  Widget _buildInfoCard(BuildContext context) {
    final lab = _labMap;
    final lang = context.watch<AppSettingsProvider>().language;
    final city = lab['city']?.toString() ?? '';
    final district = lab['district']?.toString() ?? '';
    final area = [district, city].where((e) => e.trim().isNotEmpty).join('، ');
    final rating = numOf(lab['avg_rating']) ?? 0;
    final reviews = (numOf(lab['total_reviews']) ?? 0).toInt();
    final logoUrl = labLogoUrl(lab);
    final status = labOpenStatus(lab);
    final next = lab['next_available_slot'] is Map ? lab['next_available_slot'] as Map : null;
    final distance = _distanceKm;
    final home = lab['home_service_available'] == true;
    final homeFee = numOf(lab['home_service_fee']);
    final accreditations = (lab['accreditations_list'] is List ? lab['accreditations_list'] as List : const [])
        .whereType<Map>()
        .toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(RastTokens.gutter, 0, RastTokens.gutter, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RastCard(
            // الأسفل 0: المحتوى مرفوع 22 بكسل لتعويض الشعار البارز فتبقى المسافة السفلية متوازنة
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // الشعار يبرز فوق حافة البطاقة
                    Transform.translate(
                      offset: const Offset(0, -34),
                      child: GestureDetector(
                        onTap: () {
                          if (logoUrl != null && logoUrl.isNotEmpty) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => ZoomableImageViewer(imageUrl: logoUrl)),
                            );
                          }
                        },
                        child: Container(
                          width: 80,
                          height: 80,
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 18, offset: const Offset(0, 8)),
                            ],
                          ),
                          child: Hero(
                            tag: 'lab-logo-$_labId',
                            child: RastNetImage(url: logoUrl, radius: 17, fit: BoxFit.contain, width: 70, height: 70, fallbackIcon: Icons.biotech_rounded),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _labName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, height: 1.3, color: RastTokens.ink(context)),
                          ),
                          if (area.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.location_on_rounded, size: 15, color: RastTokens.brand),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: Text(
                                    area,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 12.5, color: RastTokens.muted(context), fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                // نعوّض مساحة الشعار المرفوع
                Transform.translate(
                  offset: const Offset(0, -22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _statBlock(
                            context,
                            icon: Icons.star_rounded,
                            iconColor: RastTokens.gold,
                            value: reviews > 0 && rating > 0 ? rating.toStringAsFixed(1) : L(lang, 'جديد', 'New'),
                            label: reviews > 0 ? L(lang, '$reviews تقييم', '$reviews reviews') : L(lang, 'على راست', 'on Rast'),
                            onTap: reviews > 0 ? () => _tabController.animateTo(_tabReviews) : null,
                          ),
                          _statDivider(context),
                          _statBlock(
                            context,
                            icon: Icons.near_me_rounded,
                            iconColor: RastTokens.brand2,
                            value: distance != null ? labDistanceLabel(distance, lang) : '—',
                            label: L(lang, 'المسافة', 'Distance'),
                          ),
                          _statDivider(context),
                          _statBlock(
                            context,
                            icon: home ? Icons.home_rounded : Icons.storefront_rounded,
                            iconColor: home ? RastTokens.success : RastTokens.brand,
                            value: home
                                ? (homeFee != null && homeFee > 0 ? '${fmtPrice(homeFee)} ${L(lang, 'ر.س', 'SAR')}' : L(lang, 'متاح', 'Yes'))
                                : L(lang, 'المختبر', 'Lab'),
                            label: home ? L(lang, 'سحب منزلي', 'Home visit') : L(lang, 'الزيارة في', 'Visit at'),
                          ),
                        ],
                      ),
                      if (status.known || next != null) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (status.known)
                              LabOpenBadge(open: status.open, opensAt: status.opensAt, closesAt: status.closesAt, lang: lang),
                            if (next != null) _nextSlotChip(next, lang),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (accreditations.isNotEmpty || lab['is_featured'] == true) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  if (lab['is_featured'] == true)
                    _accreditationChip(context, Icons.workspace_premium_rounded, L(lang, 'مختبر مميز', 'Featured lab'), RastTokens.gold),
                  for (final a in accreditations)
                    _accreditationChip(context, Icons.verified_rounded, a['label']?.toString() ?? '', RastTokens.success),
                ],
              ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.05, end: 0, curve: Curves.easeOutCubic);
  }

  Widget _statBlock(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 17, color: iconColor),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, color: RastTokens.ink(context)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: RastTokens.muted(context), fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statDivider(BuildContext context) =>
      Container(width: 1, height: 30, color: RastTokens.line(context));

  Widget _accreditationChip(BuildContext context, IconData icon, String label, Color color) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: RastTokens.card(context),
          borderRadius: BorderRadius.circular(999),
          boxShadow: RastTokens.shadow(context, strength: 0.6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: RastTokens.ink(context))),
          ],
        ),
      ),
    );
  }

  Widget _nextSlotChip(Map next, String lang) {
    final offset = (numOf(next['day_offset']) ?? 0).toInt();
    final day = switch (offset) {
      0 => L(lang, 'اليوم', 'today'),
      1 => L(lang, 'غداً', 'tomorrow'),
      _ => next['date']?.toString() ?? '',
    };
    final time = labClock(next['time']?.toString(), lang);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: RastTokens.brandSoft(context),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.event_available_rounded, size: 15, color: RastTokens.brand),
          const SizedBox(width: 5),
          Text(
            L(lang, 'أقرب موعد: $day $time', 'Next slot: $day $time'),
            style: const TextStyle(color: RastTokens.brand, fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  // ---------- التبويبات (ثابتة أعلى الشاشة عند التمرير) ----------

  Widget _buildTabsHeader(BuildContext context) {
    final lang = context.watch<AppSettingsProvider>().language;
    final reviewsCount = (numOf(_labMap['total_reviews']) ?? _reviews.length).toInt();

    Tab tab(String label, int count) => Tab(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label),
              if (count > 0) ...[
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: RastTokens.brandSoft(context),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: RastTokens.brand),
                  ),
                ),
              ],
            ],
          ),
        );

    return Container(
      color: RastTokens.bg(context),
      child: Column(
        children: [
          Container(
            height: 50,
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: RastTokens.line(context))),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              dividerColor: Colors.transparent,
              overlayColor: WidgetStateProperty.all(Colors.transparent),
              indicatorSize: TabBarIndicatorSize.label,
              indicator: const UnderlineTabIndicator(
                borderSide: BorderSide(width: 3, color: RastTokens.brand),
                borderRadius: BorderRadius.vertical(top: Radius.circular(3)),
              ),
              labelColor: RastTokens.brand,
              unselectedLabelColor: RastTokens.muted(context),
              labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              labelPadding: const EdgeInsets.symmetric(horizontal: 12),
              tabs: [
                tab(L(lang, 'العروض', 'Deals'), _labOffers.length),
                tab(AppStrings.t('analyses', lang), 0),
                tab(AppStrings.t('packages', lang), _packages.length),
                tab(AppStrings.t('ratings', lang), reviewsCount),
                Tab(text: L(lang, 'عن المختبر', 'About')),
              ],
            ),
          ),
          if (_tabHasSearch)
            Padding(
              padding: const EdgeInsets.fromLTRB(RastTokens.gutter, 10, RastTokens.gutter, 8),
              child: RastSearchField(
                controller: _servicesSearchController,
                hint: AppStrings.t('searchLabServicesPackages', lang),
                onSubmitted: (v) {
                  AnalyticsService.logSearch(v, area: 'lab_details');
                  if (_tabController.index == _tabTests) {
                    unawaited(_loadServicesInternal(reset: true));
                  } else {
                    setState(() {});
                  }
                },
                trailing: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Material(
                      color: RastTokens.brandSoft(context),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _showServicesFilterSheet,
                        child: const SizedBox(
                          width: 40,
                          height: 40,
                          child: Icon(Icons.tune_rounded, color: RastTokens.brand, size: 21),
                        ),
                      ),
                    ),
                    if (_servicesHomeOnly ||
                        _servicesMinPrice != null ||
                        _servicesMaxPrice != null ||
                        _servicesSort != 'default')
                      PositionedDirectional(
                        top: -2,
                        end: -2,
                        child: Container(
                          width: 11,
                          height: 11,
                          decoration: BoxDecoration(
                            color: RastTokens.danger,
                            shape: BoxShape.circle,
                            border: Border.all(color: RastTokens.card(context), width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildActiveTabSlivers(BuildContext context) {
    switch (_tabController.index) {
      case _tabOffers:
        return _buildOffersSlivers(context);
      case _tabTests:
        return _buildServicesSlivers(context);
      case _tabPackages:
        return _buildPackagesSlivers(context);
      case _tabReviews:
        return _buildReviewsSlivers(context);
      case _tabAbout:
      default:
        return _buildAboutSlivers(context);
    }
  }

  Widget _skeletonRows() => Padding(
        padding: const EdgeInsets.fromLTRB(RastTokens.gutter, 8, RastTokens.gutter, 0),
        child: Column(
          children: List.generate(
            4,
            (_) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: RastCard(
                child: Row(
                  children: [
                    const RastSkeleton(width: 72, height: 72, radius: 16),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          RastSkeleton(width: 160, height: 13),
                          SizedBox(height: 8),
                          RastSkeleton(width: 90, height: 11),
                        ],
                      ),
                    ),
                    const RastSkeleton(width: 56, height: 30, radius: 10),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

  Widget _loadMoreIndicator() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.4)),
        ),
      );

  Widget _activeFiltersLine(int count) {
    final lang = _lang;
    return Padding(
      padding: const EdgeInsets.fromLTRB(RastTokens.gutter, 6, RastTokens.gutter, 10),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            L(lang, '$count نتيجة', '$count results'),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: RastTokens.muted(context)),
          ),
          if (_servicesHomeOnly)
            RastPill(dense: true, icon: Icons.home_rounded, color: RastTokens.success, label: AppStrings.t('homeService', lang)),
          if (_servicesMinPrice != null || _servicesMaxPrice != null)
            RastPill(
              dense: true,
              icon: Icons.payments_outlined,
              label: '${_servicesMinPrice?.toStringAsFixed(0) ?? '0'} - ${_servicesMaxPrice?.toStringAsFixed(0) ?? '∞'} ${AppStrings.t('sar', lang)}',
            ),
        ],
      ),
    );
  }

  // ---------- تبويب العروض ----------

  List<Widget> _buildOffersSlivers(BuildContext context) {
    final lang = _lang;
    if (_labOffers.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: RastEmptyState(
            icon: Icons.local_offer_outlined,
            title: L(lang, 'لا توجد عروض حالياً', 'No deals right now'),
            actionLabel: L(lang, 'تصفّح التحاليل', 'Browse tests'),
            onAction: () => _tabController.animateTo(_tabTests),
          ),
        ),
      ];
    }
    return [
      const SliverToBoxAdapter(child: SizedBox(height: 12)),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: RastTokens.gutter),
        sliver: SliverList.separated(
          itemCount: _labOffers.length,
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemBuilder: (context, i) => OfferCard(
            offer: _labOffers[i],
            lang: lang,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => OfferDetailScreen(offer: _labOffers[i])),
            ),
          ).entrance(i),
        ),
      ),
      if (_labOffers.length >= 20)
        SliverToBoxAdapter(
          child: Center(
            child: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => OffersScreen(providerId: _labId, title: L(lang, 'عروض $_labName', '$_labName deals')),
                ),
              ),
              child: Text(L(lang, 'عرض كل العروض', 'See all deals')),
            ),
          ),
        ),
    ];
  }

  // ---------- تبويب التحاليل ----------

  List<Widget> _buildServicesSlivers(BuildContext context) {
    final lang = _lang;
    final all = _visibleLabServices();
    if (_services.isEmpty && _loadingMoreServices) {
      return [SliverToBoxAdapter(child: _skeletonRows())];
    }
    if (_services.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: RastEmptyState(
            icon: Icons.science_outlined,
            title: AppStrings.t('noAnalyses', lang),
            message: _servicesSearchController.text.trim().isNotEmpty
                ? L(lang, 'لا نتائج لهذا البحث في هذا المختبر.', 'No results for this search in this lab.')
                : null,
          ),
        ),
      ];
    }
    if (all.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: RastEmptyState(
            icon: Icons.filter_alt_off_rounded,
            title: AppStrings.t('noFilterResults', lang),
            actionLabel: AppStrings.t('clear', lang),
            onAction: () {
              setState(() {
                _servicesSort = 'default';
                _servicesHomeOnly = false;
                _servicesMinPrice = null;
                _servicesMaxPrice = null;
              });
              unawaited(_loadServicesInternal(reset: true));
            },
          ),
        ),
      ];
    }
    return [
      SliverToBoxAdapter(child: _activeFiltersLine(all.length)),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: RastTokens.gutter),
        sliver: SliverList.separated(
          itemCount: all.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) => _buildServiceRow(context, all[i]).entrance(i % 8),
        ),
      ),
      if (_loadingMoreServices && _hasMoreServices) SliverToBoxAdapter(child: _loadMoreIndicator()),
    ];
  }

  Widget _buildServiceRow(BuildContext context, dynamic s) {
    final lang = _lang;
    final serviceMap = _serviceMapFromProviderService(s);
    final svc = s is Map ? Map<String, dynamic>.from(s) : <String, dynamic>{};
    final name = _serviceDisplayName(s);
    final price = _servicePrice(s);
    final oldPrice = numOf(svc['price']);
    final hasDiscount = oldPrice != null && oldPrice > price + 0.01 && price > 0;
    final homePrice = numOf(svc['home_service_price'] ?? svc['home_price']);
    final imageUrl = ApiConfig.analysisImageUrl(serviceMap, svc);
    final days = (numOf(svc['duration'] ?? serviceMap['default_duration']) ?? 0).toInt();
    final prep = serviceMap['requires_preparation'] == true;

    return RastCard(
      key: ValueKey('lab-svc-${svc['id']}'),
      onTap: () => _openServiceDetail(s),
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          Stack(
            children: [
              RastNetImage(url: imageUrl, width: 76, height: 76, radius: 16),
              if (hasDiscount)
                PositionedDirectional(
                  top: 4,
                  start: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: RastTokens.danger, borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      '-${((1 - price / oldPrice) * 100).round()}%',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, height: 1.35, color: RastTokens.ink(context)),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (days > 0)
                      RastPill(
                        dense: true,
                        icon: Icons.schedule_rounded,
                        color: RastTokens.info,
                        label: L(lang, days == 1 ? 'النتيجة خلال يوم' : 'النتيجة خلال $days أيام',
                            days == 1 ? 'Result in 1 day' : 'Result in $days days'),
                      ),
                    if (prep)
                      RastPill(dense: true, icon: Icons.no_food_outlined, color: RastTokens.warning, label: L(lang, 'يحتاج صيام', 'Fasting')),
                    if (homePrice != null && homePrice > 0)
                      RastPill(
                        dense: true,
                        icon: Icons.home_rounded,
                        color: RastTokens.success,
                        label: L(lang, 'منزلي ${fmtPrice(homePrice)}', 'Home ${fmtPrice(homePrice)}'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: RastPrice(
                        amount: price > 0 ? price : null,
                        oldAmount: hasDiscount ? oldPrice : null,
                        lang: lang,
                        size: 16.5,
                      ),
                    ),
                    if (price > 0)
                      Material(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.transparent,
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: RastTokens.brandGradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _openBookFlow(s),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Text(
                                L(lang, 'احجز', 'Book'),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- تبويب الباقات: بطاقات بصورة عريضة ----------

  List<Widget> _buildPackagesSlivers(BuildContext context) {
    final lang = _lang;
    final all = _visibleLabPackages();
    if (_packages.isEmpty && _loadingMorePackages) {
      return [SliverToBoxAdapter(child: _skeletonRows())];
    }
    if (_packages.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: RastEmptyState(icon: Icons.inventory_2_outlined, title: AppStrings.t('noPackages', lang)),
        ),
      ];
    }
    if (all.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: RastEmptyState(icon: Icons.search_off_rounded, title: AppStrings.t('noSearchResults', lang)),
        ),
      ];
    }
    return [
      SliverToBoxAdapter(child: _activeFiltersLine(all.length)),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: RastTokens.gutter),
        sliver: SliverList.separated(
          itemCount: all.length,
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemBuilder: (context, i) => _buildPackageCard(context, all[i]).entrance(i % 8),
        ),
      ),
    ];
  }

  Widget _buildPackageCard(BuildContext context, dynamic item) {
    final lang = _lang;
    final pkg = item is Map ? Map<String, dynamic>.from(item) : <String, dynamic>{};
    final displayName = LocaleUtils.localizedName(pkg, context.watch<AppSettingsProvider>().isArabic);
    final price = ApiConfig.priceFromMap(pkg);
    final testsCount = (numOf(pkg['tests_count']) ??
            (pkg['package_items'] is List ? (pkg['package_items'] as List).length : 0))
        .toInt();
    final imageUrl = ApiConfig.packageImageUrl(pkg);

    return RastCard(
      key: ValueKey('lab-pkg-${pkg['id']}'),
      padding: EdgeInsets.zero,
      clip: true,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => PackageDetailScreen(package: pkg)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 16 / 8,
            child: Stack(
              fit: StackFit.expand,
              children: [
                RastNetImage(url: imageUrl, radius: 0, fallbackIcon: Icons.inventory_2_rounded),
                if (testsCount > 0)
                  PositionedDirectional(
                    top: 10,
                    start: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.checklist_rounded, size: 14, color: RastTokens.brand),
                          const SizedBox(width: 4),
                          Text(
                            testsCountLabel(lang, testsCount),
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: RastTokens.brand),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, height: 1.35, color: RastTokens.ink(context)),
                      ),
                      const SizedBox(height: 6),
                      price > 0
                          ? RastPrice(amount: price, lang: lang, size: 17)
                          : Text(
                              AppStrings.t('callForPrice', lang),
                              style: TextStyle(fontSize: 12, color: RastTokens.muted(context), fontWeight: FontWeight.w600),
                            ),
                    ],
                  ),
                ),
                Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(shape: BoxShape.circle, gradient: RastTokens.brandGradient),
                  child: Icon(
                    context.watch<AppSettingsProvider>().isArabic ? Icons.arrow_back_rounded : Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- تبويب التقييمات: ملخص بتوزيع النجوم ثم التقييمات ----------

  List<Widget> _buildReviewsSlivers(BuildContext context) {
    final lang = _lang;
    final rating = numOf(_labMap['avg_rating']) ?? 0;
    final total = (numOf(_labMap['total_reviews']) ?? _reviews.length).toInt();

    // توزيع النجوم من التقييمات المحمّلة (نسب تقريبية حين لا تُحمّل كلها)
    final counts = List<int>.filled(6, 0);
    for (final r in _reviews) {
      final v = (numOf(r is Map ? r['rating'] : null) ?? 0).round().clamp(0, 5);
      if (v > 0) counts[v]++;
    }
    final loaded = counts.fold<int>(0, (a, b) => a + b);

    final summary = Padding(
      padding: const EdgeInsets.fromLTRB(RastTokens.gutter, 12, RastTokens.gutter, 14),
      child: RastCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Column(
              children: [
                Text(
                  rating > 0 ? rating.toStringAsFixed(1) : '—',
                  style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: RastTokens.ink(context), height: 1.05),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                    5,
                    (i) => Icon(
                      i < rating.round() ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: RastTokens.gold,
                      size: 17,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  total > 0 ? L(lang, '$total تقييم', '$total reviews') : L(lang, 'لا تقييمات', 'No reviews'),
                  style: TextStyle(fontSize: 12, color: RastTokens.muted(context), fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(width: 18),
            Container(width: 1, height: 96, color: RastTokens.line(context)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                children: [
                  for (var star = 5; star >= 1; star--)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.5),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 14,
                            child: Text('$star', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: RastTokens.ink(context))),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: TweenAnimationBuilder<double>(
                                tween: Tween(end: loaded > 0 ? counts[star] / loaded : 0),
                                duration: const Duration(milliseconds: 700),
                                curve: Curves.easeOutCubic,
                                builder: (_, v, __) => LinearProgressIndicator(
                                  value: v,
                                  minHeight: 7,
                                  color: star >= 4 ? RastTokens.brand : (star == 3 ? RastTokens.gold : RastTokens.danger),
                                  backgroundColor: RastTokens.fill(context),
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
          ],
        ),
      ),
    );

    if (_reviews.isEmpty && _loadingMoreReviews) {
      return [SliverToBoxAdapter(child: summary), SliverToBoxAdapter(child: _skeletonRows())];
    }
    if (_reviews.isEmpty) {
      return [
        SliverToBoxAdapter(child: summary),
        SliverToBoxAdapter(
          child: RastEmptyState(
            icon: Icons.rate_review_outlined,
            title: AppStrings.t('noReviewsYet', lang),
            message: L(lang, 'كن أول من يقيّم بعد زيارتك.', 'Be the first to review after your visit.'),
          ),
        ),
      ];
    }
    return [
      SliverToBoxAdapter(child: summary),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: RastTokens.gutter),
        sliver: SliverList.separated(
          itemCount: _reviews.length,
          separatorBuilder: (_, __) => Divider(height: 26, color: RastTokens.line(context)),
          itemBuilder: (context, i) => _buildReviewItem(_reviews[i]).entrance(i % 8),
        ),
      ),
      if (_hasMoreReviews)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Center(
              child: TextButton.icon(
                onPressed: _loadingMoreReviews ? null : () => _loadReviewsInternal(reset: false),
                icon: const Icon(Icons.expand_more_rounded),
                label: Text(
                  _loadingMoreReviews ? AppStrings.t('loading', lang) : AppStrings.t('loadMoreReviews', lang),
                ),
              ),
            ),
          ),
        ),
    ];
  }

  Widget _buildReviewItem(dynamic r) {
    final review = r is Map ? Map<String, dynamic>.from(r) : <String, dynamic>{};
    final lang = _lang;
    final userName = (review['user_name'] ?? (review['user'] is Map ? review['user']['name'] : null) ?? AppStrings.t('user', lang))
        .toString();
    final rating = (numOf(review['rating']) ?? 0).toDouble();
    final comment = review['comment']?.toString() ?? '';
    final date = (review['date'] ?? review['created_at'] ?? '').toString();
    final dateStr = date.length > 10 ? date.substring(0, 10) : date;
    final reply = review['provider_reply']?.toString().trim() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(shape: BoxShape.circle, color: RastTokens.brandSoft(context)),
              alignment: Alignment.center,
              child: Text(
                userName.isNotEmpty ? userName.characters.first.toUpperCase() : '؟',
                style: const TextStyle(color: RastTokens.brand, fontWeight: FontWeight.w900, fontSize: 16),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: RastTokens.ink(context)),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: List.generate(
                      5,
                      (i) => Icon(
                        i < rating.round() ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: RastTokens.gold,
                        size: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Text(dateStr, style: TextStyle(fontSize: 11, color: RastTokens.muted(context))),
          ],
        ),
        if (comment.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            '«$comment»',
            style: TextStyle(fontSize: 13.5, height: 1.7, color: RastTokens.ink(context)),
          ),
        ],
        // ردّ المختبر على التقييم
        if (reply.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            margin: const EdgeInsetsDirectional.only(start: 18),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: RastTokens.brandSoft(context),
              borderRadius: BorderRadius.circular(14),
              border: BorderDirectional(start: BorderSide(color: RastTokens.brand.withValues(alpha: 0.6), width: 3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.reply_rounded, size: 16, color: RastTokens.brand),
                    const SizedBox(width: 4),
                    Text(
                      L(lang, 'ردّ المختبر', 'Lab reply'),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: RastTokens.brand),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(reply, style: TextStyle(fontSize: 13, height: 1.6, color: RastTokens.ink(context))),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ---------- تبويب «عن المختبر» ----------

  List<Widget> _buildAboutSlivers(BuildContext context) {
    final lang = _lang;
    final isArabic = context.read<AppSettingsProvider>().isArabic;
    final lab = _labMap;
    final description = (isArabic ? lab['description_ar'] : lab['description_en'])?.toString().trim() ??
        lab['description_ar']?.toString().trim() ??
        '';
    final home = lab['home_service_available'] == true;
    final homeFee = numOf(lab['home_service_fee']);
    final mode = lab['service_mode']?.toString();
    final week = labWeeklyHours(lab);
    final hoursText = lab['working_hours'] is String ? (lab['working_hours'] as String).trim() : '';
    final gallery = (lab['gallery'] is List ? lab['gallery'] as List : const [])
        .map((e) => e?.toString() ?? '')
        .where((e) => e.isNotEmpty)
        .toList();
    final place = _mainPlace;
    final branches = _branches.whereType<Map>().toList();

    Widget section(String title, Widget child) => Padding(
          padding: const EdgeInsets.fromLTRB(RastTokens.gutter, 16, RastTokens.gutter, 0),
          child: RastCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w900, color: RastTokens.ink(context))),
                const SizedBox(height: 12),
                child,
              ],
            ),
          ),
        );

    final services = <(IconData, String, Color)>[
      if (mode != 'home')
        (Icons.storefront_rounded, L(lang, 'زيارة المختبر', 'Lab visit'), RastTokens.brand),
      if (home)
        (
          Icons.home_rounded,
          homeFee != null && homeFee > 0
              ? L(lang, 'سحب منزلي · ${fmtPrice(homeFee)} ر.س', 'Home visit · ${fmtPrice(homeFee)} SAR')
              : L(lang, 'سحب منزلي', 'Home visit'),
          RastTokens.success,
        ),
    ];

    const dayNamesAr = ['الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];
    const dayNamesEn = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    final today = DateTime.now().weekday % 7;

    return [
      if (description.isNotEmpty)
        SliverToBoxAdapter(
          child: section(
            L(lang, 'عن المختبر', 'About the lab'),
            Text(description, style: TextStyle(fontSize: 13.5, height: 1.8, color: RastTokens.muted(context))),
          ),
        ),
      SliverToBoxAdapter(
        child: section(
          L(lang, 'الخدمات', 'Services'),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final s in services)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(color: s.$3.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(s.$1, size: 18, color: s.$3),
                      const SizedBox(width: 6),
                      Text(s.$2, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: RastTokens.ink(context))),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      if (place != null)
        SliverToBoxAdapter(
          child: section(
            L(lang, 'موقع المختبر', 'Location'),
            _mapPreview(context, place, lang),
          ),
        ),
      if (week != null || hoursText.isNotEmpty)
        SliverToBoxAdapter(
          child: section(
            L(lang, 'مواعيد العمل', 'Working hours'),
            week == null
                ? Text(hoursText, style: TextStyle(fontSize: 13.5, color: RastTokens.ink(context)))
                : Column(
                    children: [
                      for (var d = 0; d < 7; d++)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                          decoration: BoxDecoration(
                            color: d == today ? RastTokens.brandSoft(context) : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Text(
                                lang == 'en' ? dayNamesEn[d] : dayNamesAr[d],
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: d == today ? FontWeight.w900 : FontWeight.w600,
                                  color: d == today ? RastTokens.brand : RastTokens.ink(context),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                week[d] == null
                                    ? L(lang, 'مغلق', 'Closed')
                                    : '${labClock(week[d]!['open'], lang)} - ${labClock(week[d]!['close'], lang)}',
                                textDirection: TextDirection.ltr,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: week[d] == null ? RastTokens.danger : RastTokens.ink(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      if (branches.isNotEmpty)
        SliverToBoxAdapter(
          child: section(
            branches.length > 1 ? L(lang, 'الفروع (${branches.length})', 'Branches (${branches.length})') : L(lang, 'الفرع', 'Branch'),
            Column(
              children: [
                for (var i = 0; i < branches.length; i++) ...[
                  if (i > 0) Divider(height: 18, color: RastTokens.line(context)),
                  _branchRow(context, branches[i], i, lang, isArabic),
                ],
              ],
            ),
          ),
        ),
      if (gallery.isNotEmpty)
        SliverToBoxAdapter(
          child: section(
            L(lang, 'صور المختبر', 'Photos'),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: gallery.length,
              itemBuilder: (context, i) => Pressable(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ZoomableImageViewer(imageUrl: gallery[i], imageUrls: gallery)),
                ),
                child: RastNetImage(url: gallery[i], radius: 14),
              ),
            ),
          ),
        ),
    ];
  }

  Widget _mapPreview(BuildContext context, Map<dynamic, dynamic> place, String lang) {
    final ll = _latLngOf(place)!;
    final pos = LatLng(ll.$1, ll.$2);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 170,
        child: Stack(
          children: [
            // خريطة ثابتة (بلا لمس) حتى لا تتعارض مع تمرير الصفحة
            IgnorePointer(
              child: GoogleMap(
                initialCameraPosition: CameraPosition(target: pos, zoom: 15),
                liteModeEnabled: true,
                zoomControlsEnabled: false,
                myLocationButtonEnabled: false,
                mapToolbarEnabled: false,
                scrollGesturesEnabled: false,
                zoomGesturesEnabled: false,
                rotateGesturesEnabled: false,
                tiltGesturesEnabled: false,
                markers: {Marker(markerId: const MarkerId('lab'), position: pos)},
              ),
            ),
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(onTap: () => _openDirections(place)),
              ),
            ),
            PositionedDirectional(
              bottom: 10,
              end: 10,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 10, offset: const Offset(0, 3))],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.directions_rounded, size: 16, color: RastTokens.brand),
                      const SizedBox(width: 5),
                      Text(
                        L(lang, 'فتح الخريطة', 'Open in Maps'),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: RastTokens.brand),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _branchRow(BuildContext context, Map b, int i, String lang, bool isArabic) {
    final bName = LocaleUtils.localizedName(Map<String, dynamic>.from(b), isArabic);
    final loc = [b['district'], b['city']]
        .where((e) => e != null && e.toString().trim().isNotEmpty)
        .join('، ');
    final hasMap = _latLngOf(b) != null;
    final u = _userLoc;
    double? km;
    if (u != null && hasMap) {
      final ll = _latLngOf(b)!;
      km = LabLocationUtils.haversineKm(u.$1, u.$2, ll.$1, ll.$2);
    }
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: hasMap ? () => _openDirections(b) : null,
      child: Row(
        children: [
          const RastIconBox(icon: Icons.location_on_rounded, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bName.isEmpty ? L(lang, 'الفرع ${i + 1}', 'Branch ${i + 1}') : bName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: RastTokens.ink(context)),
                ),
                if (loc.isNotEmpty || km != null)
                  Text(
                    [if (loc.isNotEmpty) loc, if (km != null) labDistanceLabel(km, lang)].join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, height: 1.4, color: RastTokens.muted(context)),
                  ),
              ],
            ),
          ),
          if (hasMap) const Icon(Icons.directions_rounded, color: RastTokens.brand2, size: 22),
        ],
      ),
    );
  }

  // ---------- التحميل والخطأ ----------

  Widget _buildLoading() => CustomScrollView(
        physics: const NeverScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Stack(
              children: [
                const SizedBox(height: _heroMax, width: double.infinity, child: RastSkeleton(height: _heroMax, radius: 0)),
                Positioned(
                  top: MediaQuery.paddingOf(context).top + 10,
                  left: 12,
                  child: GlassCircleButton(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.close_rounded, color: RastTokens.ink(context), size: 20),
                  ),
                ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(RastTokens.gutter, 16, RastTokens.gutter, 8),
              child: RastCard(
                child: Row(
                  children: const [
                    RastSkeleton(width: 70, height: 70, radius: 18),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RastSkeleton(width: 170, height: 16),
                          SizedBox(height: 10),
                          RastSkeleton(width: 110, height: 12),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(child: _skeletonRows()),
        ],
      );

  Widget _buildError() {
    final lang = _lang;
    return SafeArea(
      child: Column(
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(
                context.read<AppSettingsProvider>().isArabic
                    ? Icons.arrow_forward_ios_rounded
                    : Icons.arrow_back_ios_new_rounded,
                textDirection: TextDirection.ltr,
                color: RastTokens.ink(context),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: RastEmptyState(
                icon: Icons.cloud_off_rounded,
                color: RastTokens.danger,
                title: L(lang, 'تعذّر تحميل المختبر', 'Could not load the lab'),
                message: _error,
                actionLabel: AppStrings.t('retry', lang),
                onAction: _loadData,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- فلترة تحاليل المختبر ----------

  void _showServicesFilterSheet() {
    final settings = context.read<AppSettingsProvider>();
    final lang = settings.language;
    final minController = TextEditingController(text: _servicesMinPrice?.toStringAsFixed(0) ?? '');
    final maxController = TextEditingController(text: _servicesMaxPrice?.toStringAsFixed(0) ?? '');
    var sort = _servicesSort;
    var homeOnly = _servicesHomeOnly;

    InputDecoration priceDecoration(String label) => InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.payments_outlined, color: RastTokens.brand),
          filled: true,
          fillColor: RastTokens.fill(context),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: RastTokens.line(context)),
          ),
        );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Directionality(
          textDirection: settings.textDirection,
          child: Container(
            padding: EdgeInsets.fromLTRB(
              20,
              10,
              20,
              20 + MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(context).padding.bottom,
            ),
            decoration: BoxDecoration(
              color: RastTokens.card(context),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
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
                        decoration: BoxDecoration(color: RastTokens.line(context), borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const RastIconBox(icon: Icons.tune_rounded, size: 40),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            AppStrings.t('filterLabAnalyses', lang),
                            style: TextStyle(color: RastTokens.ink(context), fontSize: 18, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _sheetLabel(AppStrings.t('sort', lang)),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final entry in [
                          ('default', AppStrings.t('defaultSort', lang)),
                          ('price_low', AppStrings.t('priceLow', lang)),
                          ('price_high', AppStrings.t('priceHigh', lang)),
                          ('name', AppStrings.t('nameSort', lang)),
                        ])
                          _sheetChoice(entry.$2, entry.$1, sort, (v) => setSheetState(() => sort = v)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(color: RastTokens.fill(context), borderRadius: BorderRadius.circular(14)),
                      child: SwitchListTile(
                        value: homeOnly,
                        onChanged: (v) => setSheetState(() => homeOnly = v),
                        secondary: const Icon(Icons.home_rounded, color: RastTokens.success),
                        title: Text(
                          AppStrings.t('homeAnalysesOnly', lang),
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: RastTokens.ink(context)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                        activeThumbColor: RastTokens.brand,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _sheetLabel(L(lang, 'نطاق السعر', 'Price range')),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: minController,
                            keyboardType: TextInputType.number,
                            decoration: priceDecoration(AppStrings.t('minPrice', lang)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: maxController,
                            keyboardType: TextInputType.number,
                            decoration: priceDecoration(AppStrings.t('maxPrice', lang)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: RastButton(
                            secondary: true,
                            label: AppStrings.t('clear', lang),
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
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: RastButton(
                            icon: Icons.check_rounded,
                            label: AppStrings.t('apply', lang),
                            onPressed: () {
                              setState(() {
                                _servicesSort = sort;
                                _servicesHomeOnly = homeOnly;
                                _servicesMinPrice = double.tryParse(minController.text.trim());
                                _servicesMaxPrice = double.tryParse(maxController.text.trim());
                              });
                              Navigator.pop(ctx);
                              unawaited(_loadServicesInternal(reset: true));
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sheetLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: TextStyle(color: RastTokens.muted(context), fontSize: 12.5, fontWeight: FontWeight.w800),
        ),
      );

  Widget _sheetChoice(String label, String value, String selected, ValueChanged<String> onSelected) {
    final on = selected == value;
    return GestureDetector(
      onTap: () => onSelected(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          gradient: on ? RastTokens.brandGradient : null,
          color: on ? null : RastTokens.fill(context),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: on ? Colors.transparent : RastTokens.line(context)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: on ? Colors.white : RastTokens.ink(context),
            fontWeight: on ? FontWeight.w800 : FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}


/// رأس التبويبات الثابت أثناء التمرير.
class _TabsHeaderDelegate extends SliverPersistentHeaderDelegate {
  _TabsHeaderDelegate({required this.extent, required this.child});

  final double extent;
  final Widget child;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Material(
      color: Colors.transparent,
      elevation: overlapsContent ? 1.5 : 0,
      shadowColor: Colors.black.withValues(alpha: 0.10),
      child: SizedBox.expand(child: child),
    );
  }

  @override
  bool shouldRebuild(covariant _TabsHeaderDelegate oldDelegate) => true;
}
