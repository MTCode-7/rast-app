import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:rast/core/constants/api_config.dart';
import 'package:rast/core/providers/app_settings_provider.dart';
import 'package:rast/core/utils/locale_utils.dart';
import 'package:provider/provider.dart';
import 'package:rast/core/theme/app_theme.dart';
import 'package:rast/core/api/api_services.dart';
import 'package:rast/core/widgets/gradient_button.dart';
import 'package:rast/core/api/api_client.dart';
import 'package:rast/core/utils/responsive.dart';
import 'package:rast/core/widgets/rating_badge.dart';
import 'package:rast/features/analyses/screens/analyses_screen.dart';
import 'package:rast/features/analyses/screens/service_detail_screen.dart';
import 'package:shimmer/shimmer.dart';

class LabDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> lab;

  const LabDetailsScreen({super.key, required this.lab});

  @override
  State<LabDetailsScreen> createState() => _LabDetailsScreenState();
}

class _LabDetailsScreenState extends State<LabDetailsScreen> {
  List<dynamic> _branches = [];
  List<dynamic> _services = [];
  List<dynamic> _reviews = [];
  bool _isLoading = true;
  String? _error;

  int get _labId => widget.lab['id'] is int ? widget.lab['id'] as int : int.tryParse(widget.lab['id']?.toString() ?? '0') ?? 0;

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
      final provider = await Api.providers.getProvider(_labId);
      final branches = await Api.providers.getProviderBranches(_labId);
      final services = await Api.providers.getProviderServices(_labId);
      final reviews = provider['reviews'] is List ? List.from(provider['reviews'] as List) : [];
      setState(() {
        _branches = branches;
        _services = services;
        _reviews = reviews;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lab = widget.lab;
    final logoUrl = ApiConfig.imageFromMap(lab) ?? ApiConfig.resolveImageUrl(lab['logo_url'], lab['logo']);
    final name = LocaleUtils.localizedBusinessName(lab, context.watch<AppSettingsProvider>().isArabic);
    final city = lab['city']?.toString() ?? '';
    final district = lab['district']?.toString() ?? '';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: _isLoading
            ? _buildLoading()
            : _error != null
                ? _buildError()
                : CustomScrollView(
                    slivers: [
                      SliverAppBar(
                        expandedHeight: 260,
                        pinned: true,
                        stretch: true,
                        backgroundColor: AppTheme.primary,
                        leading: IconButton(
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(12)),
                            child: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 18),
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                        flexibleSpace: FlexibleSpaceBar(
                          stretchModes: const [StretchMode.zoomBackground],
                          background: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (logoUrl != null && logoUrl.isNotEmpty)
                                CachedNetworkImage(imageUrl: logoUrl, fit: BoxFit.cover, placeholder: (_, __) => _buildPlaceholder(), errorWidget: (_, __, ___) => _buildPlaceholder())
                              else
                                _buildPlaceholder(),
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [Colors.transparent, Colors.black.withValues(alpha: 0.6)],
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                child: Padding(
                                  padding: EdgeInsets.all(Responsive.spacing(context, 20)),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        name,
                                        style: TextStyle(fontSize: Responsive.fontSize(context, 22), fontWeight: FontWeight.w500, color: Colors.white, shadows: [Shadow(color: Colors.black54, blurRadius: 8)]),
                                      ),
                                      SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Icon(Icons.location_on_rounded, size: 16, color: Colors.white.withValues(alpha: 0.9)),
                                          SizedBox(width: 6),
                                          Text('$city${district.isNotEmpty ? ' - $district' : ''}', style: TextStyle(fontSize: Responsive.fontSize(context, 13), color: Colors.white.withValues(alpha: 0.95))),
                                        ],
                                      ),
                                      SizedBox(height: 12),
                                      Row(
                                        children: [
                                          RatingBadge(
                                            rating: (lab['avg_rating'] is num ? lab['avg_rating'] as num : 0).toDouble(),
                                            reviewCount: lab['total_reviews'] is num ? (lab['total_reviews'] as num).toInt() : 0,
                                            size: RatingBadgeSize.medium,
                                            showLabel: true,
                                          ),
                                          if (lab['home_service_available'] == true) ...[
                                            SizedBox(width: 12),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(12)),
                                              child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.home_rounded, size: 14, color: Colors.white), SizedBox(width: 5), Text('خدمة منزلية', style: TextStyle(fontSize: 12, color: Colors.white))]),
                                            ),
                                          ],
                                        ],
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
                              color: AppTheme.surface,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                              boxShadow: AppTheme.cardShadowElevated,
                            ),
                            padding: EdgeInsets.all(Responsive.spacing(context, 20)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSection('التحاليل المتوفرة', Icons.medical_services_outlined, _services.isEmpty ? _buildEmptySection('لا توجد تحاليل') : Column(children: _services.map((s) => _buildServiceItem(context, s)).toList())),
                                SizedBox(height: Responsive.spacing(context, 24)),
                                _buildSection('الفروع', Icons.location_on_rounded, _branches.isEmpty ? _buildEmptySection('لا توجد فروع') : Column(children: _branches.map((b) => _buildBranchItem(b)).toList())),
                                SizedBox(height: Responsive.spacing(context, 24)),
                                _buildSection('التقييمات', Icons.star_rounded, _reviews.isEmpty ? _buildEmptyReviews() : Column(children: _reviews.map((r) => _buildReviewItem(r)).toList())),
                                SizedBox(height: 100),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
        bottomNavigationBar: _error == null
            ? SafeArea(
                child: Padding(
                  padding: EdgeInsets.all(Responsive.spacing(context, 16)),
                  child: GradientFilledButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => AnalysesScreen(labId: _labId, labName: LocaleUtils.localizedBusinessName(lab, context.watch<AppSettingsProvider>().isArabic))),
                    ),
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: Responsive.spacing(context, 14)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      elevation: 0,
                    ),
                    child: Text('احجز تحليل', style: TextStyle(fontSize: Responsive.fontSize(context, 15), fontWeight: FontWeight.w500)),
                  ),
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, size: 20, color: AppTheme.primary),
            ),
            SizedBox(width: 12),
            Text(title, style: TextStyle(fontSize: Responsive.fontSize(context, 16), fontWeight: FontWeight.w500, color: AppTheme.onSurface)),
          ],
        ),
        SizedBox(height: 14),
        content,
      ],
    );
  }

  Widget _buildEmptySection(String text) => Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: Text(text, style: TextStyle(fontSize: Responsive.fontSize(context, 13), color: AppTheme.onSurfaceVariant))),
      );

  Widget _buildPlaceholder() => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppTheme.primary, AppTheme.primaryDark]),
        ),
        child: Center(child: Icon(Icons.business_rounded, size: 90, color: Colors.white.withValues(alpha: 0.5))),
      );

  Widget _buildServiceThumb(String? imageUrl) {
    const double size = 56;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: (imageUrl != null && imageUrl.isNotEmpty)
          ? CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              placeholder: (_, __) => Center(child: Icon(Icons.medical_services_rounded, color: AppTheme.primary, size: 24)),
              errorWidget: (_, __, ___) => Center(child: Icon(Icons.medical_services_rounded, color: AppTheme.primary, size: 24)),
            )
          : Center(child: Icon(Icons.medical_services_rounded, color: AppTheme.primary, size: 24)),
    );
  }

  Widget _buildLoading() => CustomScrollView(
        slivers: [
          SliverAppBar(expandedHeight: 240, pinned: true, flexibleSpace: FlexibleSpaceBar(background: _buildPlaceholder())),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(Responsive.spacing(context, 20)),
              child: Shimmer.fromColors(
                baseColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                highlightColor: Theme.of(context).colorScheme.surface,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(height: 28, width: 180, decoration: BoxDecoration(color: AppTheme.surfaceVariant, borderRadius: BorderRadius.circular(8))),
                    SizedBox(height: 20),
                    ...List.generate(4, (_) => Container(margin: EdgeInsets.only(bottom: 12), height: 80, decoration: BoxDecoration(color: AppTheme.surfaceVariant, borderRadius: BorderRadius.circular(18)))),
                  ],
                ),
              ),
            ),
          ),
        ],
      );

  Widget _buildError() => Center(
        child: Padding(
          padding: EdgeInsets.all(Responsive.spacing(context, 24)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off_rounded, size: 64, color: AppTheme.onSurfaceVariant.withValues(alpha: 0.5)),
              SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center, style: TextStyle(fontSize: Responsive.fontSize(context, 14), color: AppTheme.onSurfaceVariant)),
              SizedBox(height: 24),
              GradientFilledButtonIcon(onPressed: _loadData, icon: const Icon(Icons.refresh_rounded, size: 20), label: const Text('إعادة المحاولة'), style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)))),
            ],
          ),
        ),
      );

  Widget _buildEmptyReviews() => Container(
        padding: EdgeInsets.symmetric(vertical: Responsive.spacing(context, 28), horizontal: Responsive.spacing(context, 20)),
        decoration: AppTheme.cardDecorationFor(context),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.rate_review_outlined, size: 28, color: AppTheme.onSurfaceVariant.withValues(alpha: 0.5)),
            SizedBox(width: 12),
            Text('لا توجد تقييمات بعد', style: TextStyle(fontSize: Responsive.fontSize(context, 14), color: AppTheme.onSurfaceVariant)),
          ],
        ),
      );

  Widget _buildServiceItem(BuildContext context, dynamic s) {
    final svc = s is Map ? s as Map<String, dynamic> : <String, dynamic>{};
    final service = svc['service'] ?? svc;
    final displayName = LocaleUtils.localizedName(service is Map ? service as Map<String, dynamic> : svc, context.watch<AppSettingsProvider>().isArabic);
    final price = svc['final_price'] ?? svc['price'] ?? service['price'] ?? 0;
    final homePrice = svc['home_service_price'] ?? svc['home_price'];
    final serviceMap = service is Map ? Map<String, dynamic>.from(service) : <String, dynamic>{};
    serviceMap['price'] = price;
    serviceMap['home_price'] = homePrice;
    serviceMap['provider_service_id'] = svc['id'];
    final psImg = svc['image']?.toString().trim();
    if (psImg != null && psImg.isNotEmpty) serviceMap['image'] = psImg;

    final imageUrl = ApiConfig.analysisImageUrl(serviceMap, svc);

    return Container(
      margin: EdgeInsets.only(bottom: Responsive.spacing(context, 10)),
      decoration: AppTheme.cardDecorationFor(context),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ServiceDetailScreen(service: serviceMap, labId: _labId, labName: LocaleUtils.localizedBusinessName(widget.lab, context.watch<AppSettingsProvider>().isArabic)),
            ),
          ),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: EdgeInsets.all(Responsive.spacing(context, 14)),
            child: Row(
              children: [
                _buildServiceThumb(imageUrl),
                SizedBox(width: Responsive.spacing(context, 14)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(displayName, style: TextStyle(fontSize: Responsive.fontSize(context, 14), fontWeight: FontWeight.w400), maxLines: 1, overflow: TextOverflow.ellipsis),
                      SizedBox(height: 4),
                      Text(homePrice != null ? '${price is num ? (price as num).toStringAsFixed(2) : price} ر.س في المختبر • ${homePrice is num ? (homePrice as num).toStringAsFixed(2) : homePrice} ر.س منزلي' : '${price is num ? (price as num).toStringAsFixed(2) : price} ر.س', style: TextStyle(fontSize: Responsive.fontSize(context, 12), color: AppTheme.onSurfaceVariant)),
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

  Widget _buildBranchItem(dynamic b) {
    final branch = b is Map ? b as Map<String, dynamic> : <String, dynamic>{};
    final displayName = LocaleUtils.localizedName(branch, context.watch<AppSettingsProvider>().isArabic);
    final address = branch['address']?.toString() ?? '';
    final phone = branch['phone']?.toString() ?? '';

    return Container(
      margin: EdgeInsets.only(bottom: Responsive.spacing(context, 10)),
      decoration: AppTheme.cardDecorationFor(context),
      child: Padding(
        padding: EdgeInsets.all(Responsive.spacing(context, 14)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14)),
              child: Icon(Icons.location_on_rounded, color: AppTheme.primary, size: 22),
            ),
            SizedBox(width: Responsive.spacing(context, 14)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(displayName, style: TextStyle(fontSize: Responsive.fontSize(context, 14), fontWeight: FontWeight.w400)),
                  if (address.isNotEmpty) ...[SizedBox(height: 4), Text(address, style: TextStyle(fontSize: Responsive.fontSize(context, 12), color: AppTheme.onSurfaceVariant))],
                  if (phone.isNotEmpty) ...[SizedBox(height: 6), Text(phone, style: TextStyle(fontSize: Responsive.fontSize(context, 12), color: AppTheme.primary))],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewItem(dynamic r) {
    final review = r is Map ? r as Map<String, dynamic> : <String, dynamic>{};
    final userName = review['user_name'] ?? review['user']?['name'] ?? 'مستخدم';
    final rating = (review['rating'] is num ? review['rating'] as num : 0).toDouble();
    final comment = review['comment']?.toString() ?? '';
    final date = review['date'] ?? review['created_at'] ?? '';
    final dateStr = date.toString().length > 10 ? date.toString().substring(0, 10) : date.toString();

    return Container(
      margin: EdgeInsets.only(bottom: Responsive.spacing(context, 12)),
      decoration: AppTheme.cardDecorationFor(context),
      child: Padding(
        padding: EdgeInsets.all(Responsive.spacing(context, 16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                  child: Text(userName.isNotEmpty ? userName[0].toUpperCase() : '؟', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppTheme.primary)),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(userName, style: TextStyle(fontSize: Responsive.fontSize(context, 14), fontWeight: FontWeight.w500)),
                      Row(
                        children: [
                          RatingBadge(rating: rating, size: RatingBadgeSize.small, showLabel: false),
                          SizedBox(width: 8),
                          Text(dateStr, style: TextStyle(fontSize: Responsive.fontSize(context, 11), color: AppTheme.onSurfaceVariant)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (comment.isNotEmpty) ...[
              SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(Responsive.spacing(context, 12)),
                decoration: BoxDecoration(color: AppTheme.surfaceVariant.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(14)),
                child: Text(comment, style: TextStyle(fontSize: Responsive.fontSize(context, 13), height: 1.45)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
