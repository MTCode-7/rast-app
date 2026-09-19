import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'dart:async';

import 'package:rast/core/api/api_client.dart';
import 'package:rast/core/services/catalog_cache_service.dart';
import 'package:rast/core/api/api_services.dart';
import 'package:rast/core/constants/api_config.dart';
import 'package:rast/core/constants/app_strings.dart';
import 'package:rast/core/constants/dummy_data.dart';
import 'package:rast/core/providers/app_settings_provider.dart';
import 'package:rast/core/theme/app_theme.dart';
import 'package:rast/core/utils/locale_utils.dart';
import 'package:rast/core/utils/responsive.dart';
import 'package:rast/features/packages/screens/package_detail_screen.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/widgets/rast_ui.dart';

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
  List<dynamic> _packages = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  int? _totalAvailable;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _searchController.text =
        widget.initialSearchQuery?.trim() ?? '';

    _scrollController.addListener(_onScroll);

    if (_searchController.text.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _runPackageSearch();
      });
    } else {
      _loadFromCacheThenNetwork();
    }
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
    if (_isLoadingMore) return;
    if (!reset && !_hasMore) return;

    if (reset) {
      setState(() {
        if (!silent || _packages.isEmpty) _isLoading = true;
        _errorMessage = null;
        _currentPage = 1;
        _hasMore = true;
      });
    } else {
      setState(() {
        _isLoadingMore = true;
        _errorMessage = null;
      });
    }
    try {
      final res = await Api.services.getPackages(
        page: _currentPage,
        perPage: _pageSize,
      );
      final data = res['data'];
      final list = data is List
          ? List.from(data)
          : (data is Map && data['data'] is List
                ? List.from(data['data'] as List)
                : []);
      final total = _readTotal(data);
      final canLoadMore = _hasNextPage(data) ?? list.length >= _pageSize;

      if (reset && list.isEmpty) {
        final fallback = List.from(DummyData.packages);
        setState(() {
          _packages = fallback;
          _totalAvailable = fallback.length;
          _isLoading = false;
          _isLoadingMore = false;
          _hasMore = false;
        });
        return;
      }

      if (reset && list.isNotEmpty) {
        unawaited(CatalogCacheService.savePackagesPage1(list));
      }
      setState(() {
        if (reset) {
          _packages = list;
        } else {
          _packages.addAll(list);
        }
        _totalAvailable = total ?? _totalAvailable ?? _packages.length;
        _hasMore = canLoadMore;
        _currentPage += 1;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _errorMessage = e.message;
        if (reset) {
          _packages = List.from(DummyData.packages);
          _totalAvailable = _packages.length;
          _hasMore = false;
        }
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        if (reset) {
          _packages = List.from(DummyData.packages);
          _totalAvailable = _packages.length;
          _hasMore = false;
        }
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  int? _readTotal(dynamic data) {
    if (data is! Map) return null;
    final total = data['total'] ?? (data['meta'] is Map ? (data['meta'] as Map)['total'] : null);
    if (total is int) return total;
    if (total is num) return total.toInt();
    return int.tryParse(total?.toString() ?? '');
  }

  bool? _hasNextPage(dynamic data) {
    if (data is! Map) return null;
    final meta = data['meta'] is Map ? data['meta'] as Map : const {};
    final currentPage = _toInt(data['current_page'] ?? meta['current_page']);
    final lastPage = _toInt(data['last_page'] ?? meta['last_page']);
    if (currentPage != null && lastPage != null) {
      return currentPage < lastPage;
    }
    final nextPageUrl = (data['next_page_url'] ?? meta['next_page_url'])?.toString().trim();
    if (nextPageUrl != null && nextPageUrl.isNotEmpty) return true;
    return false;
  }

  int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  void _onScroll() {
    if (_searchController.text.trim().isNotEmpty) {
      return;
    }

    if (!_scrollController.hasClients ||
        _isLoading ||
        _isLoadingMore) {
      return;
    }

    final position = _scrollController.position;

    if (position.pixels >=
        position.maxScrollExtent - 280) {
      _loadData();
    }
  }

  List<dynamic> _visiblePackages() {
    return _packages;
  }

  Future<void> _runPackageSearch() async {
    final query = _searchController.text.trim();

    if (query.isEmpty) {
      await _loadData(reset: true);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Api.services.searchPackages(query);

      if (!mounted) return;

      setState(() {
        _packages = List<dynamic>.from(results);

        _totalAvailable = _packages.length;

        // Search returns all matches, so no pagination during search.
        _hasMore = false;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();
    final lang = settings.language;
    final visible = _visiblePackages();
    final totalLabel = (_totalAvailable ?? _packages.length).toString();

    return Directionality(
      textDirection: settings.textDirection,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(
            kToolbarHeight + 8,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: Colors.black.withValues(
                    alpha: 0.06,
                  ),
                  width: 1,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: 0.05,
                  ),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: SafeArea(
              bottom: false,
              child: RastTopBar(
                title: AppStrings.t(
                  'packagesPageTitle',
                  lang,
                ),
                showCart: true,
                useWhiteBackground: true,
                onBack: () => Navigator.pop(context),
              ),
            ),
          ),
        ),

        body: _isLoading
            ? _buildLoading()
            : RefreshIndicator(
          onRefresh: () => _loadData(reset: true),
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // SEARCH BAR
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    Responsive.spacing(context, 16),
                    Responsive.spacing(context, 25),
                    Responsive.spacing(context, 16),
                    Responsive.spacing(context, 10),
                  ),
                  child: Container(
                    height: 50,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFDADDE2),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: EdgeInsetsGeometry.only(right: 15),
                      child: TextField(
                        controller: _searchController,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) {
                          _runPackageSearch();
                        },
                        style: TextStyle(
                          fontSize: Responsive.fontSize(context, 14),
                          color: const Color(0xFF33363D),
                          fontWeight: FontWeight.w400,
                        ),
                        decoration: InputDecoration(
                          hintText: AppStrings.t(
                            'searchPackages',
                            lang,
                          ),
                          hintStyle: TextStyle(
                            fontSize: Responsive.fontSize(context, 14),
                            color: const Color(0xFF60646C),
                            fontWeight: FontWeight.w400,
                          ),
                          prefixIcon: settings.isArabic ? null : InkWell(
                            onTap: () {
                              _runPackageSearch();
                            },
                            borderRadius: BorderRadius.circular(24),
                            child: const SizedBox(
                              width: 48,
                              height: 48,
                              child: Center(
                                child: Icon(
                                  Icons.search_rounded,
                                  size: 23,
                                  color: Color(0xFF60646C),
                                ),
                              ),
                            ),
                          ),
                          suffixIcon: settings.isArabic
                              ? InkWell(
                            onTap: () {
                              _runPackageSearch();
                            },
                            borderRadius: BorderRadius.circular(24),
                            child: const SizedBox(
                              width: 48,
                              height: 48,
                              child: Center(
                                child: Icon(
                                  Icons.search_rounded,
                                  size: 23,
                                  color: Color(0xFF60646C),
                                ),
                              ),
                            ),
                          )
                              : null,
                          filled: true,
                          fillColor: Colors.white,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // CACHED DATA WARNING
              if (_errorMessage != null && _packages.isNotEmpty)
                SliverToBoxAdapter(
                  child: Container(
                    width: double.infinity,
                    margin: EdgeInsets.symmetric(
                      horizontal: Responsive.spacing(context, 16),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.warning.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 18,
                          color: AppTheme.warning,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            AppStrings.t(
                              'showingCachedData',
                              lang,
                            ),
                            style: const TextStyle(
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // PACKAGE COUNT
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    Responsive.spacing(context, 16),
                    Responsive.spacing(context, 10),
                    Responsive.spacing(context, 16),
                    Responsive.spacing(context, 8),
                  ),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      '${AppStrings.t('showing', lang)} '
                      '${visible.length} '
                      '${AppStrings.t('of', lang)} '
                      '$totalLabel',
                      style: TextStyle(
                        fontSize: Responsive.fontSize(
                          context,
                          12,
                        ),
                        color: Colors.black,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),

              // EMPTY STATE
              if (visible.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmpty(),
                )
              else
                // PACKAGES GRID
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: Responsive.spacing(context, 16),
                      vertical: Responsive.spacing(context, 8),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final gap = Responsive.spacing(context, 12);

                        if (constraints.maxWidth < 330) {
                          return Column(
                            children: [
                              ...List.generate(
                                visible.length,
                                    (index) {
                                  final pkg = visible[index] is Map
                                      ? visible[index] as Map<String, dynamic>
                                      : <String, dynamic>{};

                                  return Padding(
                                    padding: EdgeInsets.only(
                                      bottom: gap,
                                    ),
                                    child: _PackageCard(
                                      package: pkg,
                                      lang: lang,
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => PackageDetailScreen(
                                            package: pkg,
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
                                    ),
                                  );
                                },
                              ),

                              if (_isLoadingMore)
                                const Padding(
                                  padding: EdgeInsets.all(20),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                            ],
                          );
                        }

                        final leftPackages = <Widget>[];
                        final rightPackages = <Widget>[];

                        for (int index = 0; index < visible.length; index++) {
                          final pkg = visible[index] is Map
                              ? visible[index] as Map<String, dynamic>
                              : <String, dynamic>{};

                          final card = Padding(
                            padding: EdgeInsets.only(
                              bottom: gap,
                            ),
                            child: _PackageCard(
                              package: pkg,
                              lang: lang,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PackageDetailScreen(
                                    package: pkg,
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
                            ),
                          );

                          if (index.isEven) {
                            leftPackages.add(card);
                          } else {
                            rightPackages.add(card);
                          }
                        }

                        return Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    children: leftPackages,
                                  ),
                                ),

                                SizedBox(width: gap),

                                Expanded(
                                  child: Column(
                                    children: rightPackages,
                                  ),
                                ),
                              ],
                            ),

                            if (_isLoadingMore)
                              const Padding(
                                padding: EdgeInsets.all(20),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),

              SliverToBoxAdapter(
                child: SizedBox(
                  height: Responsive.spacing(
                    context,
                    24,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 72,
            color: AppTheme.onSurfaceVariant.withValues(alpha: 0.4),
          ),
          SizedBox(height: Responsive.spacing(context, 16)),
          Text(
            AppStrings.t('noPackagesAvailable', context.watch<AppSettingsProvider>().language),
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 15),
              color: AppTheme.onSurfaceVariant,
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
        childAspectRatio: 0.68,
        crossAxisSpacing: Responsive.spacing(context, 12),
        mainAxisSpacing: Responsive.spacing(context, 12),
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
}

class _PackageCard extends StatelessWidget {
  final Map<String, dynamic> package;
  final String lang;
  final VoidCallback onTap;

  const _PackageCard({
    required this.package,
    required this.lang,
    required this.onTap,
  });


  @override
  Widget build(BuildContext context) {
    final settings =
    context.watch<AppSettingsProvider>();

    final displayName = LocaleUtils.localizedName(
      package,
      settings.isArabic,
    );

    final secondaryName = settings.isArabic
        ? (package['name_en'] ?? '')
        .toString()
        .trim()
        : (package['name_ar'] ?? '')
        .toString()
        .trim();

    final price = ApiConfig.priceFromMap(package);

    final originalPrice =
    package['original_price'] is num
        ? (package['original_price'] as num)
        .toDouble()
        : null;

    final imageUrl =
    ApiConfig.packageImageUrl(package);

    final testsCount =
        package['tests_count'] ??
            (package['package_items'] is List
                ? (package['package_items'] as List)
                .length
                : 0);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FB),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFFE0E2E6),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 12,
                spreadRadius: 1,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              // PACKAGE IMAGE
              AspectRatio(
                aspectRatio: 1.02,
                child:
                imageUrl != null &&
                    imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                  imageUrl: imageUrl,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (_, __) =>
                      Container(
                        color:
                        AppTheme.surfaceVariant,
                      ),
                  errorWidget:
                      (_, __, ___) =>
                      _buildFallback(),
                )
                    : _buildFallback(),
              ),

              // PACKAGE INFORMATION
              Padding(
                padding: EdgeInsets.fromLTRB(
                  Responsive.spacing(
                    context,
                    12,
                  ),
                  Responsive.spacing(
                    context,
                    11,
                  ),
                  Responsive.spacing(
                    context,
                    12,
                  ),
                  Responsive.spacing(
                    context,
                    12,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    // PACKAGE NAME
                    Text(
                      displayName,
                      maxLines: 2,
                      overflow:
                      TextOverflow.ellipsis,
                      style: TextStyle(
                        color:
                        const Color(0xFF24262B),
                        fontSize:
                        Responsive.fontSize(
                          context,
                          13,
                        ),
                        fontWeight:
                        FontWeight.w700,
                        height: 1.25,
                      ),
                    ),

                    // SECOND LANGUAGE NAME
                    if (secondaryName.isNotEmpty &&
                        secondaryName !=
                            displayName) ...[
                      SizedBox(
                        height:
                        Responsive.spacing(
                          context,
                          3,
                        ),
                      ),

                      Text(
                        secondaryName,
                        maxLines: 2,
                        overflow:
                        TextOverflow.ellipsis,
                        style: TextStyle(
                          color:
                          const Color(
                            0xFF55585F,
                          ),
                          fontSize:
                          Responsive.fontSize(
                            context,
                            11,
                          ),
                          fontWeight:
                          FontWeight.w400,
                          height: 1.3,
                        ),
                      ),
                    ],

                    SizedBox(
                      height:
                      Responsive.spacing(
                        context,
                        12,
                      ),
                    ),

                    // PRICE
                    Wrap(
                      crossAxisAlignment:
                      WrapCrossAlignment.end,
                      spacing: 4,
                      runSpacing: 2,
                      children: [
                        Text(
                          price > 0
                              ? price
                              .toStringAsFixed(
                            2,
                          )
                              : AppStrings.t(
                            'contactForPrice',
                            lang,
                          ),
                          maxLines: 1,
                          overflow:
                          TextOverflow.ellipsis,
                          style: TextStyle(
                            color:
                            const Color(
                              0xFF686CFF,
                            ),
                            fontSize:
                            Responsive.fontSize(
                              context,
                              15,
                            ),
                            fontWeight:
                            FontWeight.w800,
                            height: 1,
                          ),
                        ),

                        if (price > 0)
                          Text(
                            AppStrings.t(
                              'sar',
                              lang,
                            ),
                            style: TextStyle(
                              color:
                              const Color(
                                0xFF8A8EFA,
                              ),
                              fontSize:
                              Responsive
                                  .fontSize(
                                context,
                                8,
                              ),
                              fontWeight:
                              FontWeight.w500,
                            ),
                          ),
                      ],
                    ),

                    if (originalPrice != null &&
                        originalPrice > price) ...[
                      SizedBox(
                        height:
                        Responsive.spacing(
                          context,
                          3,
                        ),
                      ),
                      Text(
                        '${originalPrice.toStringAsFixed(2)} '
                            '${AppStrings.t('sar', lang)}',
                        maxLines: 1,
                        overflow:
                        TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize:
                          Responsive.fontSize(
                            context,
                            9,
                          ),
                          color: AppTheme
                              .onSurfaceVariant,
                          decoration:
                          TextDecoration
                              .lineThrough,
                        ),
                      ),
                    ],

                    SizedBox(
                      height:
                      Responsive.spacing(
                        context,
                        12,
                      ),
                    ),

                    // TEST COUNT
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons
                              .biotech_outlined,
                          size: 14,
                          color:
                          const Color(
                            0xFF60636A,
                          ),
                        ),

                        SizedBox(
                          width:
                          Responsive.spacing(
                            context,
                            5,
                          ),
                        ),

                        Flexible(
                          child: Text(
                            testsCount > 0
                                ? '$testsCount ${AppStrings.t('testsCount', lang)}'
                                : AppStrings.t(
                              'testsShownInImage',
                              lang,
                            ),
                            maxLines: 1,
                            overflow:
                            TextOverflow
                                .ellipsis,
                            style: TextStyle(
                              color:
                              const Color(
                                0xFF55585F,
                              ),
                              fontSize:
                              Responsive
                                  .fontSize(
                                context,
                                10,
                              ),
                              fontWeight:
                              FontWeight
                                  .w500,
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
        ),
      ),
    );
  }

  Widget _buildFallback() {
    return Container(
      width: double.infinity,
      color:
      AppTheme.primary.withValues(
        alpha: 0.08,
      ),
      child: Center(
        child: Icon(
          Icons.medical_services_outlined,
          size: 48,
          color: AppTheme.primary.withValues(
            alpha: 0.4,
          ),
        ),
      ),
    );
  }
}