import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:rast/core/api/api_services.dart';
import 'package:rast/core/constants/api_config.dart';
import 'package:rast/core/providers/app_settings_provider.dart';
import 'package:rast/core/utils/locale_utils.dart';
import 'package:provider/provider.dart';
import 'package:rast/core/theme/app_theme.dart';
import 'package:rast/core/utils/responsive.dart';
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
      final data = await Api.services.getPackage(id is int ? id : int.parse(id.toString()));
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

  String? _getImageUrl(Map<String, dynamic> p) => ApiConfig.resolveImageUrl(p['image_url'], p['image']);

  Future<void> _handleBook(Map<String, dynamic> pkg) async {
    if (!AuthService.isLoggedIn) {
      final ok = await Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      if (ok != true || !mounted) return;
    }
    final raw = pkg['provider_services'] as List? ?? pkg['providerServices'] as List? ?? [];
    final providerServices = raw.map((ps) => ps is Map ? Map<String, dynamic>.from(ps) : null).whereType<Map<String, dynamic>>().toList();
    if (providerServices.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا توجد مختبرات متاحة لهذه الباقة حالياً')));
      }
      return;
    }
    final ps = providerServices.first;
    final provider = ps['provider'] is Map ? ps['provider'] as Map<String, dynamic> : <String, dynamic>{};
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
    final price = (ps['final_price'] ?? ps['price'] ?? 0) is num ? (ps['final_price'] ?? ps['price'] as num).toDouble() : 0.0;
    final homePrice = (ps['home_service_price'] ?? ps['home_service_price']) is num ? (ps['home_service_price'] as num).toDouble() : price + 25;
    final providerService = {
      'id': ps['id'],
      'final_price': price,
      'price': price,
      'home_service_price': homePrice,
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
    final displayName = LocaleUtils.localizedName(pkg, context.watch<AppSettingsProvider>().isArabic);
    final nameAr = displayName.isEmpty ? 'باقة' : displayName;
    final description = pkg['description_ar']?.toString() ?? pkg['description']?.toString() ?? '';
    final price = (pkg['price'] is num ? pkg['price'] as num : 0).toDouble();
    final originalPrice = pkg['original_price'] is num ? (pkg['original_price'] as num).toDouble() : null;
    final imageUrl = _getImageUrl(pkg);
    final items = pkg['package_items'] is List ? pkg['package_items'] as List : [];
    final testsCount = pkg['tests_count'] ?? items.length;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.surface,
        body: _isLoading && _package == null
            ? _buildLoading()
            : CustomScrollView(
                slivers: [
                  SliverAppBar(
                    expandedHeight: 240,
                    pinned: true,
                    backgroundColor: AppTheme.primary,
                    leading: IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 18),
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    flexibleSpace: FlexibleSpaceBar(
                      background: (imageUrl != null && imageUrl.isNotEmpty)
                          ? CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover, placeholder: (_, __) => _buildPlaceholder(), errorWidget: (_, __, ___) => _buildPlaceholder())
                          : _buildPlaceholder(),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Transform.translate(
                      offset: const Offset(0, -24),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                          boxShadow: AppTheme.cardShadowElevated,
                        ),
                        padding: EdgeInsets.all(Responsive.spacing(context, 20)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    nameAr,
                                    style: TextStyle(fontSize: Responsive.fontSize(context, 18), fontWeight: FontWeight.w500, color: AppTheme.onSurface),
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      decoration: BoxDecoration(gradient: AppTheme.auroraGradient, borderRadius: BorderRadius.circular(16), boxShadow: AppTheme.softGlow),
                                      child: Text('$price ر.س', style: TextStyle(fontSize: Responsive.fontSize(context, 16), color: Colors.white, fontWeight: FontWeight.w500)),
                                    ),
                                    if (originalPrice != null) SizedBox(height: 4),
                                    if (originalPrice != null) Text('$originalPrice ر.س', style: TextStyle(fontSize: Responsive.fontSize(context, 12), color: AppTheme.onSurfaceVariant, decoration: TextDecoration.lineThrough)),
                                  ],
                                ),
                              ],
                            ),
                            SizedBox(height: Responsive.spacing(context, 8)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                              child: Text('$testsCount تحليل', style: TextStyle(fontSize: Responsive.fontSize(context, 12), color: AppTheme.primary)),
                            ),
                            if (description.isNotEmpty) ...[
                              SizedBox(height: Responsive.spacing(context, 20)),
                              Text('الوصف', style: TextStyle(fontSize: Responsive.fontSize(context, 13), fontWeight: FontWeight.w500)),
                              SizedBox(height: 8),
                              Text(description, style: TextStyle(fontSize: Responsive.fontSize(context, 13), color: AppTheme.onSurfaceVariant, height: 1.6)),
                            ],
                            if (items.isNotEmpty) ...[
                              SizedBox(height: Responsive.spacing(context, 24)),
                              Row(
                                children: [
                                  Container(width: 4, height: 20, decoration: BoxDecoration(borderRadius: BorderRadius.circular(2), gradient: AppTheme.auroraGradient)),
                                  SizedBox(width: 10),
                                  Text('التحاليل المضمنة', style: TextStyle(fontSize: Responsive.fontSize(context, 14), fontWeight: FontWeight.w500)),
                                ],
                              ),
                              SizedBox(height: 12),
                              ...items.take(10).map((item) {
                                final m = item is Map ? item as Map<String, dynamic> : <String, dynamic>{};
                                final s = m['service'] ?? m;
                                final name = LocaleUtils.localizedName(s is Map ? s as Map<String, dynamic> : m is Map ? m as Map<String, dynamic> : null, context.watch<AppSettingsProvider>().isArabic);
                                return Padding(
                                  padding: EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      Icon(Icons.check_circle_rounded, size: 18, color: AppTheme.success),
                                      SizedBox(width: 10),
                                      Expanded(child: Text(name, style: TextStyle(fontSize: Responsive.fontSize(context, 13)))),
                                    ],
                                  ),
                                );
                              }),
                              if (items.length > 10) Padding(padding: EdgeInsets.only(top: 4), child: Text('و ${items.length - 10} تحاليل أخرى', style: TextStyle(fontSize: Responsive.fontSize(context, 12), color: AppTheme.onSurfaceVariant))),
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
            child: FilledButton.icon(
              onPressed: () => _handleBook(pkg),
              icon: const Icon(Icons.calendar_today_rounded, size: 20),
              label: const Text('احجز الآن'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 0,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppTheme.primary.withValues(alpha: 0.9), AppTheme.primaryDark.withValues(alpha: 0.95)]),
        ),
        child: Center(child: Icon(Icons.medical_services_outlined, size: 80, color: Colors.white.withValues(alpha: 0.6))),
      );

  Widget _buildLoading() => Padding(
        padding: EdgeInsets.all(16),
        child: Shimmer.fromColors(
          baseColor: AppTheme.surfaceVariant,
          highlightColor: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(height: 200, decoration: BoxDecoration(color: AppTheme.surfaceVariant, borderRadius: BorderRadius.circular(20))),
              SizedBox(height: 24),
              Container(height: 80, decoration: BoxDecoration(color: AppTheme.surfaceVariant, borderRadius: BorderRadius.circular(16))),
            ],
          ),
        ),
      );
}
