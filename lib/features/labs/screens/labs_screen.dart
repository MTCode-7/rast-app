import 'dart:math' as math;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rast/core/widgets/rast_motion.dart';
import 'package:rast/core/widgets/rast_kit.dart';
import 'package:rast/core/services/analytics_service.dart';
import 'package:rast/core/providers/app_settings_provider.dart';
import 'package:rast/core/utils/locale_utils.dart';
import 'package:provider/provider.dart';
import 'package:rast/core/services/location_service.dart';
import 'package:rast/core/services/favorites_service.dart';
import 'package:rast/core/services/branches_index_service.dart';
import 'package:rast/core/services/catalog_cache_service.dart';
import 'package:rast/core/utils/lab_location_utils.dart';
import 'package:rast/core/api/api_services.dart';
import 'package:rast/core/api/api_client.dart';
import 'package:rast/core/onboarding/onboarding_catalog.dart';
import 'package:rast/core/onboarding/onboarding_host.dart';
import 'package:rast/core/onboarding/onboarding_step.dart';
import 'package:rast/core/onboarding/onboarding_tour_ids.dart';
import 'package:rast/core/widgets/rast_ui.dart';
import 'package:rast/app/main_tab_index_scope.dart';
import 'package:rast/app/main_shell.dart';
import 'package:rast/core/models/region.dart';
import 'package:rast/features/lab_details/screens/lab_details_screen.dart';
import 'package:rast/features/settings/screens/default_location_screen.dart';
import 'package:rast/features/map/widgets/map_entry_button.dart';
import 'package:rast/features/labs/widgets/lab_visuals.dart';
import 'package:rast/features/analyses/widgets/test_row_card.dart' show ViewModeStore, ViewModeToggle;
import 'package:rast/core/services/app_events.dart';

import '../../../core/constants/app_strings.dart';

class LabsScreen extends StatefulWidget {
  final bool showBackButton;
  final String? initialSearchQuery;
  const LabsScreen({
    super.key,
    this.showBackButton = false, this.initialSearchQuery,
  });
  @override
  State<LabsScreen> createState() => _LabsScreenState();
}

class _LabsScreenState extends State<LabsScreen> with OnboardingTourHost {
  static const int _pageSize = 20;
  final _searchKey = GlobalKey();
  final _filterKey = GlobalKey();
  final _sortKey = GlobalKey();
  bool _labsTourScheduled = false;
  String _sortBy = 'all';
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  /// منطقة من شيت الفلترة (`region_id` في الـ API).
  int? _selectedRegionId;
  List<Region> _regions = [];
  bool _regionsLoading = false;
  List<dynamic> _labs = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  int? _totalAvailable;
  String? _error;
  double? _userLat;
  double? _userLng;
  bool _filterHomeOnly = false;

  /// Local rebuild scoping: when set, labs-data changes rebuild only these
  /// nested StatefulBuilders instead of the whole LabsScreen.
  StateSetter? _resultCountSetState;
  StateSetter? _labsListSetState;

  /// GPS أو مركز المنطقة المختارة لحساب أقرب فرع.
  (double?, double?) get _referenceLocation {
    if (_userLat != null && _userLng != null) {
      return (_userLat, _userLng);
    }
    if (_selectedRegionId != null) {
      for (final r in _regions) {
        if (r.id == _selectedRegionId) {
          return (r.latitude, r.longitude);
        }
      }
    }
    return (null, null);
  }

  @override
  String? get onboardingTourId => OnboardingTourIds.labs;

  @override
  List<OnboardingStep> buildOnboardingSteps() => OnboardingCatalog.labsTour(
    searchKey: _searchKey,
    filterKey: _filterKey,
    sortKey: _sortKey,
  );

  /// قائمة افتراضياً للمختبرات، ويمكن للمستخدم التبديل للشبكة (يُحفظ اختياره)
  bool _grid = false;

  void _setGrid(bool g) {
    setState(() => _grid = g);
    ViewModeStore.setGrid('labs', g);
  }

  @override
  void initState() {
    super.initState();

    ViewModeStore.isGrid('labs', defaultGrid: false).then((g) {
      if (mounted && g != _grid) setState(() => _grid = g);
    });
    _searchController.text = widget.initialSearchQuery ?? '';

    _scrollController.addListener(_onScroll);
    AppEvents.locationChanged.addListener(_onLocationChanged);
    _ensureRegionsLoaded();
    BranchesIndexService.instance.ensureLoaded();
    _loadFromCacheThenNetwork();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (_searchController.text.trim().isNotEmpty) {
        setState(() {});
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      if (MainTabIndexScope.of(context).currentIndex == MainScaffold.labsTabIndex) {
        _maybeScheduleLabsTour();
      }
    } catch (_) {}
  }

