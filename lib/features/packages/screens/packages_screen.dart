import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rast/core/api/api_client.dart';
import 'package:rast/core/api/api_services.dart';
import 'package:rast/core/constants/app_strings.dart';
import 'package:rast/core/providers/app_settings_provider.dart';
import 'package:rast/core/services/analytics_service.dart';
import 'package:rast/core/services/catalog_cache_service.dart';
import 'package:rast/core/widgets/rast_kit.dart';
import 'package:rast/core/widgets/rast_motion.dart';
import 'package:rast/core/widgets/rast_ui.dart';
import 'package:rast/features/packages/screens/package_detail_screen.dart';
import 'package:rast/features/packages/widgets/package_card.dart';
import 'package:rast/features/analyses/widgets/test_row_card.dart' show ViewModeStore, ViewModeToggle;

/// قائمة الباقات: بحث فوري، بطاقات أنيقة بصورة الباقة وسعرها وعدد تحاليلها وخصمها.
class PackagesScreen extends StatefulWidget {
  final String? initialSearchQuery;
  const PackagesScreen({super.key, this.initialSearchQuery});

  @override
  State<PackagesScreen> createState() => _PackagesScreenState();
}

class _PackagesScreenState extends State<PackagesScreen> {
  static const int _pageSize = 20;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounce;
  List<dynamic> _packages = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  int? _totalAvailable;
  String? _errorMessage;
  int _requestSeq = 0;

  String get _query => _searchController.text.trim();
  bool _grid = true;

