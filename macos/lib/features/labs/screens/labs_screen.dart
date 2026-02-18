import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:geolocator/geolocator.dart';
import 'package:rast/core/constants/api_config.dart';
import 'package:rast/core/providers/app_settings_provider.dart';
import 'package:rast/core/utils/locale_utils.dart';
import 'package:provider/provider.dart';
import 'package:rast/core/constants/dummy_data.dart';
import 'package:rast/core/services/location_service.dart';
import 'package:rast/core/theme/app_theme.dart';
import 'package:rast/core/utils/responsive.dart';
import 'package:rast/core/widgets/rating_badge.dart';
import 'package:rast/core/api/api_services.dart';
import 'package:rast/core/api/api_client.dart';
import 'package:rast/core/widgets/search_box.dart';
import 'package:rast/features/lab_details/screens/lab_details_screen.dart';
import 'package:rast/features/settings/screens/default_location_screen.dart';
import 'package:shimmer/shimmer.dart';

class LabsScreen extends StatefulWidget {
  const LabsScreen({super.key});

  @override
  State<LabsScreen> createState() => _LabsScreenState();
}

class _LabsScreenState extends State<LabsScreen> {
  String _sortBy = 'nearby';
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _labs = [];
  bool _isLoading = true;
  String? _error;
  double? _userLat;
  double? _userLng;

  @override
  void initState() {
    super.initState();
    _loadUserLocation();
  }

  Future<void> _loadUserLocation() async {
    double? lat;
    double? lng;
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) await Geolocator.requestPermission();
      if (await Geolocator.isLocationServiceEnabled()) {
        final pos = await Geolocator.getCurrentPosition();
        lat = pos.latitude;
        lng = pos.longitude;
      }
    } catch (_) {}
    if (lat == null || lng == null) {
      final saved = await LocationService.getDefaultLocation();
      if (saved != null) {
        lat = saved.lat;
        lng = saved.lng;
      }
    }
    if (mounted) {
      setState(() {
        _userLat = lat;
        _userLng = lng;
      });
    }
    _loadData();
  }

  List<dynamic> _extractList(dynamic resData) {
    if (resData is List) return List.from(resData);
    if (resData is Map) {
      if (resData['data'] is List) return List.from(resData['data'] as List);
    }
    return [];
  }

  /// عرض المختبرات المفعلة والنشطة فقط
  static List<dynamic> _filterActiveLabs(List<dynamic> list) {
    return list.where((e) {
      if (e is! Map) return false;
      final active = e['is_active'];
      return active == null || active == true;
    }).toList();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      String? sort = _sortBy.isEmpty ? null : _sortBy;
      if (_sortBy == 'nearby') sort = null;
      double? lat = _userLat;
      double? lng = _userLng;
      if (_sortBy != 'nearby' || lat == null || lng == null) {
        lat = null;
        lng = null;
      }
      final res = await Api.providers.getProviders(
        sort: sort,
        perPage: 50,
        latitude: lat,
        longitude: lng,
        radiusKm: (lat != null && lng != null) ? 50 : null,
      );
      var list = _extractList(res['data']);
      if (list.isEmpty) list = List.from(DummyData.labs);
      list = _filterActiveLabs(list);
      setState(() {
        _labs = list;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _labs = _filterActiveLabs(List.from(DummyData.labs));
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _labs = _filterActiveLabs(List.from(DummyData.labs));
        _error = null;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            'المختبرات',
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 18),
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: _isLoading
            ? _buildLoading()
            : _error != null && _labs.isEmpty
                ? _buildError()
                : Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.all(Responsive.spacing(context, 16)),
                        child: Column(
                          children: [
                            SearchBox(
                              controller: _searchController,
                              hintText: 'ابحث عن مختبر...',
                              onSearchTap: _loadData,
                              onSubmitted: (_) => _loadData(),
                            ),
                            SizedBox(height: Responsive.spacing(context, 12)),
                            _buildSortRow(),
                            if (_sortBy == 'nearby' && _userLat == null && _userLng == null) ...[
                              SizedBox(height: 8),
                              GestureDetector(
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DefaultLocationScreen())).then((_) => _loadUserLocation()),
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
                                  child: Row(
                                    children: [
                                      Icon(Icons.location_off, size: 18, color: AppTheme.primary),
                                      SizedBox(width: 8),
                                      Expanded(child: Text('احفظ موقعك من الإعدادات لعرض الأقرب', style: TextStyle(fontSize: 12, color: AppTheme.primary))),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Expanded(
                        child: _labs.isEmpty
                            ? _buildEmpty()
                            : RefreshIndicator(
                                onRefresh: _loadData,
                                child: ListView.separated(
                                  padding: EdgeInsets.symmetric(horizontal: Responsive.spacing(context, 16)),
                                  itemCount: _labs.length,
                                  separatorBuilder: (_, __) => SizedBox(height: Responsive.spacing(context, 12)),
                                  itemBuilder: (context, index) {
                                    final lab = _labs[index] is Map ? _labs[index] as Map<String, dynamic> : <String, dynamic>{};
                                    return _LabCard(
                                      lab: lab,
                                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LabDetailsScreen(lab: lab))),
                                    ).animate().fadeIn(duration: 400.ms, delay: Duration(milliseconds: (index % 8) * 40)).slideY(begin: 0.02, end: 0, curve: Curves.easeOutCubic);
                                  },
                                ),
                              ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildSortRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Text(
            'ترتيب: ',
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 13),
              fontWeight: FontWeight.w500,
              color: AppTheme.onSurfaceVariant,
            ),
          ),
          SizedBox(width: 8),
          _sortChip('الأقرب', 'nearby'),
          SizedBox(width: 8),
          _sortChip('التقييم', 'rating'),
          SizedBox(width: 8),
          _sortChip('المميزة', 'featured'),
          SizedBox(width: 8),
          _sortChip('الكل', ''),
        ],
      ),
    );
  }

  Widget _sortChip(String label, String value) {
    final selected = _sortBy == value;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: Responsive.fontSize(context, 13),
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
      selected: selected,
      onSelected: (_) {
        setState(() {
          _sortBy = value;
          _loadData();
        });
      },
      selectedColor: AppTheme.primary.withValues(alpha: 0.14),
      checkmarkColor: AppTheme.primary,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _buildEmpty() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.business_rounded, size: 72, color: AppTheme.onSurfaceVariant.withValues(alpha: 0.4)),
            SizedBox(height: 16),
            Text('لا توجد مختبرات', style: TextStyle(fontSize: Responsive.fontSize(context, 15), color: AppTheme.onSurfaceVariant)),
          ],
        ),
      );

  Widget _buildLoading() => ListView.builder(
        padding: EdgeInsets.all(Responsive.spacing(context, 16)),
        itemCount: 6,
        itemBuilder: (_, __) => Shimmer.fromColors(
          baseColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          highlightColor: Theme.of(context).colorScheme.surface,
          child: Container(
            margin: EdgeInsets.only(bottom: 12),
            height: 100,
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        ),
      );

  Widget _buildError() => Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off_rounded, size: 56, color: AppTheme.onSurfaceVariant.withValues(alpha: 0.5)),
              SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: AppTheme.onSurfaceVariant)),
              SizedBox(height: 20),
              FilledButton.icon(onPressed: _loadData, icon: const Icon(Icons.refresh_rounded, size: 20), label: const Text('إعادة المحاولة')),
            ],
          ),
        ),
      );
}

