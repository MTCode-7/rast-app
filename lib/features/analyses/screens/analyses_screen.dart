import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:rast/core/api/api_client.dart';
import 'package:rast/core/api/api_services.dart';
import 'package:rast/core/constants/api_config.dart';
import 'package:rast/core/constants/app_strings.dart';
import 'package:rast/core/constants/dummy_data.dart';
import 'package:rast/core/onboarding/onboarding_catalog.dart';
import 'package:rast/core/onboarding/onboarding_host.dart';
import 'package:rast/core/onboarding/onboarding_step.dart';
import 'package:rast/core/onboarding/onboarding_tour_ids.dart';
import 'package:rast/core/providers/app_settings_provider.dart';
import 'package:rast/core/services/analytics_service.dart';
import 'package:rast/core/services/catalog_cache_service.dart';
import 'package:rast/core/utils/locale_utils.dart';
import 'package:rast/core/widgets/rast_kit.dart';
import 'package:rast/core/widgets/rast_motion.dart';
import 'package:rast/core/widgets/rast_ui.dart';
import 'package:rast/features/analyses/screens/service_detail_screen.dart';
import 'package:rast/features/analyses/widgets/test_row_card.dart';
import 'package:rast/features/offers/screens/offer_detail_screen.dart';
import 'package:rast/features/offers/widgets/offer_card.dart';

/// قائمة التحاليل: بحث فوري، تصنيفات، اقتراحات سريعة، وقائمة مقروءة بنظرة
/// (السعر الأقل، عدد المختبرات، مدة النتيجة، الحاجة للصيام) حتى يختار المستخدم التحليل بسهولة.
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

class _AnalysesScreenState extends State<AnalysesScreen> with OnboardingTourHost {
  static const int _pageSize = 24;
  final _searchKey = GlobalKey();
  final _filterKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _minPriceController = TextEditingController();
  final TextEditingController _maxPriceController = TextEditingController();
  Timer? _searchDebounce;
  List<dynamic> _services = [];
  List<dynamic> _categories = [];
  int? _selectedCategoryId;
  String _sortBy = 'default';
  double? _minPrice;
  double? _maxPrice;
  bool _onlyAvailable = false;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  int? _totalAvailable;
  String? _error;
  int _requestSeq = 0;

  // التبويب العلوي: 0 تحاليل وباقات، 1 عروض المختبرات
  int _tab = 0;

  /// شبكة أو قائمة (يختارها المستخدم وتُحفظ). شاشة تحاليل المختبر لها مفتاح مستقل.
  bool _grid = true;
  String get _viewKey => _isLabView ? 'lab_tests' : 'tests';

  void _setGrid(bool g) {
    setState(() => _grid = g);
    ViewModeStore.setGrid(_viewKey, g);
  }
  final List<Map<String, dynamic>> _offers = [];
  bool _offersLoading = false;
  int _offersPage = 0;
  int _offersLastPage = 1;
  String? _offersError;

  bool get _showAnalysesTour => widget.labId == null;
  bool get _isLabView => widget.labId != null;
  String get _query => _searchController.text.trim();

  bool get _hasActiveFilters =>
      _sortBy != 'default' || _minPrice != null || _maxPrice != null || _onlyAvailable;

  @override
  String? get onboardingTourId =>
      _showAnalysesTour ? OnboardingTourIds.analyses : null;

  @override
  List<OnboardingStep> buildOnboardingSteps() => OnboardingCatalog.analysesTour(
        searchKey: _searchKey,
        filterKey: _filterKey,
      );

