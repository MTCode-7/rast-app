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
import 'package:rast/core/widgets/search_box.dart';
import 'package:rast/core/utils/responsive.dart';
import 'package:rast/features/analyses/screens/service_detail_screen.dart';
import 'package:shimmer/shimmer.dart';

class AnalysesScreen extends StatefulWidget {
  final int? labId;
  final String? labName;
  final int? categoryId;

  const AnalysesScreen({super.key, this.labId, this.labName, this.categoryId});

  @override
  State<AnalysesScreen> createState() => _AnalysesScreenState();
}

class _AnalysesScreenState extends State<AnalysesScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _services = [];
  List<dynamic> _categories = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      List<dynamic> categories = [];
      List<dynamic> services = [];
      try {
        categories = await Api.services.getCategories();
      } catch (_) {}
      if (widget.labId != null) {
        services = await Api.providers.getProviderServices(widget.labId!);
      } else {
        final res = await Api.services.getServices(
          categoryId: widget.categoryId,
          search: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
        );
        final data = res['data'];
        services = data is List ? List.from(data) : (data is Map && data['data'] is List ? List.from(data['data'] as List) : []);
      }
      if (services.isEmpty) services = List.from(DummyData.services);
      if (categories.isEmpty) categories = List.from(DummyData.categories);
      setState(() {
        _categories = categories;
        _services = services;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _services = List.from(DummyData.services);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _services = List.from(DummyData.services);
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _getCategoryName(BuildContext context, dynamic catId) {
    if (catId == null) return '';
    for (final x in _categories) {
      if (x is Map && (x['id'] == catId || x['id']?.toString() == catId.toString())) {
        return LocaleUtils.localizedName(x as Map<String, dynamic>, context.watch<AppSettingsProvider>().isArabic);
      }
    }
    return '';
  }

  String? _getServiceImageUrl(Map<String, dynamic> service) {
    return ApiConfig.resolveImageUrl(
      service['image_url'],
      service['image'] ?? service['thumbnail'],
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.labName != null ? '${widget.labName}' : 'التحاليل';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.surface,
        appBar: AppBar(
          title: Text(
            title,
            style: TextStyle(fontSize: Responsive.fontSize(context, 16), fontWeight: FontWeight.w500),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: _isLoading
            ? _buildLoading()
            : _error != null && _services.isEmpty
                ? _buildError()
                : Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.all(Responsive.spacing(context, 16)),
                        child: SearchBox(
                          controller: _searchController,
                          hintText: 'ابحث عن تحليل...',
                          onSearchTap: _loadData,
                          onSubmitted: (_) => _loadData(),
                        ),
                      ),
                      Expanded(
                        child: _services.isEmpty
                            ? _buildEmpty()
                            : RefreshIndicator(
                                onRefresh: _loadData,
                                child: GridView.builder(
                                  padding: EdgeInsets.symmetric(horizontal: Responsive.spacing(context, 16)),
                                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    childAspectRatio: 0.72,
                                    crossAxisSpacing: Responsive.spacing(context, 10),
                                    mainAxisSpacing: Responsive.spacing(context, 10),
                                  ),
                                  itemCount: _services.length,
                                  itemBuilder: (context, index) {
                                    final item = _services[index];
                                    Map<String, dynamic> service;
                                    if (widget.labId != null) {
                                      final ps = item is Map ? item as Map<String, dynamic> : <String, dynamic>{};
                                      final s = ps['service'] ?? ps;
                                      service = s is Map ? Map<String, dynamic>.from(s) : <String, dynamic>{};
                                      service['price'] = ps['final_price'] ?? ps['price'] ?? service['price'];
                                      service['home_price'] = ps['home_service_price'] ?? ps['home_service_price'];
                                      service['provider_service_id'] = ps['id'];
                                    } else {
                                      service = item is Map ? Map<String, dynamic>.from(item) : <String, dynamic>{};
                                    }
                                    return _AnalysisCard(
                                      service: service,
                                      categoryName: _getCategoryName(context, service['category_id'] ?? service['service_category_id']),
                                      imageUrl: _getServiceImageUrl(service),
                                      isArabic: context.watch<AppSettingsProvider>().isArabic,
                                      isLabView: widget.labId != null,
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ServiceDetailScreen(
                                            service: service,
                                            labId: widget.labId,
                                            labName: widget.labName,
                                          ),
                                        ),
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
          Icon(Icons.medical_services_outlined, size: 72, color: AppTheme.onSurfaceVariant.withValues(alpha: 0.4)),
          SizedBox(height: Responsive.spacing(context, 16)),
          Text('لا توجد نتائج', style: TextStyle(fontSize: Responsive.fontSize(context, 15), color: AppTheme.onSurfaceVariant, fontWeight: FontWeight.w400)),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return GridView.builder(
      padding: EdgeInsets.all(Responsive.spacing(context, 16)),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.72,
        crossAxisSpacing: Responsive.spacing(context, 10),
        mainAxisSpacing: Responsive.spacing(context, 10),
      ),
      itemCount: 6,
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: AppTheme.surfaceVariant,
        highlightColor: Colors.white,
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
            Icon(Icons.cloud_off_rounded, size: 56, color: AppTheme.onSurfaceVariant.withValues(alpha: 0.5)),
            SizedBox(height: Responsive.spacing(context, 16)),
            Text(_error!, textAlign: TextAlign.center, style: TextStyle(fontSize: Responsive.fontSize(context, 13), color: AppTheme.onSurfaceVariant)),
            SizedBox(height: Responsive.spacing(context, 20)),
            FilledButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: const Text('إعادة المحاولة'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalysisCard extends StatelessWidget {
  final Map<String, dynamic> service;
  final String categoryName;
  final String? imageUrl;
  final bool isLabView;
  final bool isArabic;
  final VoidCallback onTap;

  const _AnalysisCard({
    required this.service,
    required this.categoryName,
    this.imageUrl,
    required this.isLabView,
    required this.isArabic,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final price = (service['price'] is num ? service['price'] as num : 0).toDouble();
    final displayName = LocaleUtils.localizedName(service, isArabic);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: AppTheme.cardDecoration(),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: (imageUrl != null && imageUrl!.isNotEmpty)
                    ? CachedNetworkImage(
                        imageUrl: imageUrl!,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          color: AppTheme.primary.withValues(alpha: 0.08),
                          child: Icon(Icons.medical_services_outlined, size: 36, color: AppTheme.primary.withValues(alpha: 0.5)),
                        ),
                        errorWidget: (_, __, ___) => _buildImageFallback(),
                      )
                    : _buildImageFallback(),
              ),
              Expanded(
                flex: 4,
                child: Padding(
                  padding: EdgeInsets.all(Responsive.spacing(context, 10)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: Responsive.fontSize(context, 11), fontWeight: FontWeight.w400),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              gradient: AppTheme.auroraGradient,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: AppTheme.softGlow,
                            ),
                            child: Text(
                              '$price ر.س',
                              style: TextStyle(fontSize: Responsive.fontSize(context, 10), color: Colors.white, fontWeight: FontWeight.w500),
                            ),
                          ),
                          Icon(Icons.arrow_forward_ios, size: 10, color: AppTheme.onSurfaceVariant.withValues(alpha: 0.6)),
                        ],
                      ),
                      if (categoryName.isNotEmpty)
                        Text(
                          categoryName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: Responsive.fontSize(context, 9), color: AppTheme.onSurfaceVariant),
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

  Widget _buildImageFallback() {
    return Container(
      width: double.infinity,
      color: AppTheme.primary.withValues(alpha: 0.08),
      child: Icon(Icons.medical_services_outlined, size: 48, color: AppTheme.primary.withValues(alpha: 0.4)),
    );
  }
}
