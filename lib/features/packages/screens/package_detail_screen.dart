import 'package:flutter/material.dart';
import 'package:rast/core/api/api_services.dart';
import 'package:rast/core/constants/api_config.dart';
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

class _PackageDetailScreenState extends State<PackageDetailScreen> {
  Map<String, dynamic>? _package;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final id = widget.package['id'];
    if (id == null) {
      setState(() {
        _package = widget.package;
        _isLoading = false;
      });
      return;
    }
    setState(() => _isLoading = true);
    try {
      final data = await Api.services.getPackage(
        id is int ? id : int.parse(id.toString()),
      );
      setState(() {
        _package = data.isNotEmpty ? data : widget.package;
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _package = widget.package;
        _isLoading = false;
      });
    }
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
      final n =
          serviceMap['name_ar'] ??
          serviceMap['name_en'] ??
          serviceMap['title_ar'] ??
          serviceMap['title'];
      if (n != null && n.toString().trim().isNotEmpty) {
        return n.toString().trim();
      }
    }
    final fromItem = LocaleUtils.localizedName(m, isArabic);
    if (fromItem.isNotEmpty) return fromItem;
    final nameAr = m['name_ar'] ?? m['title_ar'];
    final nameEn = m['name_en'] ?? m['title_en'] ?? m['title'];
    if (nameAr != null && nameAr.toString().trim().isNotEmpty) {
      return nameAr.toString().trim();
    }
    if (nameEn != null && nameEn.toString().trim().isNotEmpty) {
      return nameEn.toString().trim();
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لا توجد مختبرات متاحة لهذه الباقة حالياً'),
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
    final price = (ps['final_price'] ?? ps['price'] ?? 0) is num
        ? (ps['final_price'] ?? ps['price'] as num).toDouble()
        : 0.0;
    var homeFee = 0.0;
    final h = ps['home_service_price'] ?? ps['home_price'];
    if (h is num) {
      homeFee = h.toDouble();
    } else if (h != null) {
      homeFee = double.tryParse(h.toString()) ?? 0;
    }
    if (homeFee == 0) {
      final fee = provider['home_service_fee'];
      if (fee is num) {
        homeFee = fee.toDouble();
      } else if (fee != null) {
        homeFee = double.tryParse(fee.toString()) ?? 0;
      }
    }
    final providerService = {
      'id': ps['id'],
      'final_price': price,
      'price': price,
      'home_service_price': homeFee,
      'service': {'name_ar': pkgName},
      'name_ar': pkgName,
    };
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookFlowScreen(
          labId: labId!,
          labName: LocaleUtils.localizedBusinessName(provider, isArabic),
          providerService: providerService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pkg = _package ?? widget.package;
    final displayName = LocaleUtils.localizedName(
      pkg,
      context.watch<AppSettingsProvider>().isArabic,
    );
    final nameAr = displayName.isEmpty ? 'باقة' : displayName;
    final description =
        pkg['description_ar']?.toString() ??
        pkg['description']?.toString() ??
        '';
    double price = ApiConfig.priceFromMap(pkg);
    if (price == 0.0) {
      final psList = pkg['provider_services'] ?? pkg['providerServices'];
      if (psList is List && psList.isNotEmpty && psList.first is Map) {
        price = ApiConfig.priceFromMap(
          Map<String, dynamic>.from(psList.first as Map),
        );
      }
    }
    final orig = pkg['original_price'];
    final originalPrice = (orig is num)
        ? orig.toDouble()
        : ((orig is String) ? double.tryParse(orig) : null);
    final imageUrl = _getImageUrl(pkg);
    final items = _getPackageItemsList(pkg);
    final testsCount = pkg['tests_count'] ?? items.length;
    final isArabic = context.watch<AppSettingsProvider>().isArabic;
    final providerName = _providerName(pkg, isArabic);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        decoration: const BoxDecoration(gradient: RastUi.headerGradient),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: _isLoading && _package == null
              ? _buildLoading()
              : CustomScrollView(
                  slivers: [
                    SliverAppBar(
                      expandedHeight: 275,
                      pinned: true,
                      backgroundColor: RastUi.purple,
                      leading: IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.24),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.arrow_back_ios,
                            color: RastUi.screenSurface(context),
                            size: 18,
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      flexibleSpace: FlexibleSpaceBar(
                        background: Stack(
                          fit: StackFit.expand,
                          children: [
                            HeroImageBackground(
                              imageUrl: imageUrl,
                              placeholder: _buildPlaceholder(),
                            ),
                            IgnorePointer(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      RastUi.purple.withValues(alpha: 0.18),
                                      RastUi.purple.withValues(alpha: 0.88),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            IgnorePointer(
                              child: PositionedDirectional(
                              start: 22,
                              end: 22,
                              bottom: 34,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.18,
                                      ),
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    child: Text(
                                      '$testsCount تحليل',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    nameAr,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: Responsive.fontSize(
                                        context,
                                        23,
                                      ),
                                      fontWeight: FontWeight.w800,
                                      height: 1.2,
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
                    SliverToBoxAdapter(
                      child: Transform.translate(
                        offset: const Offset(0, -28),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(30),
                            ),
                          ),
                          padding: EdgeInsets.all(
                            Responsive.spacing(context, 20),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      nameAr,
                                      style: TextStyle(
                                        fontSize: Responsive.fontSize(
                                          context,
                                          20,
                                        ),
                                        fontWeight: FontWeight.w800,
                                        color: RastUi.primaryText(context),
                                      ),
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          gradient: RastUi.brandGradient,
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                          boxShadow: RastUi.softShadow,
                                        ),
                                        child: Text(
                                          price > 0
                                              ? '${price.toStringAsFixed(2)} ر.س'
                                              : 'اتصل للمعرفة',
                                          style: TextStyle(
                                            fontSize: Responsive.fontSize(
                                              context,
                                              15,
                                            ),
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      if (originalPrice != null)
                                        SizedBox(height: 4),
                                      if (originalPrice != null)
                                        Text(
                                          '${originalPrice.toStringAsFixed(2)} ر.س',
                                          style: TextStyle(
                                            fontSize: Responsive.fontSize(
                                              context,
                                              12,
                                            ),
                                            color: AppTheme.onSurfaceVariant,
                                            decoration:
                                                TextDecoration.lineThrough,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                              SizedBox(height: Responsive.spacing(context, 8)),
                              if (providerName.isNotEmpty)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: RastUi.panelSurface(context),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    providerName,
                                    style: TextStyle(
                                      fontSize: Responsive.fontSize(context, 12),
                                      color: RastUi.textPurple,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: RastUi.chipFill,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '$testsCount تحليل',
                                  style: TextStyle(
                                    fontSize: Responsive.fontSize(context, 12),
                                    color: RastUi.purple,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (description.isNotEmpty) ...[
                                SizedBox(
                                  height: Responsive.spacing(context, 20),
                                ),
                                _sectionTitle(
                                  'الوصف',
                                  Icons.description_outlined,
                                ),
                                SizedBox(height: 8),
                                _infoCard(
                                  child: Text(
                                    description,
                                    style: TextStyle(
                                      fontSize: Responsive.fontSize(
                                        context,
                                        13,
                                      ),
                                      color: const Color(0xFF6F6A75),
                                      height: 1.6,
                                    ),
                                  ),
                                ),
                              ],
                              if (items.isNotEmpty || testsCount > 0) ...[
                                SizedBox(
                                  height: Responsive.spacing(context, 24),
                                ),
                                Row(
                                  children: [
                                    _sectionTitle(
                                      'التحاليل المضمنة',
                                      Icons.fact_check_outlined,
                                    ),
                                  ],
                                ),
                                SizedBox(height: 12),
                                if (items.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Text(
                                      '$testsCount تحليل ضمن الباقة',
                                      style: TextStyle(
                                        fontSize: Responsive.fontSize(
                                          context,
                                          13,
                                        ),
                                        color: AppTheme.onSurfaceVariant,
                                      ),
                                    ),
                                  )
                                else
                                  ...items.take(20).map((item) {
                                    final isArabic = context
                                        .watch<AppSettingsProvider>()
                                        .isArabic;
                                    final name = _getItemDisplayName(
                                      item,
                                      isArabic,
                                    );
                                    final displayName = name.isEmpty
                                        ? 'تحليل'
                                        : name;
                                    return Padding(
                                      padding: EdgeInsets.only(bottom: 8),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.check_circle_rounded,
                                            size: 18,
                                            color: RastUi.blue,
                                          ),
                                          SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              displayName,
                                              style: TextStyle(
                                                fontSize: Responsive.fontSize(
                                                  context,
                                                  13,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                if (items.length > 20)
                                  Padding(
                                    padding: EdgeInsets.only(top: 4),
                                    child: Text(
                                      'و ${items.length - 20} تحليل آخر',
                                      style: TextStyle(
                                        fontSize: Responsive.fontSize(
                                          context,
                                          12,
                                        ),
                                        color: AppTheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                              ],
                              SizedBox(height: 100),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: EdgeInsets.all(Responsive.spacing(context, 16)),
              child: GradientFilledButtonIcon(
                onPressed: () => _handleBook(pkg),
                icon: const Icon(Icons.calendar_today_rounded, size: 20),
                label: const Text('احجز الآن'),
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            gradient: RastUi.brandGradient,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            color: RastUi.primaryText(context),
            fontSize: Responsive.fontSize(context, 15),
            fontWeight: FontWeight.w800,
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
