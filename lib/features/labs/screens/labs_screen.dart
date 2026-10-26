import 'dart:math' as math;

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:rast/core/services/analytics_service.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:rast/core/constants/api_config.dart';
import 'package:rast/core/providers/app_settings_provider.dart';
import 'package:rast/core/utils/locale_utils.dart';
import 'package:provider/provider.dart';
import 'package:rast/core/services/location_service.dart';
import 'package:rast/core/services/favorites_service.dart';
import 'package:rast/core/services/branches_index_service.dart';
import 'package:rast/core/services/catalog_cache_service.dart';
import 'package:rast/core/utils/lab_location_utils.dart';
import 'package:rast/core/theme/app_theme.dart';
import 'package:rast/core/utils/responsive.dart';
import 'package:rast/core/api/api_services.dart';
import 'package:rast/core/api/api_client.dart';
import 'package:rast/core/onboarding/onboarding_catalog.dart';
import 'package:rast/core/onboarding/onboarding_host.dart';
import 'package:rast/core/onboarding/onboarding_step.dart';
import 'package:rast/core/onboarding/onboarding_tour_ids.dart';
import 'package:rast/core/widgets/search_box.dart';
import 'package:rast/core/widgets/rast_ui.dart';
import 'package:rast/app/main_tab_index_scope.dart';
import 'package:rast/app/main_shell.dart';
import 'package:rast/core/models/region.dart';
import 'package:rast/features/lab_details/screens/lab_details_screen.dart';
import 'package:rast/features/settings/screens/default_location_screen.dart';
import 'package:shimmer/shimmer.dart';

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

  @override
  void initState() {
    super.initState();

    _searchController.text = widget.initialSearchQuery ?? '';

    _scrollController.addListener(_onScroll);
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
    try {
      final current = await LocationService.getCurrentLocation();
      if (current != null) {
        lat = current.lat;
        lng = current.lng;
      }
    } catch (_) {}
    if (lat == null || lng == null) {
      final saved = await LocationService.getDefaultLocation();
      if (saved != null) {
        lat = saved.lat;
        lng = saved.lng;
      }
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

  @override
  void dispose() {
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

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();
    final lang = settings.language;
    final theme = Theme.of(context);
    return Directionality(
      textDirection: settings.textDirection,
      child: Container(
        decoration: const BoxDecoration(
          gradient: RastUi.headerGradient,
        ),
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
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(38),
              topRight: Radius.circular(38),
            ),
            child: Container(
              width: double.infinity,
              color: RastUi.screenSurface(context),
              child: RefreshIndicator(
                onRefresh: () => _loadData(reset: true),
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          Responsive.spacing(context, 18),
                          Responsive.spacing(context, 30),
                          Responsive.spacing(context, 18),
                          Responsive.spacing(context, 10),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: KeyedSubtree(
                                key: _searchKey,
                                child: SearchBox(
                                  controller: _searchController,
                                  hintText: AppStrings.t('searchLabs', lang),                                  onSearchTap: () =>
                                    _loadData(reset: true),
                                  onSubmitted: (v) {
 AnalyticsService.logSearch(v, area: 'labs');
 _loadData(reset: true);
},
                                ),
                              ),
                            ),

                            const SizedBox(width: 14),

                            KeyedSubtree(
                              key: _filterKey,
                              child: _buildFilterButton(),
                            ),
                          ],
                        ),
                      ),
                    ),

                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal:
                          Responsive.spacing(context, 18),
                        ),
                        child: StatefulBuilder(
                          builder: (context, setResultCountState) {
                            _resultCountSetState = setResultCountState;
                            final resultCountLabel =
                            (_totalAvailable ?? _labs.length).toString();
                            return Align(
                              alignment:
                              AlignmentDirectional.centerStart,
                              child: Text(
                                '${AppStrings.t('showing', lang)} '
                                    '${_visibleLabs().length} '
                                    '${AppStrings.t('of', lang)} '
                                    '$resultCountLabel',
                                style: TextStyle(
                                  fontSize:
                                  Responsive.fontSize(context, 12),
                                  color:
                                  AppTheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: Responsive.spacing(context, 14),
                        ),
                        child: KeyedSubtree(
                          key: _sortKey,
                          child: _buildSortRow(),
                        ),
                      ),
                    ),

                    if (_sortBy == 'nearby' &&
                        _userLat == null &&
                        _userLng == null)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            Responsive.spacing(context, 18),
                            0,
                            Responsive.spacing(context, 18),
                            Responsive.spacing(context, 14),
                          ),
                          child: GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                const DefaultLocationScreen(),
                              ),
                            ).then((_) async {
                              await _loadUserLocation();
                              await _loadData(reset: true);
                            }),
                            child: Container(
                              padding:
                              const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: theme
                                    .colorScheme.primary
                                    .withValues(alpha: 0.08),
                                borderRadius:
                                BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.location_off,
                                    size: 18,
                                    color: theme
                                        .colorScheme.primary,
                                  ),

                                  const SizedBox(width: 8),

                                  Expanded(
                                    child: Text(
                                      AppStrings.t(
                                        'saveLocationFromSettings',
                                        lang,
                                      ),
                                      style: TextStyle(
                                        fontSize:
                                        Responsive.fontSize(
                                          context,
                                          12,
                                        ),
                                        color: theme
                                            .colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
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
                            return SizedBox(
                              height: 350,
                              child: _buildEmpty(),
                            );
                          }

                          return Padding(
                            padding: EdgeInsets.fromLTRB(
                              Responsive.spacing(context, 16),
                              4,
                              Responsive.spacing(context, 16),
                              Responsive.spacing(context, 24),
                            ),
                            child: ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount:
                              visibleLabs.length +
                                  (_isLoadingMore ? 1 : 0),
                              itemBuilder: (context, index) {
                                // PAGINATION LOADER
                                if (index >= visibleLabs.length) {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(
                                      vertical: 18,
                                    ),
                                    child: Center(
                                      child:
                                      CircularProgressIndicator(),
                                    ),
                                  );
                                }

                                final lab =
                                visibleLabs[index] is Map
                                    ? visibleLabs[index]
                                as Map<String, dynamic>
                                    : <String, dynamic>{};

                                final ref = _referenceLocation;

                                return Padding(
                                  padding: EdgeInsets.only(
                                    bottom:
                                    Responsive.spacing(
                                      context,
                                      12,
                                    ),
                                  ),
                                  child: _LabCard(
                                    lab: lab,
                                    userLat: ref.$1,
                                    userLng: ref.$2,
                                    branches:
                                    BranchesIndexService
                                        .instance
                                        .branchesFor(lab) ??
                                        (lab['branches']
                                        is List
                                            ? lab['branches']
                                        as List<dynamic>
                                            : null),
                                    onTap: () =>
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                LabDetailsScreen(
                                                  lab: lab,
                                                ),
                                          ),
                                        ),
                                  )
                                      .animate()
                                      .fadeIn(
                                    duration: 400.ms,
                                    delay: Duration(
                                      milliseconds:
                                      (index % 8) * 40,
                                    ),
                                  )
                                      .slideY(
                                    begin: 0.02,
                                    end: 0,
                                    curve:
                                    Curves.easeOutCubic,
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),

                    SliverToBoxAdapter(
                      child: SizedBox(
                        height:
                        Responsive.spacing(context, 24),
                      ),
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


  Widget _buildSortRow() {
    final settings = context.watch<AppSettingsProvider>();
    final lang = settings.language;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.spacing(context, 15),
      ),
      child: Row(
        children: [
          _sortChip(
            AppStrings.t('allLabs', lang),
            'all',
          ),

          const SizedBox(width: 8),

          _sortChip(
            AppStrings.t('nearbyLabs', lang),
            'nearby',
          ),

          const SizedBox(width: 8),

          _sortChip(
            AppStrings.t('homeServiceLabs', lang),
            'home_service',
          ),

          const SizedBox(width: 8),

          _sortChip(
            AppStrings.t('featuredLabsFilter', lang),
            'featured',
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton() {
    return InkWell(
      onTap: _showFilterSheet,
      borderRadius: BorderRadius.circular(13),
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: RastUi.cardSurface(context),
          borderRadius: BorderRadius.circular(13),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(Icons.tune_rounded, color: RastUi.purple, size: 22),
      ),
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
              Responsive.spacing(context, 20),
              10,
              Responsive.spacing(context, 20),
              Responsive.spacing(context, 20) +
                  MediaQuery.of(context).padding.bottom,
            ),
            decoration: BoxDecoration(
              color: RastUi.cardSurface(context),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(26),
              ),
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
                          color: AppTheme.onSurfaceVariant.withValues(
                            alpha: 0.35,
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    SizedBox(height: Responsive.spacing(context, 16)),
                    Text(
                      AppStrings.t('filterLabs', lang),
                      style: TextStyle(
                        color: RastUi.primaryText(context),
                        fontSize: Responsive.fontSize(context, 18),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: Responsive.spacing(context, 18)),
                    Text(
                      AppStrings.t('region', lang),
                      style: TextStyle(
                        color: RastUi.textPurple,
                        fontSize: Responsive.fontSize(context, 13),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
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
                          fillColor: Theme.of(context).colorScheme.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                        ),
                        hint: Text(
                          AppStrings.t('allRegions', lang),
                        ),
                        items: [
                          DropdownMenuItem<int?>(
                            value: null,
                            child: Text(
                              AppStrings.t('allRegions', lang),
                            ),
                          ),
                          ..._regions.map(
                                (r) => DropdownMenuItem<int?>(
                              value: r.id,
                              child: Text(r.displayName(isArabic)),
                            ),
                          ),
                        ],
                        onChanged: (v) =>
                            setSheetState(() => selectedRegionId = v),
                      ),
                    SizedBox(height: Responsive.spacing(context, 16)),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _sheetSortChoice(
                          AppStrings.t('allLabs', lang),
                          'all',
                          selectedSort,
                              (value) {
                            setSheetState(() => selectedSort = value);
                          },
                        ),
                        _sheetSortChoice(
                          AppStrings.t('nearbyLabs', lang),
                          'nearby',
                          selectedSort,
                              (value) {
                            setSheetState(() => selectedSort = value);
                          },
                        ),

                        _sheetSortChoice(
                          AppStrings.t('homeServiceLabs', lang),
                          'home_service',
                          selectedSort,
                              (value) {
                            setSheetState(() => selectedSort = value);
                          },
                        ),

                        _sheetSortChoice(
                          AppStrings.t('featuredLabsFilter', lang),
                          'featured',
                          selectedSort,
                              (value) {
                            setSheetState(() => selectedSort = value);
                          },
                        ),
                      ],
                    ),
                    SizedBox(height: Responsive.spacing(context, 14)),
                    SwitchListTile(
                      value: homeOnly,
                      onChanged: (value) =>
                          setSheetState(() => homeOnly = value),
                      title: Text(
                        AppStrings.t(
                          'homeServiceOnly',
                          lang,
                        ),
                      ),
                      contentPadding: EdgeInsets.zero,
                      activeThumbColor: RastUi.purple,
                    ),
                    SizedBox(height: Responsive.spacing(context, 18)),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _sortBy = 'all';
                                _filterHomeOnly = false;
                                _selectedRegionId = null;
                              });
                              Navigator.pop(ctx);
                              _loadData(reset: true);
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
                              final sort = selectedSort == 'region'
                                  ? 'all'
                                  : selectedSort;
                              setState(() {
                                _sortBy = sort;
                                _filterHomeOnly = homeOnly;
                                _selectedRegionId = selectedRegionId;
                              });
                              Navigator.pop(ctx);
                              _loadData(reset: true);
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
        ),
      ),
    );
  }

  Widget _sheetSortChoice(
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

  Widget _sortChip(String label, String value) {
    final selected = _sortBy == value;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: Responsive.fontSize(context, 13),
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          color: selected ? Colors.white : RastUi.textPurple,
        ),
      ),
      selected: selected,
      onSelected: (_) {
        setState(() {
          _sortBy = value;
        });
        _loadData(reset: true);
      },
      selectedColor: RastUi.purple,
      showCheckmark: false,
      checkmarkColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _buildEmpty() {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.business_rounded,
            size: 72,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
          ),
          SizedBox(height: 16),
          Text(
            AppStrings.t(
              'noLabs',
              context.watch<AppSettingsProvider>().language,
            ),
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 15),
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() => ListView.builder(
    padding: EdgeInsets.all(Responsive.spacing(context, 16)),
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: 6,
    itemBuilder: (_, __) => Shimmer.fromColors(
      baseColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      highlightColor: Theme.of(context).colorScheme.surface,
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        height: 100,
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(24),
        ),
      ),
    ),
  );

  Widget _buildError() {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 56,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: Text(
                AppStrings.t(
                  'retry',
                  context.watch<AppSettingsProvider>().language,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LabCard extends StatefulWidget {
  final Map<String, dynamic> lab;
  final double? userLat;
  final double? userLng;
  final List<dynamic>? branches;
  final VoidCallback onTap;

  const _LabCard({
    required this.lab,
    this.userLat,
    this.userLng,
    this.branches,
    required this.onTap,
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
    if (FavoritesService.itemId(oldWidget.lab) !=
        FavoritesService.itemId(widget.lab)) {
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

  @override
  Widget build(BuildContext context) {
    final lab = widget.lab;

    final settings = context.watch<AppSettingsProvider>();
    final isArabic = settings.isArabic;

    final logoUrl = ApiConfig.resolveImageUrl(
      lab['logo_url'],
      lab['logo'],
    );

    final businessName = LocaleUtils.localizedBusinessName(
      lab,
      isArabic,
    );

    final locationText = LabLocationUtils.displayText(
      lab: lab,
      userLat: widget.userLat,
      userLng: widget.userLng,
      branches: widget.branches,
      isArabic: isArabic,
    );

    final homeService = lab['home_service_available'] == true;

    final screenWidth = MediaQuery.sizeOf(context).width;
    final imageSize = (screenWidth * 0.17).clamp(58.0, 72.0);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: RastUi.cardSurface(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: RastUi.softBorder(context).withValues(alpha: 0.65),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.13),
            blurRadius: 18,
            spreadRadius: 1,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: EdgeInsets.all(
              Responsive.spacing(context, 14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildLogo(
                  context,
                  logoUrl,
                  imageSize,
                ),

                SizedBox(
                  width: Responsive.spacing(context, 14),
                ),

                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      // NAME + FAVORITE
                      Row(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              businessName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize:
                                Responsive.fontSize(
                                  context,
                                  14,
                                ),
                                height: 1.25,
                                color:
                                RastUi.primaryText(context),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),

                          const SizedBox(width: 8),

                          InkWell(
                            onTap: _toggleFavorite,
                            borderRadius:
                            BorderRadius.circular(20),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                _isFavorite
                                    ? Icons.favorite_rounded
                                    : Icons
                                    .favorite_border_rounded,
                                color:
                                const Color(0xFFFF5A6F),
                                size:
                                Responsive.fontSize(
                                  context,
                                  21,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 5),

                      // LOCATION
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size:
                            Responsive.fontSize(
                              context,
                              15,
                            ),
                            color:
                            AppTheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              locationText,
                              maxLines: 1,
                              overflow:
                              TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize:
                                Responsive.fontSize(
                                  context,
                                  11,
                                ),
                                color:
                                AppTheme.onSurfaceVariant,
                                fontWeight:
                                FontWeight.w400,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // BADGE + RATING
                      LayoutBuilder(
                        builder: (context, constraints) {
                          return Row(
                            children: [
                              Flexible(
                                child: Container(
                                  padding:
                                  const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: RastUi.purple
                                        .withValues(
                                      alpha: 0.08,
                                    ),
                                    borderRadius:
                                    BorderRadius.circular(
                                      10,
                                    ),
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
                                    maxLines: 1,
                                    overflow:
                                    TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize:
                                      Responsive.fontSize(
                                        context,
                                        10,
                                      ),
                                      color: RastUi.purple,
                                      fontWeight:
                                      FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(width: 10),

                              Row(
                                mainAxisSize:
                                MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.star_rounded,
                                    color: AppTheme.accent,
                                    size: 17,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    '4.8',
                                    style: TextStyle(
                                      fontSize:
                                      Responsive.fontSize(
                                        context,
                                        11,
                                      ),
                                      color:
                                      RastUi.primaryText(
                                        context,
                                      ),
                                      fontWeight:
                                      FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
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

  Widget _buildLogo(
      BuildContext context,
      String? url,
      double size,
      ) {
    final theme = Theme.of(context);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: theme.colorScheme.surfaceContainerHighest,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: (url != null && url.isNotEmpty)
            ? CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          placeholder: (_, __) => Center(
            child: Icon(
              Icons.business_rounded,
              size: size * 0.40,
              color: theme.colorScheme.primary,
            ),
          ),
          errorWidget: (_, __, ___) => Center(
            child: Icon(
              Icons.business_rounded,
              size: size * 0.40,
              color: theme.colorScheme.primary,
            ),
          ),
        )
            : Center(
          child: Icon(
            Icons.business_rounded,
            size: size * 0.40,
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }

}