  @override
  void initState() {
    super.initState();
    AnalyticsService.logScreen('packages');
    ViewModeStore.isGrid('packages').then((g) {
      if (mounted && g != _grid) setState(() => _grid = g);
    });
    _searchController.text = widget.initialSearchQuery?.trim() ?? '';
    _scrollController.addListener(_onScroll);
    if (_searchController.text.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _runPackageSearch();
      });
    } else {
      _loadFromCacheThenNetwork();
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFromCacheThenNetwork() async {
    await CatalogCacheService.ensureHydrated();
    final hasCache = CatalogCacheService.packagesPage1.isNotEmpty;
    if (hasCache && mounted) {
      setState(() {
        _packages = List.from(CatalogCacheService.packagesPage1);
        _totalAvailable ??= _packages.length;
        _isLoading = false;
      });
    }
    await _loadData(reset: true, silent: hasCache);
  }

  Future<void> _loadData({bool reset = false, bool silent = false}) async {
    if (!reset && (_isLoadingMore || !_hasMore)) return;
    final seq = ++_requestSeq;
    setState(() {
      if (reset) {
        if (!silent || _packages.isEmpty) _isLoading = true;
        _currentPage = 1;
        _hasMore = true;
      } else {
        _isLoadingMore = true;
      }
      _errorMessage = null;
    });

    try {
      final page = reset ? 1 : _currentPage;
      final res = await Api.services.getPackages(page: page, perPage: _pageSize);
      final data = res['data'];
      final list = data is List
          ? List.from(data)
          : (data is Map && data['data'] is List ? List.from(data['data'] as List) : <dynamic>[]);
      if (!mounted || seq != _requestSeq) return;
      if (reset && list.isNotEmpty) unawaited(CatalogCacheService.savePackagesPage1(list));
      setState(() {
        if (reset) {
          _packages = list;
        } else {
          _packages.addAll(list);
        }
        _totalAvailable = _readTotal(data) ?? _packages.length;
        _hasMore = _hasNextPage(data) ?? list.length >= _pageSize;
        _currentPage = page + 1;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _errorMessage = e is ApiException ? e.message : e.toString();
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  int? _readTotal(dynamic data) {
    if (data is! Map) return null;
    final total = data['total'] ?? (data['meta'] is Map ? (data['meta'] as Map)['total'] : null);
    return _toInt(total);
  }

  bool? _hasNextPage(dynamic data) {
    if (data is! Map) return null;
    final meta = data['meta'] is Map ? data['meta'] as Map : const {};
    final currentPage = _toInt(data['current_page'] ?? meta['current_page']);
    final lastPage = _toInt(data['last_page'] ?? meta['last_page']);
    if (currentPage != null && lastPage != null) return currentPage < lastPage;
    final next = (data['next_page_url'] ?? meta['next_page_url'])?.toString().trim();
    return next != null && next.isNotEmpty;
  }

  int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  void _onScroll() {
    // نتائج البحث تأتي كاملة دون صفحات
    if (_query.isNotEmpty) return;
    if (!_scrollController.hasClients || _isLoading || _isLoadingMore) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 360) _loadData();
  }

  Future<void> _runPackageSearch() async {
    final query = _query;
    if (query.isEmpty) {
      await _loadData(reset: true);
      return;
    }
    final seq = ++_requestSeq;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final results = await Api.services.searchPackages(query);
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _packages = List<dynamic>.from(results);
        _totalAvailable = _packages.length;
        _hasMore = false;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _errorMessage = e is ApiException ? e.message : e.toString();
        _packages = [];
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  void _onSearchChanged(String _) {
    setState(() {});
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 450), () {
      if (mounted) _runPackageSearch();
    });
  }

  void _submitSearch(String v) {
    _searchDebounce?.cancel();
    FocusScope.of(context).unfocus();
    AnalyticsService.logSearch(v, area: 'packages');
    _runPackageSearch();
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    _loadData(reset: true);
  }

  SliverGridDelegate _gridDelegate(BuildContext context) => SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: ViewModeStore.gridExtent(MediaQuery.sizeOf(context).width, body: 104),
      );

  Widget _card(int index, String lang, bool isArabic) {
    final pkg = _packages[index] is Map ? Map<String, dynamic>.from(_packages[index] as Map) : <String, dynamic>{};
    final card = PackageCard(
      key: ValueKey('pkg-${_grid ? 'g' : 'l'}-${pkg['id']}-${pkg['provider_service_id'] ?? ''}'),
      package: pkg,
      lang: lang,
      isArabic: isArabic,
      grid: _grid,
      onTap: () => _openPackage(pkg),
    );
    return index < 6 ? card.entrance(index) : card;
  }

  void _openPackage(Map<String, dynamic> pkg) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PackageDetailScreen(package: pkg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();
    final lang = settings.language;
    final total = _totalAvailable ?? _packages.length;

    return Directionality(
      textDirection: settings.textDirection,
      child: Scaffold(
        backgroundColor: RastTokens.bg(context),
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight + 8),
          child: Container(
            color: RastTokens.card(context),
            child: SafeArea(
              bottom: false,
              child: RastTopBar(
                title: AppStrings.t('packagesPageTitle', lang),
                showCart: true,
                useWhiteBackground: true,
                backgroundColor: RastTokens.card(context),
                onBack: () => Navigator.pop(context),
              ),
            ),
          ),
        ),
        body: RefreshIndicator(
          color: RastTokens.brand,
          onRefresh: () => _query.isEmpty ? _loadData(reset: true) : _runPackageSearch(),
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RastSearchField(
                        controller: _searchController,
                        hint: L(lang, 'ابحث عن باقة: شاملة، فيتامينات، ما قبل الزواج…',
                            'Search packages: full checkup, vitamins…'),
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
                      const SizedBox(height: 12),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _isLoading
                                  ? L(lang, 'جارٍ التحميل…', 'Loading…')
                                  : (_query.isNotEmpty
                                      ? L(lang, 'نتائج «$_query»: $total', 'Results for "$_query": $total')
                                      : L(lang, '$total باقة متاحة', '$total packages')),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: RastTokens.ink(context)),
                            ),
                          ),
                          ViewModeToggle(
                            grid: _grid,
                            height: 40,
                            onChanged: (g) {
                              setState(() => _grid = g);
                              ViewModeStore.setGrid('packages', g);
                            },
                          ),
                        ],
                      ),
                      if (_errorMessage != null && _packages.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        RastPill(
                          icon: Icons.wifi_off_rounded,
                          label: AppStrings.t('showingCachedData', lang),
                          color: RastTokens.warning,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (_isLoading)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  sliver: _grid
                      ? SliverGrid(
                          gridDelegate: _gridDelegate(context),
                          delegate: SliverChildBuilderDelegate((_, __) => const RastSkeleton(radius: 18), childCount: 6),
                        )
                      : SliverList.separated(
                          itemCount: 3,
                          separatorBuilder: (_, __) => const SizedBox(height: 14),
                          itemBuilder: (_, __) => const PackageCardSkeleton(),
                        ),
                )
              else if (_packages.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: _errorMessage != null
                        ? RastEmptyState(
                            icon: Icons.cloud_off_rounded,
                            title: L(lang, 'تعذّر تحميل الباقات', 'Could not load packages'),
                            message: L(lang, 'تحقّق من اتصالك بالإنترنت ثم حاول مرة أخرى.',
                                'Check your connection and try again.'),
                            actionLabel: AppStrings.t('retry', lang),
                            onAction: () => _query.isEmpty ? _loadData(reset: true) : _runPackageSearch(),
                          )
                        : RastEmptyState(
                            icon: Icons.inventory_2_outlined,
                            title: _query.isNotEmpty
                                ? L(lang, 'لا توجد باقات مطابقة', 'No matching packages')
                                : AppStrings.t('noPackagesAvailable', lang),
                            message: _query.isNotEmpty
                                ? L(lang, 'جرّب كلمة أخرى أو تصفّح كل الباقات.', 'Try another word or browse all packages.')
                                : null,
                            actionLabel: _query.isNotEmpty ? L(lang, 'عرض كل الباقات', 'Show all packages') : null,
                            onAction: _clearSearch,
                          ),
                  ),
                )
              else ...[
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, _isLoadingMore ? 0 : 28),
                  sliver: _grid
                      ? SliverGrid(
                          gridDelegate: _gridDelegate(context),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => _card(index, lang, settings.isArabic),
                            childCount: _packages.length,
                          ),
                        )
                      : SliverList.separated(
                          itemCount: _packages.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 14),
                          itemBuilder: (context, index) => _card(index, lang, settings.isArabic),
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
}
