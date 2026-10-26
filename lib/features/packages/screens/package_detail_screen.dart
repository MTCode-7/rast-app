import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:rast/core/services/analytics_service.dart';
import 'package:rast/core/api/api_services.dart';
import 'package:rast/core/constants/api_config.dart';
import 'package:rast/core/constants/app_strings.dart';
import 'package:rast/core/widgets/package_image_tap_hint.dart';
import 'package:rast/core/providers/app_settings_provider.dart';
import 'package:rast/core/utils/locale_utils.dart';
import 'package:provider/provider.dart';
import 'package:rast/core/theme/app_theme.dart';
import 'package:rast/core/utils/responsive.dart';
import 'package:rast/core/widgets/gradient_button.dart';
import 'package:rast/core/widgets/rast_ui.dart';
import 'package:rast/core/widgets/zoomable_image_viewer.dart';
import 'package:rast/features/auth/services/auth_service.dart';
import 'package:rast/features/auth/screens/login_screen.dart';
import 'package:rast/features/bookings/screens/book_flow_screen.dart';
import 'package:shimmer/shimmer.dart';

class PackageDetailScreen extends StatefulWidget {
  final Map<String, dynamic> package;

  const PackageDetailScreen({super.key, required this.package});

  @override
  State<PackageDetailScreen> createState() => _PackageDetailScreenState();
}

