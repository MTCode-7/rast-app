import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:rast/core/api/api_services.dart';
import 'package:rast/core/constants/api_config.dart';
import 'package:rast/core/providers/app_settings_provider.dart';
import 'package:rast/core/utils/locale_utils.dart';
import 'package:provider/provider.dart';
import 'package:rast/core/utils/date_formatter.dart';
import 'package:rast/core/api/api_client.dart';
import 'package:rast/core/theme/app_theme.dart';
import 'package:rast/core/utils/responsive.dart';
import 'package:rast/features/auth/services/auth_service.dart';
import 'package:rast/features/bookings/screens/booking_detail_screen.dart';
import 'package:rast/features/auth/screens/login_screen.dart';
import 'package:shimmer/shimmer.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _upcoming = [];
  List<dynamic> _past = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!AuthService.isLoggedIn) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final upcoming = await Api.bookings.getUpcoming();
      final pastRes = await Api.bookings.getPast();
      final past = pastRes['data'] is List ? List.from(pastRes['data'] as List) : [];
      setState(() {
        _upcoming = upcoming;
        _past = past;
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

  Map<String, dynamic> _toBookingMap(dynamic b) {
    final booking = b is Map ? b as Map<String, dynamic> : <String, dynamic>{};
    final ps = booking['provider_service'] ?? {};
    final service = ps is Map ? ps['service'] ?? ps : {};
    final provider = booking['provider'] ?? {};
    final timeSlot = booking['time_slot'] ?? {};
    final providerMap = provider is Map ? provider as Map<String, dynamic> : <String, dynamic>{};
    return {
      'id': booking['id'],
      'booking_number': booking['booking_number'] ?? 'RST-${booking['id']}',
      'status': booking['status'] ?? 'pending',
      'payment_status': booking['payment_status'] ?? 'pending',
      'booking_date': booking['booking_date'] ?? timeSlot['date'] ?? '',
      'booking_time': booking['booking_time'] ?? timeSlot['start_time'] ?? '',
      'service_type': booking['service_type'] ?? 'in_clinic',
      'service_name_ar': service is Map ? service['name_ar'] : '',
      'service_name_en': service is Map ? service['name_en'] : '',
      'provider_name_ar': providerMap['business_name_ar'] ?? '',
      'provider_name_en': providerMap['business_name_en'] ?? '',
      'provider_logo_url': providerMap['logo_url'] ?? providerMap['logo'],
      'total_amount': booking['total_amount'] ?? 0,
      'branch_name': booking['branch_name'] ?? (booking['service_type'] == 'home_service' ? 'منزلي' : 'الفرع'),
      ...booking,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (!AuthService.isLoggedIn) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: AppTheme.surface,
          appBar: AppBar(
            title: const Text('حجوزاتي'),
            elevation: 0,
          ),
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(Responsive.spacing(context, 24)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.event_available_rounded, size: 64, color: AppTheme.primary),
                  ),
                  SizedBox(height: Responsive.spacing(context, 24)),
                  Text(
                    'سجّل الدخول لعرض حجوزاتك',
                    style: TextStyle(fontSize: Responsive.fontSize(context, 18), color: AppTheme.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: Responsive.spacing(context, 24)),
                  FilledButton.icon(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())).then((_) => setState(() {})),
                    icon: const Icon(Icons.login_rounded),
                    label: const Text('تسجيل الدخول'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_error != null) {
      return _buildErrorState();
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.surface,
        appBar: AppBar(
          title: const Text('حجوزاتي'),
          elevation: 0,
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: AppTheme.primary,
            indicatorWeight: 3,
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.onSurfaceVariant,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: Responsive.fontSize(context, 15)),
            tabs: const [
              Tab(text: 'القادمة'),
              Tab(text: 'السابقة'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildBookingList(_upcoming),
            _buildBookingList(_past),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.surface,
        appBar: AppBar(title: const Text('حجوزاتي'), elevation: 0),
        body: ListView.builder(
          padding: EdgeInsets.all(Responsive.spacing(context, 16)),
          itemCount: 4,
          itemBuilder: (_, __) => Shimmer.fromColors(
            baseColor: AppTheme.surfaceVariant,
            highlightColor: Colors.white,
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              height: 150,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(20)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.surface,
        appBar: AppBar(title: const Text('حجوزاتي'), elevation: 0),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(Responsive.spacing(context, 24)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline_rounded, size: 64, color: AppTheme.error),
                SizedBox(height: Responsive.spacing(context, 16)),
                Text(_error!, textAlign: TextAlign.center, style: TextStyle(fontSize: Responsive.fontSize(context, 15))),
                SizedBox(height: Responsive.spacing(context, 20)),
                FilledButton.icon(
                  onPressed: _loadData,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('إعادة المحاولة'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBookingList(List<dynamic> bookings) {
    if (bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariant.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.event_busy_rounded, size: 56, color: AppTheme.onSurfaceVariant.withValues(alpha: 0.6)),
            ),
            SizedBox(height: Responsive.spacing(context, 20)),
            Text(
              'لا توجد حجوزات',
              style: TextStyle(fontSize: Responsive.fontSize(context, 18), color: AppTheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.separated(
        padding: EdgeInsets.all(Responsive.spacing(context, 16)),
        itemCount: bookings.length,
        separatorBuilder: (_, __) => SizedBox(height: Responsive.spacing(context, 12)),
        itemBuilder: (context, index) {
          final b = _toBookingMap(bookings[index]);
          return _BookingCard(
            booking: b,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => BookingDetailScreen(booking: b)),
            ).then((_) => _loadData()),
          );
        },
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  final VoidCallback onTap;

  const _BookingCard({required this.booking, required this.onTap});

  Color _statusColor(String status) {
    switch (status) {
      case 'confirmed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'completed':
        return AppTheme.primary;
      default:
        return AppTheme.onSurfaceVariant;
    }
  }

  String _statusText(String status) {
    switch (status) {
      case 'confirmed':
        return 'مؤكد';
      case 'pending':
        return 'قيد الانتظار';
      case 'completed':
        return 'مكتمل';
      default:
        return status;
    }
  }

  Widget _buildBookingThumb(String? logoUrl) {
    const double size = 56;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: (logoUrl != null && logoUrl.isNotEmpty)
            ? CachedNetworkImage(
                imageUrl: logoUrl,
                width: size,
                height: size,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: AppTheme.surfaceVariant, child: Icon(Icons.business_rounded, color: AppTheme.primary, size: 28)),
                errorWidget: (_, __, ___) => Container(color: AppTheme.surfaceVariant, child: Icon(Icons.business_rounded, color: AppTheme.primary, size: 28)),
              )
            : Container(
                color: AppTheme.primary.withValues(alpha: 0.1),
                child: Icon(Icons.medical_services_rounded, color: AppTheme.primary, size: 28),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = context.watch<AppSettingsProvider>().isArabic;
    final serviceName = LocaleUtils.localizedName(booking, isArabic, arKey: 'service_name_ar', enKey: 'service_name_en');
    final providerName = LocaleUtils.localizedName(booking, isArabic, arKey: 'provider_name_ar', enKey: 'provider_name_en');
    final status = (booking['status'] ?? 'pending').toString();
    final paymentPending = (booking['payment_status'] ?? 'pending') != 'paid';
    return Container(
      decoration: AppTheme.cardDecoration(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: EdgeInsets.all(Responsive.spacing(context, 16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (booking['booking_number'] != null)
                      Expanded(
                        child: Row(
                          children: [
                            Icon(Icons.confirmation_number_outlined, size: 16, color: AppTheme.primary),
                            SizedBox(width: 6),
                            Text(
                              booking['booking_number'].toString(),
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary),
                            ),
                          ],
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _statusColor(status).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(_statusText(status), style: TextStyle(fontSize: 12, color: _statusColor(status), fontWeight: FontWeight.w600)),
                    ),
                    if (paymentPending) ...[
                      SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text('غير مدفوع', style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: Responsive.spacing(context, 12)),
                Row(
                  children: [
                    _buildBookingThumb(ApiConfig.resolveImageUrl(booking['provider_logo_url'], booking['provider_logo'])),
                    SizedBox(width: Responsive.spacing(context, 14)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            serviceName.isEmpty ? 'حجز' : serviceName,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: Responsive.fontSize(context, 15)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 4),
                          Text(
                            providerName,
                            style: TextStyle(fontSize: 13, color: AppTheme.onSurfaceVariant),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.onSurfaceVariant),
                  ],
                ),
                Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calendar_today_rounded, size: 16, color: AppTheme.onSurfaceVariant),
                        SizedBox(width: 6),
                        Text(
                              '${DateFormatter.formatBookingDate(booking['booking_date']?.toString())} • ${DateFormatter.formatBookingTime(booking['booking_time']?.toString())}',
                              style: TextStyle(fontSize: 13),
                            ),
                      ],
                    ),
                    Text('${booking['total_amount']} ر.س', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary, fontSize: 15)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
