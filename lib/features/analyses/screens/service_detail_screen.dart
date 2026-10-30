import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:rast/core/widgets/rast_motion.dart';
import 'package:rast/features/loyalty/loyalty_config.dart';
import 'package:rast/core/services/analytics_service.dart';
import 'package:rast/core/constants/api_config.dart';
import 'package:rast/core/constants/app_strings.dart';
import 'package:rast/core/providers/app_settings_provider.dart';
import 'package:rast/core/services/favorites_service.dart';
import 'package:rast/core/utils/locale_utils.dart';
import 'package:provider/provider.dart';
import 'package:rast/core/theme/app_theme.dart';
import 'package:rast/core/utils/responsive.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:rast/core/services/branches_index_service.dart';
import 'package:rast/core/services/location_service.dart';
import 'package:rast/core/utils/lab_location_utils.dart';
import 'package:rast/core/widgets/rast_kit.dart';
import 'package:rast/core/widgets/rast_ui.dart';
import 'package:rast/core/widgets/zoomable_image_viewer.dart';
import 'package:rast/core/api/api_services.dart';
import 'package:rast/core/api/api_client.dart';
import 'package:rast/features/bookings/screens/book_flow_screen.dart';
import 'package:rast/features/lab_details/screens/lab_details_screen.dart';
import 'package:rast/features/analyses/detail_widgets/premium_detail.dart';
import 'package:rast/features/map/widgets/map_entry_button.dart';

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
  // الأرخص أولاً: هذا ما يبحث عنه أغلب العملاء عند مقارنة المختبرات
  String _providersSort = 'price_low';
  bool _providersHomeOnly = false;
  double? _providersMinPrice;
  double? _providersMaxPrice;

  final ScrollController _scrollController = ScrollController();
  bool _showHeaderTitle = false;
  bool _providersLoading = true;
  bool _aboutExpanded = false;
  (double, double)? _userLoc;
  int? _selectedPsId;
  int _tab = 0; // 0 المختبرات، 1 التفاصيل، 2 التحضير

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      final show = _scrollController.offset > 205;
      if (show != _showHeaderTitle) setState(() => _showHeaderTitle = show);
    });
    _loadUserLocation();
    AnalyticsService.logScreen('test_details');
    AnalyticsService.logViewItem(AnalyticsService.itemFromMap(
      widget.service,
      lab: widget.labName ?? widget.lab?['business_name_ar']?.toString(),
    ));

    _service = Map<String, dynamic>.from(
      widget.service,
    );

    _isLoading = false;

    _loadFavorite(widget.service);
    _loadData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
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
          _providersLoading = false;
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
        _providersLoading = false;
      });

      _loadFavorite(displayService);
    } on ApiException catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _providersLoading = false;

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
        _providersLoading = false;

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
        case 'distance':
          final da = _distanceFor(a) ?? double.infinity;
          final db = _distanceFor(b) ?? double.infinity;
          return da.compareTo(db);
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

  // ===================== أدوات العرض الجديدة =====================

  Map<String, dynamic> _providerOf(Map<String, dynamic> ps) => ps['provider'] is Map
      ? Map<String, dynamic>.from(ps['provider'] as Map)
      : <String, dynamic>{};

  int? _labIdOf(Map<String, dynamic> ps) {
    final provider = _providerOf(ps);
    return _asInt(provider['id'] ?? ps['provider_id']);
  }

  /// المسافة لأقرب فرع للمختبر من موقع المستخدم المحفوظ (إن وُجد).
  double? _distanceFor(Map<String, dynamic> ps) {
    final loc = _userLoc;
    if (loc == null) return null;
    final provider = _providerOf(ps);
    if (provider.isEmpty) return null;
    final branches = BranchesIndexService.instance.branchesFor(provider) ??
        (provider['branches'] is List ? provider['branches'] as List<dynamic> : null);
    return LabLocationUtils.distanceKmToNearest(
      lab: provider,
      userLat: loc.$1,
      userLng: loc.$2,
      branches: branches,
    );
  }

  Future<void> _loadUserLocation() async {
    try {
      final loc = await LocationService.getDefaultLocation();
      if (loc == null || !mounted) return;
      setState(() => _userLoc = (loc.lat, loc.lng));
      await BranchesIndexService.instance.ensureLoaded();
      if (mounted) setState(() {});
    } catch (_) {}
  }

  /// أرخص عرض متاح (لزر الحجز السريع والوسم «الأرخص»).
  Map<String, dynamic>? get _cheapestPs {
    Map<String, dynamic>? best;
    double? bestPrice;
    for (final ps in _providerServices) {
      final p = _priceForProviderService(ps);
      if (p <= 0) continue;
      if (bestPrice == null || p < bestPrice) {
        bestPrice = p;
        best = ps;
      }
    }
    return best ?? (_providerServices.isNotEmpty ? _providerServices.first : null);
  }

  Map<String, dynamic>? get _nearestPs {
    if (_userLoc == null) return null;
    Map<String, dynamic>? best;
    double? bestKm;
    for (final ps in _providerServices) {
      final km = _distanceFor(ps);
      if (km == null) continue;
      if (bestKm == null || km < bestKm) {
        bestKm = km;
        best = ps;
      }
    }
    return best;
  }

  /// المختبر المختار لزر الحجز في الأسفل (افتراضياً الأرخص).
  Map<String, dynamic>? get _selectedPs {
    final id = _selectedPsId;
    if (id != null) {
      for (final ps in _providerServices) {
        if (_asInt(ps['id']) == id) return ps;
      }
    }
    return _cheapestPs;
  }

  /// نصوص وصف وهمية لا تفيد المستخدم فلا نعرضها
  bool _isRealDescription(String? text) {
    final t = (text ?? '').trim();
    if (t.length < 12) return false;
    const fillers = ['تحليل مخبري', 'تحليل طبي', 'Lab test', 'lab test'];
    return !fillers.contains(t);
  }

  String _resultTimeText(String lang, Map<String, dynamic> service) {
    final d = _asInt(service['default_duration']) ?? 0;
    if (d <= 0) return '';
    if (lang == 'en') return d == 1 ? 'Results in 1 day' : 'Results in $d days';
    if (d == 1) return 'النتيجة خلال يوم';
    if (d == 2) return 'النتيجة خلال يومين';
    if (d <= 10) return 'النتيجة خلال $d أيام';
    return 'النتيجة خلال $d يوماً';
  }

  void _bookProviderService(
    BuildContext context,
    Map<String, dynamic> service,
    Map<String, dynamic> ps,
  ) {
    final isArabic = context.read<AppSettingsProvider>().isArabic;
    final provider = _providerOf(ps);
    final labIdVal = _labIdOf(ps);
    if (labIdVal == null) {
      _showBookingOptions(context, service);
      return;
    }
    _openBookFlow(
      context,
      service,
      labIdVal,
      LocaleUtils.localizedBusinessName(provider, isArabic),
      _psToProviderServiceMap(ps, LocaleUtils.localizedName(service, isArabic)),
    );
  }

  // ===================== البناء =====================

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();
    final isArabic = settings.isArabic;
    final lang = settings.language;
    final service = _service ?? widget.service;
    final category = service['category'] is Map
        ? service['category'] as Map<String, dynamic>
        : <String, dynamic>{};
    final catName = LocaleUtils.localizedName(category, isArabic);
    final categoryName = catName.isEmpty ? L(lang, 'تحليل', 'Test') : catName;
    final imageUrl = _getImageUrl(
      service,
      _providerServices.isNotEmpty ? _providerServices.first : null,
    );
    final description = isArabic
        ? (service['description_ar'] ?? service['description'] ?? service['description_en'])?.toString()
        : (service['description_en'] ?? service['description'] ?? service['description_ar'])?.toString();

    final title = LocaleUtils.localizedName(service, isArabic);

    final hasImage = imageUrl != null && imageUrl.trim().isNotEmpty;
    final tabs = [
      widget.labId != null ? L(lang, 'المختبر', 'Lab') : L(lang, 'المختبرات', 'Labs'),
      L(lang, 'التفاصيل', 'Details'),
      L(lang, 'التحضير', 'Preparation'),
    ];

    return Directionality(
      textDirection: settings.textDirection,
      child: Scaffold(
        backgroundColor: RastTokens.bg(context),
        bottomNavigationBar: _buildBottomBar(context, service, lang),
        body: CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            PremiumHeroAppBar(
              title: title,
              collapsed: _showHeaderTitle,
              image: PremiumHeroImage(url: imageUrl),
              onImageTap: hasImage ? () => showZoomableImage(context, imageUrl) : null,
              onBack: () => Navigator.pop(context),
              favorite: AnimatedFavoriteIcon(
                active: _isFavorite,
                inactiveColor: _showHeaderTitle ? RastTokens.ink(context) : Colors.white,
                size: 21,
              ),
              onFavorite: () => _toggleFavorite(service),
              onShare: service['id'] == null
                  ? null
                  : () => shareViaWhatsApp(
                        '$title — ${L(lang, 'قارن الأسعار واحجز على راست لابس', 'Compare prices and book on Rast Labs')}\n'
                        'https://rast-labs.com/user/services/${service['id']}',
                      ),
            ),
            // اللوحة البيضاء: التصنيف، الاسم، السعر الكبير، والمعلومات السريعة
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(RastTokens.gutter, 2, RastTokens.gutter, 0),
                child: _buildTitleBlock(context, service, title, categoryName, lang, isArabic),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(RastTokens.gutter, 16, RastTokens.gutter, 8),
                child: _buildFacts(context, service, lang),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: PremiumTabsHeader(
                tabs: tabs,
                index: _tab,
                dark: RastTokens.dark(context),
                onChanged: (i) => setState(() => _tab = i),
              ),
            ),
            SliverToBoxAdapter(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutCubic,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero).animate(anim),
                    child: child,
                  ),
                ),
                child: KeyedSubtree(
                  key: ValueKey('tab-$_tab'),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: switch (_tab) {
                      0 => widget.labId != null
                          ? Padding(
                              padding: const EdgeInsets.symmetric(horizontal: RastTokens.gutter),
                              child: _buildLabChip(widget.labName ?? ''),
                            )
                          : _buildLabsSection(context, service, lang, isArabic),
                      1 => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: RastTokens.gutter),
                          child: _buildDetailsTab(context, service, categoryName, description, lang),
                        ),
                      _ => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: RastTokens.gutter),
                          child: _buildPrepTab(context, service, lang),
                        ),
                    },
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
          ],
        ),
      ),
    );
  }

  /// تبويب «التفاصيل»: معلومات منظمة + الوصف الحقيقي فقط (لا نصوص حشو)
  Widget _buildDetailsTab(
    BuildContext context,
    Map<String, dynamic> service,
    String categoryName,
    String? description,
    String lang,
  ) {
    final resultTime = _resultTimeText(lang, service);
    final count = _providerServices.where((ps) => _priceForProviderService(ps) > 0).length;
    final nameEn = (service['name_en'] ?? '').toString().trim();
    final rows = <Widget>[
      RastInfoRow(icon: Icons.category_rounded, label: L(lang, 'التصنيف', 'Category'), value: categoryName),
      if (nameEn.isNotEmpty)
        RastInfoRow(icon: Icons.translate_rounded, label: L(lang, 'الاسم العلمي', 'Scientific name'), value: nameEn, color: RastTokens.brand2),
      if (resultTime.isNotEmpty)
        RastInfoRow(icon: Icons.schedule_rounded, label: L(lang, 'مدة ظهور النتيجة', 'Result time'), value: resultTime, color: RastTokens.info),
      if (widget.labId == null && count > 0)
        RastInfoRow(
          icon: Icons.apartment_rounded,
          label: L(lang, 'متوفر لدى', 'Available at'),
          value: lang == 'en' ? '$count labs' : (count == 1 ? 'مختبر واحد' : '$count مختبرات'),
          color: RastTokens.success,
        ),
    ];
    return Column(
      children: [
        RastCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) Divider(height: 22, color: RastTokens.line(context)),
                rows[i],
              ],
            ],
          ),
        ).entrance(0),
        if (_isRealDescription(description)) ...[
          const SizedBox(height: 14),
          _buildAbout(context, description!, lang).entrance(1),
        ],
      ],
    );
  }

  /// تبويب «التحضير»: التعليمات أو طمأنة واضحة بعدم الحاجة لصيام
  Widget _buildPrepTab(BuildContext context, Map<String, dynamic> service, String lang) {
    final needsPrep = service['requires_preparation'] == true ||
        service['requires_preparation'] == 1 ||
        service['requires_preparation']?.toString() == 'true';
    final prepText = (service['preparation_instructions'] ?? '').toString().trim();
    if (!needsPrep) {
      return RastCard(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const RastIconBox(icon: Icons.check_circle_rounded, color: RastTokens.success, size: 46),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    L(lang, 'لا يحتاج تحضيراً', 'No preparation needed'),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: RastTokens.ink(context)),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    L(lang, 'يمكنك إجراء التحليل في أي وقت دون صيام.', 'You can take this test anytime, no fasting.'),
                    style: TextStyle(fontSize: 13, height: 1.6, color: RastTokens.muted(context)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ).entrance(0);
    }
    return PremiumTextBlock(
      icon: Icons.no_food_rounded,
      color: RastTokens.warning,
      title: L(lang, 'قبل التحليل', 'Before the test'),
      text: prepText.isNotEmpty
          ? prepText
          : L(lang, 'يحتاج هذا التحليل تحضيراً مسبقاً، وسيؤكد لك المختبر التعليمات عند الحجز.',
              'This test needs preparation; the lab will confirm instructions when you book.'),
    );
  }

  Widget _headerButton({required Widget child, VoidCallback? onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: RastTokens.fill(context),
            shape: BoxShape.circle,
            border: Border.all(color: RastTokens.line(context)),
          ),
          alignment: Alignment.center,
          child: child,
        ),
      ),
    );
  }

  /// رأس اللوحة البيضاء: التصنيف، الاسم الكبير، والسعر البارز مع عدد المختبرات
  Widget _buildTitleBlock(
    BuildContext context,
    Map<String, dynamic> service,
    String title,
    String categoryName,
    String lang,
    bool isArabic,
  ) {
    final nameEn = (service['name_en'] ?? '').toString().trim();
    final showEn = isArabic && nameEn.isNotEmpty && nameEn != title;
    final count = _providerServices.where((ps) => _priceForProviderService(ps) > 0).length;
    final cheapest = _cheapestPs;
    final fromPrice = widget.labId != null
        ? ApiConfig.priceFromMap(service)
        : (cheapest != null ? _priceForProviderService(cheapest) : ApiConfig.priceFromMap(service));

    Widget? trailing;
    if (widget.labId == null && _providersLoading) {
      trailing = const RastSkeleton(width: 92, height: 30, radius: 999);
    } else if (widget.labId == null && count > 0) {
      trailing = GestureDetector(
        onTap: () => setState(() => _tab = 0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: RastTokens.brand2.withValues(alpha: RastTokens.dark(context) ? 0.2 : 0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.apartment_rounded, size: 16, color: RastTokens.brand2),
              const SizedBox(width: 6),
              Text(
                count == 1
                    ? L(lang, 'مختبر واحد', '1 lab')
                    : (lang == 'en' ? '$count labs' : '$count ${count <= 10 ? 'مختبرات' : 'مختبراً'}'),
                style: const TextStyle(color: RastTokens.brand2, fontWeight: FontWeight.w800, fontSize: 12.5),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RastPill(label: categoryName, icon: Icons.category_rounded, dense: true),
        const SizedBox(height: 10),
        Text(
          title,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: RastTokens.ink(context), height: 1.3),
        ),
        if (showEn) ...[
          const SizedBox(height: 2),
          Text(
            nameEn,
            textDirection: TextDirection.ltr,
            style: TextStyle(fontSize: 13.5, color: RastTokens.muted(context), fontWeight: FontWeight.w600),
          ),
        ],
        const SizedBox(height: 16),
        PremiumPriceBlock(
          amount: fromPrice > 0 ? fromPrice : null,
          lang: lang,
          from: widget.labId == null && count > 1,
          trailing: trailing,
        ),
      ],
    ).animate().fadeIn(duration: 350.ms, delay: 60.ms).slideY(begin: 0.06, end: 0, curve: Curves.easeOutCubic);
  }

  /// المعلومات السريعة كشارات + نقاط الولاء المتوقعة. شارة التحضير تفتح تبويب «التحضير».
  Widget _buildFacts(BuildContext context, Map<String, dynamic> service, String lang) {
    final resultTime = _resultTimeText(lang, service);
    final needsPrep = service['requires_preparation'] == true ||
        service['requires_preparation'] == 1 ||
        service['requires_preparation']?.toString() == 'true';
    final homeLabs = _providerServices.where((ps) => _homePriceForProviderService(ps) > 0).length;
    final cheapest = _cheapestPs;
    final price = widget.labId != null
        ? ApiConfig.priceFromMap(service)
        : (cheapest != null ? _priceForProviderService(cheapest) : 0.0);

    final pills = <Widget>[
      if (resultTime.isNotEmpty) RastPill(icon: Icons.schedule_rounded, label: resultTime, color: RastTokens.info),
      if (needsPrep)
        GestureDetector(
          onTap: () => setState(() => _tab = 2),
          child: RastPill(icon: Icons.no_food_rounded, label: L(lang, 'يحتاج تحضيراً', 'Needs preparation'), color: RastTokens.warning),
        )
      else if (service.containsKey('requires_preparation'))
        RastPill(icon: Icons.check_circle_rounded, label: L(lang, 'لا يحتاج صياماً', 'No fasting needed'), color: RastTokens.success),
      if (homeLabs > 0)
        RastPill(
          icon: Icons.home_rounded,
          label: lang == 'en'
              ? 'Home collection at $homeLabs ${homeLabs == 1 ? 'lab' : 'labs'}'
              : (homeLabs == 1 ? 'سحب منزلي لدى مختبر' : 'سحب منزلي لدى $homeLabs مختبرات'),
          color: RastTokens.brand,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (pills.isNotEmpty) Wrap(spacing: 8, runSpacing: 8, children: pills),
        if (price > 0) ...[
          const SizedBox(height: 10),
          EarnPointsBadge(amount: price, lang: lang, dense: false),
        ],
      ],
    ).animate().fadeIn(duration: 350.ms, delay: 120.ms);
  }

  Widget _buildLabsSection(
    BuildContext context,
    Map<String, dynamic> service,
    String lang,
    bool isArabic,
  ) {
    final visible = _visibleProviderServices();
    final cheapestId = _asInt(_cheapestPs?['id']);
    final nearestId = _asInt(_nearestPs?['id']);
    final selectedId = _asInt(_selectedPs?['id']);
    final sorts = <String>['price_low', if (_userLoc != null) 'distance', 'rating'];
    final hasExtraFilters = _providersHomeOnly || _providersMinPrice != null || _providersMaxPrice != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: RastSectionHeader(
                title: L(lang, 'قارن المختبرات', 'Compare labs'),
              ),
            ),
            // عرض مختبرات هذا التحليل على الخريطة بأسعارها
            if (service['id'] != null && _providerServices.isNotEmpty)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: RastTokens.gutter),
                child: MapEntryButton(
                  size: 42,
                  serviceId: _asInt(service['id']),
                  serviceName: LocaleUtils.localizedName(service, isArabic),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        // أدوات الترتيب لا معنى لها عندما لا يقدّم أي مختبر التحليل
        if (_providersLoading || _providerServices.isNotEmpty)
        Row(
          children: [
            Expanded(
              child: RastChoiceChips<String>(
                items: sorts,
                selected: sorts.contains(_providersSort) ? _providersSort : null,
                labelOf: (s) => switch (s) {
                  'price_low' => L(lang, 'الأرخص', 'Cheapest'),
                  'distance' => L(lang, 'الأقرب', 'Nearest'),
                  _ => L(lang, 'الأعلى تقييماً', 'Top rated'),
                },
                iconOf: (s) => switch (s) {
                  'price_low' => Icons.savings_rounded,
                  'distance' => Icons.near_me_rounded,
                  _ => Icons.star_rounded,
                },
                onSelected: (s) => setState(() => _providersSort = s),
                padding: const EdgeInsetsDirectional.only(start: RastTokens.gutter, end: 8),
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.only(end: RastTokens.gutter),
              child: Badge(
                isLabelVisible: hasExtraFilters,
                smallSize: 9,
                backgroundColor: RastTokens.danger,
                child: _headerButton(
                  onTap: _showProvidersFilterSheet,
                  child: const Icon(Icons.tune_rounded, color: RastTokens.brand, size: 20),
                ),
              ),
            ),
          ],
        ),
        if (_providerServices.length > 5) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: RastTokens.gutter),
            child: RastSearchField(
              hint: AppStrings.t('searchLabOrArea', lang),
              controller: _providersSearchController,
              onChanged: (_) => setState(() {}),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: RastTokens.gutter),
          child: Builder(
            builder: (context) {
              if (_providersLoading && _providerServices.isEmpty) {
                return Column(
                  children: List.generate(
                    3,
                    (_) => const Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: RastSkeleton(height: 96, radius: RastTokens.radius),
                    ),
                  ),
                );
              }
              if (_providerServices.isEmpty) {
                return SizedBox(
                  width: double.infinity,
                  child: RastCard(
                    child: RastEmptyState(
                      icon: Icons.apartment_rounded,
                      title: L(lang, 'غير متوفر حالياً', 'Not available yet'),
                      message: L(
                        lang,
                        'لا يقدّم أي مختبر هذا التحليل الآن. تصفّح تحاليل مشابهة أو اسألنا على واتساب.',
                        'No lab offers this test right now. Browse similar tests or ask us on WhatsApp.',
                      ),
                    ),
                  ),
                );
              }
              if (visible.isEmpty) {
                return SizedBox(width: double.infinity, child: RastCard(
                  child: RastEmptyState(
                    icon: Icons.filter_alt_off_rounded,
                    title: AppStrings.t('noLabsMatchFilters', lang),
                    actionLabel: AppStrings.t('clear', lang),
                    onAction: () => setState(() {
                      _providersHomeOnly = false;
                      _providersMinPrice = null;
                      _providersMaxPrice = null;
                      _providersSearchController.clear();
                    }),
                  ),
                ));
              }
              return Column(
                children: [
                  for (var i = 0; i < visible.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _LabOfferRow(
                        key: ValueKey('ps-${visible[i]['id']}'),
                        provider: _providerOf(visible[i]),
                        isArabic: isArabic,
                        lang: lang,
                        price: _priceForProviderService(visible[i]),
                        homePrice: _homePriceForProviderService(visible[i]),
                        distanceKm: _distanceFor(visible[i]),
                        isCheapest: _providerServices.length > 1 && _asInt(visible[i]['id']) == cheapestId,
                        isNearest: _providerServices.length > 1 && _asInt(visible[i]['id']) == nearestId,
                        selected: _providerServices.length > 1 && _asInt(visible[i]['id']) == selectedId,
                        onSelect: () => setState(() => _selectedPsId = _asInt(visible[i]['id'])),
                        onBook: () => _bookProviderService(context, service, visible[i]),
                        onOpenLab: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => LabDetailsScreen(lab: _providerOf(visible[i]))),
                        ),
                      ).entrance(i),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAbout(BuildContext context, String description, String lang) {
    return RastCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const RastIconBox(icon: Icons.description_rounded, size: 36),
              const SizedBox(width: 10),
              Text(
                L(lang, 'عن التحليل', 'About this test'),
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: RastTokens.ink(context)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AnimatedSize(
            duration: const Duration(milliseconds: 260),
            alignment: Alignment.topCenter,
            child: Text(
              description.trim(),
              maxLines: _aboutExpanded ? null : 4,
              overflow: _aboutExpanded ? null : TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, height: 1.7, color: RastTokens.muted(context)),
            ),
          ),
          if (description.trim().length > 180)
            GestureDetector(
              onTap: () => setState(() => _aboutExpanded = !_aboutExpanded),
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _aboutExpanded ? L(lang, 'عرض أقل', 'Show less') : L(lang, 'اقرأ المزيد', 'Read more'),
                  style: const TextStyle(color: RastTokens.brand, fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// شريط الحجز الثابت: يعرض سعر المختبر المختار واسمه، والحجز بضغطة واحدة.
  Widget? _buildBottomBar(BuildContext context, Map<String, dynamic> service, String lang) {
    final isArabic = context.read<AppSettingsProvider>().isArabic;
    String? labLine;
    double price;
    bool enabled;
    VoidCallback onBook;

    if (widget.labId != null) {
      price = ApiConfig.priceFromMap(service);
      labLine = widget.labName;
      enabled = true;
      onBook = () => _showBookingOptions(context, service);
    } else {
      final ps = _selectedPs;
      if (ps == null) {
        if (_providersLoading || _isLoading) return null;
        return RastStickyBar(
          child: RastButton(
            label: L(lang, 'غير متوفر حالياً', 'Not available yet'),
            icon: Icons.event_busy_rounded,
            onPressed: null,
          ),
        );
      }
      price = _priceForProviderService(ps);
      labLine = LocaleUtils.localizedBusinessName(_providerOf(ps), isArabic);
      enabled = true;
      onBook = () => _bookProviderService(context, service, ps);
    }

    return RastStickyBar(
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RastPrice(amount: price > 0 ? price : null, lang: lang, size: 19),
                if (labLine != null && labLine.isNotEmpty)
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: Text(
                      labLine,
                      key: ValueKey(labLine),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, color: RastTokens.muted(context), fontWeight: FontWeight.w600),
                    ),
                  ),
                // نقاط الولاء المتوقعة لهذا الحجز
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: EarnPointsBadge(amount: price > 0 ? price : null, lang: lang),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 6,
            child: RastButton(
              label: AppStrings.t('bookNow', lang),
              icon: Icons.event_available_rounded,
              onPressed: enabled ? onBook : null,
            ),
          ),
        ],
      ),
    );
  }

  /// عند فتح التحليل من صفحة مختبر: بطاقة المختبر بدل المقارنة.
  Widget _buildLabChip(String labName) {
    final lang = context.read<AppSettingsProvider>().language;
    final lab = widget.lab;
    final logo = lab == null
        ? null
        : (ApiConfig.imageFromMap(lab) ?? ApiConfig.resolveImageUrl(lab['logo_url'], lab['logo']));
    return RastCard(
      onTap: lab == null
          ? null
          : () => Navigator.push(context, MaterialPageRoute(builder: (_) => LabDetailsScreen(lab: lab))),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            height: 52,
            child: RastNetImage(url: logo, radius: 14, fallbackIcon: Icons.apartment_rounded, width: 52, height: 52),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  L(lang, 'تحجز لدى', 'Booking at'),
                  style: TextStyle(fontSize: 11.5, color: RastTokens.muted(context)),
                ),
                Text(
                  labName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: RastTokens.ink(context)),
                ),
                const SizedBox(height: 4),
                RastPill(
                  icon: Icons.verified_rounded,
                  label: AppStrings.t('certifiedLaboratory', lang),
                  color: RastTokens.success,
                  dense: true,
                ),
              ],
            ),
          ),
          if (lab != null)
            Icon(
              Directionality.of(context) == TextDirection.rtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
              color: RastTokens.muted(context),
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

/// صف مختبر في المقارنة: الشعار، الاسم، الموقع/المسافة، التقييم، السعر، الوسوم، وزر «احجز».
/// الضغط على الصف يختاره لشريط الحجز السفلي، والضغط على الشعار يفتح صفحة المختبر.
class _LabOfferRow extends StatelessWidget {
  const _LabOfferRow({
    super.key,
    required this.provider,
    required this.isArabic,
    required this.lang,
    required this.price,
    required this.homePrice,
    required this.distanceKm,
    required this.isCheapest,
    required this.isNearest,
    required this.selected,
    required this.onSelect,
    required this.onBook,
    required this.onOpenLab,
  });

  final Map<String, dynamic> provider;
  final bool isArabic;
  final String lang;
  final double price;
  final double homePrice;
  final double? distanceKm;
  final bool isCheapest;
  final bool isNearest;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onBook;
  final VoidCallback onOpenLab;

  @override
  Widget build(BuildContext context) {
    final name = LocaleUtils.localizedBusinessName(provider, isArabic);
    final logo = ApiConfig.imageFromMap(provider) ?? ApiConfig.resolveImageUrl(provider['logo_url'], provider['logo']);
    final rating = numOf(provider['avg_rating']) ?? 0;
    final reviews = (numOf(provider['total_reviews']) ?? 0).toInt();
    final city = (provider['city'] ?? '').toString().trim();
    final district = (provider['district'] ?? '').toString().trim();
    final place = [city, district].where((s) => s.isNotEmpty).join(' · ');
    final km = distanceKm;
    final distance = km == null
        ? null
        : (km < 1
            ? '${(km * 1000).round()} ${L(lang, 'م', 'm')}'
            : '${km.toStringAsFixed(1)} ${L(lang, 'كم', 'km')}');
    final locationLine = distance != null ? (place.isEmpty ? distance : '$distance · $place') : place;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(RastTokens.radius + 2),
        border: Border.all(color: selected ? RastTokens.brand : Colors.transparent, width: 1.6),
      ),
      child: RastCard(
        onTap: onSelect,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: onOpenLab,
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: RastTokens.line(context)),
                    ),
                    child: RastNetImage(url: logo, radius: 13, fallbackIcon: Icons.apartment_rounded, width: 50, height: 50),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: RastTokens.ink(context)),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          if (rating > 0) ...[
                            const Icon(Icons.star_rounded, color: RastTokens.gold, size: 16),
                            const SizedBox(width: 2),
                            Text(
                              rating.toStringAsFixed(1),
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: RastTokens.ink(context)),
                            ),
                            if (reviews > 0)
                              Text(' ($reviews)', style: TextStyle(fontSize: 11, color: RastTokens.muted(context))),
                            const SizedBox(width: 8),
                          ],
                          Flexible(
                            child: Text(
                              locationLine,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11.5, color: RastTokens.muted(context)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                RastPrice(
                  amount: price > 0 ? price : null,
                  lang: lang,
                  size: 18,
                  crossAxisAlignment: CrossAxisAlignment.end,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (isCheapest)
                        RastPill(icon: Icons.savings_rounded, label: L(lang, 'الأرخص', 'Cheapest'), color: RastTokens.success, dense: true),
                      if (isNearest)
                        RastPill(icon: Icons.near_me_rounded, label: L(lang, 'الأقرب', 'Nearest'), color: RastTokens.info, dense: true),
                      if (homePrice > 0)
                        RastPill(
                          icon: Icons.home_rounded,
                          label: '${L(lang, 'سحب منزلي', 'Home visit')} +${fmtPrice(homePrice)}',
                          color: RastTokens.brand,
                          dense: true,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 92,
                  child: RastButton(
                    label: L(lang, 'احجز', 'Book'),
                    height: 38,
                    onPressed: price > 0 ? onBook : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
