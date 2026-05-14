import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:rast/core/api/api_client.dart';
import 'package:rast/core/api/api_services.dart';
import 'package:rast/core/constants/api_config.dart';
import 'package:rast/core/constants/app_strings.dart';
import 'package:rast/core/constants/dummy_data.dart';
import 'package:rast/core/providers/app_settings_provider.dart';
import 'package:rast/core/services/favorites_service.dart';
import 'package:rast/core/theme/app_theme.dart';
import 'package:rast/core/utils/locale_utils.dart';
import 'package:rast/core/widgets/gradient_button.dart';
import 'package:rast/core/utils/responsive.dart';
import 'package:rast/core/widgets/search_box.dart';
import 'package:rast/core/widgets/rast_ui.dart';
import 'package:rast/features/analyses/screens/service_detail_screen.dart';
import 'package:shimmer/shimmer.dart';

class AnalysesScreen extends StatefulWidget {
  final int? labId;
  final String? labName;
  final int? categoryId;
  final String? initialSearchQuery;

  const AnalysesScreen({
    super.key,
    this.labId,
    this.labName,
    this.categoryId,
    this.initialSearchQuery,
  });

  @override
  State<AnalysesScreen> createState() => _AnalysesScreenState();
}

class _AnalysesScreenState extends State<AnalysesScreen> {
  static const int _pageSize = 24;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _minPriceController = TextEditingController();
  final TextEditingController _maxPriceController = TextEditingController();
  List<dynamic> _services = [];
  List<dynamic> _categories = [];
  int? _selectedCategoryId;
  String _sortBy = 'default';
  double? _minPrice;
  double? _maxPrice;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  int? _totalAvailable;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialSearchQuery != null &&
        widget.initialSearchQuery!.trim().isNotEmpty) {
      _searchController.text = widget.initialSearchQuery!.trim();
    }
    _scrollController.addListener(_onScroll);
    _loadData(reset: true);
  }

  Future<void> _loadData({bool reset = false}) async {
    if (_isLoadingMore) return;
    if (!reset && !_hasMore) return;

    if (reset) {
      setState(() {
        _isLoading = true;
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
      List<dynamic> categories = List.from(_categories);
      if (reset || categories.isEmpty) {
        try {
          categories = await Api.services.getCategories();
        } catch (_) {}
      }

      List<dynamic> servicesPage = [];
      bool canLoadMore = false;
      int? totalFromApi;

      if (widget.labId != null) {
        final pageRes = await Api.providers.getProviderServicesPage(
          widget.labId!,
          page: reset ? 1 : _currentPage,
          perPage: _pageSize,
          q: _searchController.text.trim().isEmpty
              ? null
              : _searchController.text.trim(),
        );
        servicesPage = pageRes.items;
        canLoadMore = pageRes.hasMore;
        totalFromApi = pageRes.total;
      } else {
        final res = await Api.services.getServices(
          categoryId: widget.categoryId,
          search: _searchController.text.trim().isEmpty
              ? null
              : _searchController.text.trim(),
          page: _currentPage,
          perPage: _pageSize,
        );
        servicesPage = _extractServiceItems(res['data']);
        canLoadMore =
            _hasNextPage(res['data']) ?? servicesPage.length >= _pageSize;
        totalFromApi = _toInt(
          (res['data'] is Map) ? (res['data'] as Map)['total'] : null,
        );
      }

      if (servicesPage.isEmpty && reset && widget.labId == null) {
        servicesPage = List.from(DummyData.services.take(_pageSize));
        canLoadMore = false;
      }
      if (categories.isEmpty) categories = List.from(DummyData.categories);
      setState(() {
        _categories = categories;
        if (reset) {
          _services = servicesPage;
        } else {
          _services.addAll(servicesPage);
        }
        _currentPage += 1;
        _hasMore = canLoadMore;
        _totalAvailable = totalFromApi ?? _totalAvailable ?? _services.length;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        if (reset) _services = List.from(DummyData.services.take(_pageSize));
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        if (reset) _services = List.from(DummyData.services.take(_pageSize));
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  List<dynamic> _extractServiceItems(dynamic data) {
    if (data is List) return List.from(data);
    if (data is Map) {
      final nested = data['data'];
      if (nested is List) return List.from(nested);
    }
    return [];
  }

  bool? _hasNextPage(dynamic data) {
    if (data is Map) {
      final currentPage = _toInt(data['current_page']);
      final lastPage = _toInt(data['last_page']);
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

  void _onScroll() {
    if (!_scrollController.hasClients || _isLoading || _isLoadingMore) return;
    final p = _scrollController.position;
    if (p.pixels >= p.maxScrollExtent - 320) {
      _loadData();
    }
  }

  double _servicePrice(Map<String, dynamic> service) {
    return ApiConfig.priceFromMap(service);
  }

  int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  String _getCategoryName(BuildContext context, dynamic catId) {
    if (catId == null) return '';
    for (final x in _categories) {
      if (x is Map &&
          (x['id'] == catId || x['id']?.toString() == catId.toString())) {
        return LocaleUtils.localizedName(
          x as Map<String, dynamic>,
          context.watch<AppSettingsProvider>().isArabic,
        );
      }
    }
    return '';
  }

  String? _getServiceImageUrl(
    Map<String, dynamic> service, [
    Map<String, dynamic>? providerService,
  ]) {
    return ApiConfig.analysisImageUrl(service, providerService);
  }

  List<dynamic> _visibleServices() {
    final q = _searchController.text.trim().toLowerCase();
    final visible = _services.where((item) {
      Map<String, dynamic> service;
      if (widget.labId != null) {
        final ps = item is Map
            ? item as Map<String, dynamic>
            : <String, dynamic>{};
        final s = ps['service'] ?? ps;
        service = s is Map ? Map<String, dynamic>.from(s) : <String, dynamic>{};
      } else {
        service = item is Map
            ? Map<String, dynamic>.from(item)
            : <String, dynamic>{};
      }

      final cId = _toInt(
        service['category_id'] ?? service['service_category_id'],
      );
      if (_selectedCategoryId != null && cId != _selectedCategoryId) {
        return false;
      }
      final price = _servicePrice(service);
      if (_minPrice != null && price < _minPrice!) return false;
      if (_maxPrice != null && price > _maxPrice!) return false;

      if (q.isEmpty) return true;
      final n1 = (service['name_ar'] ?? '').toString().toLowerCase();
      final n2 = (service['name_en'] ?? '').toString().toLowerCase();
      final n3 = (service['name'] ?? '').toString().toLowerCase();
      return n1.contains(q) || n2.contains(q) || n3.contains(q);
    }).toList();

    visible.sort((a, b) {
      Map<String, dynamic> serviceA;
      Map<String, dynamic> serviceB;
      if (widget.labId != null) {
        final psA = a is Map ? a as Map<String, dynamic> : <String, dynamic>{};
        final psB = b is Map ? b as Map<String, dynamic> : <String, dynamic>{};
        serviceA = psA['service'] is Map
            ? Map<String, dynamic>.from(psA['service'] as Map)
            : psA;
        serviceB = psB['service'] is Map
            ? Map<String, dynamic>.from(psB['service'] as Map)
            : psB;
        serviceA['price'] =
            psA['final_price'] ?? psA['price'] ?? serviceA['price'];
        serviceB['price'] =
            psB['final_price'] ?? psB['price'] ?? serviceB['price'];
      } else {
        serviceA = a is Map
            ? Map<String, dynamic>.from(a)
            : <String, dynamic>{};
        serviceB = b is Map
            ? Map<String, dynamic>.from(b)
            : <String, dynamic>{};
      }
      switch (_sortBy) {
        case 'price_low':
          return _servicePrice(serviceA).compareTo(_servicePrice(serviceB));
        case 'price_high':
          return _servicePrice(serviceB).compareTo(_servicePrice(serviceA));
        case 'name':
          final isArabic = context.read<AppSettingsProvider>().isArabic;
          return LocaleUtils.localizedName(
            serviceA,
            isArabic,
          ).compareTo(LocaleUtils.localizedName(serviceB, isArabic));
        default:
          return 0;
      }
    });
    return visible;
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppSettingsProvider>().language;
    final title = widget.labName ?? AppStrings.t('analyses', lang);
    final visible = _visibleServices();
    final totalLabel = (_totalAvailable ?? _services.length).toString();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        decoration: const BoxDecoration(gradient: RastUi.headerGradient),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: RastTopBar(title: title),
          body: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: Container(
              color: RastUi.screenSurface(context),
              child: _isLoading
                  ? _buildLoading()
                  : _error != null && _services.isEmpty
                  ? _buildError()
                  : Column(
                      children: [
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            Responsive.spacing(context, 24),
                            Responsive.spacing(context, 32),
                            Responsive.spacing(context, 24),
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
                              SizedBox(height: Responsive.spacing(context, 10)),
                              Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: Text(
                                  'عرض ${visible.length} من $totalLabel',
                                  style: TextStyle(
                                    fontSize: Responsive.fontSize(context, 12),
                                    color: AppTheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              SizedBox(height: Responsive.spacing(context, 8)),
                              _buildCategoriesStrip(),
                            ],
                          ),
                        ),
                        Expanded(
                          child: visible.isEmpty
                              ? _buildEmpty()
                              : RefreshIndicator(
                                  onRefresh: () => _loadData(reset: true),
                                  child: GridView.builder(
                                    controller: _scrollController,
                                    padding: EdgeInsets.fromLTRB(
                                      Responsive.spacing(context, 24),
                                      Responsive.spacing(context, 10),
                                      Responsive.spacing(context, 24),
                                      Responsive.spacing(context, 24),
                                    ),
                                    gridDelegate:
                                        SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 2,
                                          childAspectRatio: 0.70,
                                          crossAxisSpacing: Responsive.spacing(
                                            context,
                                            22,
                                          ),
                                          mainAxisSpacing: Responsive.spacing(
                                            context,
                                            24,
                                          ),
                                        ),
                                    itemCount:
                                        visible.length +
                                        (_isLoadingMore ? 1 : 0),
                                    itemBuilder: (context, index) {
                                      if (index >= visible.length) {
                                        return const Center(
                                          child: CircularProgressIndicator(),
                                        );
                                      }
                                      final item = visible[index];
                                      Map<String, dynamic> service;
                                      if (widget.labId != null) {
                                        final ps = item is Map
                                            ? item as Map<String, dynamic>
                                            : <String, dynamic>{};
                                        final s = ps['service'] ?? ps;
                                        service = s is Map
                                            ? Map<String, dynamic>.from(s)
                                            : <String, dynamic>{};
                                        service['price'] =
                                            ps['final_price'] ??
                                            ps['price'] ??
                                            service['price'];
                                        service['home_price'] =
                                            ps['home_service_price'] ??
                                            ps['home_price'];
                                        service['provider_service_id'] =
                                            ps['id'];
                                        final psImg = ps['image']
                                            ?.toString()
                                            .trim();
                                        if (psImg != null && psImg.isNotEmpty) {
                                          service['image'] = psImg;
                                        }
                                      } else {
                                        service = item is Map
                                            ? Map<String, dynamic>.from(item)
                                            : <String, dynamic>{};
                                      }
                                      final providerSvc =
                                          widget.labId != null && item is Map
                                          ? item as Map<String, dynamic>
                                          : null;

                                      return _AnalysisCard(
                                            service: service,
                                            categoryName: _getCategoryName(
                                              context,
                                              service['category_id'] ??
                                                  service['service_category_id'],
                                            ),
                                            imageUrl: _getServiceImageUrl(
                                              service,
                                              providerSvc,
                                            ),
                                            isArabic: context
                                                .watch<AppSettingsProvider>()
                                                .isArabic,
                                            isLabView: widget.labId != null,
                                            lang: lang,
                                            onTap: () => Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    ServiceDetailScreen(
                                                      service: service,
                                                      labId: widget.labId,
                                                      labName: widget.labName,
                                                    ),
                                              ),
                                            ),
                                          )
                                          .animate()
                                          .fadeIn(
                                            duration: 400.ms,
                                            delay: Duration(
                                              milliseconds: (index % 6) * 50,
                                            ),
                                          )
                                          .slideY(
                                            begin: 0.03,
                                            end: 0,
                                            curve: Curves.easeOutCubic,
                                          );
                                    },
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

  void _showFilterSheet() {
    _minPriceController.text = _minPrice?.toStringAsFixed(0) ?? '';
    _maxPriceController.text = _maxPrice?.toStringAsFixed(0) ?? '';
    var sort = _sortBy;

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
                      'فلترة التحاليل',
                      style: TextStyle(
                        color: RastUi.primaryText(context),
                        fontSize: Responsive.fontSize(context, 18),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: Responsive.spacing(context, 18)),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _sortChoice('الافتراضي', 'default', sort, (value) {
                          setSheetState(() => sort = value);
                        }),
                        _sortChoice('الأقل سعراً', 'price_low', sort, (value) {
                          setSheetState(() => sort = value);
                        }),
                        _sortChoice('الأعلى سعراً', 'price_high', sort, (
                          value,
                        ) {
                          setSheetState(() => sort = value);
                        }),
                        _sortChoice('الاسم', 'name', sort, (value) {
                          setSheetState(() => sort = value);
                        }),
                      ],
                    ),
                    SizedBox(height: Responsive.spacing(context, 18)),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _minPriceController,
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
                            controller: _maxPriceController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'أعلى سعر',
                              prefixIcon: Icon(Icons.payments_outlined),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: Responsive.spacing(context, 20)),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _sortBy = 'default';
                                _minPrice = null;
                                _maxPrice = null;
                                _minPriceController.clear();
                                _maxPriceController.clear();
                              });
                              Navigator.pop(ctx);
                            },
                            child: const Text('مسح'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              setState(() {
                                _sortBy = sort;
                                _minPrice = double.tryParse(
                                  _minPriceController.text.trim(),
                                );
                                _maxPrice = double.tryParse(
                                  _maxPriceController.text.trim(),
                                );
                              });
                              Navigator.pop(ctx);
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

  Widget _sortChoice(
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

  Widget _buildCategoriesStrip() {
    final categories = _categories
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    if (categories.isEmpty || widget.labId != null) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final isAll = index == 0;
          final selected = isAll
              ? _selectedCategoryId == null
              : _selectedCategoryId == _toInt(categories[index - 1]['id']);
          final label = isAll
              ? AppStrings.t(
                  'viewAll',
                  context.watch<AppSettingsProvider>().language,
                )
              : LocaleUtils.localizedName(
                  categories[index - 1],
                  context.watch<AppSettingsProvider>().isArabic,
                );

          return ChoiceChip(
            label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            selected: selected,
            showCheckmark: false,
            selectedColor: RastUi.purple,
            backgroundColor: const Color(0xFFE7E9F8),
            labelStyle: TextStyle(
              color: selected ? Colors.white : RastUi.textPurple,
              fontSize: Responsive.fontSize(context, 12),
              fontWeight: FontWeight.w600,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide.none,
            ),
            onSelected: (_) {
              setState(() {
                _selectedCategoryId = isAll
                    ? null
                    : _toInt(categories[index - 1]['id']);
              });
            },
          );
        },
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.medical_services_outlined,
            size: 72,
            color: AppTheme.onSurfaceVariant.withValues(alpha: 0.4),
          ),
          SizedBox(height: Responsive.spacing(context, 16)),
          Text(
            AppStrings.t(
              'noResultsFound',
              context.watch<AppSettingsProvider>().language,
            ),
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 15),
              color: AppTheme.onSurfaceVariant,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return GridView.builder(
      padding: EdgeInsets.all(Responsive.spacing(context, 16)),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.74,
        crossAxisSpacing: Responsive.spacing(context, 10),
        mainAxisSpacing: Responsive.spacing(context, 10),
      ),
      itemCount: 6,
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        highlightColor: Theme.of(context).colorScheme.surface,
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceVariant,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(Responsive.spacing(context, 24)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 56,
              color: AppTheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            SizedBox(height: Responsive.spacing(context, 16)),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: Responsive.fontSize(context, 13),
                color: AppTheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: Responsive.spacing(context, 20)),
            GradientFilledButtonIcon(
              onPressed: () => _loadData(reset: true),
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: Text(
                AppStrings.t(
                  'retry',
                  context.watch<AppSettingsProvider>().language,
                ),
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalysisCard extends StatefulWidget {
  final Map<String, dynamic> service;
  final String categoryName;
  final String? imageUrl;
  final bool isLabView;
  final bool isArabic;
  final String lang;
  final VoidCallback onTap;

  const _AnalysisCard({
    required this.service,
    required this.categoryName,
    this.imageUrl,
    required this.isLabView,
    required this.isArabic,
    required this.lang,
    required this.onTap,
  });

  @override
  State<_AnalysisCard> createState() => _AnalysisCardState();
}

class _AnalysisCardState extends State<_AnalysisCard> {
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _loadFavorite();
  }

  @override
  void didUpdateWidget(covariant _AnalysisCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (FavoritesService.itemId(oldWidget.service) !=
        FavoritesService.itemId(widget.service)) {
      _loadFavorite();
    }
  }

  Future<void> _loadFavorite() async {
    final value = await FavoritesService.isAnalysisFavorite(widget.service);
    if (mounted) setState(() => _isFavorite = value);
  }

  Future<void> _toggleFavorite() async {
    final value = await FavoritesService.toggleAnalysis(widget.service);
    if (!mounted) return;
    setState(() => _isFavorite = value);
  }

  @override
  Widget build(BuildContext context) {
    final service = widget.service;
    final price = ApiConfig.priceFromMap(service);
    final displayName = LocaleUtils.localizedName(service, widget.isArabic);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: RastUi.cardSurface(context),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 9,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned.fill(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(9, 9, 9, 0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: SizedBox(
                          height: 118,
                          width: double.infinity,
                          child:
                              (widget.imageUrl != null &&
                                  widget.imageUrl!.isNotEmpty)
                              ? CachedNetworkImage(
                                  imageUrl: widget.imageUrl!,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => _buildImageFallback(),
                                  errorWidget: (_, __, ___) =>
                                      _buildImageFallback(),
                                )
                              : _buildImageFallback(),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          Responsive.spacing(context, 8),
                          Responsive.spacing(context, 6),
                          Responsive.spacing(context, 8),
                          Responsive.spacing(context, 8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: Responsive.fontSize(context, 12),
                                color: RastUi.textPurple,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (widget.categoryName.isNotEmpty)
                              Text(
                                widget.categoryName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: Responsive.fontSize(context, 9),
                                  color: const Color(0xFFB5B0B8),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            Text(
                              price > 0
                                  ? '${price.toStringAsFixed(2)} ${AppStrings.t('sar', widget.lang)}'
                                  : '— ${AppStrings.t('sar', widget.lang)}',
                              style: TextStyle(
                                fontSize: Responsive.fontSize(context, 12),
                                color: RastUi.purple,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              PositionedDirectional(
                start: 12,
                top: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        color: AppTheme.accent,
                        size: 12,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '4.8',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: Responsive.fontSize(context, 8),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              PositionedDirectional(
                end: 8,
                top: 8,
                child: IconButton(
                  onPressed: _toggleFavorite,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    _isFavorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: const Color(0xFFFF4D61),
                    size: Responsive.fontSize(context, 21),
                  ),
                ),
              ),
              PositionedDirectional(
                end: 9,
                bottom: 8,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: RastUi.brandGradient,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: RastUi.purple.withValues(alpha: 0.28),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.add_rounded, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageFallback() {
    return Container(
      width: double.infinity,
      color: AppTheme.primary.withValues(alpha: 0.08),
      child: Icon(
        Icons.medical_services_outlined,
        size: 48,
        color: AppTheme.primary.withValues(alpha: 0.4),
      ),
    );
  }
}