  void _maybeScheduleLabsTour() {
    if (_labsTourScheduled) return;
    _labsTourScheduled = true;
    scheduleOnboardingTour(delay: const Duration(milliseconds: 600));
  }

  bool get _canUseLabsCache =>
      _selectedRegionId == null &&
          _sortBy == 'all' &&
          !_filterHomeOnly &&
          _searchController.text.trim().isEmpty;

  Future<void> _loadFromCacheThenNetwork() async {
    await CatalogCacheService.ensureHydrated();
    final hasCache = _canUseLabsCache && CatalogCacheService.labsPage1.isNotEmpty;
    if (hasCache && mounted) {
      _setLabsState(() {
        _labs = List.from(CatalogCacheService.labsPage1);
        _totalAvailable ??= _labs.length;
        _isLoading = false;
        _currentPage = 2;
        _hasMore = true;
      });
    }
    await _loadUserLocation();
    await _loadData(reset: true, silent: hasCache);
  }

  Future<void> _loadUserLocation() async {
    double? lat;
    double? lng;
    // الموقع الذي اختاره المستخدم (مدينة/عنوان من محدد الموقع) أولاً، ثم GPS عند عدم وجوده
    final saved = await LocationService.getDefaultLocation();
    if (saved != null) {
      lat = saved.lat;
      lng = saved.lng;
    }
    if (lat == null || lng == null) {
      try {
        final current = await LocationService.getCurrentLocation();
        if (current != null) {
          lat = current.lat;
          lng = current.lng;
        }
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _userLat = lat;
        _userLng = lng;
      });
    }
  }

  List<dynamic> _extractList(dynamic resData) {
    if (resData is List) return List.from(resData);
    if (resData is Map) {
      if (resData['data'] is List) return List.from(resData['data'] as List);
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

  Future<void> _loadData({bool reset = false, bool silent = false}) async {
    if (_isLoadingMore) return;
    if (!reset && !_hasMore) return;

    if (reset) {
      _setLabsState(() {
        if (!silent || _labs.isEmpty) _isLoading = true;
        _error = null;
        _currentPage = 1;
        _hasMore = true;
      });
    } else {
      _setLabsState(() {
        _isLoadingMore = true;
        _error = null;
      });
    }
    try {
      String? sort;
      bool? homeService;
      double? lat;
      double? lng;
      int? radiusKm;

      switch (_sortBy) {
        case 'nearby':
          lat = _userLat;
          lng = _userLng;
          break;
        case 'home_service':
          homeService = true;
          break;
        case 'featured':
          sort = 'featured';
          break;
        default:
          break;
      }

      final regionId = _selectedRegionId;
      final nearbyRequested = regionId == null &&
          _sortBy == 'nearby' &&
          lat != null &&
          lng != null;

      final res = await Api.providers.getProviders(
        regionId: regionId,
        sort: sort,
        homeService: homeService,
        page: _currentPage,
        perPage: _pageSize,
        latitude: regionId == null ? lat : null,
        longitude: regionId == null ? lng : null,
        radiusKm: regionId == null ? radiusKm : null,
      );
      var list = _extractList(res['data']);
      list = _filterActiveLabs(list);
      if (reset && nearbyRequested && list.isEmpty) {
        final fallbackRes = await Api.providers.getProviders(
          page: 1,
          perPage: _pageSize,
        );
        list = _filterActiveLabs(_extractList(fallbackRes['data']));
      }
      if (nearbyRequested && reset) {
        _sortLabsByDistance(list, lat, lng);
      }
      final nextLabs = list;
      final hasMoreFromMeta = _hasNextPage(res['data']);
      final hasMoreFromSize = list.length >= _pageSize;
      final canLoadMore = hasMoreFromMeta ?? hasMoreFromSize;
      final totalFromApi = _parseInt(
        (res['data'] is Map) ? (res['data'] as Map)['total'] : null,
      );
      if (reset && _canUseLabsCache && nextLabs.isNotEmpty) {
        unawaited(CatalogCacheService.saveLabsPage1(nextLabs));
      }
      _setLabsState(() {
        if (reset) {
          _labs = nextLabs;
        } else {
          _labs.addAll(list);
        }
        _totalAvailable = totalFromApi ?? _totalAvailable ?? _labs.length;
        _hasMore = canLoadMore;
        _currentPage += 1;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } on ApiException catch (e) {
      _setLabsState(() {
        _error = e.message;
        if (reset) _labs = [];
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      _setLabsState(() {
        if (reset) _labs = [];
        _error = null;
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  bool? _hasNextPage(dynamic data) {
    if (data is Map) {
      final currentPage = _parseInt(data['current_page']);
      final lastPage = _parseInt(data['last_page']);
      if (currentPage != null && lastPage != null) {
        return currentPage < lastPage;
      }
      final nextUrl = data['next_page_url'];
      if (nextUrl != null && nextUrl.toString().trim().isNotEmpty) {
        return true;
      }
      return false;
    }
    return null;
  }

  int? _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _isLoading || _isLoadingMore) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 300) {
      _loadData();
    }
  }

  void _sortLabsByDistance(List<dynamic> labs, double userLat, double userLng) {
    labs.sort((a, b) {
      final aMap = a is Map ? a : const {};
      final bMap = b is Map ? b : const {};
      final aDistance = _distanceFromLab(aMap, userLat, userLng);
      final bDistance = _distanceFromLab(bMap, userLat, userLng);
      return aDistance.compareTo(bDistance);
    });
  }

  double _distanceFromLab(
      Map<dynamic, dynamic> lab,
      double userLat,
      double userLng,
      ) {
    final labMap = Map<String, dynamic>.from(lab);
    final branches = BranchesIndexService.instance.branchesFor(labMap) ??
        (labMap['branches'] is List ? labMap['branches'] as List<dynamic> : null);
    final km = LabLocationUtils.distanceKmToNearest(
      lab: labMap,
      userLat: userLat,
      userLng: userLng,
      branches: branches,
    );
    if (km != null) return km;
    final coords = _extractCoordinates(lab);
    if (coords == null) return double.infinity;
    return _haversineKm(userLat, userLng, coords.$1, coords.$2);
  }

  (double, double)? _extractCoordinates(Map<dynamic, dynamic> lab) {
    final direct = _readLatLng(lab);
    if (direct != null) return direct;

    for (final key in ['branch', 'default_branch', 'main_branch', 'location']) {
      final nested = lab[key];
      if (nested is Map) {
        final coords = _readLatLng(nested);
        if (coords != null) return coords;
      }
    }

    final branches = lab['branches'];
    if (branches is List) {
      for (final branch in branches) {
        if (branch is Map) {
          final coords = _readLatLng(branch);
          if (coords != null) return coords;
        }
      }
    }
    return null;
  }

  (double, double)? _readLatLng(Map<dynamic, dynamic> map) {
    final lat = _firstDouble(map, const [
      'latitude',
      'lat',
      'location_lat',
      'branch_latitude',
    ]);
    final lng = _firstDouble(map, const [
      'longitude',
      'lng',
      'lon',
      'location_lng',
      'branch_longitude',
    ]);
    if (lat == null || lng == null) return null;
    return (lat, lng);
  }

  double? _firstDouble(Map<dynamic, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is num) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
    const earthRadiusKm = 6371.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLng = _degToRad(lng2 - lng1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
            math.cos(_degToRad(lat1)) *
                math.cos(_degToRad(lat2)) *
                math.sin(dLng / 2) *
                math.sin(dLng / 2);
    return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _degToRad(double degree) => degree * math.pi / 180;

  Future<void> _ensureRegionsLoaded() async {
    if (_regions.isNotEmpty) return;
    if (_regionsLoading) {
      while (_regionsLoading && mounted) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      return;
    }
    setState(() => _regionsLoading = true);
    try {
      final list = await Api.providers.getRegions();
      if (mounted) setState(() => _regions = list);
    } catch (_) {
      try {
        final list = await Api.providers.getRegionsAlias();
        if (mounted) setState(() => _regions = list);
      } catch (_) {}
    } finally {
      if (mounted) setState(() => _regionsLoading = false);
    }
  }

  /// تغيّر الموقع المعتمد (محدد المدينة/عناويني): نعيد حساب المسافات والترتيب
  Future<void> _onLocationChanged() async {
    await _loadUserLocation();
    if (mounted) await _loadData(reset: true, silent: _labs.isNotEmpty);
  }

  @override
  void dispose() {
    AppEvents.locationChanged.removeListener(_onLocationChanged);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<dynamic> _visibleLabs() {
    final q = _searchController.text.trim().toLowerCase();
    return _labs.where((item) {
      if (item is! Map) return false;
      final lab = item;
      final nameAr = (lab['business_name_ar'] ?? lab['name_ar'] ?? '')
          .toString()
          .toLowerCase();
      final nameEn = (lab['business_name_en'] ?? lab['name_en'] ?? '')
          .toString()
          .toLowerCase();
      final name = (lab['business_name'] ?? lab['name'] ?? '')
          .toString()
          .toLowerCase();
      final city = (lab['city'] ?? '').toString().toLowerCase();
      final district = (lab['district'] ?? '').toString().toLowerCase();

      if (q.isNotEmpty &&
          !nameAr.contains(q) &&
          !nameEn.contains(q) &&
          !name.contains(q) &&
          !city.contains(q) &&
          !district.contains(q)) {
        return false;
      }
      if (_filterHomeOnly && lab['home_service_available'] != true) {
        return false;
      }
      return true;
    }).toList();
  }

  /// Applies a labs-data mutation ([_isLoading], [_labs], [_error], etc.)
  /// and rebuilds only the result-count text and labs list/loading/error
  /// area, instead of the entire LabsScreen (search bar, filter button,
  /// sort chips stay untouched).
  void _setLabsState(VoidCallback update) {
    update();
    if (!mounted) return;
    if (_resultCountSetState != null || _labsListSetState != null) {
      _resultCountSetState?.call(() {});
      _labsListSetState?.call(() {});
    } else {
      setState(() {});
    }
  }

  bool get _hasActiveFilters => _filterHomeOnly || _selectedRegionId != null;

  String? _selectedRegionName(bool isArabic) {
    if (_selectedRegionId == null) return null;
    for (final r in _regions) {
      if (r.id == _selectedRegionId) return r.displayName(isArabic);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();
    final lang = settings.language;
    final regionName = _selectedRegionName(settings.isArabic);
    return Directionality(
      textDirection: settings.textDirection,
      // رأس بنفسجي بتدرج الهوية وجسم أبيض بزاوية علوية دائرية (كالتصميم الأول)
      child: Container(
        decoration: const BoxDecoration(gradient: RastUi.headerGradient),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: RastTopBar(
            title: AppStrings.t('labs', lang),
            showCart: true,
            showBack: widget.showBackButton,
            helpTourId: OnboardingTourIds.labs,
            helpTourSteps: buildOnboardingSteps(),
            iconColor: Colors.white,
          ),
          body: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: Container(
              width: double.infinity,
              color: RastTokens.bg(context),
              child: RefreshIndicator(
                color: RastTokens.brand,
                onRefresh: () => _loadData(reset: true),
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    // البحث + زر الفلترة
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(RastTokens.gutter, 6, RastTokens.gutter, 12),
                        child: KeyedSubtree(
                          key: _searchKey,
                          child: RastSearchField(
                            controller: _searchController,
                            hint: AppStrings.t('searchLabs', lang),
                            onChanged: (_) => _setLabsState(() {}),
                            onSubmitted: (v) {
                              AnalyticsService.logSearch(v, area: 'labs');
                              _loadData(reset: true);
                            },
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // خريطة المختبرات
                                MapEntryButton(size: 40, background: RastTokens.brandSoft(context)),
                                const SizedBox(width: 6),
                                KeyedSubtree(
                                  key: _filterKey,
                                  child: _buildFilterButton(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // شرائح الترتيب السريع
                    SliverToBoxAdapter(
                      child: KeyedSubtree(
                        key: _sortKey,
                        child: _buildSortRow(),
                      ),
                    ),

                    // عدد النتائج + الفلاتر المفعّلة
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(RastTokens.gutter, 14, RastTokens.gutter, 6),
                        child: StatefulBuilder(
                          builder: (context, setResultCountState) {
                            _resultCountSetState = setResultCountState;
                            final total = _totalAvailable ?? _labs.length;
                            return Row(
                              children: [
                                Expanded(
                                  child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  _isLoading
                                      ? L(lang, 'جارِ تحميل المختبرات…', 'Loading labs…')
                                      : L(lang, '${_visibleLabs().length} من $total مختبر',
                                          '${_visibleLabs().length} of $total labs'),
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: RastTokens.muted(context),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (_filterHomeOnly)
                                  RastPill(
                                    dense: true,
                                    icon: Icons.home_rounded,
                                    color: RastTokens.success,
                                    label: AppStrings.t('homeServiceOnly', lang),
                                  ),
                                if (regionName != null)
                                  RastPill(
                                    dense: true,
                                    icon: Icons.place_rounded,
                                    label: regionName,
                                  ),
                              ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ViewModeToggle(grid: _grid, onChanged: _setGrid, height: 40),
                              ],
                            );
                          },
                        ),
                      ),
                    ),

                    if (_sortBy == 'nearby' && _userLat == null && _userLng == null)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(RastTokens.gutter, 6, RastTokens.gutter, 4),
                          child: RastCard(
                            color: RastTokens.brandSoft(context),
                            borderColor: RastTokens.brand.withValues(alpha: 0.15),
                            padding: const EdgeInsets.all(12),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const DefaultLocationScreen(),
                              ),
                            ).then((_) async {
                              await _loadUserLocation();
                              await _loadData(reset: true);
                            }),
                            child: Row(
                              children: [
                                const RastIconBox(icon: Icons.my_location_rounded, size: 38),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    AppStrings.t('saveLocationFromSettings', lang),
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      height: 1.5,
                                      color: RastTokens.ink(context),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Icon(
                                  settings.isArabic ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                                  color: RastTokens.brand,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    SliverToBoxAdapter(
                      child: StatefulBuilder(
                        builder: (context, setLabsListState) {
                          _labsListSetState = setLabsListState;
                          final visibleLabs = _visibleLabs();

                          if (_isLoading) {
                            return _buildLoading();
                          }

                          if (_error != null && _labs.isEmpty) {
                            return _buildError();
                          }

                          if (visibleLabs.isEmpty) {
                            return _buildEmpty();
                          }

                          final ref = _referenceLocation;
                          Widget labCard(int index) {
                            final lab = visibleLabs[index] is Map
                                ? visibleLabs[index] as Map<String, dynamic>
                                : <String, dynamic>{};
                            return _LabCard(
                              key: ValueKey('lab-${_grid ? 'g' : 'l'}-${lab['id']}'),
                              lab: lab,
                              grid: _grid,
                              userLat: ref.$1,
                              userLng: ref.$2,
                              branches: BranchesIndexService.instance.branchesFor(lab) ??
                                  (lab['branches'] is List ? lab['branches'] as List<dynamic> : null),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => LabDetailsScreen(lab: lab),
                                ),
                              ),
                            ).entrance(index % 8);
                          }

                          const loader = Padding(
                            padding: EdgeInsets.symmetric(vertical: 18),
                            child: Center(
                              child: SizedBox(
                                width: 26,
                                height: 26,
                                child: CircularProgressIndicator(strokeWidth: 2.4),
                              ),
                            ),
                          );

                          return Padding(
                            padding: const EdgeInsets.fromLTRB(RastTokens.gutter, 8, RastTokens.gutter, 24),
                            child: _grid
                                ? Column(
                                    children: [
                                      GridView.builder(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        padding: EdgeInsets.zero,
                                        itemCount: visibleLabs.length,
                                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 2,
                                          mainAxisSpacing: 12,
                                          crossAxisSpacing: 12,
                                          mainAxisExtent: (MediaQuery.sizeOf(context).width - RastTokens.gutter * 2 - 12) / 2 * 0.62 + 98,
                                        ),
                                        itemBuilder: (context, index) => labCard(index),
                                      ),
                                      if (_isLoadingMore) loader,
                                    ],
                                  )
                                : ListView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    padding: EdgeInsets.zero,
                                    itemCount: visibleLabs.length + (_isLoadingMore ? 1 : 0),
                                    itemBuilder: (context, index) {
                                      // PAGINATION LOADER
                                      if (index >= visibleLabs.length) return loader;
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 16),
                                        child: labCard(index),
                                      );
                                    },
                                  ),
                          );
                        },
                      ),
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSortRow() {
    final lang = context.watch<AppSettingsProvider>().language;
    const options = ['all', 'nearby', 'home_service', 'featured'];
    String label(String v) => switch (v) {
          'nearby' => AppStrings.t('nearbyLabs', lang),
          'home_service' => AppStrings.t('homeServiceLabs', lang),
          'featured' => AppStrings.t('featuredLabsFilter', lang),
          _ => AppStrings.t('allLabs', lang),
        };
    IconData icon(String v) => switch (v) {
          'nearby' => Icons.near_me_rounded,
          'home_service' => Icons.home_rounded,
          'featured' => Icons.workspace_premium_rounded,
          _ => Icons.apps_rounded,
        };
    return RastChoiceChips<String>(
      items: options,
      selected: options.contains(_sortBy) ? _sortBy : 'all',
      labelOf: label,
      iconOf: icon,
      onSelected: (value) {
        if (value == _sortBy) return;
        setState(() => _sortBy = value);
        _loadData(reset: true);
      },
    );
  }

  Widget _buildFilterButton() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: RastTokens.brandSoft(context),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: _showFilterSheet,
            borderRadius: BorderRadius.circular(12),
            child: const SizedBox(
              width: 40,
              height: 40,
              child: Icon(Icons.tune_rounded, color: RastTokens.brand, size: 21),
            ),
          ),
        ),
        if (_hasActiveFilters)
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
    );
  }

  Future<void> _showFilterSheet() async {
    await _ensureRegionsLoaded();
    if (!mounted) return;
    var selectedSort = _sortBy == 'region' ? 'all' : _sortBy;
    var homeOnly = _filterHomeOnly;
    int? selectedRegionId = _selectedRegionId;
    final settings = context.read<AppSettingsProvider>();
    final isArabic = settings.isArabic;
    final lang = settings.language;
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
              20 + MediaQuery.of(context).padding.bottom,
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
                        decoration: BoxDecoration(
                          color: RastTokens.line(context),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const RastIconBox(icon: Icons.tune_rounded, size: 40),
                        const SizedBox(width: 12),
                        Text(
                          AppStrings.t('filterLabs', lang),
                          style: TextStyle(
                            color: RastTokens.ink(context),
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _sheetLabel(AppStrings.t('region', lang)),
                    if (_regionsLoading && _regions.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else
                      DropdownButtonFormField<int?>(
                        key: ValueKey<Object>(selectedRegionId ?? '__all__'),
                        isExpanded: true,
                        initialValue: selectedRegionId != null &&
                                _regions.any((r) => r.id == selectedRegionId)
                            ? selectedRegionId
                            : null,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: RastTokens.fill(context),
                          prefixIcon: const Icon(Icons.place_outlined, color: RastTokens.brand),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: RastTokens.line(context)),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        hint: Text(AppStrings.t('allRegions', lang)),
                        items: [
                          DropdownMenuItem<int?>(
                            value: null,
                            child: Text(AppStrings.t('allRegions', lang)),
                          ),
                          ..._regions.map(
                            (r) => DropdownMenuItem<int?>(
                              value: r.id,
                              child: Text(r.displayName(isArabic)),
                            ),
                          ),
                        ],
                        onChanged: (v) => setSheetState(() => selectedRegionId = v),
                      ),
                    const SizedBox(height: 18),
                    _sheetLabel(AppStrings.t('sort', lang)),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final entry in [
                          ('all', AppStrings.t('allLabs', lang)),
                          ('nearby', AppStrings.t('nearbyLabs', lang)),
                          ('home_service', AppStrings.t('homeServiceLabs', lang)),
                          ('featured', AppStrings.t('featuredLabsFilter', lang)),
                        ])
                          _sheetSortChoice(
                            entry.$2,
                            entry.$1,
                            selectedSort,
                            (value) => setSheetState(() => selectedSort = value),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      decoration: BoxDecoration(
                        color: RastTokens.fill(context),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: SwitchListTile(
                        value: homeOnly,
                        onChanged: (value) => setSheetState(() => homeOnly = value),
                        secondary: const Icon(Icons.home_rounded, color: RastTokens.success),
                        title: Text(
                          AppStrings.t('homeServiceOnly', lang),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: RastTokens.ink(context),
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                        activeThumbColor: RastTokens.brand,
                      ),
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
                                _sortBy = 'all';
                                _filterHomeOnly = false;
                                _selectedRegionId = null;
                              });
                              Navigator.pop(ctx);
                              _loadData(reset: true);
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
                              final sort = selectedSort == 'region' ? 'all' : selectedSort;
                              setState(() {
                                _sortBy = sort;
                                _filterHomeOnly = homeOnly;
                                _selectedRegionId = selectedRegionId;
                              });
                              Navigator.pop(ctx);
                              _loadData(reset: true);
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
          style: TextStyle(
            color: RastTokens.muted(context),
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      );

  Widget _sheetSortChoice(
    String label,
    String value,
    String selected,
    ValueChanged<String> onSelected,
  ) {
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

  Widget _buildEmpty() {
    final lang = context.watch<AppSettingsProvider>().language;
    final filtered = _hasActiveFilters || _sortBy != 'all' || _searchController.text.trim().isNotEmpty;
    return RastEmptyState(
      icon: Icons.biotech_outlined,
      title: AppStrings.t('noLabs', lang),
      message: filtered
          ? L(lang, 'جرّب تغيير البحث أو إزالة الفلاتر لعرض مختبرات أكثر.',
              'Try a different search or clear the filters to see more labs.')
          : null,
      actionLabel: filtered ? L(lang, 'إزالة الفلاتر', 'Clear filters') : null,
      onAction: filtered
          ? () {
              setState(() {
                _sortBy = 'all';
                _filterHomeOnly = false;
                _selectedRegionId = null;
                _searchController.clear();
              });
              _loadData(reset: true);
            }
          : null,
    );
  }

  /// هيكل تحميل بنفس شكل بطاقة المختبر
  Widget _buildLoading() => ListView.builder(
        padding: const EdgeInsets.fromLTRB(RastTokens.gutter, 8, RastTokens.gutter, 16),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 5,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: RastCard(
            padding: EdgeInsets.zero,
            clip: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AspectRatio(aspectRatio: 16 / 7, child: RastSkeleton(radius: 0)),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const RastSkeleton(width: 56, height: 56, radius: 16),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            RastSkeleton(width: 150, height: 14),
                            SizedBox(height: 8),
                            RastSkeleton(width: 190, height: 11),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _buildError() {
    final lang = context.watch<AppSettingsProvider>().language;
    return RastEmptyState(
      icon: Icons.cloud_off_rounded,
      color: RastTokens.danger,
      title: L(lang, 'تعذّر تحميل المختبرات', 'Could not load labs'),
      message: _error,
      actionLabel: AppStrings.t('retry', lang),
      onAction: () => _loadData(reset: true),
    );
  }
}

/// بطاقة مختبر: الشعار، الاسم، أقرب فرع، المسافة، التقييم الحقيقي، والسحب المنزلي.
class _LabCard extends StatefulWidget {
  final Map<String, dynamic> lab;
  final double? userLat;
  final double? userLng;
  final List<dynamic>? branches;
  final VoidCallback onTap;

  /// بطاقة شبكة مدمجة: غلاف، شعار صغير، الاسم، التقييم والمسافة
  final bool grid;

  const _LabCard({
    super.key,
    required this.lab,
    this.userLat,
    this.userLng,
    this.branches,
    required this.onTap,
    this.grid = false,
  });

  @override
  State<_LabCard> createState() => _LabCardState();
}

class _LabCardState extends State<_LabCard> {
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _loadFavorite();
  }

  @override
  void didUpdateWidget(covariant _LabCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (FavoritesService.itemId(oldWidget.lab) != FavoritesService.itemId(widget.lab)) {
      _loadFavorite();
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

  double? _distanceKm() {
    final lab = widget.lab;
    if (widget.userLat != null && widget.userLng != null) {
      final d = LabLocationUtils.distanceKmToNearest(
        lab: lab,
        userLat: widget.userLat!,
        userLng: widget.userLng!,
        branches: widget.branches,
      );
      if (d != null) return d;
    }
    final nearest = LabLocationUtils.resolveForDisplay(
      lab: lab,
      userLat: widget.userLat,
      userLng: widget.userLng,
      branches: widget.branches,
    );
    return nearest?.distanceKm ?? numOf(lab['distance_km'] ?? lab['distance']);
  }

  @override
  Widget build(BuildContext context) {
    final lab = widget.lab;
    final settings = context.watch<AppSettingsProvider>();
    final isArabic = settings.isArabic;
    final lang = settings.language;

    final logoUrl = labLogoUrl(lab);
    final coverUrl = labCoverUrl(lab);
    final businessName = LocaleUtils.localizedBusinessName(lab, isArabic);
    final locationText = LabLocationUtils.displayText(
      lab: lab,
      userLat: widget.userLat,
      userLng: widget.userLng,
      branches: widget.branches,
      isArabic: isArabic,
    );
    final homeService = lab['home_service_available'] == true;
    final featured = lab['is_featured'] == true;
    final rating = numOf(lab['avg_rating']) ?? 0;
    final reviews = (numOf(lab['total_reviews']) ?? 0).toInt();
    final distance = _distanceKm();
    final branchesCount = widget.branches?.length ?? 0;
    final status = labOpenStatus(lab);

    if (widget.grid) {
      return RastCard(
        onTap: widget.onTap,
        padding: EdgeInsets.zero,
        radius: 18,
        clip: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 1 / 0.62,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (coverUrl != null) RastNetImage(url: coverUrl, radius: 0) else LabCoverFallback(logoUrl: logoUrl),
                  PositionedDirectional(
                    top: 8,
                    end: 8,
                    child: GlassCircleButton(
                      size: 32,
                      onTap: _toggleFavorite,
                      child: AnimatedFavoriteIcon(active: _isFavorite, size: 16, inactiveColor: RastTokens.ink(context)),
                    ),
                  ),
                  PositionedDirectional(
                    bottom: 8,
                    start: 8,
                    child: Container(
                      width: 38,
                      height: 38,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(11),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 8, offset: const Offset(0, 3))],
                      ),
                      child: RastNetImage(url: logoUrl, radius: 8, fit: BoxFit.contain, fallbackIcon: Icons.biotech_rounded),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      businessName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13.5, height: 1.3, fontWeight: FontWeight.w800, color: RastTokens.ink(context)),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, size: 14, color: RastTokens.gold),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            reviews > 0 && rating > 0 ? rating.toStringAsFixed(1) : L(lang, 'جديد', 'New'),
                            maxLines: 1,
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: RastTokens.ink(context)),
                          ),
                        ),
                        if (distance != null) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.near_me_rounded, size: 13, color: RastTokens.muted(context)),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              labDistanceLabel(distance, lang),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11.5, color: RastTokens.muted(context)),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (homeService) ...[
                      const SizedBox(height: 3),
                      Text(
                        L(lang, 'سحب منزلي متاح', 'Home visit available'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: RastTokens.success, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // بطاقة بصرية: غلاف عريض (صورة المختبر أو تدرج الهوية) مع الشعار البارز ثم التفاصيل
    return RastCard(
      onTap: widget.onTap,
      padding: EdgeInsets.zero,
      clip: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 16 / 7,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (coverUrl != null)
                  RastNetImage(url: coverUrl, radius: 0)
                else
                  LabCoverFallback(logoUrl: logoUrl),
                // تظليل سفلي خفيف يبرز الشعار
                IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.18)],
                      ),
                    ),
                  ),
                ),
                PositionedDirectional(
                  top: 10,
                  end: 10,
                  child: GlassCircleButton(
                    size: 38,
                    onTap: _toggleFavorite,
                    child: AnimatedFavoriteIcon(active: _isFavorite, size: 19, inactiveColor: RastTokens.ink(context)),
                  ),
                ),
                if (featured || status.known)
                  PositionedDirectional(
                    top: 12,
                    start: 12,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (featured) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: RastTokens.gold,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.workspace_premium_rounded, size: 13, color: Colors.white),
                                const SizedBox(width: 3),
                                Text(
                                  L(lang, 'مميز', 'Featured'),
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        if (status.known) LabOpenBadge(open: status.open, lang: lang, compact: true, onDark: true),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // الشعار يبرز فوق حافة الغلاف
                Transform.translate(
                  offset: const Offset(0, -26),
                  child: Container(
                    width: 64,
                    height: 64,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 14, offset: const Offset(0, 6))],
                    ),
                    child: Hero(
                      tag: 'lab-logo-${lab['id']}',
                      child: RastNetImage(
                        url: logoUrl,
                        radius: 14,
                        fit: BoxFit.contain,
                        fallbackIcon: Icons.biotech_rounded,
                        width: 56,
                        height: 56,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          businessName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 15.5, height: 1.3, color: RastTokens.ink(context), fontWeight: FontWeight.w900),
                        ),
                        if (locationText.trim().isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              const Icon(Icons.location_on_rounded, size: 14, color: RastTokens.brand),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  locationText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 12, color: RastTokens.muted(context), fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 10),
                        // سطر معلومات مختصر بدل الشارات الكثيرة: التقييم · المسافة · سحب منزلي · الفروع
                        Wrap(
                          spacing: 12,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _meta(
                              context,
                              Icons.star_rounded,
                              RastTokens.gold,
                              reviews > 0 && rating > 0
                                  ? '${rating.toStringAsFixed(1)} ($reviews)'
                                  : L(lang, 'جديد على راست', 'New on Rast'),
                            ),
                            if (distance != null)
                              _meta(context, Icons.near_me_rounded, RastTokens.brand2, labDistanceLabel(distance, lang)),
                            if (homeService)
                              _meta(context, Icons.home_rounded, RastTokens.success, L(lang, 'سحب منزلي', 'Home visit')),
                            if (branchesCount > 1)
                              _meta(context, Icons.account_tree_outlined, RastTokens.brand,
                                  L(lang, '$branchesCount فروع', '$branchesCount branches')),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _meta(BuildContext context, IconData icon, Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: RastTokens.ink(context))),
      ],
    );
  }
}
