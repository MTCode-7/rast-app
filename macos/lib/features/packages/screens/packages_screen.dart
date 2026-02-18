import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:rast/core/api/api_services.dart';
import 'package:rast/core/constants/api_config.dart';
import 'package:rast/core/providers/app_settings_provider.dart';
import 'package:rast/core/utils/locale_utils.dart';
import 'package:provider/provider.dart';
import 'package:rast/core/api/api_client.dart';
import 'package:rast/core/constants/dummy_data.dart';
import 'package:rast/core/theme/app_theme.dart';
import 'package:rast/core/utils/responsive.dart';
import 'package:rast/features/packages/screens/package_detail_screen.dart';
import 'package:shimmer/shimmer.dart';

class PackagesScreen extends StatefulWidget {
  const PackagesScreen({super.key});

  @override
  State<PackagesScreen> createState() => _PackagesScreenState();
}

class _PackagesScreenState extends State<PackagesScreen> {
  List<dynamic> _packages = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final res = await Api.services.getPackages(page: 1, perPage: 50);
      final data = res['data'];
      var list = data is List ? List.from(data) : (data is Map && data['data'] is List ? List.from(data['data'] as List) : []);
      if (list.isEmpty) list = List.from(DummyData.packages);
      setState(() {
        _packages = list;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _packages = List.from(DummyData.packages);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _packages = List.from(DummyData.packages);
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          title: Text(
            'الباقات',
            style: TextStyle(fontSize: Responsive.fontSize(context, 16), fontWeight: FontWeight.w500),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Column(
          children: [
            if (_errorMessage != null && _packages.isNotEmpty)
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: AppTheme.primary.withValues(alpha: 0.1),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 18, color: AppTheme.primary),
                    SizedBox(width: 8),
                    Expanded(child: Text('عرض بيانات محلية بسبب خطأ في التحميل', style: TextStyle(fontSize: 12, color: AppTheme.primary))),
                  ],
                ),
              ),
            Expanded(
              child: _isLoading
                  ? _buildLoading()
                  : _packages.isEmpty
                      ? _buildEmpty()
                      : RefreshIndicator(
                    onRefresh: _loadData,
                    child: GridView.builder(
                      padding: EdgeInsets.all(Responsive.spacing(context, 16)),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.65,
                        crossAxisSpacing: Responsive.spacing(context, 12),
                        mainAxisSpacing: Responsive.spacing(context, 12),
                      ),
                      itemCount: _packages.length,
                      itemBuilder: (context, index) {
                        final pkg = _packages[index] is Map ? _packages[index] as Map<String, dynamic> : <String, dynamic>{};
                        return _PackageCard(
                          package: pkg,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => PackageDetailScreen(package: pkg)),
                          ),
                        ).animate().fadeIn(duration: 400.ms, delay: Duration(milliseconds: (index % 6) * 50)).slideY(begin: 0.03, end: 0, curve: Curves.easeOutCubic);
                      },
                    ),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 72, color: AppTheme.onSurfaceVariant.withValues(alpha: 0.4)),
          SizedBox(height: Responsive.spacing(context, 16)),
          Text('لا توجد باقات', style: TextStyle(fontSize: Responsive.fontSize(context, 15), color: AppTheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return GridView.builder(
      padding: EdgeInsets.all(Responsive.spacing(context, 16)),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.65,
        crossAxisSpacing: Responsive.spacing(context, 12),
        mainAxisSpacing: Responsive.spacing(context, 12),
      ),
      itemCount: 6,
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        highlightColor: Theme.of(context).colorScheme.surface,
        child: Container(
          decoration: BoxDecoration(color: AppTheme.surfaceVariant, borderRadius: BorderRadius.circular(20)),
        ),
      ),
    );
  }
}

class _PackageCard extends StatelessWidget {
  final Map<String, dynamic> package;
  final VoidCallback onTap;

  const _PackageCard({required this.package, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final displayName = LocaleUtils.localizedName(package, context.watch<AppSettingsProvider>().isArabic);
    final price = ApiConfig.priceFromMap(package);
    final originalPrice = (package['original_price'] is num) ? (package['original_price'] as num).toDouble() : null;
    final imageUrl = ApiConfig.packageImageUrl(package);
    final testsCount = package['tests_count'] ?? (package['package_items'] is List ? (package['package_items'] as List).length : 0);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: AppTheme.cardDecorationFor(context),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: (imageUrl != null && imageUrl.isNotEmpty)
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(color: AppTheme.primary.withValues(alpha: 0.08), child: Icon(Icons.medical_services_outlined, size: 36, color: AppTheme.primary.withValues(alpha: 0.5))),
                        errorWidget: (_, __, ___) => _buildFallback(),
                      )
                    : _buildFallback(),
              ),
              Expanded(
                flex: 4,
                child: Padding(
                  padding: EdgeInsets.all(Responsive.spacing(context, 10)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(displayName, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: Responsive.fontSize(context, 13), fontWeight: FontWeight.w500)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(gradient: AppTheme.auroraGradient, borderRadius: BorderRadius.circular(10), boxShadow: AppTheme.softGlow),
                            child: Text(price > 0 ? '${price.toStringAsFixed(2)} ر.س' : 'اتصل للمعرفة', style: TextStyle(fontSize: Responsive.fontSize(context, 12), color: Colors.white, fontWeight: FontWeight.w600)),
                          ),
                          if (originalPrice != null) Text('${originalPrice.toStringAsFixed(2)} ر.س', style: TextStyle(fontSize: Responsive.fontSize(context, 11), color: AppTheme.onSurfaceVariant, decoration: TextDecoration.lineThrough)),
                        ],
                      ),
                      Text('$testsCount تحليل', style: TextStyle(fontSize: Responsive.fontSize(context, 11), color: AppTheme.onSurfaceVariant)),
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

  Widget _buildFallback() => Container(width: double.infinity, color: AppTheme.primary.withValues(alpha: 0.08), child: Icon(Icons.medical_services_outlined, size: 48, color: AppTheme.primary.withValues(alpha: 0.4)));
}
