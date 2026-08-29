import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:rast/core/constants/api_config.dart';
import 'package:rast/core/constants/app_strings.dart';
import 'package:rast/core/providers/app_settings_provider.dart';
import 'package:rast/core/services/favorites_service.dart';
import 'package:rast/core/utils/locale_utils.dart';
import 'package:provider/provider.dart';
import 'package:rast/core/theme/app_theme.dart';
import 'package:rast/core/utils/responsive.dart';
import 'package:rast/core/widgets/gradient_button.dart';
import 'package:rast/core/widgets/rast_ui.dart';
import 'package:rast/core/widgets/search_box.dart';
import 'package:rast/core/widgets/zoomable_image_viewer.dart';
import 'package:rast/core/api/api_services.dart';
import 'package:rast/core/api/api_client.dart';
import 'package:rast/features/bookings/screens/book_flow_screen.dart';
import 'package:rast/features/lab_details/screens/lab_details_screen.dart';
import 'package:shimmer/shimmer.dart';

class ServiceDetailScreen extends StatefulWidget {
  final Map<String, dynamic> service;
  final int? labId;
  final String? labName;
  final Map<String, dynamic>? lab;

  const ServiceDetailScreen({
    super.key,
    required this.service,
    this.labId,
    this.labName,
    this.lab,
  });

  @override
  State<ServiceDetailScreen> createState() => _ServiceDetailScreenState();
}

class _ServiceDetailScreenState extends State<ServiceDetailScreen> {
  final TextEditingController _providersSearchController =
      TextEditingController();
  Map<String, dynamic>? _service;
  List<Map<String, dynamic>> _providerServices = [];
  bool _isLoading = true;
  bool _isFavorite = false;
  String _providersSort = 'rating';
  bool _providersHomeOnly = false;
  double? _providersMinPrice;
  double? _providersMaxPrice;

  @override
  void initState() {
    super.initState();

    _service = Map<String, dynamic>.from(
      widget.service,
    );

    _isLoading = false;

    _loadFavorite(widget.service);
    _loadData();
  }