class _PackageDetailScreenState extends State<PackageDetailScreen>
    with PackageImageTapHintMixin {
  Map<String, dynamic>? _package;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    AnalyticsService.logScreen('package_details');
    AnalyticsService.logViewItem(AnalyticsService.itemFromMap(widget.package, category: 'package'));
    _loadData();
  }

  Future<void> _loadData() async {
    final id = widget.package['id'];

    if (id == null) {
      setState(() {
        _package = widget.package;
        _isLoading = false;
      });

      await _afterPackageLoaded();
      return;
    }

    setState(() => _isLoading = true);

    try {
      final data = await Api.services.getPackage(
        id is int ? id : int.parse(id.toString()),
      );

      final merged = <String, dynamic>{
        ...widget.package,
        ...data,
      };

      // Keep provider-specific package cover
      if (widget.package['image'] != null) {
        merged['image'] = widget.package['image'];
      }

      if (widget.package['image_url'] != null) {
        merged['image_url'] =
        widget.package['image_url'];
      }

      // Keep provider-specific package information
      if (widget.package['provider_service_id'] != null) {
        merged['provider_service_id'] =
        widget.package['provider_service_id'];
      }

      if (widget.package['provider_id'] != null) {
        merged['provider_id'] =
        widget.package['provider_id'];
      }

      if (widget.package['price'] != null) {
        merged['price'] =
        widget.package['price'];
      }

      if (widget.package['final_price'] != null) {
        merged['final_price'] =
        widget.package['final_price'];
      }

      if (widget.package['is_available'] != null) {
        merged['is_available'] =
        widget.package['is_available'];
      }

      setState(() {
        _package = merged;
        _isLoading = false;
      });

      await _afterPackageLoaded();
    } catch (_) {
      setState(() {
        _package = widget.package;
        _isLoading = false;
      });

      await _afterPackageLoaded();
    }
  }

  Future<void> _afterPackageLoaded() async {
    final pkg = _package ?? widget.package;
    await preparePackageImageTapHint(
      hasImages: ApiConfig.packageImageUrls(pkg).isNotEmpty,
    );
  }

  String? _getImageUrl(Map<String, dynamic> p) => ApiConfig.packageImageUrl(p);

  /// استخراج قائمة تحاليل الباقة (يدعم package_items و packageItems و items)
  List<dynamic> _getPackageItemsList(Map<String, dynamic> pkg) {
    final raw = pkg['package_items'] ?? pkg['packageItems'] ?? pkg['items'];
    if (raw is List) return raw;
    return [];
  }

  /// اسم عنصر الباقة (تحليل) من العلاقة service أو من الحقل مباشرة
  String _getItemDisplayName(dynamic item, bool isArabic) {
    if (item == null) return '';
    final m = item is Map ? item as Map<String, dynamic> : <String, dynamic>{};
    final service = m['service'];
    final serviceMap = service is Map ? service as Map<String, dynamic> : null;
    if (serviceMap != null) {
      final fromService = LocaleUtils.localizedName(serviceMap, isArabic);
      if (fromService.isNotEmpty) return fromService;
      final n = isArabic
          ? (
          serviceMap['name_ar'] ??
              serviceMap['title_ar'] ??
              serviceMap['name_en'] ??
              serviceMap['title_en'] ??
              serviceMap['title']
      )
          : (
          serviceMap['name_en'] ??
              serviceMap['title_en'] ??
              serviceMap['title'] ??
              serviceMap['name_ar'] ??
              serviceMap['title_ar']
      );
      if (n != null && n.toString().trim().isNotEmpty) {
        return n.toString().trim();
      }
    }
    final fromItem = LocaleUtils.localizedName(m, isArabic);
    if (fromItem.isNotEmpty) return fromItem;
    final preferredName = isArabic
        ? (m['name_ar'] ?? m['title_ar'])
        : (m['name_en'] ?? m['title_en'] ?? m['title']);

    final fallbackName = isArabic
        ? (m['name_en'] ?? m['title_en'] ?? m['title'])
        : (m['name_ar'] ?? m['title_ar']);

    if (preferredName != null &&
        preferredName.toString().trim().isNotEmpty) {
      return preferredName.toString().trim();
    }

    if (fallbackName != null &&
        fallbackName.toString().trim().isNotEmpty) {
      return fallbackName.toString().trim();
    }
    return '';
  }

  String _providerName(Map<String, dynamic> pkg, bool isArabic) {
    final provider = pkg['provider'];
    if (provider is Map<String, dynamic>) {
      final name = LocaleUtils.localizedBusinessName(provider, isArabic).trim();
      if (name.isNotEmpty) return name;
    }
    final providerServices = pkg['provider_services'] ?? pkg['providerServices'];
    if (providerServices is List && providerServices.isNotEmpty) {
      final first = providerServices.first;
      if (first is Map) {
        final providerMap = first['provider'];
        if (providerMap is Map<String, dynamic>) {
          final name = LocaleUtils.localizedBusinessName(providerMap, isArabic)
              .trim();
          if (name.isNotEmpty) return name;
        }
      }
    }
    return '';
  }

  double _resolvePackagePrice(
    Map<String, dynamic> pkg,
    Map<String, dynamic> ps,
  ) {
    var price = ApiConfig.priceFromMap(pkg);
    if (price > 0) return price;
    price = ApiConfig.priceFromMap(ps);
    if (price > 0) return price;
    final psList = pkg['provider_services'] ?? pkg['providerServices'];
    if (psList is List) {
      for (final item in psList) {
        if (item is! Map) continue;
        price = ApiConfig.priceFromMap(Map<String, dynamic>.from(item));
        if (price > 0) return price;
      }
    }
    return 0;
  }

  double _resolvePackageHomeFee(
    Map<String, dynamic> ps,
    Map<String, dynamic> provider,
  ) {
    var fee = ApiConfig.priceFromMap({
      'price': ps['home_service_price'] ?? ps['home_price'],
    });
    if (fee > 0) return fee;
    final fromProvider = provider['home_service_fee'] ?? provider['home_service_price'];
    if (fromProvider is num) return fromProvider.toDouble();
    if (fromProvider != null) {
      return double.tryParse(fromProvider.toString()) ?? 0;
    }
    return 0;
  }

  Future<void> _handleBook(Map<String, dynamic> pkg) async {
    if (!AuthService.isLoggedIn) {
      final ok = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      if (ok != true || !mounted) return;
    }
    final raw =
        pkg['provider_services'] as List? ??
        pkg['providerServices'] as List? ??
        [];
    final providerServices = raw
        .map((ps) => ps is Map ? Map<String, dynamic>.from(ps) : null)
        .whereType<Map<String, dynamic>>()
        .toList();
    if (providerServices.isEmpty) {
      if (mounted) {
        final lang =
            context.read<AppSettingsProvider>().language;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppStrings.t(
                'noLabsForPackage',
                lang,
              ),
            ),
          ),
        );
      }
      return;
    }
    final ps = providerServices.first;
    final provider = ps['provider'] is Map
        ? ps['provider'] as Map<String, dynamic>
        : <String, dynamic>{};
    int? labId;
    if (provider['id'] is int) {
      labId = provider['id'] as int;
    } else if (provider['id'] is num) {
      labId = (provider['id'] as num).truncate();
    } else if (provider['id'] != null) {
      labId = int.tryParse(provider['id'].toString());
    }
    if (labId == null || !mounted) return;
    final isArabic = context.read<AppSettingsProvider>().isArabic;
    final pkgName = LocaleUtils.localizedName(pkg, isArabic);
    final price = _resolvePackagePrice(pkg, ps);
    final homeFee = _resolvePackageHomeFee(ps, provider);
    final providerService = {
      'id': ps['id'],
      'final_price': price,
      'price': price,
      'home_service_price': homeFee,
      'provider': provider,
      'service': {'name_ar': pkgName},
      'name_ar': pkgName,
    };
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookFlowScreen(
          labId: labId!,
          lab: provider.isNotEmpty ? provider : null,
          labName: LocaleUtils.localizedBusinessName(provider, isArabic),
          providerService: providerService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();
    final isArabic = settings.isArabic;
    final lang = settings.language;

    final pkg = _package ?? widget.package;

    final displayName = LocaleUtils.localizedName(
      pkg,
      isArabic,
    );

    final packageName = displayName.isEmpty
        ? AppStrings.t('packagesPageTitle', lang)
        : displayName;

    final preferredDescription = isArabic
        ? pkg['description_ar']
        : pkg['description_en'];

    final fallbackDescription = isArabic
        ? pkg['description_en']
        : pkg['description_ar'];

    final description =
    preferredDescription?.toString().trim().isNotEmpty == true
        ? preferredDescription.toString().trim()
        : fallbackDescription?.toString().trim().isNotEmpty == true
        ? fallbackDescription.toString().trim()
        : pkg['description']?.toString().trim() ?? '';

    double price = ApiConfig.priceFromMap(pkg);

    if (price == 0.0) {
      final psList =
          pkg['provider_services'] ??
              pkg['providerServices'];

      if (psList is List &&
          psList.isNotEmpty &&
          psList.first is Map) {
        price = ApiConfig.priceFromMap(
          Map<String, dynamic>.from(
            psList.first as Map,
          ),
        );
      }
    }

    final orig = pkg['original_price'];

    final originalPrice = orig is num
        ? orig.toDouble()
        : orig is String
        ? double.tryParse(orig)
        : null;

    final imageUrl = _getImageUrl(pkg);
    final imageUrls = imageUrl != null && imageUrl.isNotEmpty
        ? [imageUrl]
        : <String>[];
    final items = _getPackageItemsList(pkg);

    final testsCount =
        pkg['tests_count'] ?? items.length;

    final tapHintMessage = imageUrls.length > 1
        ? AppStrings.t(
      'packageImagesTapHint',
      lang,
    )
        : AppStrings.t(
      'packageImageTapHint',
      lang,
    );

    final providerName =
    _providerName(pkg, isArabic);

    return Directionality(
      textDirection: settings.textDirection,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),

        bottomNavigationBar:
        _buildBottomBar(context, pkg),

        body: _isLoading && _package == null
            ? _buildLoading()
            : CustomScrollView(
          physics:
          const BouncingScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              floating: false,
              automaticallyImplyLeading: false,

              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,

              elevation: 5,
              scrolledUnderElevation: 5,
              shadowColor: Colors.black
                  .withValues(alpha: 0.14),

              toolbarHeight: 64,

              flexibleSpace: SafeArea(
                bottom: false,
                child: SizedBox(
                  height: 64,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PositionedDirectional(
                        start: 8,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: Material(
                            color:
                            Colors.transparent,
                            child: InkWell(
                              onTap: () =>
                                  Navigator.pop(
                                    context,
                                  ),
                              borderRadius:
                              BorderRadius.circular(
                                30,
                              ),
                              child: SizedBox(
                                width: 48,
                                height: 48,
                                child: Center(
                                  child: Icon(
                                    isArabic
                                        ? Icons.arrow_forward_ios_rounded
                                        : Icons.arrow_back_ios_new_rounded,
                                    textDirection: TextDirection.ltr,
                                    size: 20,
                                    color: const Color(0xFF202124),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: AspectRatio(
                aspectRatio: 16 / 10,
                child: _buildHeroBackground(
                  context,
                  imageUrl: imageUrl,
                  imageUrls: imageUrls,
                  tapHintMessage:
                  tapHintMessage,
                  tapLabel: AppStrings.t(
                    'tapToZoom',
                    lang,
                  ),
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  Responsive.spacing(
                    context,
                    16,
                  ),
                  Responsive.spacing(
                    context,
                    18,
                  ),
                  Responsive.spacing(
                    context,
                    16,
                  ),
                  Responsive.spacing(
                    context,
                    28,
                  ),
                ),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(
                        Responsive.spacing(
                          context,
                          18,
                        ),
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                        BorderRadius.circular(
                          22,
                        ),
                        border: Border.all(
                          color: const Color(
                            0xFFE7E8EC,
                          ),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black
                                .withValues(
                              alpha: 0.10,
                            ),
                            blurRadius: 20,
                            offset:
                            const Offset(
                              0,
                              7,
                            ),
                          ),
                        ],
                      ),
                      child: LayoutBuilder(
                        builder:
                            (
                            context,
                            constraints,
                            ) {
                          final narrow =
                              constraints
                                  .maxWidth <
                                  310;

                          final titleWidget =
                          Column(
                            crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                            children: [
                              Text(
                                packageName,
                                maxLines: 3,
                                overflow:
                                TextOverflow
                                    .ellipsis,
                                style:
                                TextStyle(
                                  fontSize:
                                  Responsive
                                      .fontSize(
                                    context,
                                    20,
                                  ),
                                  fontWeight:
                                  FontWeight
                                      .w800,
                                  color:
                                  const Color(
                                    0xFF202124,
                                  ),
                                  height: 1.3,
                                ),
                              ),

                              if (providerName
                                  .isNotEmpty) ...[
                                SizedBox(
                                  height:
                                  Responsive
                                      .spacing(
                                    context,
                                    10,
                                  ),
                                ),

                                Container(
                                  constraints:
                                  const BoxConstraints(
                                    maxWidth: double
                                        .infinity,
                                  ),
                                  padding:
                                  const EdgeInsets
                                      .symmetric(
                                    horizontal:
                                    10,
                                    vertical: 6,
                                  ),
                                  decoration:
                                  BoxDecoration(
                                    color: RastUi
                                        .purple
                                        .withValues(
                                      alpha:
                                      0.08,
                                    ),
                                    borderRadius:
                                    BorderRadius
                                        .circular(
                                      12,
                                    ),
                                  ),
                                  child: Text(
                                    providerName,
                                    maxLines: 2,
                                    overflow:
                                    TextOverflow
                                        .ellipsis,
                                    style:
                                    TextStyle(
                                      color: RastUi
                                          .purple,
                                      fontSize:
                                      Responsive
                                          .fontSize(
                                        context,
                                        11,
                                      ),
                                      fontWeight:
                                      FontWeight
                                          .w700,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          );

                          final priceWidget =
                          Column(
                            crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                            children: [
                              Container(
                                padding:
                                const EdgeInsets
                                    .symmetric(
                                  horizontal: 14,
                                  vertical: 9,
                                ),
                                decoration:
                                BoxDecoration(
                                  gradient: RastUi
                                      .brandGradient,
                                  borderRadius:
                                  BorderRadius
                                      .circular(
                                    14,
                                  ),
                                  boxShadow:
                                  RastUi
                                      .softShadow,
                                ),
                                child: Text(
                                  price > 0
                                      ? '${price.toStringAsFixed(2)} ${AppStrings.t('sar', lang)}'
                                      : AppStrings.t(
                                    'contactForPrice',
                                    lang,
                                  ),
                                  maxLines: 2,
                                  overflow:
                                  TextOverflow
                                      .ellipsis,
                                  textAlign:
                                  TextAlign
                                      .center,
                                  style:
                                  TextStyle(
                                    color:
                                    Colors.white,
                                    fontSize:
                                    Responsive
                                        .fontSize(
                                      context,
                                      15,
                                    ),
                                    fontWeight:
                                    FontWeight
                                        .w800,
                                  ),
                                ),
                              ),

                              if (originalPrice !=
                                  null &&
                                  originalPrice >
                                      price) ...[
                                SizedBox(
                                  height:
                                  Responsive
                                      .spacing(
                                    context,
                                    5,
                                  ),
                                ),
                                Text(
                                  '${originalPrice.toStringAsFixed(2)} ${AppStrings.t('sar', lang)}',
                                  maxLines: 1,
                                  overflow:
                                  TextOverflow
                                      .ellipsis,
                                  style:
                                  TextStyle(
                                    fontSize:
                                    Responsive
                                        .fontSize(
                                      context,
                                      11,
                                    ),
                                    color: AppTheme
                                        .onSurfaceVariant,
                                    decoration:
                                    TextDecoration
                                        .lineThrough,
                                  ),
                                ),
                              ],
                            ],
                          );

                          if (narrow) {
                            return Column(
                              crossAxisAlignment:
                              CrossAxisAlignment
                                  .stretch,
                              children: [
                                titleWidget,

                                SizedBox(
                                  height:
                                  Responsive
                                      .spacing(
                                    context,
                                    14,
                                  ),
                                ),

                                Align(
                                  alignment:
                                  AlignmentDirectional
                                      .centerStart,
                                  child:
                                  priceWidget,
                                ),
                              ],
                            );
                          }

                          return Row(
                            crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                            children: [
                              Expanded(
                                child:
                                titleWidget,
                              ),

                              SizedBox(
                                width: Responsive
                                    .spacing(
                                  context,
                                  12,
                                ),
                              ),

                              Flexible(
                                flex: 0,
                                child:
                                ConstrainedBox(
                                  constraints:
                                  BoxConstraints(
                                    maxWidth:
                                    constraints
                                        .maxWidth *
                                        0.38,
                                  ),
                                  child:
                                  priceWidget,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),

                    SizedBox(
                      height: Responsive.spacing(
                        context,
                        14,
                      ),
                    ),

                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _modernInfoChip(
                          context,
                          icon: Icons.biotech_outlined,
                          text: testsCount > 0
                              ? '$testsCount ${AppStrings.t('testsCount', lang)}'
                              : AppStrings.t(
                            'testsShownInImage',
                            lang,
                          ),
                        ),

                        if (providerName
                            .isNotEmpty)
                          _modernInfoChip(
                            context,
                            icon: Icons
                                .business_outlined,
                            text:
                            providerName,
                          ),
                      ],
                    ),

                    if (description.isNotEmpty) ...[
                      SizedBox(
                        height:
                        Responsive.spacing(
                          context,
                          24,
                        ),
                      ),

                      _sectionTitle(
                        AppStrings.t('description', lang),
                        Icons.description_outlined,
                      ),

                      SizedBox(
                        height:
                        Responsive.spacing(
                          context,
                          10,
                        ),
                      ),

                      _infoCard(
                        child: Text(
                          description,
                          softWrap: true,
                          style: TextStyle(
                            fontSize:
                            Responsive
                                .fontSize(
                              context,
                              13,
                            ),
                            color:
                            const Color(
                              0xFF62656D,
                            ),
                            height: 1.65,
                          ),
                        ),
                      ),
                    ],

                    if (items.isNotEmpty ||
                        testsCount > 0) ...[
                      SizedBox(
                        height:
                        Responsive.spacing(
                          context,
                          24,
                        ),
                      ),

                      _sectionTitle(
                        AppStrings.t('includedTests', lang),
                        Icons.fact_check_outlined,
                      ),

                      SizedBox(
                        height:
                        Responsive.spacing(
                          context,
                          10,
                        ),
                      ),

                      _infoCard(
                        child: items.isEmpty
                            ? Text(
                          '$testsCount ${AppStrings.t('testsIncludedInPackage', lang)}',
                          softWrap:
                          true,
                          style:
                          TextStyle(
                            fontSize:
                            Responsive
                                .fontSize(
                              context,
                              13,
                            ),
                            color: AppTheme
                                .onSurfaceVariant,
                          ),
                        )
                            : Column(
                          mainAxisSize:
                          MainAxisSize
                              .min,
                          children: [
                            ...items
                                .take(20)
                                .map(
                                  (
                                  item,
                                  ) {
                                final name =
                                _getItemDisplayName(
                                  item,
                                  isArabic,
                                );

                                final itemName = name.isEmpty
                                    ? AppStrings.t('analysis', lang)
                                    : name;

                                return Padding(
                                  padding:
                                  EdgeInsets.only(
                                    bottom:
                                    Responsive.spacing(
                                      context,
                                      11,
                                    ),
                                  ),
                                  child:
                                  Row(
                                    crossAxisAlignment:
                                    CrossAxisAlignment
                                        .start,
                                    children: [
                                      Container(
                                        width:
                                        28,
                                        height:
                                        28,
                                        alignment:
                                        Alignment.center,
                                        decoration:
                                        BoxDecoration(
                                          color: RastUi.blue.withValues(
                                            alpha: 0.10,
                                          ),
                                          shape:
                                          BoxShape.circle,
                                        ),
                                        child:
                                        Icon(
                                          Icons.check_rounded,
                                          size:
                                          17,
                                          color:
                                          RastUi.blue,
                                        ),
                                      ),

                                      SizedBox(
                                        width:
                                        Responsive.spacing(
                                          context,
                                          10,
                                        ),
                                      ),

                                      Expanded(
                                        child:
                                        Text(
                                          itemName,
                                          softWrap:
                                          true,
                                          style:
                                          TextStyle(
                                            fontSize:
                                            Responsive.fontSize(
                                              context,
                                              13,
                                            ),
                                            color:
                                            const Color(
                                              0xFF34363C,
                                            ),
                                            height:
                                            1.45,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),

                            if (items.length >
                                20)
                              Align(
                                alignment:
                                AlignmentDirectional
                                    .centerStart,
                                child: Text(
                                  isArabic
                                      ? 'و ${items.length - 20} ${AppStrings.t('moreTests', lang)}'
                                      : '${AppStrings.t('and', lang)} ${items.length - 20} ${AppStrings.t('moreTests', lang)}',
                                  softWrap:
                                  true,
                                  style:
                                  TextStyle(
                                    fontSize:
                                    Responsive
                                        .fontSize(
                                      context,
                                      12,
                                    ),
                                    color: AppTheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],

                    if (imageUrls.length >
                        1) ...[
                      SizedBox(
                        height:
                        Responsive.spacing(
                          context,
                          24,
                        ),
                      ),

                      Row(
                        children: [
                          Expanded(
                            child:
                            _sectionTitle(
                              AppStrings.t(
                                'packagePhotos',
                                lang,
                              ),
                              Icons
                                  .photo_library_outlined,
                            ),
                          ),

                          const SizedBox(
                            width: 8,
                          ),

                          Flexible(
                            child:
                            PackageImageTapBadge(
                              label:
                              AppStrings.t(
                                'tapToZoom',
                                lang,
                              ),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(
                        height:
                        Responsive.spacing(
                          context,
                          12,
                        ),
                      ),

                      SizedBox(
                        height: 110,
                        child:
                        ListView.separated(
                          scrollDirection:
                          Axis.horizontal,
                          itemCount:
                          imageUrls.length,
                          separatorBuilder:
                              (_, __) =>
                          const SizedBox(
                            width: 10,
                          ),
                          itemBuilder:
                              (
                              context,
                              index,
                              ) {
                            final url =
                            imageUrls[index];

                            return GestureDetector(
                              onTap: () {
                                dismissPackageImageTapHint();

                                showZoomableImage(
                                  context,
                                  url,
                                  imageUrls:
                                  imageUrls,
                                );
                              },
                              child: Container(
                                width: 110,
                                decoration:
                                BoxDecoration(
                                  borderRadius:
                                  BorderRadius
                                      .circular(
                                    16,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors
                                          .black
                                          .withValues(
                                        alpha:
                                        0.10,
                                      ),
                                      blurRadius:
                                      8,
                                      offset:
                                      const Offset(
                                        0,
                                        3,
                                      ),
                                    ),
                                  ],
                                ),
                                child:
                                ClipRRect(
                                  borderRadius:
                                  BorderRadius
                                      .circular(
                                    16,
                                  ),
                                  child:
                                  CachedNetworkImage(
                                    imageUrl:
                                    url,
                                    fit: BoxFit
                                        .cover,
                                    placeholder:
                                        (
                                        _,
                                        __,
                                        ) =>
                                        ColoredBox(
                                          color: AppTheme
                                              .primary
                                              .withValues(
                                            alpha:
                                            0.08,
                                          ),
                                          child:
                                          const Center(
                                            child:
                                            CircularProgressIndicator(
                                              strokeWidth:
                                              2,
                                            ),
                                          ),
                                        ),
                                    errorWidget:
                                        (
                                        _,
                                        __,
                                        ___,
                                        ) =>
                                        ColoredBox(
                                          color: AppTheme
                                              .primary
                                              .withValues(
                                            alpha:
                                            0.08,
                                          ),
                                          child:
                                          Icon(
                                            Icons
                                                .broken_image_outlined,
                                            color:
                                            AppTheme.primary,
                                          ),
                                        ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],

                    SizedBox(
                      height: Responsive.spacing(
                        context,
                        20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroBackground(
    BuildContext context, {
    required String? imageUrl,
    required List<String> imageUrls,
    required String tapHintMessage,
    required String tapLabel,
  }) {
    final hasImage = imageUrl != null && imageUrl.trim().isNotEmpty;
    if (!hasImage) return _buildPlaceholder();

    return Stack(
      fit: StackFit.expand,
      children: [
        HeroImageBackground(
          imageUrl: imageUrl,
          galleryUrls: imageUrls.length > 1 ? imageUrls : null,
          onImageTap: dismissPackageImageTapHint,
          placeholder: _buildImageLoadingPlaceholder(context),
          fit: BoxFit.cover,
        ),
        IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.28),
                  Colors.transparent,
                  Colors.transparent,
                ],
                stops: const [0.0, 0.35, 1.0],
              ),
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: showPackageImageTapHint ? 68 : 18,
          child: IgnorePointer(
            child: PackageHeroTapChip(label: tapLabel),
          ),
        ),
        if (showPackageImageTapHint)
          Positioned(
            left: 16,
            right: 16,
            bottom: 14,
            child: PackageImageTapHintBanner(
              message: tapHintMessage,
              compact: true,
              onDismiss: dismissPackageImageTapHint,
            ),
          ),
      ],
    );
  }

  Widget _buildImageLoadingPlaceholder(BuildContext context) {
    return ColoredBox(
      color: RastUi.subtleFill(context),
      child: Center(
        child: Icon(
          Icons.inventory_2_outlined,
          size: 64,
          color: AppTheme.primary.withValues(alpha: 0.35),
        ),
      ),
    );
  }

  Widget _buildBottomBar(
      BuildContext context,
      Map<String, dynamic> pkg,
      ) {
    final lang =
        context.watch<AppSettingsProvider>().language;

    return Material(
      elevation: 14,
      shadowColor:
      Colors.black.withValues(alpha: 0.14),
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            Responsive.spacing(context, 16),
            Responsive.spacing(context, 10),
            Responsive.spacing(context, 16),
            Responsive.spacing(context, 12),
          ),
          child: SizedBox(
            width: double.infinity,
            child: GradientFilledButton(
              onPressed: () => _handleBook(pkg),
              style: FilledButton.styleFrom(
                minimumSize:
                const Size(double.infinity, 56),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 15,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(18),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment:
                MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.calendar_today_rounded,
                    size: 20,
                  ),

                  const SizedBox(width: 9),

                  Flexible(
                    child: Text(
                      AppStrings.t(
                        'bookNow',
                        lang,
                      ),
                      maxLines: 1,
                      overflow:
                      TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize:
                        Responsive.fontSize(
                          context,
                          16,
                        ),
                        fontWeight:
                        FontWeight.w700,
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

  Widget _modernInfoChip(
      BuildContext context, {
        required IconData icon,
        required String text,
      }) {
    return Container(
      constraints: BoxConstraints(
        maxWidth:
        MediaQuery.sizeOf(context).width * 0.75,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: RastUi.purple.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: RastUi.purple.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: RastUi.purple,
          ),

          const SizedBox(width: 6),

          Flexible(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.start,
              style: TextStyle(
                color: RastUi.textPurple,
                fontSize:
                Responsive.fontSize(context, 11),
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(
      String title,
      IconData icon,
      ) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            gradient: RastUi.brandGradient,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 18,
          ),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: Text(
            title,
            softWrap: true,
            style: TextStyle(
              color: RastUi.primaryText(context),
              fontSize:
              Responsive.fontSize(context, 15),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(Responsive.spacing(context, 16)),
      decoration: BoxDecoration(
        color: RastUi.panelSurface(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: RastUi.softBorder(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildPlaceholder() => Container(
    decoration: BoxDecoration(gradient: RastUi.headerGradient),
    child: Center(
      child: Icon(
        Icons.medical_services_outlined,
        size: 80,
        color: Colors.white.withValues(alpha: 0.6),
      ),
    ),
  );

  Widget _buildLoading() => Padding(
    padding: EdgeInsets.all(16),
    child: Shimmer.fromColors(
      baseColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      highlightColor: Theme.of(context).colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          SizedBox(height: 24),
          Container(
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ],
      ),
    ),
  );
}