class _LabCard extends StatelessWidget {
  final Map<String, dynamic> lab;
  final VoidCallback onTap;

  const _LabCard({required this.lab, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final logoUrl = ApiConfig.resolveImageUrl(lab['logo_url'], lab['logo']);
    final businessName = LocaleUtils.localizedBusinessName(lab, context.watch<AppSettingsProvider>().isArabic);
    final city = lab['city']?.toString() ?? '';
    final district = lab['district']?.toString() ?? '';
    final avgRating = (lab['avg_rating'] is num ? lab['avg_rating'] as num : 0).toDouble();
    final totalReviews = lab['total_reviews'] is num ? (lab['total_reviews'] as num).toInt() : 0;
    final homeService = lab['home_service_available'] == true;
    final size = 56.0 * (MediaQuery.of(context).size.width / 375).clamp(1.0, 1.2);

    return Container(
      decoration: AppTheme.cardDecorationFor(context),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: EdgeInsets.all(Responsive.spacing(context, 14)),
            child: Row(
              children: [
                _buildLogo(logoUrl, size),
                SizedBox(width: Responsive.spacing(context, 14)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(businessName, style: TextStyle(fontSize: Responsive.fontSize(context, 14), fontWeight: FontWeight.w400), maxLines: 1, overflow: TextOverflow.ellipsis),
                      SizedBox(height: 4),
                      Text('$city ${district.isNotEmpty ? '- $district' : ''}', style: TextStyle(fontSize: Responsive.fontSize(context, 11), color: AppTheme.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          RatingBadge(rating: avgRating, reviewCount: totalReviews, size: RatingBadgeSize.small, showLabel: true),
                          if (homeService) ...[
                            SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                              child: Text('منزلي', style: TextStyle(fontSize: Responsive.fontSize(context, 9), color: AppTheme.primary, fontWeight: FontWeight.w400)),
                            ),
                          ],
                        ],
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

  Widget _buildLogo(String? url, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: Colors.white.withValues(alpha: 0.95), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: (url != null && url.isNotEmpty)
            ? CachedNetworkImage(imageUrl: url, fit: BoxFit.cover, placeholder: (_, __) => Container(color: AppTheme.surfaceVariant, child: Icon(Icons.business_rounded, size: size * 0.45, color: AppTheme.primary)), errorWidget: (_, __, ___) => Container(color: AppTheme.surfaceVariant, child: Icon(Icons.business_rounded, size: size * 0.45, color: AppTheme.primary)))
            : Container(color: AppTheme.surfaceVariant, child: Icon(Icons.business_rounded, size: size * 0.45, color: AppTheme.primary)),
      ),
    );
  }
}
