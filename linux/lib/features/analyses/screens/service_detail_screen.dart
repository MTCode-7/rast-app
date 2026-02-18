import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:rast/core/constants/api_config.dart';
import 'package:rast/core/providers/app_settings_provider.dart';
import 'package:rast/core/utils/locale_utils.dart';
import 'package:provider/provider.dart';
import 'package:rast/core/theme/app_theme.dart';
import 'package:rast/core/utils/responsive.dart';
import 'package:rast/core/widgets/rating_badge.dart';
import 'package:rast/core/api/api_services.dart';
import 'package:rast/core/api/api_client.dart';
import 'package:rast/features/bookings/screens/book_flow_screen.dart';
import 'package:rast/features/lab_details/screens/lab_details_screen.dart';
import 'package:shimmer/shimmer.dart';

class ServiceDetailScreen extends StatefulWidget {
  final Map<String, dynamic> service;
  final int? labId;
  final String? labName;

  const ServiceDetailScreen({super.key, required this.service, this.labId, this.labName});

  @override
  State<ServiceDetailScreen> createState() => _ServiceDetailScreenState();
}

class _ServiceDetailScreenState extends State<ServiceDetailScreen> {
  Map<String, dynamic>? _service;
  List<Map<String, dynamic>> _providerServices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final id = widget.service['id'];
    if (id == null) {
      setState(() {
        _service = widget.service;
        _isLoading = false;
      });
      return;
    }
    setState(() => _isLoading = true);
    try {
      final service = await Api.services.getService(id is int ? id : int.parse(id.toString()));
      final raw = service['provider_services'] as List? ?? [];
      final providerServices = raw.map((ps) => ps is Map ? Map<String, dynamic>.from(ps) : null).whereType<Map<String, dynamic>>().toList();
      setState(() {
        _service = service;
        _providerServices = providerServices;
        _isLoading = false;
      });
    } on ApiException catch (_) {
      setState(() {
        _isLoading = false;
        _service = widget.service;
      });
    } catch (_) {
      setState(() {
        _isLoading = false;
        _service = widget.service;
      });
    }
  }

  String? _getImageUrl(Map<String, dynamic> s) =>
      ApiConfig.resolveImageUrl(s['image_url'], s['image'] ?? s['thumbnail']);

  @override
  Widget build(BuildContext context) {
    final service = _service ?? widget.service;
    final category = service['category'] is Map ? service['category'] as Map<String, dynamic> : <String, dynamic>{};
    final _catName = LocaleUtils.localizedName(category, context.watch<AppSettingsProvider>().isArabic);
    final categoryName = _catName.isEmpty ? 'تحليل' : _catName;
    final imageUrl = _getImageUrl(service);
    final description = service['description_ar']?.toString() ?? service['description']?.toString() ?? 'تحليل مخبري';
    final price = (service['price'] is num ? service['price'] as num : 0).toDouble();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.surface,
        body: _isLoading && _service == null
            ? _buildLoading()
            : Column(
                children: [
                  Expanded(
                    child: CustomScrollView(
                      slivers: [
                  SliverAppBar(
                    expandedHeight: 220,
                    pinned: true,
                    backgroundColor: AppTheme.primary,
                    leading: IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 18),
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    flexibleSpace: FlexibleSpaceBar(
                      background: (imageUrl != null && imageUrl.isNotEmpty)
                          ? CachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(color: AppTheme.primary.withValues(alpha: 0.3)),
                              errorWidget: (_, __, ___) => _buildImagePlaceholder(),
                            )
                          : _buildImagePlaceholder(),
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
                        child: Padding(
                          padding: EdgeInsets.all(Responsive.spacing(context, 20)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          LocaleUtils.localizedName(service, context.watch<AppSettingsProvider>().isArabic),
                                          style: TextStyle(
                                            fontSize: Responsive.fontSize(context, 18),
                                            fontWeight: FontWeight.w500,
                                            color: AppTheme.onSurface,
                                          ),
                                        ),
                                        SizedBox(height: Responsive.spacing(context, 4)),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primary.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            categoryName,
                                            style: TextStyle(
                                              fontSize: Responsive.fontSize(context, 11),
                                              color: AppTheme.primary,
                                              fontWeight: FontWeight.w400,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      gradient: AppTheme.auroraGradient,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: AppTheme.softGlow,
                                    ),
                                    child: Text(
                                      '$price ر.س',
                                      style: TextStyle(
                                        fontSize: Responsive.fontSize(context, 16),
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: Responsive.spacing(context, 20)),
                              Text(
                                'الوصف',
                                style: TextStyle(
                                  fontSize: Responsive.fontSize(context, 13),
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.onSurface,
                                ),
                              ),
                              SizedBox(height: Responsive.spacing(context, 8)),
                              Text(
                                description,
                                style: TextStyle(
                                  fontSize: Responsive.fontSize(context, 13),
                                  color: AppTheme.onSurfaceVariant,
                                  height: 1.6,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              SizedBox(height: Responsive.spacing(context, 28)),
                              if (widget.labId != null && widget.labName != null) ...[
                                _buildLabChip(widget.labName!),
                              ] else ...[
                                Row(
                                  children: [
                                    Container(
                                      width: 4,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(2),
                                        gradient: AppTheme.auroraGradient,
                                      ),
                                    ),
                                    SizedBox(width: Responsive.spacing(context, 10)),
                                    Text(
                                      'المختبرات المتوفرة',
                                      style: TextStyle(
                                        fontSize: Responsive.fontSize(context, 14),
                                        fontWeight: FontWeight.w500,
                                        color: AppTheme.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: Responsive.spacing(context, 12)),
                                if (_providerServices.isEmpty && !_isLoading)
                                  Padding(
                                    padding: EdgeInsets.symmetric(vertical: Responsive.spacing(context, 16)),
                                    child: Text(
                                      'لا توجد مختبرات متاحة',
                                      style: TextStyle(fontSize: Responsive.fontSize(context, 13), color: AppTheme.onSurfaceVariant),
                                    ),
                                  )
                                else
                                  ..._providerServices.take(8).map((ps) => _ProviderCard(providerService: ps, serviceName: LocaleUtils.localizedName(service, context.watch<AppSettingsProvider>().isArabic), isArabic: context.watch<AppSettingsProvider>().isArabic)),
                              ],
                              SizedBox(height: Responsive.spacing(context, 100)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                    ),
                  ),
                ],
              ),
        bottomNavigationBar: _isLoading && _service == null ? null : SafeArea(
                  child: Padding(
                    padding: EdgeInsets.all(Responsive.spacing(context, 16)),
                    child: FilledButton(
                      onPressed: () => _showBookingOptions(context, service),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        padding: EdgeInsets.symmetric(vertical: Responsive.spacing(context, 14)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        elevation: 0,
                      ),
                      child: Text(
                        'احجز الآن',
                        style: TextStyle(
                          fontSize: Responsive.fontSize(context, 15),
                          fontWeight: FontWeight.w500,
                        ),
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
        child: Icon(Icons.medical_services_outlined, size: 80, color: Colors.white.withValues(alpha: 0.6)),
      ),
    );
  }

  Widget _buildLabChip(String labName) {
    return Container(
      padding: EdgeInsets.all(Responsive.spacing(context, 14)),
      decoration: AppTheme.cardDecoration(),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.business_rounded, color: AppTheme.primary, size: 24),
          ),
          SizedBox(width: Responsive.spacing(context, 14)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  labName,
                  style: TextStyle(fontSize: Responsive.fontSize(context, 14), fontWeight: FontWeight.w500),
                ),
                Text('مختبر معتمد', style: TextStyle(fontSize: Responsive.fontSize(context, 11), color: AppTheme.onSurfaceVariant)),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios, size: 12, color: AppTheme.onSurfaceVariant),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return Padding(
      padding: EdgeInsets.all(Responsive.spacing(context, 16)),
      child: Shimmer.fromColors(
        baseColor: AppTheme.surfaceVariant,
        highlightColor: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 200,
              decoration: BoxDecoration(color: AppTheme.surfaceVariant, borderRadius: BorderRadius.circular(20)),
            ),
            SizedBox(height: Responsive.spacing(context, 24)),
            Container(
              height: 80,
              decoration: BoxDecoration(color: AppTheme.surfaceVariant, borderRadius: BorderRadius.circular(16)),
            ),
            SizedBox(height: Responsive.spacing(context, 16)),
            Container(
              height: 120,
              decoration: BoxDecoration(color: AppTheme.surfaceVariant, borderRadius: BorderRadius.circular(16)),
            ),
          ],
        ),
      ),
    );
  }

  void _showBookingOptions(BuildContext context, Map<String, dynamic> service) {
    final labId = widget.labId;
    final providerServiceId = service['provider_service_id'];

    if (labId != null && providerServiceId != null) {
      _openBookFlow(context, service, labId, widget.labName ?? '', _buildProviderServiceMap(service, providerServiceId));
      return;
    }

    if (_providerServices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد مختبرات متاحة لهذا التحليل حالياً')),
      );
      return;
    }

    if (_providerServices.length == 1) {
      final ps = _providerServices.first;
      final provider = ps['provider'] is Map ? ps['provider'] as Map<String, dynamic> : <String, dynamic>{};
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
        _openBookFlow(context, service, labIdVal, LocaleUtils.localizedBusinessName(provider, context.read<AppSettingsProvider>().isArabic), _psToProviderServiceMap(ps, LocaleUtils.localizedName(service, context.read<AppSettingsProvider>().isArabic)));
        return;
      }
    }

    _showLabPickerSheet(context, service);
  }

  Map<String, dynamic> _buildProviderServiceMap(Map<String, dynamic> service, dynamic providerServiceId) {
    final price = (service['price'] is num ? service['price'] as num : 0).toDouble();
    final homePrice = (service['home_price'] is num ? (service['home_price'] as num).toDouble() : price + 25);
    return {
      'id': providerServiceId,
      'final_price': price,
      'price': price,
      'home_service_price': homePrice,
      'service': {'name_ar': service['name_ar']},
      'name_ar': service['name_ar'],
    };
  }

  Map<String, dynamic> _psToProviderServiceMap(Map<String, dynamic> ps, String serviceNameAr) {
    final price = (ps['final_price'] ?? ps['price'] ?? 0) is num ? (ps['final_price'] ?? ps['price'] as num).toDouble() : 0.0;
    final homePrice = (ps['home_service_price'] ?? ps['home_service_price']) is num ? (ps['home_service_price'] as num).toDouble() : price + 25;
    return {
      'id': ps['id'],
      'final_price': price,
      'price': price,
      'home_service_price': homePrice,
      'service': {'name_ar': serviceNameAr},
      'name_ar': serviceNameAr,
    };
  }

  void _openBookFlow(BuildContext context, Map<String, dynamic> service, int labId, String labName, Map<String, dynamic> providerService) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookFlowScreen(
          labId: labId,
          labName: labName,
          providerService: providerService,
        ),
      ),
    );
  }

  void _showLabPickerSheet(BuildContext context, Map<String, dynamic> service) {
    final isArabic = context.read<AppSettingsProvider>().isArabic;
    final serviceName = LocaleUtils.localizedName(service, isArabic);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: AppTheme.cardShadowElevated,
        ),
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 6),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.onSurfaceVariant.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: EdgeInsets.all(Responsive.spacing(context, 20)),
              child: Row(
                children: [
                  Icon(Icons.business_rounded, color: AppTheme.primary, size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('اختر المختبر للحجز', style: TextStyle(fontSize: Responsive.fontSize(context, 18), fontWeight: FontWeight.w600)),
                        Text('اختر المختبر الذي تفضل إجراء التحليل فيه', style: TextStyle(fontSize: Responsive.fontSize(context, 12), color: AppTheme.onSurfaceVariant)),
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
                  final provider = ps['provider'] is Map ? ps['provider'] as Map<String, dynamic> : <String, dynamic>{};
                  final labIdVal = provider['id'] is int ? provider['id'] as int : int.tryParse(provider['id']?.toString() ?? '0') ?? 0;
                  final labName = LocaleUtils.localizedBusinessName(provider, isArabic);
                  return _LabPickerTile(
                    labName: labName,
                    city: provider['city']?.toString() ?? '',
                    price: (ps['final_price'] ?? ps['price'] ?? 0) is num ? (ps['final_price'] ?? ps['price'] as num).toDouble() : 0.0,
                    onTap: () {
                      Navigator.pop(ctx);
                      _openBookFlow(context, service, labIdVal, labName, _psToProviderServiceMap(ps, serviceName));
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LabPickerTile extends StatelessWidget {
  final String labName;
  final String city;
  final double price;
  final VoidCallback onTap;

  const _LabPickerTile({required this.labName, required this.city, required this.price, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.all(Responsive.spacing(context, 14)),
          decoration: AppTheme.cardDecoration(),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.business_rounded, color: AppTheme.primary, size: 24),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(labName, style: TextStyle(fontSize: Responsive.fontSize(context, 14), fontWeight: FontWeight.w500)),
                    if (city.isNotEmpty) Text(city, style: TextStyle(fontSize: Responsive.fontSize(context, 11), color: AppTheme.onSurfaceVariant)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(gradient: AppTheme.auroraGradient, borderRadius: BorderRadius.circular(10)),
                child: Text('$price ر.س', style: TextStyle(fontSize: Responsive.fontSize(context, 12), color: Colors.white, fontWeight: FontWeight.w500)),
              ),
              SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProviderCard extends StatelessWidget {
  final Map<String, dynamic> providerService;
  final String serviceName;
  final bool isArabic;

  const _ProviderCard({required this.providerService, required this.serviceName, required this.isArabic});

  @override
  Widget build(BuildContext context) {
    final lab = providerService['provider'] is Map ? providerService['provider'] as Map<String, dynamic> : <String, dynamic>{};
    final avgRating = (lab['avg_rating'] is num ? lab['avg_rating'] as num : 0).toDouble();
    final totalReviews = (lab['total_reviews'] is num ? (lab['total_reviews'] as num).toInt() : 0);
    final logoUrl = ApiConfig.resolveImageUrl(lab['logo_url'], lab['logo']);
    final name = LocaleUtils.localizedBusinessName(lab, isArabic);
    final city = lab['city']?.toString() ?? '';

    return Container(
      margin: EdgeInsets.only(bottom: Responsive.spacing(context, 10)),
      decoration: AppTheme.cardDecoration(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => LabDetailsScreen(lab: lab)),
          ),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: EdgeInsets.all(Responsive.spacing(context, 12)),
            child: Row(
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
                          fontSize: Responsive.fontSize(context, 13),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      SizedBox(height: Responsive.spacing(context, 4)),
                      Text(
                        city,
                        style: TextStyle(
                          fontSize: Responsive.fontSize(context, 11),
                          color: AppTheme.onSurfaceVariant,
                        ),
                      ),
                      SizedBox(height: Responsive.spacing(context, 6)),
                      RatingBadge(
                        rating: avgRating,
                        reviewCount: totalReviews,
                        size: RatingBadgeSize.small,
                        showLabel: true,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, size: 12, color: AppTheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
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
        border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: (url != null && url.isNotEmpty)
            ? CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: AppTheme.surfaceVariant, child: Icon(Icons.business_rounded, color: AppTheme.primary, size: 24)),
                errorWidget: (_, __, ___) => Container(color: AppTheme.surfaceVariant, child: Icon(Icons.business_rounded, color: AppTheme.primary, size: 24)),
              )
            : Container(
                color: AppTheme.primary.withValues(alpha: 0.1),
                child: Icon(Icons.business_rounded, color: AppTheme.primary, size: 24),
              ),
      ),
    );
  }
}
