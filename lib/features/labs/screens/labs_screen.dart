import 'dart:math' as math;

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
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
import 'package:rast/core/widgets/search_box.dart';
import 'package:rast/core/widgets/rast_ui.dart';
import 'package:rast/core/models/region.dart';
import 'package:rast/features/lab_details/screens/lab_details_screen.dart';
import 'package:rast/features/settings/screens/default_location_screen.dart';
import 'package:shimmer/shimmer.dart';

class LabsScreen extends StatefulWidget {
  const LabsScreen({super.key});

  @override
  State<LabsScreen> createState() => _LabsScreenState();
}

class _LabsScreenState extends State<LabsScreen> {
  static const int _pageSize = 20;
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

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _ensureRegionsLoaded();
    BranchesIndexService.instance.ensureLoaded();
    _loadFromCacheThenNetwork();
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
      setState(() {
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
      setState(() {
        if (!silent || _labs.isEmpty) _isLoading = true;
        _error = null;
        _currentPage = 1;
        _hasMore = true;
      });
    } else {
      setState(() {
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
      setState(() {
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
      setState(() {
        _error = e.message;
        if (reset) _labs = [];
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visibleLabs = _visibleLabs();
    final totalLabel = (_totalAvailable ?? _labs.length).toString();
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        decoration: BoxDecoration(gradient: _backgroundGradient(theme)),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: const RastTopBar(title: 'المختبرات'),
          body: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: Container(
              color: RastUi.screenSurface(context),
              child: _isLoading
                  ? _buildLoading()
                  : _error != null && _labs.isEmpty
                  ? _buildError()
                  : Column(
                      children: [
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            Responsive.spacing(context, 18),
                            Responsive.spacing(context, 18),
                            Responsive.spacing(context, 18),
                            Responsive.spacing(context, 10),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: SearchBox(
                                      controller: _searchController,
                                      hintText: 'ابحث عن مختبر',
                                      onSearchTap: () => _loadData(reset: true),
                                      onSubmitted: (_) =>
                                          _loadData(reset: true),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  _buildFilterButton(),
                                ],
                              ),
                              SizedBox(height: Responsive.spacing(context, 12)),
                              Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: Text(
                                  'عرض ${visibleLabs.length} من $totalLabel',
                                  style: TextStyle(
                                    fontSize: Responsive.fontSize(context, 12),
                                    color: AppTheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              SizedBox(height: Responsive.spacing(context, 10)),
                              _buildSortRow(),
                              if (_sortBy == 'nearby' &&
                                  _userLat == null &&
                                  _userLng == null) ...[
                                SizedBox(height: 8),
                                GestureDetector(
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
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary
                                          .withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.location_off,
                                          size: 18,
                                          color: theme.colorScheme.primary,
                                        ),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'احفظ موقعك من الإعدادات لعرض الأقرب',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: theme.colorScheme.primary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Expanded(
                          child: visibleLabs.isEmpty
                              ? _buildEmpty()
                              : RefreshIndicator(
                                  onRefresh: () => _loadData(reset: true),
                                  child: _buildLabsList(visibleLabs),
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

  LinearGradient _backgroundGradient(ThemeData theme) {
    if (theme.brightness == Brightness.dark) {
      return const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF07131A), Color(0xFF081924), Color(0xFF0B2230)],
        stops: [0.0, 0.5, 1.0],
      );
    }
    return AppTheme.backgroundGradient;
  }

  Widget _buildSortRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _sortChip('الكل', 'all'),
          SizedBox(width: 8),
          _sortChip('القريب', 'nearby'),
          SizedBox(width: 8),
          _sortChip('الخدمة المنزلية', 'home_service'),
          SizedBox(width: 8),
          _sortChip('المميزة', 'featured'),
        ],
      ),
    );
  }

  Widget _buildLabsList(List<dynamic> visibleLabs) {
    return ListView.separated(
      controller: _scrollController,
      padding: EdgeInsets.symmetric(horizontal: Responsive.spacing(context, 16)),
      itemCount: visibleLabs.length + (_isLoadingMore ? 1 : 0),
      separatorBuilder: (_, __) => SizedBox(height: Responsive.spacing(context, 12)),
      itemBuilder: (context, index) {
        if (index >= visibleLabs.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final lab = visibleLabs[index] is Map
            ? visibleLabs[index] as Map<String, dynamic>
            : <String, dynamic>{};
        return _LabCard(
              lab: lab,
              userLat: _userLat,
              userLng: _userLng,
              branches: BranchesIndexService.instance.branchesFor(lab) ??
                  (lab['branches'] is List
                      ? lab['branches'] as List<dynamic>
                      : null),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => LabDetailsScreen(lab: lab)),
              ),
            )
            .animate()
            .fadeIn(
              duration: 400.ms,
              delay: Duration(milliseconds: (index % 8) * 40),
            )
            .slideY(begin: 0.02, end: 0, curve: Curves.easeOutCubic);
      },
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
    final isArabic = context.read<AppSettingsProvider>().isArabic;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Directionality(
          textDirection: TextDirection.rtl,
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
                      'فلترة المختبرات',
                      style: TextStyle(
                        color: RastUi.primaryText(context),
                        fontSize: Responsive.fontSize(context, 18),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: Responsive.spacing(context, 18)),
                    Text(
                      'المنطقة',
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
                        hint: const Text('كل المناطق'),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('كل المناطق'),
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
                        _sheetSortChoice('الكل', 'all', selectedSort, (value) {
                          setSheetState(() => selectedSort = value);
                        }),
                        _sheetSortChoice('القريب', 'nearby', selectedSort, (
                          value,
                        ) {
                          setSheetState(() => selectedSort = value);
                        }),
                        _sheetSortChoice(
                          'الخدمة المنزلية',
                          'home_service',
                          selectedSort,
                          (value) {
                            setSheetState(() => selectedSort = value);
                          },
                        ),
                        _sheetSortChoice('المميزة', 'featured', selectedSort, (
                          value,
                        ) {
                          setSheetState(() => selectedSort = value);
                        }),
                      ],
                    ),
                    SizedBox(height: Responsive.spacing(context, 14)),
                    SwitchListTile(
                      value: homeOnly,
                      onChanged: (value) =>
                          setSheetState(() => homeOnly = value),
                      title: const Text('مختبرات توفر خدمة منزلية فقط'),
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
                            child: const Text('مسح'),
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
            'لا توجد مختبرات',
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
              label: const Text('إعادة المحاولة'),
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
    final logoUrl = ApiConfig.resolveImageUrl(lab['logo_url'], lab['logo']);
    final businessName = LocaleUtils.localizedBusinessName(
      lab,
      context.watch<AppSettingsProvider>().isArabic,
    );
    final locationLine = LabLocationUtils.displayLine(
      lab: lab,
      userLat: widget.userLat,
      userLng: widget.userLng,
      branches: widget.branches,
    );
    final homeService = lab['home_service_available'] == true;
    final size =
        56.0 * (MediaQuery.of(context).size.width / 375).clamp(1.0, 1.2);

    return Container(
      decoration: BoxDecoration(
        color: RastUi.cardSurface(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: RastUi.softBorder(context)),
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
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.all(Responsive.spacing(context, 14)),
            child: Stack(
              children: [
                PositionedDirectional(
                  end: 0,
                  top: 0,
                  child: IconButton(
                    onPressed: _toggleFavorite,
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      _isFavorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: const Color(0xFFFF4D61),
                      size: Responsive.fontSize(context, 22),
                    ),
                  ),
                ),
                Row(
                  children: [
                    _buildLogo(context, logoUrl, size),
                    SizedBox(width: Responsive.spacing(context, 14)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            businessName,
                            style: TextStyle(
                              fontSize: Responsive.fontSize(context, 13),
                              color: RastUi.textPurple,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 4),
                          Text(
                            locationLine.formatted,
                            style: TextStyle(
                              fontSize: Responsive.fontSize(context, 11),
                              color: RastUi.blue,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 8),
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: Container(
                              constraints: const BoxConstraints(minWidth: 88),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                gradient: RastUi.brandGradient,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Text(
                                homeService ? 'منزلي' : 'منزلي',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: Responsive.fontSize(context, 10),
                                  color: Colors.white,
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
                PositionedDirectional(
                  end: 0,
                  bottom: 0,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '4.8',
                        style: TextStyle(
                          fontSize: Responsive.fontSize(context, 10),
                          color: RastUi.textPurple,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.star_rounded,
                        color: AppTheme.accent,
                        size: 16,
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

  Widget _buildLogo(BuildContext context, String? url, double size) {
    final theme = Theme.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: (url != null && url.isNotEmpty)
            ? CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: Icon(
                    Icons.business_rounded,
                    size: size * 0.45,
                    color: theme.colorScheme.primary,
                  ),
                ),
                errorWidget: (_, __, ___) => Container(
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: Icon(
                    Icons.business_rounded,
                    size: size * 0.45,
                    color: theme.colorScheme.primary,
                  ),
                ),
              )
            : Container(
                color: theme.colorScheme.surfaceContainerHighest,
                child: Icon(
                  Icons.business_rounded,
                  size: size * 0.45,
                  color: theme.colorScheme.primary,
                ),
              ),
      ),
    );
  }
}