  @override
  void dispose() {
    _providersSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadFavorite(Map<String, dynamic> service) async {
    final value = await FavoritesService.isAnalysisFavorite(service);
    if (mounted) setState(() => _isFavorite = value);
  }

  Future<void> _toggleFavorite(Map<String, dynamic> service) async {
    final value = await FavoritesService.toggleAnalysis(service);
    if (!mounted) return;
    setState(() => _isFavorite = value);
  }

  Future<void> _loadData() async {
    final id = widget.service['id'];

    if (id == null) {
      if (mounted) {
        setState(() {
          _service = _serviceForSelectedLab(
            widget.service,
            const <Map<String, dynamic>>[],
          );
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final service = await Api.services.getService(
        id is int
            ? id
            : int.parse(id.toString()),
      );

      final raw =
          service['provider_services'] as List? ??
              [];

      final providerServices = raw
          .map(
            (ps) => ps is Map
            ? Map<String, dynamic>.from(ps)
            : null,
      )
          .whereType<Map<String, dynamic>>()
          .toList();

      final svc =
      Map<String, dynamic>.from(service);

      final selectedProviderService =
      _selectedProviderServiceForLab(
        providerServices,
        svc,
      );

      final visibleProviderServices =
      widget.labId != null
          ? [
        if (selectedProviderService != null)
          selectedProviderService,
      ]
          : providerServices;

      final displayService =
      _serviceForSelectedLab(
        svc,
        visibleProviderServices,
      );

      if (displayService['image'] == null ||
          displayService['image']
              .toString()
              .trim()
              .isEmpty) {
        for (final ps
        in visibleProviderServices) {
          final img =
          ps['image']?.toString().trim();

          if (img != null && img.isNotEmpty) {
            displayService['image'] = img;
            break;
          }
        }
      }

      if (!mounted) return;

      setState(() {
        _service = displayService;
        _providerServices =
            visibleProviderServices;
        _isLoading = false;
      });

      _loadFavorite(displayService);
    } on ApiException catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;

        _service ??=
            _serviceForSelectedLab(
              widget.service,
              const <Map<String, dynamic>>[],
            );
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;

        _service ??=
            _serviceForSelectedLab(
              widget.service,
              const <Map<String, dynamic>>[],
            );
      });
    }
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  double _priceForProviderService(Map<String, dynamic> providerService) {
    final value =
        providerService['final_price'] ??
        providerService['price'] ??
        providerService['base_price'] ??
        providerService['sale_price'];
    if (value is num) return value.toDouble();
    if (value != null) {
      final parsed = double.tryParse(
        value.toString().trim().replaceAll(',', ''),
      );
      if (parsed != null) return parsed;
    }
    return ApiConfig.priceFromMap(providerService);
  }

  double _homePriceForProviderService(Map<String, dynamic> providerService) {
    final value =
        providerService['home_service_price'] ??
        providerService['home_price'] ??
        (providerService['provider'] is Map
            ? (providerService['provider'] as Map)['home_service_fee']
            : null);
    if (value is num) return value.toDouble();
    if (value != null) {
      return double.tryParse(value.toString().replaceAll(',', '').trim()) ??
          0.0;
    }
    return 0.0;
  }

  double _providerRating(Map<String, dynamic> providerService) {
    final provider = providerService['provider'] is Map
        ? providerService['provider'] as Map<String, dynamic>
        : <String, dynamic>{};
    final rating = provider['avg_rating'];
    if (rating is num) return rating.toDouble();
    return double.tryParse(rating?.toString() ?? '') ?? 0.0;
  }

  List<Map<String, dynamic>> _visibleProviderServices() {
    final q = _providersSearchController.text.trim().toLowerCase();
    final visible = _providerServices.where((ps) {
      final provider = ps['provider'] is Map
          ? ps['provider'] as Map<String, dynamic>
          : <String, dynamic>{};
      final labName = LocaleUtils.localizedBusinessName(
        provider,
        context.read<AppSettingsProvider>().isArabic,
      ).toLowerCase();
      final city = (provider['city'] ?? '').toString().toLowerCase();
      final district = (provider['district'] ?? '').toString().toLowerCase();
      if (q.isNotEmpty &&
          !labName.contains(q) &&
          !city.contains(q) &&
          !district.contains(q)) {
        return false;
      }

      final price = _priceForProviderService(ps);
      if (_providersMinPrice != null && price < _providersMinPrice!) {
        return false;
      }
      if (_providersMaxPrice != null && price > _providersMaxPrice!) {
        return false;
      }
      if (_providersHomeOnly && _homePriceForProviderService(ps) <= 0) {
        return false;
      }
      return true;
    }).toList();

    visible.sort((a, b) {
      switch (_providersSort) {
        case 'price_low':
          return _priceForProviderService(
            a,
          ).compareTo(_priceForProviderService(b));
        case 'price_high':
          return _priceForProviderService(
            b,
          ).compareTo(_priceForProviderService(a));
        case 'rating':
          return _providerRating(b).compareTo(_providerRating(a));
        case 'name':
          final aProvider = a['provider'] is Map
              ? a['provider'] as Map<String, dynamic>
              : <String, dynamic>{};
          final bProvider = b['provider'] is Map
              ? b['provider'] as Map<String, dynamic>
              : <String, dynamic>{};
          final isArabic = context.read<AppSettingsProvider>().isArabic;
          return LocaleUtils.localizedBusinessName(
            aProvider,
            isArabic,
          ).compareTo(LocaleUtils.localizedBusinessName(bProvider, isArabic));
        default:
          return 0;
      }
    });
    return visible;
  }

  Map<String, dynamic>? _selectedProviderServiceForLab(
    List<Map<String, dynamic>> providerServices,
    Map<String, dynamic> service,
  ) {
    final selectedProviderServiceId = _asInt(
      service['provider_service_id'] ?? widget.service['provider_service_id'],
    );
    if (selectedProviderServiceId != null) {
      for (final ps in providerServices) {
        if (_asInt(ps['id']) == selectedProviderServiceId) return ps;
      }
    }

    final labId = widget.labId;
    if (labId == null) return null;
    for (final ps in providerServices) {
      final provider = ps['provider'] is Map
          ? ps['provider'] as Map<String, dynamic>
          : <String, dynamic>{};
      if (_asInt(provider['id'] ?? ps['provider_id']) == labId) return ps;
    }
    return null;
  }

  Map<String, dynamic> _serviceForSelectedLab(
    Map<String, dynamic> service,
    List<Map<String, dynamic>> providerServices,
  ) {
    final result = Map<String, dynamic>.from(service);
    final selectedProviderService = providerServices.isNotEmpty
        ? providerServices.first
        : null;
    final selectedProviderServiceId =
        selectedProviderService?['id'] ?? widget.service['provider_service_id'];
    if (selectedProviderServiceId != null) {
      result['provider_service_id'] = selectedProviderServiceId;
    }

    if (widget.labId == null) return result;

    final price = selectedProviderService != null
        ? _priceForProviderService(selectedProviderService)
        : ApiConfig.priceFromMap(widget.service);
    if (price > 0) {
      result['price'] = price;
      result['final_price'] = price;
    }

    final homePrice =
        selectedProviderService?['home_service_price'] ??
        selectedProviderService?['home_price'] ??
        widget.service['home_service_price'] ??
        widget.service['home_price'];
    if (homePrice != null) {
      result['home_service_price'] = homePrice;
      result['home_price'] = homePrice;
    }
    return result;
  }

  String? _getImageUrl(
    Map<String, dynamic> s, [
    Map<String, dynamic>? providerService,
  ]) => ApiConfig.analysisImageUrl(s, providerService);

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();
    final isArabic = settings.isArabic;
    final lang = settings.language;
    final service = _service ?? widget.service;
    final category = service['category'] is Map
        ? service['category'] as Map<String, dynamic>
        : <String, dynamic>{};
    final catName = LocaleUtils.localizedName(
      category,
      context.watch<AppSettingsProvider>().isArabic,
    );
    final categoryName = catName.isEmpty ? 'تحليل' : catName;
    final imageUrl = _getImageUrl(
      service,
      _providerServices.isNotEmpty ? _providerServices.first : null,
    );
    final description =
        service['description_ar']?.toString() ??
        service['description']?.toString() ??
        'تحليل مخبري';
    double price = ApiConfig.priceFromMap(service);
    if (price == 0.0 && _providerServices.isNotEmpty) {
      final first = _providerServices.first;
      price = ApiConfig.priceFromMap(first);
    }
    final providersCount = _providerServices.length;

    return Directionality(
      textDirection: settings.textDirection,
      child: Container(
        decoration: const BoxDecoration(gradient: RastUi.headerGradient),
        child: Scaffold(
          backgroundColor: RastUi.screenSurface(context),
          bottomNavigationBar: (!_isLoading && _service != null)
              ? _buildBottomBar(context, service)
              : null,
          body: _isLoading && _service == null
              ? _buildLoading()
              : CustomScrollView(
            slivers: [
              // HEADER
              SliverAppBar(
                pinned: true,
                floating: false,
                automaticallyImplyLeading: false,

                elevation: 7,
                scrolledUnderElevation: 7,
                shadowColor: Colors.black.withValues(alpha: 0.36),

                backgroundColor: Colors.white,
                surfaceTintColor: Colors.white,
                toolbarHeight: 72,

                flexibleSpace: Directionality(
                  textDirection: TextDirection.ltr,
                  child: SafeArea(
                    bottom: false,
                    child: Stack(
                      children: [
                        // BACK
                        Positioned(
                          left: isArabic ? null : 7,
                          right: isArabic ? 7 : null,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => Navigator.pop(context),
                                borderRadius: BorderRadius.circular(30),
                                child: SizedBox(
                                  width: 44,
                                  height: 44,
                                  child: Center(
                                    child: Icon(
                                      isArabic
                                          ? Icons.arrow_forward_ios_rounded
                                          : Icons.arrow_back_ios_new_rounded,
                                      textDirection: TextDirection.ltr,
                                      color: const Color(0xFF171717),
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // FAVORITE
                        Positioned(
                          left: isArabic ? 10 : null,
                          right: isArabic ? null : 10,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _toggleFavorite(service),
                                borderRadius: BorderRadius.circular(30),
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE4F3FF),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFFD3E9F8),
                                    ),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      _isFavorite
                                          ? Icons.favorite_rounded
                                          : Icons.favorite_border_rounded,
                                      color: _isFavorite
                                          ? const Color(0xFFFF4D61)
                                          : const Color(0xFF172033),
                                      size: 22,
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

              // BODY
              SliverToBoxAdapter(
                child: Directionality(
                  textDirection:
                  context.watch<AppSettingsProvider>().textDirection,
                  child: Column(
                    children: [
                      // IMAGE
                      SizedBox(
                        height: imageUrl != null && imageUrl.isNotEmpty
                            ? 240
                            : 190,
                        width: double.infinity,
                        child: _buildHeroBackground(
                          context,
                          imageUrl,
                        ),
                      ),

                      // CONTENT
                      Transform.translate(
                        offset: const Offset(0, -45),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal:
                            Responsive.spacing(context, 20),
                          ),
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              // FLOATING TITLE CARD
                              _buildTitleSection(
                                context,
                                service,
                                categoryName,
                                price,
                              ),

                              SizedBox(
                                height:
                                Responsive.spacing(context, 20),
                              ),

                              // QUICK FACTS
                              _buildQuickFactsRow(
                                context,
                                price,
                                categoryName,
                                providersCount,
                              ),

                              SizedBox(
                                height:
                                Responsive.spacing(context, 24),
                              ),

                              // DESCRIPTION
                              _buildDescriptionCard(
                                context,
                                description,
                              ),

                              SizedBox(
                                height:
                                Responsive.spacing(context, 24),
                              ),

                              // LAB
                              if (widget.labId != null &&
                                  widget.labName != null)
                                _buildLabChip(
                                  widget.labName!,
                                )
                              else
                                _buildLabsSection(
                                  context,
                                  service,
                                ),

                              SizedBox(
                                height:
                                Responsive.spacing(context, 24),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitleSection(
    BuildContext context,
    Map<String, dynamic> service,
    String categoryName,
    double price,
  ) {
    final lang =
        context.watch<AppSettingsProvider>().language;
    return Container(
      padding: EdgeInsets.all(Responsive.spacing(context, 16)),
      decoration: BoxDecoration(
        color: RastUi.panelSurface(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: RastUi.softBorder(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 24,
            spreadRadius: 1,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  LocaleUtils.localizedName(
                    service,
                    context.watch<AppSettingsProvider>().isArabic,
                  ),
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 20),
                    fontWeight: FontWeight.w800,
                    color: RastUi.primaryText(context),
                    height: 1.3,
                  ),
                ),
                SizedBox(height: Responsive.spacing(context, 8)),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: RastUi.chipFill,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    categoryName,
                    style: TextStyle(
                      fontSize: Responsive.fontSize(context, 12),
                      color: RastUi.purple,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: Responsive.spacing(context, 12)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: RastUi.brandGradient,
              borderRadius: BorderRadius.circular(14),
              boxShadow: RastUi.softShadow,
            ),
            child: Text(
              price > 0
                  ? '${price.toStringAsFixed(2)} ${AppStrings.t('sar', lang)}'
                  : AppStrings.t('contactForPrice', lang),
              style: TextStyle(
                fontSize: Responsive.fontSize(context, 16),
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickFactsRow(
      BuildContext context,
      double price,
      String categoryName,
      int providersCount,
      ) {
    final lang =
        context.watch<AppSettingsProvider>().language;

    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = Responsive.spacing(context, 10);

        final isNarrow = constraints.maxWidth < 350;

        final itemWidth = isNarrow
            ? (constraints.maxWidth - spacing) / 2
            : (constraints.maxWidth - (spacing * 2)) / 3;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          alignment: WrapAlignment.center,
          children: [
            SizedBox(
              width: itemWidth,
              child: _buildFactTile(
                context,
                icon: Icons.payments_outlined,
                title: AppStrings.t('price', lang),
                value: price > 0
                    ? '${price.toStringAsFixed(0)} ${AppStrings.t('sar', lang)}'
                    : AppStrings.t('dependsOnLab', lang),
              ),
            ),

            SizedBox(
              width: itemWidth,
              child: _buildFactTile(
                context,
                icon: Icons.category_outlined,
                title: AppStrings.t('category', lang),
                value: categoryName,
              ),
            ),

            SizedBox(
              width: itemWidth,
              child: _buildFactTile(
                context,
                icon: Icons.business_outlined,
                title: AppStrings.t('laboratories', lang),
                value: providersCount > 0
                    ? providersCount.toString()
                    : AppStrings.t('notAvailable', lang),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFactTile(
      BuildContext context, {
        required IconData icon,
        required String title,
        required String value,
      }) {
    return Container(
      constraints: const BoxConstraints(
        minHeight: 105,
      ),
      padding: EdgeInsets.symmetric(
        vertical: Responsive.spacing(context, 10),
        horizontal: Responsive.spacing(context, 7),
      ),
      decoration: BoxDecoration(
        color: RastUi.panelSurface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: RastUi.softBorder(context),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: RastUi.purple.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 18,
              color: RastUi.purple,
            ),
          ),

          SizedBox(
            height: Responsive.spacing(context, 6),
          ),

          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 10.5),
              color: const Color(0xFF5B5561),
              fontWeight: FontWeight.w700,
              height: 1.15,
            ),
          ),

          SizedBox(
            height: Responsive.spacing(context, 3),
          ),

          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 12),
              color: const Color(0xFF171717),
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionCard(BuildContext context, String description) {
    final lang =
        context.watch<AppSettingsProvider>().language;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(Responsive.spacing(context, 18)),
      decoration: BoxDecoration(
        color: RastUi.panelSurface(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: RastUi.softBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: RastUi.brandGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.description_outlined,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              SizedBox(width: Responsive.spacing(context, 10)),
              Text(
                AppStrings.t('description', lang),
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 15),
                  fontWeight: FontWeight.w600,
                  color: RastUi.primaryText(context),
                ),
              ),
            ],
          ),
          SizedBox(height: Responsive.spacing(context, 12)),
          Text(
            description,
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 14),
              color: const Color(0xFF535353),
              height: 1.65,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabsSection(BuildContext context, Map<String, dynamic> service) {
    final settings =
    context.watch<AppSettingsProvider>();

    final lang = settings.language;
    final visible = _visibleProviderServices();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 22,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                gradient: AppTheme.auroraGradient,
              ),
            ),
            SizedBox(width: Responsive.spacing(context, 10)),
            Text(
              AppStrings.t('availableLabs', lang),
              style: TextStyle(
                fontSize: Responsive.fontSize(context, 16),
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
        SizedBox(height: Responsive.spacing(context, 14)),
        Row(
          children: [
            Expanded(
              child: SearchBox(
                controller: _providersSearchController,
                hintText: AppStrings.t(
                  'searchLabOrArea',
                  lang,
                ),
                onSearchTap: () => setState(() {}),
                onSubmitted: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 12),
            _providerFilterButton(),
          ],
        ),
        SizedBox(height: Responsive.spacing(context, 10)),
        _providerFilterSummary(visible.length),
        SizedBox(height: Responsive.spacing(context, 12)),
        if (_providerServices.isEmpty && !_isLoading)
          _emptyProviders(
            AppStrings.t(
              'noLabs',
              context.watch<AppSettingsProvider>().language,
            ),
          )
        else if (visible.isEmpty)
          _emptyProviders(
            AppStrings.t(
              'noLabsMatchFilters',
              lang,
            ),
          )
        else
          ...visible.map(
            (ps) => Padding(
              padding: EdgeInsets.only(bottom: Responsive.spacing(context, 12)),
              child: _ProviderCard(
                providerService: ps,
                serviceName: LocaleUtils.localizedName(
                  service,
                  context.watch<AppSettingsProvider>().isArabic,
                ),
                isArabic: context.watch<AppSettingsProvider>().isArabic,
                price: _priceForProviderService(ps),
                homePrice: _homePriceForProviderService(ps),
              ),
            ),
          ),
      ],
    );
  }

  Widget _emptyProviders(String text) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        vertical: Responsive.spacing(context, 24),
        horizontal: Responsive.spacing(context, 16),
      ),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.business_rounded,
            size: 28,
            color: AppTheme.onSurfaceVariant.withValues(alpha: 0.7),
          ),
          SizedBox(width: Responsive.spacing(context, 10)),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: Responsive.fontSize(context, 14),
                color: AppTheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _providerFilterButton() {
    return InkWell(
      onTap: _showProvidersFilterSheet,
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

  Widget _providerFilterSummary(int count) {
    final lang =
        context.watch<AppSettingsProvider>().language;

    final chips = <Widget>[
      _providerMiniChip(
        '$count ${AppStrings.t('laboratory', lang)}',
        Icons.business_rounded,
      ),
    ];

    if (_providersHomeOnly) {
      chips.add(
        _providerMiniChip(
          AppStrings.t('homeService', lang),
          Icons.home_rounded,
        ),
      );
    }

    if (_providersMinPrice != null ||
        _providersMaxPrice != null) {
      chips.add(
        _providerMiniChip(
          '${_providersMinPrice?.toStringAsFixed(0) ?? '0'}'
              ' - '
              '${_providersMaxPrice?.toStringAsFixed(0) ?? '∞'} '
              '${AppStrings.t('sar', lang)}',
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
            padding:
            const EdgeInsetsDirectional.only(
              end: 8,
            ),
            child: chip,
          ),
        )
            .toList(),
      ),
    );
  }

  Widget _providerMiniChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: RastUi.purple.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: RastUi.purple),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: RastUi.purple,
              fontSize: Responsive.fontSize(context, 11),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  void _showProvidersFilterSheet() {
    final settings =
    context.read<AppSettingsProvider>();

    final lang = settings.language;

    final minController = TextEditingController(
      text:
      _providersMinPrice?.toStringAsFixed(0) ?? '',
    );

    final maxController = TextEditingController(
      text:
      _providersMaxPrice?.toStringAsFixed(0) ?? '',
    );

    var sort = _providersSort;
    var homeOnly = _providersHomeOnly;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) =>
            Directionality(
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
                  borderRadius:
                  const BorderRadius.vertical(
                    top: Radius.circular(26),
                  ),
                  boxShadow:
                  AppTheme.cardShadowElevated,
                ),
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize:
                      MainAxisSize.min,
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 42,
                            height: 4,
                            decoration:
                            BoxDecoration(
                              color: AppTheme
                                  .onSurfaceVariant
                                  .withValues(
                                alpha: 0.35,
                              ),
                              borderRadius:
                              BorderRadius.circular(
                                2,
                              ),
                            ),
                          ),
                        ),

                        SizedBox(
                          height:
                          Responsive.spacing(
                            context,
                            16,
                          ),
                        ),

                        Text(
                          AppStrings.t(
                            'filterAvailableLabs',
                            lang,
                          ),
                          style: TextStyle(
                            color:
                            RastUi.primaryText(
                              context,
                            ),
                            fontSize:
                            Responsive.fontSize(
                              context,
                              18,
                            ),
                            fontWeight:
                            FontWeight.w800,
                          ),
                        ),

                        SizedBox(
                          height:
                          Responsive.spacing(
                            context,
                            18,
                          ),
                        ),

                        Text(
                          AppStrings.t(
                            'sortBy',
                            lang,
                          ),
                          style: TextStyle(
                            color:
                            RastUi.textPurple,
                            fontSize:
                            Responsive.fontSize(
                              context,
                              13,
                            ),
                            fontWeight:
                            FontWeight.w700,
                          ),
                        ),

                        const SizedBox(height: 8),

                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _providerChoice(
                              AppStrings.t(
                                'highestRated',
                                lang,
                              ),
                              'rating',
                              sort,
                                  (value) {
                                setSheetState(
                                      () => sort = value,
                                );
                              },
                            ),

                            _providerChoice(
                              AppStrings.t(
                                'priceLowToHigh',
                                lang,
                              ),
                              'price_low',
                              sort,
                                  (value) {
                                setSheetState(
                                      () => sort = value,
                                );
                              },
                            ),

                            _providerChoice(
                              AppStrings.t(
                                'priceHighToLow',
                                lang,
                              ),
                              'price_high',
                              sort,
                                  (value) {
                                setSheetState(
                                      () => sort = value,
                                );
                              },
                            ),

                            _providerChoice(
                              AppStrings.t(
                                'sortByName',
                                lang,
                              ),
                              'name',
                              sort,
                                  (value) {
                                setSheetState(
                                      () => sort = value,
                                );
                              },
                            ),
                          ],
                        ),

                        SizedBox(
                          height:
                          Responsive.spacing(
                            context,
                            18,
                          ),
                        ),

                        SwitchListTile(
                          value: homeOnly,
                          onChanged: (value) =>
                              setSheetState(
                                    () => homeOnly = value,
                              ),
                          title: Text(
                            AppStrings.t(
                              'homeVisitLabsOnly',
                              lang,
                            ),
                          ),
                          contentPadding:
                          EdgeInsets.zero,
                          activeThumbColor:
                          RastUi.purple,
                        ),

                        SizedBox(
                          height:
                          Responsive.spacing(
                            context,
                            10,
                          ),
                        ),

                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller:
                                minController,
                                keyboardType:
                                TextInputType
                                    .number,
                                decoration:
                                InputDecoration(
                                  labelText:
                                  AppStrings.t(
                                    'minimumPrice',
                                    lang,
                                  ),
                                  prefixIcon:
                                  const Icon(
                                    Icons
                                        .payments_outlined,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(
                              width: 12,
                            ),

                            Expanded(
                              child: TextField(
                                controller:
                                maxController,
                                keyboardType:
                                TextInputType
                                    .number,
                                decoration:
                                InputDecoration(
                                  labelText:
                                  AppStrings.t(
                                    'maximumPrice',
                                    lang,
                                  ),
                                  prefixIcon:
                                  const Icon(
                                    Icons
                                        .payments_outlined,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        SizedBox(
                          height:
                          Responsive.spacing(
                            context,
                            20,
                          ),
                        ),

                        Row(
                          children: [
                            Expanded(
                              child:
                              OutlinedButton(
                                onPressed: () {
                                  setState(() {
                                    _providersSort =
                                    'rating';

                                    _providersHomeOnly =
                                    false;

                                    _providersMinPrice =
                                    null;

                                    _providersMaxPrice =
                                    null;
                                  });

                                  Navigator.pop(ctx);
                                },
                                child: Text(
                                  AppStrings.t(
                                    'clear',
                                    lang,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(
                              width: 12,
                            ),

                            Expanded(
                              child: FilledButton(
                                onPressed: () {
                                  setState(() {
                                    _providersSort =
                                        sort;

                                    _providersHomeOnly =
                                        homeOnly;

                                    _providersMinPrice =
                                        double.tryParse(
                                          minController
                                              .text
                                              .trim(),
                                        );

                                    _providersMaxPrice =
                                        double.tryParse(
                                          maxController
                                              .text
                                              .trim(),
                                        );
                                  });

                                  Navigator.pop(ctx);
                                },
                                child: Text(
                                  AppStrings.t(
                                    'apply',
                                    lang,
                                  ),
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

  Widget _providerChoice(
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

  Widget _buildHeroBackground(BuildContext context, String? imageUrl) {
    final hasImage = imageUrl != null && imageUrl.trim().isNotEmpty;
    if (!hasImage) {
      return _buildImagePlaceholder();
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        HeroImageBackground(
          imageUrl: imageUrl,
          placeholder: _buildImageLoadingPlaceholder(),
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
      ],
    );
  }

  Widget _buildImageLoadingPlaceholder() {
    return ColoredBox(
      color: RastUi.subtleFill(context),
      child: Center(
        child: Icon(
          Icons.medical_services_outlined,
          size: 64,
          color: AppTheme.primary.withValues(alpha: 0.35),
        ),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, Map<String, dynamic> service) {
    return Material(
      elevation: 12,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      color: RastUi.screenSurface(context),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            Responsive.spacing(context, 20),
            Responsive.spacing(context, 12),
            Responsive.spacing(context, 20),
            Responsive.spacing(context, 14),
          ),
          child: SizedBox(
            width: double.infinity,
          child: GradientFilledButton(
            onPressed: () => _showBookingOptions(context, service),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 54),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.calendar_today_rounded, size: 22),
                const SizedBox(width: 10),
                Text(
                  AppStrings.t(
                    'bookNow',
                    context.watch<AppSettingsProvider>().language,
                  ),
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 16),
                    fontWeight: FontWeight.w600,
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

  Widget _buildImagePlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.primary.withValues(alpha: 0.9),
            AppTheme.primaryDark.withValues(alpha: 0.95),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.medical_services_outlined,
          size: 80,
          color: Colors.white.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  Widget _buildLabChip(String labName) {
    return Container(
      padding: EdgeInsets.all(Responsive.spacing(context, 16)),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.business_rounded,
              color: AppTheme.primary,
              size: 26,
            ),
          ),
          SizedBox(width: Responsive.spacing(context, 14)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  labName,
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 15),
                    fontWeight: FontWeight.w600,
                    color: AppTheme.onSurface,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  AppStrings.t(
                  'certifiedLaboratory',
                  context.watch<AppSettingsProvider>().language,
                  ),
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 12),
                    color: AppTheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.primary),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return Padding(
      padding: EdgeInsets.all(Responsive.spacing(context, 16)),
      child: Shimmer.fromColors(
        baseColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        highlightColor: Theme.of(context).colorScheme.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            SizedBox(height: Responsive.spacing(context, 24)),
            Container(
              height: 80,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            SizedBox(height: Responsive.spacing(context, 16)),
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBookingOptions(BuildContext context, Map<String, dynamic> service) {
    final labId = widget.labId;
    final providerServiceId = service['provider_service_id'];

    if (labId != null) {
      if (providerServiceId != null) {
        _openBookFlow(
          context,
          service,
          labId,
          widget.labName ?? '',
          _buildProviderServiceMap(service, providerServiceId),
          lab: widget.lab,
        );
        return;
      }

      if (_providerServices.isNotEmpty) {
        final ps = _providerServices.first;
        _openBookFlow(
          context,
          service,
          labId,
          widget.labName ?? '',
          _psToProviderServiceMap(
            ps,
            LocaleUtils.localizedName(
              service,
              context.read<AppSettingsProvider>().isArabic,
            ),
          ),
          lab: widget.lab,
        );
        return;
      }

      final lang = context.read<AppSettingsProvider>().language;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.t('noLabsForService', lang))),
      );
      return;
    }

    if (_providerServices.isEmpty) {
      final lang = context.read<AppSettingsProvider>().language;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.t('noLabsForService', lang))),
      );
      return;
    }

    if (_providerServices.length == 1) {
      final ps = _providerServices.first;
      final provider = ps['provider'] is Map
          ? ps['provider'] as Map<String, dynamic>
          : <String, dynamic>{};
      final lid = provider['id'];
      int? labIdVal;
      if (lid is int) {
        labIdVal = lid;
      } else if (lid is num) {
        labIdVal = lid.truncate();
      } else if (lid != null) {
        labIdVal = int.tryParse(lid.toString());
      }
      if (labIdVal != null) {
        _openBookFlow(
          context,
          service,
          labIdVal,
          LocaleUtils.localizedBusinessName(
            provider,
            context.read<AppSettingsProvider>().isArabic,
          ),
          _psToProviderServiceMap(
            ps,
            LocaleUtils.localizedName(
              service,
              context.read<AppSettingsProvider>().isArabic,
            ),
          ),
        );
        return;
      }
    }

    _showLabPickerSheet(context, service);
  }

  /// يُرجع خريطة provider_service للمرور لشاشة الحجز، مع سعر التحليل ورسوم المنزل من الـ API.
  Map<String, dynamic> _buildProviderServiceMap(
    Map<String, dynamic> service,
    dynamic providerServiceId,
  ) {
    final id = providerServiceId is int
        ? providerServiceId
        : int.tryParse(providerServiceId?.toString() ?? '');
    Map<String, dynamic>? matchedPs;
    if (id != null && _providerServices.isNotEmpty) {
      for (final ps in _providerServices) {
        final psId = ps['id'] is int
            ? ps['id'] as int
            : int.tryParse(ps['id']?.toString() ?? '');
        if (psId == id) {
          matchedPs = ps;
          break;
        }
      }
    }
    double price = 0.0;
    double? homePriceRaw;
    if (matchedPs != null) {
      price = _priceForProviderService(matchedPs);
      if (price == 0.0 && matchedPs['service'] is Map<String, dynamic>) {
        price = ApiConfig.priceFromMap(
          matchedPs['service'] as Map<String, dynamic>,
        );
      }
      final v = matchedPs['home_service_price'] ?? matchedPs['home_price'];
      if (v is num) {
        homePriceRaw = v.toDouble();
      } else if (v != null) {
        homePriceRaw = double.tryParse(v.toString());
      }
      if (homePriceRaw == null) {
        final provider = matchedPs['provider'] is Map
            ? matchedPs['provider'] as Map<String, dynamic>
            : widget.lab;
        final fee = provider?['home_service_fee'];
        if (fee is num) {
          homePriceRaw = fee.toDouble();
        } else if (fee != null) {
          homePriceRaw = double.tryParse(fee.toString());
        }
      }
    }
    if (homePriceRaw == null && widget.lab != null) {
      final fee = widget.lab!['home_service_fee'];
      if (fee is num) {
        homePriceRaw = fee.toDouble();
      } else if (fee != null) {
        homePriceRaw = double.tryParse(fee.toString());
      }
    }
    if (price == 0.0) {
      price = ApiConfig.priceFromMap(service);
      if (price == 0.0) {
        price = (service['price'] is num ? service['price'] as num : 0)
            .toDouble();
      }
    }
    homePriceRaw ??=
        (service['home_price'] is num
            ? (service['home_price'] as num).toDouble()
            : null) ??
        (id != null ? _findHomePriceForProviderService(id) : null);
    final homePrice = homePriceRaw ?? 0.0;
    return {
      'id': providerServiceId,
      'final_price': price,
      'price': price,
      'home_service_price': homePrice,
      'service': {'name_ar': service['name_ar']},
      'name_ar': service['name_ar'],
    };
  }

  double? _findHomePriceForProviderService(dynamic providerServiceId) {
    final id = providerServiceId is int
        ? providerServiceId
        : int.tryParse(providerServiceId?.toString() ?? '');
    if (id == null) return null;
    for (final ps in _providerServices) {
      final psId = ps['id'] is int
          ? ps['id'] as int
          : int.tryParse(ps['id']?.toString() ?? '');
      if (psId == id) {
        final v = ps['home_service_price'] ?? ps['home_price'];
        if (v is num) return v.toDouble();
        if (v != null) return double.tryParse(v.toString());
        return null;
      }
    }
    return null;
  }

  /// يبني خريطة provider_service من عنصر provider_services القادم من الـ API (مطابق لحساب الفاتورة في الباكند).
  Map<String, dynamic> _psToProviderServiceMap(
    Map<String, dynamic> ps,
    String serviceNameAr,
  ) {
    double price = _priceForProviderService(ps);
    if (price == 0.0 && ps['service'] is Map<String, dynamic>) {
      price = ApiConfig.priceFromMap(ps['service'] as Map<String, dynamic>);
    }
    var homeVal = ps['home_service_price'] ?? ps['home_price'];
    double homePrice = 0.0;
    if (homeVal is num) {
      homePrice = homeVal.toDouble();
    } else if (homeVal != null) {
      homePrice = double.tryParse(homeVal.toString()) ?? 0.0;
    } else {
      final provider = ps['provider'] is Map
          ? ps['provider'] as Map<String, dynamic>
          : widget.lab;
      final fee = provider?['home_service_fee'];
      if (fee is num) {
        homePrice = fee.toDouble();
      } else if (fee != null) {
        homePrice = double.tryParse(fee.toString()) ?? 0.0;
      }
    }
    return {
      'id': ps['id'],
      'final_price': price,
      'price': price,
      'home_service_price': homePrice,
      'service': {'name_ar': serviceNameAr},
      'name_ar': serviceNameAr,
    };
  }

  void _openBookFlow(
    BuildContext context,
    Map<String, dynamic> service,
    int labId,
    String labName,
    Map<String, dynamic> providerService, {
    Map<String, dynamic>? lab,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookFlowScreen(
          labId: labId,
          labName: labName,
          lab: lab,
          providerService: providerService,
        ),
      ),
    );
  }

  void _showLabPickerSheet(BuildContext context, Map<String, dynamic> service) {
    final settings =
    context.read<AppSettingsProvider>();

    final isArabic = settings.isArabic;
    final lang = settings.language;
    final serviceName = LocaleUtils.localizedName(service, isArabic);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
          textDirection: settings.textDirection,
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(ctx).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: AppTheme.cardShadowElevated,
            ),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 6),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(Responsive.spacing(context, 20)),
                  child: Row(
                    children: [
                      Icon(
                        Icons.business_rounded,
                        color: AppTheme.primary,
                        size: 28,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppStrings.t(
                              'chooseLabForBooking',
                                lang,
                              ),
                              style: TextStyle(
                                fontSize: Responsive.fontSize(context, 18),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              AppStrings.t(
                                'choosePreferredLab',
                                lang,
                              ),
                              style: TextStyle(
                                fontSize: Responsive.fontSize(context, 12),
                                color: AppTheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: _providerServices.length,
                    separatorBuilder: (_, __) => SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final ps = _providerServices[i];
                      final provider = ps['provider'] is Map
                          ? ps['provider'] as Map<String, dynamic>
                          : <String, dynamic>{};
                      final labIdVal = provider['id'] is int
                          ? provider['id'] as int
                          : int.tryParse(provider['id']?.toString() ?? '0') ?? 0;
                      final labName = LocaleUtils.localizedBusinessName(
                        provider,
                        isArabic,
                      );
                      final labImageUrl =
                          ApiConfig.imageFromMap(provider) ??
                              ApiConfig.resolveImageUrl(
                                provider['logo_url'],
                                provider['logo'],
                              );

                      return _LabPickerTile(
                        labName: labName,
                        city: provider['city']?.toString() ?? '',
                        price: _priceForProviderService(ps),
                        labImageUrl: labImageUrl,
                        onTap: () {
                          Navigator.pop(ctx);

                          _openBookFlow(
                            context,
                            service,
                            labIdVal,
                            labName,
                            _psToProviderServiceMap(
                              ps,
                              serviceName,
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
      )
    );
  }
}

class _LabPickerTile extends StatelessWidget {
  final String labName;
  final String city;
  final double price;
  final String? labImageUrl;
  final VoidCallback onTap;

  const _LabPickerTile({
    required this.labName,
    required this.city,
    required this.price,
    required this.labImageUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final lang =
        context.watch<AppSettingsProvider>().language;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.all(
            Responsive.spacing(context, 14),
          ),
          decoration:
          AppTheme.cardDecorationFor(context),
          child: Row(
            children: [
              // LAB IMAGE
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius:
                  BorderRadius.circular(12),
                  color: AppTheme.surfaceVariant,
                  border: Border.all(
                    color: AppTheme.primary
                        .withValues(alpha: 0.10),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black
                          .withValues(alpha: 0.07),
                      blurRadius: 8,
                      offset:
                      const Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius:
                  BorderRadius.circular(12),
                  child: labImageUrl != null &&
                      labImageUrl!.isNotEmpty
                      ? CachedNetworkImage(
                    imageUrl:
                    labImageUrl!,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    placeholder:
                        (_, __) =>
                        _labFallback(),
                    errorWidget:
                        (_, __, ___) =>
                        _labFallback(),
                  )
                      : _labFallback(),
                ),
              ),

              SizedBox(
                width:
                Responsive.spacing(context, 14),
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      labName,
                      maxLines: 1,
                      overflow:
                      TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize:
                        Responsive.fontSize(
                          context,
                          14,
                        ),
                        fontWeight:
                        FontWeight.w600,
                      ),
                    ),

                    if (city.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        city,
                        maxLines: 1,
                        overflow:
                        TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize:
                          Responsive.fontSize(
                            context,
                            11,
                          ),
                          color: AppTheme
                              .onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 8),

              Container(
                padding:
                const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  gradient:
                  AppTheme.auroraGradient,
                  borderRadius:
                  BorderRadius.circular(10),
                ),
                child: Text(
                  '${price.toStringAsFixed(2)} '
                      '${AppStrings.t('sar', lang)}',
                  maxLines: 1,
                  style: TextStyle(
                    fontSize:
                    Responsive.fontSize(
                      context,
                      12,
                    ),
                    color: Colors.white,
                    fontWeight:
                    FontWeight.w500,
                  ),
                ),
              ),

              const SizedBox(width: 8),

              Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: AppTheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _labFallback() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      alignment: Alignment.center,
      color: AppTheme.surfaceVariant,
      child: const Icon(
        Icons.business_rounded,
        color: AppTheme.primary,
        size: 22,
      ),
    );
  }
}

class _ProviderCard extends StatelessWidget {
  final Map<String, dynamic> providerService;
  final String serviceName;
  final bool isArabic;
  final double price;
  final double homePrice;

  const _ProviderCard({
    required this.providerService,
    required this.serviceName,
    required this.isArabic,
    required this.price,
    required this.homePrice,
  });

  @override
  Widget build(BuildContext context) {
    final lang =
        context.watch<AppSettingsProvider>().language;
    final lab = providerService['provider'] is Map
        ? providerService['provider'] as Map<String, dynamic>
        : <String, dynamic>{};
    final avgRating = (lab['avg_rating'] is num ? lab['avg_rating'] as num : 0)
        .toDouble();
    final totalReviews = (lab['total_reviews'] is num
        ? (lab['total_reviews'] as num).toInt()
        : 0);
    final logoUrl =
        ApiConfig.imageFromMap(lab) ??
        ApiConfig.resolveImageUrl(lab['logo_url'], lab['logo']);
    final name = LocaleUtils.localizedBusinessName(lab, isArabic);
    final city = lab['city']?.toString() ?? '';
    final district = lab['district']?.toString() ?? '';

    return Container(
      decoration: BoxDecoration(
        color: RastUi.cardSurface(context),
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppTheme.cardShadowElevated,
        border: Border.all(color: RastUi.softBorder(context)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => LabDetailsScreen(lab: lab)),
          ),
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: EdgeInsets.all(Responsive.spacing(context, 16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildLogo(logoUrl),
                    SizedBox(width: Responsive.spacing(context, 12)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: Responsive.fontSize(context, 15),
                              fontWeight: FontWeight.w800,
                              color: RastUi.primaryText(context),
                            ),
                          ),
                          SizedBox(height: Responsive.spacing(context, 4)),
                          Text(
                            '$city${district.isNotEmpty ? ' - $district' : ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: Responsive.fontSize(context, 11),
                              color: AppTheme.onSurfaceVariant,
                            ),
                          ),
                          SizedBox(height: Responsive.spacing(context, 7)),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF7E6),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFFFE0A3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  color: Color(0xFFFFB000),
                                  size: 16,
                                ),

                                const SizedBox(width: 5),

                                Text(
                                  avgRating.toStringAsFixed(1),
                                  style: TextStyle(
                                    color: const Color(0xFF27272A),
                                    fontSize: Responsive.fontSize(
                                      context,
                                      11,
                                    ),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),

                                if (totalReviews > 0) ...[
                                  const SizedBox(width: 4),

                                  Text(
                                    '($totalReviews)',
                                    style: TextStyle(
                                      color: const Color(0xFF71717A),
                                      fontSize: Responsive.fontSize(
                                        context,
                                        9.5,
                                      ),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: RastUi.purple.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: RastUi.purple.withValues(alpha: 0.20),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.payments_rounded,
                            color: RastUi.purple,
                            size: 16,
                          ),

                          const SizedBox(width: 6),

                          Text(
                            price > 0
                                ? '${price.toStringAsFixed(0)} ${AppStrings.t('sar', lang)}'
                                : AppStrings.t('priceAvailableLater', lang),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: RastUi.purple,
                              fontSize: Responsive.fontSize(
                                context,
                                12,
                              ),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: Responsive.spacing(context, 12)),
                Row(
                  children: [
                    Expanded(
                      child: _providerMetaChip(
                        context,
                        Icons.science_outlined,
                        serviceName,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _providerMetaChip(
                      context,
                      Icons.home_rounded,
                        homePrice > 0
                            ? '${homePrice.toStringAsFixed(0)} '
                            '${AppStrings.t('sar', lang)} · '
                            '${AppStrings.t('homeService', lang)}'
                            : AppStrings.t(
                          'noHomeService',
                          lang,
                        ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 12,
                      color: AppTheme.onSurfaceVariant,
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

  Widget _providerMetaChip(BuildContext context, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: RastUi.chipFill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: RastUi.purple),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: RastUi.textPurple,
                fontSize: Responsive.fontSize(context, 10),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo(String? url) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.9),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: (url != null && url.isNotEmpty)
            ? CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: AppTheme.surfaceVariant,
                  child: Icon(
                    Icons.business_rounded,
                    color: AppTheme.primary,
                    size: 24,
                  ),
                ),
                errorWidget: (_, __, ___) => Container(
                  color: AppTheme.surfaceVariant,
                  child: Icon(
                    Icons.business_rounded,
                    color: AppTheme.primary,
                    size: 24,
                  ),
                ),
              )
            : Container(
                color: AppTheme.primary.withValues(alpha: 0.1),
                child: Icon(
                  Icons.business_rounded,
                  color: AppTheme.primary,
                  size: 24,
                ),
              ),
      ),
    );
  }
}