  @override
  void initState() {
    super.initState();
    AnalyticsService.logScreen('tests');
    _selectedCategoryId = widget.categoryId;
    if (widget.initialSearchQuery != null &&
        widget.initialSearchQuery!.trim().isNotEmpty) {
      _searchController.text = widget.initialSearchQuery!.trim();
    }
    _scrollController.addListener(_onScroll);
    ViewModeStore.isGrid(_viewKey).then((g) {
      if (mounted && g != _grid) setState(() => _grid = g);
    });
    _loadFromCacheThenNetwork();
    if (_showAnalysesTour) {
      scheduleOnboardingTour(delay: const Duration(milliseconds: 900));
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  /// الصفحة الأولى المحفوظة تُعرض فوراً (فقط للقائمة العامة دون بحث أو تصنيف)، ثم تُحدّث من الخادم.
  Future<void> _loadFromCacheThenNetwork() async {
    final plainList = !_isLabView && _query.isEmpty && _selectedCategoryId == null;
    if (!_isLabView) {
      await CatalogCacheService.ensureHydrated();
      final hasCategories = CatalogCacheService.categories.isNotEmpty;
      final hasServices = plainList && CatalogCacheService.servicesPage1.isNotEmpty;
      if ((hasCategories || hasServices) && mounted) {
        setState(() {
          if (hasCategories) _categories = List.from(CatalogCacheService.categories);
          if (hasServices) {
            _services = List.from(CatalogCacheService.servicesPage1);
            _totalAvailable ??= _services.length;
            _isLoading = false;
          }
        });
      }
      await _loadData(reset: true, silent: hasServices);
    } else {
      await _loadData(reset: true);
    }
  }

  Future<void> _loadData({bool reset = false, bool silent = false}) async {
    if (!reset && (_isLoadingMore || !_hasMore)) return;
    final seq = ++_requestSeq;

    setState(() {
      if (reset) {
        if (!silent || _services.isEmpty) _isLoading = true;
        _currentPage = 1;
        _hasMore = true;
      } else {
        _isLoadingMore = true;
      }
      _error = null;
    });

    try {
      List<dynamic> categories = List.from(_categories);
      if (!_isLabView && (reset || categories.isEmpty) && categories.isEmpty) {
        try {
          categories = await Api.services.getCategories();
        } catch (_) {}
      }

      List<dynamic> servicesPage = [];
      bool canLoadMore = false;
      int? totalFromApi;
      final page = reset ? 1 : _currentPage;

      if (_isLabView) {
        final pageRes = await Api.providers.getProviderServicesPage(
          widget.labId!,
          page: page,
          perPage: _pageSize,
          q: _query.isEmpty ? null : _query,
        );
        servicesPage = pageRes.items;
        canLoadMore = pageRes.hasMore;
        totalFromApi = pageRes.total;
      } else {
        final res = await Api.services.getServices(
          categoryId: _selectedCategoryId,
          search: _query.isEmpty ? null : _query,
          page: page,
          perPage: _pageSize,
        );
        servicesPage = _extractServiceItems(res['data']);
        canLoadMore = _hasNextPage(res['data']) ?? servicesPage.length >= _pageSize;
        totalFromApi = _toInt((res['data'] is Map) ? (res['data'] as Map)['total'] : null);
      }

      // نتيجة طلب أقدم (المستخدم كتب حرفاً جديداً أو غيّر التصنيف) تُهمل
      if (!mounted || seq != _requestSeq) return;

      if (!_isLabView) {
        if (categories.isEmpty) categories = List.from(DummyData.categories);
        if (categories.isNotEmpty) unawaited(CatalogCacheService.saveCategories(categories));
        if (reset && servicesPage.isNotEmpty && _query.isEmpty && _selectedCategoryId == null) {
          unawaited(CatalogCacheService.saveServicesPage1(servicesPage));
        }
      }

      setState(() {
        _categories = categories;
        if (reset) {
          _services = servicesPage;
        } else {
          _services.addAll(servicesPage);
        }
        _currentPage = page + 1;
        _hasMore = canLoadMore;
        _totalAvailable = totalFromApi ?? _services.length;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _error = e is ApiException ? e.message : e.toString();
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
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
      if (currentPage != null && lastPage != null) return currentPage < lastPage;
      final nextUrl = data['next_page_url'];
      return nextUrl != null && nextUrl.toString().trim().isNotEmpty;
    }
    return null;
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final p = _scrollController.position;
    if (p.pixels < p.maxScrollExtent - 420) return;
    if (_tab == 1 && !_isLabView) {
      _loadOffers();
      return;
    }
    if (_isLoading || _isLoadingMore) return;
    _loadData();
  }

  void _onSearchChanged(String _) {
    setState(() {}); // زر المسح يظهر/يختفي
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 450), () {
      if (mounted) _loadData(reset: true);
    });
  }

  void _submitSearch(String v) {
    _searchDebounce?.cancel();
    FocusScope.of(context).unfocus();
    AnalyticsService.logSearch(v, area: 'tests');
    _loadData(reset: true);
  }

  void _applySuggestion(String q) {
    _searchController.text = q;
    _submitSearch(q);
  }

  void _clearSearch() {
    _searchController.clear();
    _searchDebounce?.cancel();
    _loadData(reset: true);
  }

  void _selectCategory(int? id) {
    if (_selectedCategoryId == id) return;
    setState(() => _selectedCategoryId = id);
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    _loadData(reset: true);
  }

  void _clearAll() {
    setState(() {
      _sortBy = 'default';
      _minPrice = null;
      _maxPrice = null;
      _onlyAvailable = false;
      _minPriceController.clear();
      _maxPriceController.clear();
      _selectedCategoryId = widget.categoryId;
    });
    _searchController.clear();
    _loadData(reset: true);
  }

  int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  String _categoryName(dynamic catId, bool isArabic) {
    if (catId == null) return '';
    for (final x in _categories) {
      if (x is Map && x['id']?.toString() == catId.toString()) {
        return LocaleUtils.localizedName(Map<String, dynamic>.from(x), isArabic);
      }
    }
    return '';
  }

  /// يحوّل عنصر القائمة إلى خريطة التحليل (في وضع المختبر العنصر هو «خدمة المختبر» وبداخله التحليل).
  Map<String, dynamic> _serviceOf(dynamic item) {
    if (!_isLabView) {
      return item is Map ? Map<String, dynamic>.from(item) : <String, dynamic>{};
    }
    final ps = item is Map ? Map<String, dynamic>.from(item) : <String, dynamic>{};
    final s = ps['service'] ?? ps;
    final service = s is Map ? Map<String, dynamic>.from(s) : <String, dynamic>{};
    service['price'] = ps['final_price'] ?? ps['price'] ?? service['price'];
    service['home_price'] = ps['home_service_price'] ?? ps['home_price'];
    service['provider_service_id'] = ps['id'];
    final psImg = ps['image']?.toString().trim();
    if (psImg != null && psImg.isNotEmpty) service['image'] = psImg;
    return service;
  }

  double _priceOf(Map<String, dynamic> service) {
    if (_isLabView) return ApiConfig.priceFromMap(service);
    return numOf(service['min_price']) ?? ApiConfig.priceFromMap(service);
  }

  List<dynamic> _visibleServices(bool isArabic) {
    final visible = _services.where((item) {
      final service = _serviceOf(item);
      // في وضع المختبر التصنيف يُرشّح محلياً (الخادم لا يدعمه هنا)
      if (_isLabView && _selectedCategoryId != null) {
        final cId = _toInt(service['category_id'] ?? service['service_category_id']);
        if (cId != _selectedCategoryId) return false;
      }
      final price = _priceOf(service);
      if (_onlyAvailable && price <= 0) return false;
      if (_minPrice != null && (price <= 0 || price < _minPrice!)) return false;
      if (_maxPrice != null && (price <= 0 || price > _maxPrice!)) return false;
      return true;
    }).toList();

    if (_sortBy != 'default') {
      // التحاليل غير المتوفرة (بلا سعر) دائماً في آخر القائمة عند الترتيب بالسعر
      double sortPrice(dynamic x, {required bool asc}) {
        final p = _priceOf(_serviceOf(x));
        if (p > 0) return p;
        return asc ? double.infinity : -1;
      }

      visible.sort((a, b) {
        switch (_sortBy) {
          case 'price_low':
            return sortPrice(a, asc: true).compareTo(sortPrice(b, asc: true));
          case 'price_high':
            return sortPrice(b, asc: false).compareTo(sortPrice(a, asc: false));
          case 'name':
            return LocaleUtils.localizedName(_serviceOf(a), isArabic)
                .compareTo(LocaleUtils.localizedName(_serviceOf(b), isArabic));
          default:
            return 0;
        }
      });
    }
    return visible;
  }

  void _openService(Map<String, dynamic> service) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ServiceDetailScreen(
          service: service,
          labId: widget.labId,
          labName: widget.labName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();
    final lang = settings.language;
    final isArabic = settings.isArabic;
    final title = widget.labName ?? L(lang, 'عن ماذا تبحث اليوم؟', 'What are you looking for?');
    final visible = _visibleServices(isArabic);
    final showOffers = !_isLabView && _tab == 1;

    return Scaffold(
      backgroundColor: RastTokens.bg(context),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight + 8),
        child: Container(
          color: RastTokens.card(context),
          child: SafeArea(
            bottom: false,
            child: RastTopBar(
              title: title,
              showCart: true,
              useWhiteBackground: true,
              backgroundColor: RastTokens.card(context),
              helpTourId: _showAnalysesTour ? OnboardingTourIds.analyses : null,
              helpTourSteps: _showAnalysesTour ? buildOnboardingSteps() : null,
            ),
          ),
        ),
      ),
      body: Directionality(
        textDirection: settings.textDirection,
        child: RefreshIndicator(
          color: RastTokens.brand,
          onRefresh: () => showOffers ? _loadOffers(reset: true) : _loadData(reset: true),
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverToBoxAdapter(child: _buildTopControls(lang, isArabic, visible.length)),
              if (showOffers)
                ..._buildOfferSlivers(lang)
              else if (_isLoading)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  sliver: _grid
                      ? SliverGrid(
                          gridDelegate: _gridDelegate(context),
                          delegate: SliverChildBuilderDelegate(
                            (_, __) => const RastSkeleton(radius: 18),
                            childCount: 6,
                          ),
                        )
                      : SliverList.separated(
                          itemCount: 7,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, __) => const _TestRowSkeleton(),
                        ),
                )
              else if (_error != null && _services.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: RastEmptyState(
                      icon: Icons.cloud_off_rounded,
                      title: L(lang, 'تعذّر تحميل التحاليل', 'Could not load tests'),
                      message: L(lang, 'تحقّق من اتصالك بالإنترنت ثم حاول مرة أخرى.',
                          'Check your connection and try again.'),
                      actionLabel: AppStrings.t('retry', lang),
                      onAction: () => _loadData(reset: true),
                    ),
                  ),
                )
              else if (visible.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: RastEmptyState(
                      icon: Icons.search_off_rounded,
                      title: L(lang, 'لا توجد تحاليل مطابقة', 'No matching tests'),
                      message: L(
                        lang,
                        'جرّب كتابة الاسم بطريقة أخرى (مثل: فيتامين د أو Vitamin D)، أو امسح الفلاتر.',
                        'Try another spelling (e.g. Vitamin D), or clear the filters.',
                      ),
                      actionLabel: (_query.isNotEmpty || _hasActiveFilters || _selectedCategoryId != widget.categoryId)
                          ? L(lang, 'مسح البحث والفلاتر', 'Clear search & filters')
                          : null,
                      onAction: _clearAll,
                    ),
                  ),
                )
              else ...[
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, _isLoadingMore ? 0 : 28),
                  sliver: _grid
                      ? SliverGrid(
                          gridDelegate: _gridDelegate(context),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => _testCard(visible[index], index, lang, isArabic, grid: true),
                            childCount: visible.length,
                          ),
                        )
                      : SliverList.separated(
                          itemCount: visible.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) => _testCard(visible[index], index, lang, isArabic, grid: false),
                        ),
                ),
                if (_isLoadingMore)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(top: 18, bottom: 28),
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// شبكة عمودين بارتفاع ثابت للخلايا (صفوف متساوية ولا تجاوز على الشاشات الضيقة)
  SliverGridDelegate _gridDelegate(BuildContext context, {double body = 118}) =>
      SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: ViewModeStore.gridExtent(MediaQuery.sizeOf(context).width, body: body),
      );

  Widget _testCard(dynamic item, int index, String lang, bool isArabic, {required bool grid}) {
    final service = _serviceOf(item);
    final providerSvc = _isLabView && item is Map ? Map<String, dynamic>.from(item) : null;
    final card = TestRowCard(
      key: ValueKey('test-${grid ? 'g' : 'l'}-${service['id']}-${service['provider_service_id'] ?? ''}'),
      service: service,
      lang: lang,
      isArabic: isArabic,
      categoryName: _categoryName(
        service['category_id'] ?? service['service_category_id'] ?? (service['category'] is Map ? service['category']['id'] : null),
        isArabic,
      ),
      imageUrl: ApiConfig.analysisImageUrl(service, providerSvc),
      price: _priceOf(service),
      labsCount: _isLabView ? null : _toInt(service['labs_count']),
      isLabView: _isLabView,
      grid: grid,
      onTap: () => _openService(service),
    );
    return index < 10 ? card.entrance(index) : card;
  }

  Widget _buildTopControls(String lang, bool isArabic, int visibleCount) {
    final categories = _categories.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    final total = _totalAvailable ?? _services.length;
    final showSuggestions = !_isLabView && _query.isEmpty && _selectedCategoryId == null;

    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: KeyedSubtree(
                    key: _searchKey,
                    child: RastSearchField(
                      controller: _searchController,
                      hint: _isLabView
                          ? L(lang, 'ابحث في تحاليل هذا المختبر', 'Search this lab\'s tests')
                          : L(lang, 'ابحث: فيتامين د، السكر التراكمي، الغدة…', 'Search: Vitamin D, HbA1c, Thyroid…'),
                      onChanged: _onSearchChanged,
                      onSubmitted: _submitSearch,
                      trailing: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: L(lang, 'مسح', 'Clear'),
                              onPressed: _clearSearch,
                              icon: Icon(Icons.close_rounded, color: RastTokens.muted(context), size: 20),
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                KeyedSubtree(key: _filterKey, child: _buildFilterButton()),
                const SizedBox(width: 8),
                _buildSortButton(lang),
              ],
            ),
          ),
          if (!_isLabView) ...[
            const SizedBox(height: 14),
            _buildTabs(lang),
          ],
          if (_tab == 1 && !_isLabView)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      L(lang, 'عروض المختبرات', 'Lab offers'),
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: RastTokens.ink(context)),
                    ),
                  ),
                  ViewModeToggle(grid: _grid, onChanged: _setGrid, height: 40),
                ],
              ),
            )
          else ...[
          if (showSuggestions) ...[
            const SizedBox(height: 12),
            _buildSuggestions(lang),
          ],
          if (categories.isNotEmpty && !_isLabView) ...[
            const SizedBox(height: 14),
            _buildCategoryCircles(categories, lang, isArabic),
          ],
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: Text(
                      _isLoading
                          ? L(lang, 'جارٍ التحميل…', 'Loading…')
                          : (_query.isNotEmpty
                              ? L(lang, 'نتائج «$_query»: $total', 'Results for "$_query": $total')
                              : L(lang, '$total تحليل', '$total tests')),
                      key: ValueKey('$_isLoading-$_query-$total'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: RastTokens.ink(context)),
                    ),
                  ),
                ),
                if (_hasActiveFilters)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _sortBy = 'default';
                        _minPrice = null;
                        _maxPrice = null;
                        _onlyAvailable = false;
                      });
                    },
                    child: RastPill(
                      icon: Icons.close_rounded,
                      label: L(lang, 'إلغاء الفلاتر', 'Clear filters'),
                      dense: true,
                    ),
                  ),
                const SizedBox(width: 8),
                ViewModeToggle(grid: _grid, onChanged: _setGrid, height: 40),
              ],
            ),
          ),
          ],
        ],
      ),
    );
  }

  // ---------------- التبويب العلوي: تحاليل وباقات / عروض ----------------

  Widget _buildTabs(String lang) {
    final labels = [L(lang, 'تحاليل وباقات', 'Tests & packages'), L(lang, 'العروض', 'Offers')];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 46,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: RastTokens.fill(context),
          borderRadius: BorderRadius.circular(14),
        ),
        child: LayoutBuilder(
          builder: (context, c) {
            final w = (c.maxWidth) / 2;
            final rtl = Directionality.of(context) == TextDirection.rtl;
            return Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  top: 0,
                  bottom: 0,
                  left: rtl ? (_tab == 0 ? w : 0) : (_tab == 0 ? 0 : w),
                  width: w,
                  child: Container(
                    decoration: BoxDecoration(
                      color: RastTokens.card(context),
                      borderRadius: BorderRadius.circular(11),
                      boxShadow: RastTokens.shadow(context, strength: 0.8),
                    ),
                  ),
                ),
                Row(
                  children: List.generate(2, (i) {
                    final on = _tab == i;
                    return Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _switchTab(i),
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                i == 0 ? Icons.biotech_rounded : Icons.local_offer_rounded,
                                size: 17,
                                color: on ? RastTokens.brand : RastTokens.muted(context),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                labels[i],
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: on ? FontWeight.w800 : FontWeight.w600,
                                  color: on ? RastTokens.ink(context) : RastTokens.muted(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _switchTab(int i) {
    if (_tab == i) return;
    HapticFeedback.selectionClick();
    setState(() => _tab = i);
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    if (i == 1 && _offers.isEmpty && !_offersLoading) _loadOffers(reset: true);
  }

  // ---------------- دوائر التصنيفات بالصور ----------------

  Widget _buildCategoryCircles(List<Map<String, dynamic>> categories, String lang, bool isArabic) {
    final items = <Map<String, dynamic>?>[null, ...categories];
    return SizedBox(
      height: 98,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, i) {
          final c = items[i];
          final id = c == null ? null : _toInt(c['id']);
          final on = _selectedCategoryId == id;
          final name = c == null ? L(lang, 'الكل', 'All') : LocaleUtils.localizedName(c, isArabic);
          final img = c == null ? null : ApiConfig.resolveImageUrl(c['icon_url'] ?? c['image_url'], c['icon'] ?? c['image']);
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              _selectCategory(id);
            },
            child: SizedBox(
              width: 70,
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 240),
                    width: 64,
                    height: 64,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: on ? RastTokens.brandGradient : null,
                      color: on ? null : RastTokens.line(context),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(shape: BoxShape.circle, color: RastTokens.card(context)),
                      child: ClipOval(
                        child: c == null
                            ? Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      RastTokens.brand.withValues(alpha: 0.12),
                                      RastTokens.brand2.withValues(alpha: 0.12),
                                    ],
                                  ),
                                ),
                                child: const Icon(Icons.apps_rounded, color: RastTokens.brand, size: 26),
                              )
                            : RastNetImage(url: img, radius: 0, fallbackIcon: Icons.science_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.2,
                      fontWeight: on ? FontWeight.w800 : FontWeight.w600,
                      color: on ? RastTokens.brand : RastTokens.ink(context),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ---------------- زر الترتيب السريع ----------------

  Widget _buildSortButton(String lang) {
    final active = _sortBy != 'default';
    return Pressable(
      onTap: () => _showSortSheet(lang),
      child: Container(
        width: 48,
        height: 52,
        decoration: BoxDecoration(
          color: active ? RastTokens.brandSoft(context) : RastTokens.card(context),
          borderRadius: BorderRadius.circular(16),
          boxShadow: RastTokens.shadow(context, strength: 0.6),
        ),
        child: Icon(Icons.swap_vert_rounded, color: RastTokens.brand, size: 22),
      ),
    );
  }

  void _showSortSheet(String lang) {
    final sorts = <String, (String, IconData)>{
      'default': (L(lang, 'الأنسب', 'Recommended'), Icons.auto_awesome_rounded),
      'price_low': (AppStrings.t('priceLowToHigh', lang), Icons.trending_up_rounded),
      'price_high': (AppStrings.t('priceHighToLow', lang), Icons.trending_down_rounded),
      'name': (AppStrings.t('sortByName', lang), Icons.sort_by_alpha_rounded),
    };
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: context.read<AppSettingsProvider>().textDirection,
        child: Container(
          padding: EdgeInsets.fromLTRB(16, 10, 16, 16 + MediaQuery.of(ctx).padding.bottom),
          decoration: BoxDecoration(
            color: RastTokens.card(ctx),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(color: RastTokens.line(ctx), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 14),
              Text(L(lang, 'ترتيب حسب', 'Sort by'),
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: RastTokens.ink(ctx))),
              const SizedBox(height: 8),
              for (final e in sorts.entries)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: RastIconBox(icon: e.value.$2, size: 36),
                  title: Text(
                    e.value.$1,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: _sortBy == e.key ? FontWeight.w800 : FontWeight.w600,
                      color: RastTokens.ink(ctx),
                    ),
                  ),
                  trailing: _sortBy == e.key
                      ? const Icon(Icons.check_circle_rounded, color: RastTokens.brand)
                      : null,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _sortBy = e.key);
                    Navigator.pop(ctx);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- تبويب العروض ----------------

  Future<void> _loadOffers({bool reset = false}) async {
    if (!reset && (_offersLoading || _offersPage >= _offersLastPage)) return;
    setState(() {
      _offersLoading = true;
      if (reset) _offersError = null;
    });
    try {
      final page = reset ? 1 : _offersPage + 1;
      final res = await Api.growth.offers(page: page);
      if (!mounted) return;
      final rows = (res['data'] is List ? res['data'] as List : const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      setState(() {
        if (reset) _offers.clear();
        _offers.addAll(rows);
        _offersPage = page;
        _offersLastPage = (numOf(res['last_page']) ?? 1).toInt();
        _offersLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _offersError = e is ApiException ? e.message : e.toString();
        _offersLoading = false;
      });
    }
  }

  List<Widget> _buildOfferSlivers(String lang) {
    final q = _query.toLowerCase();
    final list = q.isEmpty
        ? _offers
        : _offers.where((o) {
            final v = OfferView(o);
            return v.title(lang).toLowerCase().contains(q) || v.providerName(lang).toLowerCase().contains(q);
          }).toList();

    if (_offersLoading && _offers.isEmpty) {
      return [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          sliver: SliverList.separated(
            itemCount: 4,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, __) => const RastSkeleton(height: 200, radius: 20),
          ),
        ),
      ];
    }
    if (_offersError != null && _offers.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: RastEmptyState(
              icon: Icons.cloud_off_rounded,
              title: L(lang, 'تعذّر تحميل العروض', 'Could not load offers'),
              actionLabel: AppStrings.t('retry', lang),
              onAction: () => _loadOffers(reset: true),
            ),
          ),
        ),
      ];
    }
    if (list.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: RastEmptyState(
              icon: Icons.local_offer_outlined,
              title: q.isEmpty
                  ? L(lang, 'لا توجد عروض حالياً', 'No offers right now')
                  : L(lang, 'لا توجد عروض مطابقة', 'No matching offers'),
              message: L(lang, 'المختبرات تضيف عروضاً جديدة باستمرار، عد قريباً.',
                  'Labs add new deals all the time — check back soon.'),
            ),
          ),
        ),
      ];
    }
    Widget offerCard(BuildContext context, int i) {
      final offer = list[i];
      final card = OfferCard(
        key: ValueKey('offer-${_grid ? 'g' : 'l'}-${offer['id']}'),
        offer: offer,
        lang: lang,
        grid: _grid,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => OfferDetailScreen(offer: offer)),
        ),
      );
      return i < 8 ? card.entrance(i) : card;
    }

    return [
      SliverPadding(
        padding: EdgeInsets.fromLTRB(16, 6, 16, _offersLoading ? 0 : 28),
        sliver: _grid
            ? SliverGrid(
                gridDelegate: _gridDelegate(context, body: 104),
                delegate: SliverChildBuilderDelegate(offerCard, childCount: list.length),
              )
            : SliverList.separated(
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: offerCard,
              ),
      ),
      if (_offersLoading)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(top: 18, bottom: 28),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
          ),
        ),
    ];
  }

  /// اقتراحات سريعة لأكثر التحاليل طلباً: لمسة واحدة بدل الكتابة.
  Widget _buildSuggestions(String lang) {
    final items = lang == 'en'
        ? const ['Vitamin D', 'CBC', 'HbA1c', 'TSH', 'Iron', 'Lipid profile']
        : const ['فيتامين د', 'صورة الدم', 'السكر التراكمي', 'الغدة الدرقية', 'الحديد', 'الدهون'];
    return SizedBox(
      height: 34,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: items.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          if (i == 0) {
            return Center(
              child: Padding(
                padding: const EdgeInsetsDirectional.only(end: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.local_fire_department_rounded, size: 16, color: RastTokens.warning),
                    const SizedBox(width: 3),
                    Text(
                      L(lang, 'الأكثر طلباً', 'Popular'),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: RastTokens.muted(context)),
                    ),
                  ],
                ),
              ),
            );
          }
          final q = items[i - 1];
          return ActionChip(
            label: Text(q),
            onPressed: () {
              HapticFeedback.selectionClick();
              _applySuggestion(q);
            },
            visualDensity: VisualDensity.compact,
            labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: RastTokens.brand),
            backgroundColor: RastTokens.brandSoft(context),
            side: BorderSide.none,
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 6),
          );
        },
      ),
    );
  }

  Widget _buildFilterButton() {
    return Pressable(
      onTap: _showFilterSheet,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: _hasActiveFilters ? null : RastTokens.card(context),
          gradient: _hasActiveFilters ? RastTokens.brandGradient : null,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _hasActiveFilters ? Colors.transparent : RastTokens.line(context)),
          boxShadow: RastTokens.shadow(context, strength: 0.6),
        ),
        child: Icon(
          Icons.tune_rounded,
          color: _hasActiveFilters ? Colors.white : RastTokens.brand,
          size: 22,
        ),
      ),
    );
  }

  void _showFilterSheet() {
    final settings = context.read<AppSettingsProvider>();
    final lang = settings.language;
    _minPriceController.text = _minPrice?.toStringAsFixed(0) ?? '';
    _maxPriceController.text = _maxPrice?.toStringAsFixed(0) ?? '';
    var sort = _sortBy;
    var onlyAvailable = _onlyAvailable;

    final sorts = <String, String>{
      'default': L(lang, 'الأنسب', 'Recommended'),
      'price_low': AppStrings.t('priceLowToHigh', lang),
      'price_high': AppStrings.t('priceHighToLow', lang),
      'name': AppStrings.t('sortByName', lang),
    };

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
              20 + MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom,
            ),
            decoration: BoxDecoration(
              color: RastTokens.card(ctx),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
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
                        color: RastTokens.line(ctx),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const RastIconBox(icon: Icons.tune_rounded, size: 38),
                      const SizedBox(width: 10),
                      Text(
                        AppStrings.t('filterAnalyses', lang),
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: RastTokens.ink(ctx)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _sheetLabel(ctx, L(lang, 'الترتيب', 'Sort by')),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: sorts.entries
                        .map((e) => _sheetChoice(ctx, e.value, sort == e.key, () => setSheetState(() => sort = e.key)))
                        .toList(),
                  ),
                  const SizedBox(height: 18),
                  _sheetLabel(ctx, L(lang, 'نطاق السعر (ر.س)', 'Price range (SAR)')),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _priceField(ctx, _minPriceController, AppStrings.t('minimumPrice', lang))),
                      const SizedBox(width: 10),
                      Expanded(child: _priceField(ctx, _maxPriceController, AppStrings.t('maximumPrice', lang))),
                    ],
                  ),
                  if (!_isLabView) ...[
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: RastTokens.fill(ctx),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: SwitchListTile.adaptive(
                        value: onlyAvailable,
                        onChanged: (v) => setSheetState(() => onlyAvailable = v),
                        activeThumbColor: RastTokens.brand,
                        title: Text(
                          L(lang, 'المتوفر للحجز فقط', 'Bookable only'),
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: RastTokens.ink(ctx)),
                        ),
                        subtitle: Text(
                          L(lang, 'إخفاء التحاليل التي لا يقدّمها أي مختبر حالياً', 'Hide tests no lab offers right now'),
                          style: TextStyle(fontSize: 12, color: RastTokens.muted(ctx)),
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: RastButton(
                          label: AppStrings.t('clear', lang),
                          secondary: true,
                          onPressed: () {
                            setState(() {
                              _sortBy = 'default';
                              _minPrice = null;
                              _maxPrice = null;
                              _onlyAvailable = false;
                              _minPriceController.clear();
                              _maxPriceController.clear();
                            });
                            Navigator.pop(ctx);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: RastButton(
                          label: AppStrings.t('apply', lang),
                          icon: Icons.check_rounded,
                          onPressed: () {
                            setState(() {
                              _sortBy = sort;
                              _onlyAvailable = onlyAvailable;
                              _minPrice = double.tryParse(_minPriceController.text.trim());
                              _maxPrice = double.tryParse(_maxPriceController.text.trim());
                            });
                            Navigator.pop(ctx);
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
    );
  }

  Widget _sheetLabel(BuildContext ctx, String text) => Text(
        text,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: RastTokens.muted(ctx)),
      );

  Widget _sheetChoice(BuildContext ctx, String label, bool on, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          gradient: on ? RastTokens.brandGradient : null,
          color: on ? null : RastTokens.fill(ctx),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: on ? FontWeight.w800 : FontWeight.w600,
            color: on ? Colors.white : RastTokens.ink(ctx),
          ),
        ),
      ),
    );
  }

  Widget _priceField(BuildContext ctx, TextEditingController c, String label) {
    return TextField(
      controller: c,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.payments_outlined, size: 20),
        filled: true,
        fillColor: RastTokens.fill(ctx),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: RastTokens.brand, width: 1.4),
        ),
      ),
    );
  }
}

class _TestRowSkeleton extends StatelessWidget {
  const _TestRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return RastCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const RastSkeleton(width: 96, height: 96, radius: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                RastSkeleton(width: 160, height: 15),
                SizedBox(height: 8),
                RastSkeleton(width: 110, height: 11),
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: RastSkeleton(height: 20)),
                    SizedBox(width: 40),
                    RastSkeleton(width: 38, height: 38, radius: 12),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
