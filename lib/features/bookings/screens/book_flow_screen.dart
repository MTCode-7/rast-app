import 'dart:ui' as ui show TextDirection;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:rast/core/providers/app_settings_provider.dart';
import 'package:rast/core/utils/locale_utils.dart';
import 'package:rast/core/api/api_services.dart';
import 'package:rast/core/constants/api_config.dart';
import 'package:rast/core/utils/date_formatter.dart';
import 'package:rast/core/api/api_client.dart';
import 'package:rast/core/theme/app_theme.dart';
import 'package:rast/core/utils/responsive.dart';
import 'package:rast/core/widgets/gradient_button.dart';
import 'package:rast/features/auth/services/auth_service.dart';
import 'package:rast/features/auth/screens/login_screen.dart';
import 'package:rast/features/bookings/screens/booking_detail_screen.dart';
import 'package:rast/features/bookings/screens/payment_webview_screen.dart';

/// شاشة حجز تحليل: نوع الخدمة → التاريخ → الوقت → تأكيد وإنشاء → الدفع
class BookFlowScreen extends StatefulWidget {
  /// المختبر (إن وُجد) أو نستخدم labId لجلبه
  final Map<String, dynamic>? lab;
  final int labId;
  final String? labName;
  /// خريطة provider_service: id, final_price, home_service_price, service.name_ar
  final Map<String, dynamic> providerService;

  const BookFlowScreen({
    super.key,
    this.lab,
    required this.labId,
    this.labName,
    required this.providerService,
  });

  @override
  State<BookFlowScreen> createState() => _BookFlowScreenState();
}

class _BookFlowScreenState extends State<BookFlowScreen> {
  Map<String, dynamic>? _lab;
  int _step = 0;
  String _serviceType = 'in_clinic';
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _districtController = TextEditingController();
  DateTime? _selectedDate;
  Map<String, dynamic>? _selectedSlot;
  List<dynamic> _timeSlots = [];
  bool _loadingSlots = false;
  bool _creating = false;
  String? _error;
  Map<String, dynamic>? _createdBooking;
  /// نسب من API: platform_discount_rate, vat_rate (بديل عن ApiConfig.globalDiscountPercent)
  Map<String, dynamic>? _bookingConfig;
  bool _isNonSaudi = false;

  /// معاينة الأسعار من الـ API (نفس أرقام الفاتورة) - للمرحلة 1
  Map<String, dynamic>? _previewData;
  /// معاينة الأسعار للمرحلة 3 (ملخص الحجز) حسب nationality
  Map<String, dynamic>? _previewConfirm;
  bool _loadingPreview = false;

  /// قيم احتياطية من الخريطة إن فشل الـ API
  late double _resolvedPrice;
  late double _resolvedHomeServiceFeeRaw;

  int get _providerServiceId => (widget.providerService['id'] is int)
      ? widget.providerService['id'] as int
      : int.parse(widget.providerService['id']?.toString() ?? '0');
  String get _serviceNameAr => (widget.providerService['service'] is Map
          ? (widget.providerService['service'] as Map)['name_ar']
          : widget.providerService['name_ar'])
      ?.toString() ??
      '';
  static double _extractPrice(Map<String, dynamic> map) {
    var v = map['final_price'] ?? map['price'] ?? map['base_price'] ?? map['sale_price']
        ?? map['finalPrice'] ?? map['basePrice'] ?? map['salePrice'];
    if (v is num) return v.toDouble();
    if (v != null) {
      final parsed = double.tryParse(v.toString().trim().replaceAll(',', ''));
      if (parsed != null && parsed > 0) return parsed;
    }
    final fromMap = ApiConfig.priceFromMap(map);
    if (fromMap > 0) return fromMap;
    final service = map['service'];
    if (service is Map<String, dynamic>) {
      final fromService = ApiConfig.priceFromMap(service);
      if (fromService > 0) return fromService;
    }
    final ps = map['provider_service'] ?? map['providerService'];
    if (ps is Map<String, dynamic>) {
      final fromPs = ApiConfig.priceFromMap(ps);
      if (fromPs > 0) return fromPs;
    }
    return 0.0;
  }

  /// استخراج رسوم الخدمة المنزلية من الخريطة (مطابق للباكند: home_service_price أو من المختبر).
  static double _extractHomeFee(Map<String, dynamic> map) {
    var v = map['home_service_price'] ?? map['home_price'] ?? map['home_service_fee'];
    if (v is num) return v.toDouble();
    if (v != null) {
      final parsed = double.tryParse(v.toString().trim().replaceAll(',', ''));
      if (parsed != null) return parsed;
    }
    final ps = map['provider_service'] ?? map['providerService'];
    if (ps is Map<String, dynamic>) {
      final h = ps['home_service_price'] ?? ps['home_price'];
      if (h is num) return h.toDouble();
      if (h != null) return double.tryParse(h.toString()) ?? 0;
    }
    return 0;
  }

  double get _price => _resolvedPrice;
  double get _homeServiceFeeRaw => _resolvedHomeServiceFeeRaw;

  /// إجمالي سعر الزيارة المنزلية = سعر التحليل + رسوم المنزل
  double get _homeTotal => _price + _homeServiceFeeRaw;
  bool get _homeAvailable => _lab?['home_service_available'] == true;

  @override
  void initState() {
    super.initState();
    _resolvedPrice = _extractPrice(widget.providerService);
    _resolvedHomeServiceFeeRaw = _extractHomeFee(widget.providerService);
    _lab = widget.lab;
    if (_lab == null) _loadLab();
    _loadBookingConfig();
    _loadPreview();
  }

  /// جلب معاينة الأسعار من الباكند (نفس منطق الفاتورة)
  Future<void> _loadPreview() async {
    if (_loadingPreview) return;
    setState(() => _loadingPreview = true);
    try {
      final data = await Api.bookings.getBookingPreview(_providerServiceId, nationality: 'saudi');
      if (mounted) setState(() => _previewData = data);
    } catch (_) {
      if (mounted) setState(() => _previewData = null);
    } finally {
      if (mounted) setState(() => _loadingPreview = false);
    }
  }

  Future<void> _loadConfirmPreview() async {
    try {
      final nationality = _isNonSaudi ? 'non_saudi' : 'saudi';
      final data = await Api.bookings.getBookingPreview(_providerServiceId, nationality: nationality);
      if (mounted) setState(() => _previewConfirm = data);
    } catch (_) {
      if (mounted) setState(() => _previewConfirm = null);
    }
  }

  Future<void> _loadBookingConfig() async {
    try {
      final config = await Api.home.getConfig();
      final booking = config['booking'];
      if (booking is Map) {
        setState(() => _bookingConfig = Map<String, dynamic>.from(booking));
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _addressController.dispose();
    _cityController.dispose();
    _districtController.dispose();
    super.dispose();
  }

  Future<void> _loadLab() async {
    try {
      final lab = await Api.providers.getProvider(widget.labId);
      setState(() => _lab = lab);
    } catch (_) {
      setState(() => _error = 'تعذر تحميل بيانات المختبر');
    }
  }

  /// نسبة خصم المنصة (٪): من API أو 7% افتراضي. يدعم API يعيد 7 أو 0.07 أو نصاً
  double get _platformDiscountRate {
    final v = _bookingConfig?['platform_discount_rate'] ?? _bookingConfig?['platformDiscountRate'];
    double d = 0;
    if (v is num) {
      d = v.toDouble();
    } else if (v != null) {
      d = double.tryParse(v.toString().trim()) ?? 0;
    }
    if (d > 0) return d <= 1 ? d * 100 : d; // 0.07 → 7%, 7 → 7%
    return ApiConfig.globalDiscountPercent.toDouble();
  }

  /// نسبة الضريبة (٪): من API أو 15% عند اختيار غير سعودي لضمان تطبيق الضريبة
  double get _vatRate {
    final v = _bookingConfig?['vat_rate'];
    if (v is num) {
      final d = v.toDouble();
      if (d > 0) return d <= 1 ? d * 100 : d; // 0.15 → 15%, 15 → 15%
    }
    return 15.0; // افتراضي لغير السعودي عندما لا يرسل الـ API النسبة
  }

  /// رسوم الخدمة المنزلية (المبلغ الإضافي فقط، بدون سعر التحليل)
  double get _homeServiceFee =>
      _serviceType == 'home_service' ? _homeServiceFeeRaw : 0.0;

  /// منطق الحساب مطابق للـ API: الخصم على سعر التحليل فقط، الضريبة على المبلغ بعد الخصم
  double get _basePrice => _serviceType == 'home_service' ? (_price + _homeServiceFeeRaw) : _price;

  double get _discountAmount {
    final rate = _platformDiscountRate;
    if (rate <= 0 || _price <= 0) return 0;
    final amount = _price * (rate / 100);
    return amount.roundToDouble();
  }

  double get _afterDiscount => (_basePrice - _discountAmount).roundToDouble();

  double get _vatAmount =>
      _isNonSaudi && _vatRate > 0
          ? (_afterDiscount * (_vatRate / 100)).roundToDouble()
          : 0.0;

  double get _totalAmount =>
      (_afterDiscount + _vatAmount).roundToDouble();

  void _nextStep() {
    if (_step == 0) {
      if (_serviceType == 'home_service' && (_addressController.text.trim().isEmpty || _cityController.text.trim().isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أدخل العنوان والمدينة للخدمة المنزلية')));
        return;
      }
    }
    if (_step == 1 && _selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اختر التاريخ')));
      return;
    }
    if (_step == 2 && _selectedSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اختر وقت الزيارة')));
      return;
    }
    if (_step < 3) {
      setState(() {
        _step++;
        _error = null;
        if (_step == 2 && _selectedDate != null) _loadTimeSlots();
      });
      if (_step == 3) _loadConfirmPreview();
    }
  }

  void _backStep() {
    if (_step > 0) setState(() => _step--);
  }

  Future<void> _loadTimeSlots() async {
    if (_selectedDate == null) return;
    setState(() {
      _loadingSlots = true;
      _timeSlots = [];
      _selectedSlot = null;
    });
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate!);
      final slots = await Api.providers.getTimeSlots(widget.labId, dateStr);
      setState(() {
        _timeSlots = slots;
        _loadingSlots = false;
      });
    } catch (_) {
      setState(() {
        _loadingSlots = false;
        _error = 'تعذر تحميل المواعيد';
      });
    }
  }

  Future<void> _createBooking() async {
    if (!AuthService.isLoggedIn) {
      final ok = await Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      if (ok == true && mounted) setState(() {});
      return;
    }
    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      final body = <String, dynamic>{
        'provider_service_id': _providerServiceId,
        'time_slot_id': _selectedSlot!['id'],
        'service_type': _serviceType,
      };
      if (_isNonSaudi) body['nationality'] = 'non_saudi';
      if (_serviceType == 'home_service') {
        body['home_address'] = _addressController.text.trim();
        body['home_city'] = _cityController.text.trim();
        body['home_district'] = _districtController.text.trim();
      }
      final booking = await Api.bookings.create(body);
      final b = _toBookingMap(booking);
      setState(() {
        _creating = false;
        _createdBooking = b;
        _step = 4;
      });
    } on ApiException catch (e) {
      setState(() {
        _creating = false;
        _error = e.message;
      });
    } catch (e) {
      setState(() {
        _creating = false;
        _error = e.toString().contains('SocketException') ? 'تحقق من الاتصال' : e.toString();
      });
    }
  }

  Map<String, dynamic> _toBookingMap(Map<String, dynamic> booking) {
    final summary = booking['summary'] is Map ? booking['summary'] as Map<String, dynamic> : null;
    final ps = booking['provider_service'] ?? {};
    final service = ps is Map ? ps['service'] ?? ps : {};
    final provider = booking['provider'] ?? {};
    final timeSlot = booking['time_slot'] ?? {};
    final providerMap = provider is Map ? provider as Map<String, dynamic> : <String, dynamic>{};
    final base = <String, dynamic>{
      'id': booking['id'],
      'booking_number': booking['booking_number'] ?? 'RST-${booking['id']}',
      'status': booking['status'] ?? 'pending',
      'payment_status': booking['payment_status'] ?? 'pending',
      'booking_date': booking['booking_date'] ?? timeSlot['date'] ?? '',
      'booking_time': booking['booking_time'] ?? timeSlot['start_time'] ?? '',
      'service_type': booking['service_type'] ?? 'in_clinic',
      'service_name_ar': service is Map ? service['name_ar'] : _serviceNameAr,
      'service_name_en': service is Map ? service['name_en'] : null,
      'provider_name_ar': providerMap['business_name_ar'] ?? widget.labName ?? '',
      'provider_name_en': providerMap['business_name_en'],
      'provider_logo_url': providerMap['logo_url'] ?? providerMap['logo'],
      'branch_name': booking['branch_name'] ?? (_serviceType == 'home_service' ? 'منزلي' : 'الفرع'),
      ...booking,
    };
    if (summary != null) {
      base['summary'] = summary;
      base['service_price'] = _parseNum(summary['service_price']);
      base['home_service_fee'] = _parseNum(summary['home_service_fee']);
      final d = _parseNum(summary['discount_amount']);
      final p = _parseNum(summary['platform_discount']);
      base['discount_amount'] = d > 0 ? d : p;
      base['total_amount'] = _parseNum(summary['total_amount']);
    } else {
      base['total_amount'] = booking['total_amount'] ?? _totalAmount;
    }
    return base;
  }

  Future<void> _openPayment() async {
    final bid = _createdBooking?['id'];
    if (bid == null) return;
    try {
      final res = await Api.bookings.createPaymentSession(bid is int ? bid : int.parse(bid.toString()));
      final success = res['success'] == true;
      final paymentUrl = res['payment_url']?.toString();

      if (success && paymentUrl != null && paymentUrl.isNotEmpty) {
        if (!mounted) return;
        final paid = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentWebViewScreen(paymentUrl: paymentUrl),
          ),
        );
        if (mounted) {
          if (paid == true) {
            setState(() => _createdBooking = {...?_createdBooking, 'payment_status': 'paid'});
          }
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('بعد إتمام الدفع يمكنك مراجعة الحجز من حجوزاتي')),
          );
        }
      } else {
        final msg = res['message']?.toString() ?? 'فشل إنشاء جلسة الدفع';
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر فتح الدفع: ${e.toString().split('\n').first}')));
    }
  }

  void _goToBookingDetail() {
    if (_createdBooking == null) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => BookingDetailScreen(booking: _createdBooking!)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!AuthService.isLoggedIn) {
      return Directionality(
        textDirection: ui.TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(title: const Text('حجز تحليل')),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.login, size: 64, color: AppTheme.primary.withValues(alpha: 0.7)),
                  const SizedBox(height: 16),
                  const Text('سجّل الدخول لحجز التحليل', textAlign: TextAlign.center, style: TextStyle(fontSize: 18)),
                  const SizedBox(height: 24),
                  GradientFilledButtonIcon(
                    onPressed: () async {
                      final ok = await Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                      if (ok == true && mounted) setState(() {});
                    },
                    icon: const Icon(Icons.login),
                    label: const Text('تسجيل الدخول'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_createdBooking != null ? 'تم الحجز' : 'حجز تحليل'),
          leading: _step > 0 && _createdBooking == null
              ? IconButton(icon: const Icon(Icons.arrow_back_ios_new), onPressed: _backStep)
              : null,
        ),
        body: _error != null && _step < 4
            ? _buildErrorBody()
            : _createdBooking != null
                ? _buildSuccessBody()
                : SingleChildScrollView(
                    padding: EdgeInsets.all(Responsive.spacing(context, 16)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildStepIndicator(),
                        SizedBox(height: Responsive.spacing(context, 24)),
                        if (_step == 0) _buildStepServiceType(),
                        if (_step == 1) _buildStepDate(),
                        if (_step == 2) _buildStepTime(),
                        if (_step == 3) _buildStepConfirm(),
                        SizedBox(height: Responsive.spacing(context, 24)),
                        if (_step < 4 && _createdBooking == null) _buildNextButton(),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildErrorBody() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 56, color: AppTheme.error),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: () => setState(() => _error = null), icon: const Icon(Icons.refresh), label: const Text('إعادة المحاولة')),
          ],
        ),
      ),
    );
  }

  double _parseNum(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  Widget _buildSuccessBody() {
    final paid = _createdBooking?['payment_status'] == 'paid';
    final summary = _createdBooking?['summary'] is Map ? _createdBooking!['summary'] as Map<String, dynamic> : null;
    final servicePrice = summary != null ? _parseNum(summary['service_price']) : _parseNum(_createdBooking?['service_price']);
    final homeFee = summary != null ? _parseNum(summary['home_service_fee']) : _parseNum(_createdBooking?['home_service_fee']);
    final discountAmount = summary != null
        ? (_parseNum(summary['discount_amount']) > 0 ? _parseNum(summary['discount_amount']) : _parseNum(summary['platform_discount']))
        : _parseNum(_createdBooking?['discount_amount']);
    final totalAmount = summary != null ? _parseNum(summary['total_amount']) : _parseNum(_createdBooking?['total_amount']);
    final vatAmount = summary != null ? _parseNum(summary['vat_amount']) : (() {
      final meta = _createdBooking?['metadata'];
      return meta is Map ? _parseNum(meta['vat_amount']) : 0.0;
    })();
    final isHomeService = _createdBooking?['service_type'] == 'home_service';

    return SingleChildScrollView(
      padding: EdgeInsets.all(Responsive.spacing(context, 20)),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(Responsive.spacing(context, 24)),
            decoration: AppTheme.cardDecorationElevatedFor(context),
            child: Column(
              children: [
                Icon(Icons.check_circle, size: 72, color: AppTheme.primary),
                SizedBox(height: Responsive.spacing(context, 16)),
                Text('تم إنشاء الحجز بنجاح', style: TextStyle(fontSize: Responsive.fontSize(context, 20), fontWeight: FontWeight.bold)),
                SizedBox(height: Responsive.spacing(context, 8)),
                Text(_createdBooking?['booking_number']?.toString() ?? '', style: TextStyle(fontSize: Responsive.fontSize(context, 16), color: AppTheme.primary)),
                SizedBox(height: Responsive.spacing(context, 20)),
                if (!paid) ...[
                  GradientFilledButtonIcon(
                    onPressed: _openPayment,
                    icon: const Icon(Icons.payment),
                    label: const Text('ادفع الآن'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  SizedBox(height: Responsive.spacing(context, 12)),
                  Text('أو ادعم في المختبر', style: TextStyle(fontSize: Responsive.fontSize(context, 13), color: AppTheme.onSurfaceVariant)),
                ],
              ],
            ),
          ),
          SizedBox(height: Responsive.spacing(context, 16)),
          Container(
            padding: EdgeInsets.all(Responsive.spacing(context, 20)),
            decoration: AppTheme.cardDecorationFor(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('تفاصيل الفاتورة', style: TextStyle(fontSize: Responsive.fontSize(context, 15), fontWeight: FontWeight.w600)),
                SizedBox(height: Responsive.spacing(context, 12)),
                _confirmRow('سعر التحليل', '${servicePrice.toStringAsFixed(2)} ر.س'),
                if (isHomeService) _confirmRow('رسوم الخدمة المنزلية', '+ ${homeFee.toStringAsFixed(2)} ر.س'),
                _confirmRow('خصم المنصة', '- ${discountAmount.toStringAsFixed(2)} ر.س', valueStyle: TextStyle(color: AppTheme.success, fontWeight: FontWeight.w600)),
                _confirmRow('ضريبة القيمة المضافة', '+ ${vatAmount.toStringAsFixed(2)} ر.س', valueStyle: TextStyle(color: AppTheme.onSurfaceVariant)),
                Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Divider(height: 1, color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5))),
                _confirmRow('المبلغ الإجمالي', '${totalAmount.toStringAsFixed(2)} ر.س', valueStyle: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          SizedBox(height: Responsive.spacing(context, 16)),
          OutlinedButton.icon(
            onPressed: _goToBookingDetail,
            icon: const Icon(Icons.list_alt),
            label: const Text('عرض تفاصيل الحجز'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Row(
      children: List.generate(4, (i) {
        final active = i == _step;
        final done = i < _step;
        return Expanded(
          child: Row(
            children: [
              if (i > 0) Expanded(child: Container(height: 2, color: done ? AppTheme.primary : AppTheme.surfaceVariant)),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: active ? AppTheme.primary : (done ? AppTheme.primary : AppTheme.surfaceVariant),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: done ? const Icon(Icons.check, size: 16, color: Colors.white) : Text('${i + 1}', style: TextStyle(color: active ? Colors.white : AppTheme.onSurfaceVariant, fontSize: 12)),
                ),
              ),
              if (i < 3) Expanded(child: Container(height: 2, color: done ? AppTheme.primary : AppTheme.surfaceVariant)),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildStepServiceType() {
    final inClinicTotal = _previewData != null && _previewData!['in_clinic'] is Map
        ? _parseNum((_previewData!['in_clinic'] as Map)['total_amount'])
        : _price;
    final homeTotal = _previewData != null && _previewData!['home_service'] is Map
        ? _parseNum((_previewData!['home_service'] as Map)['total_amount'])
        : _homeTotal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('نوع الزيارة', style: TextStyle(fontSize: Responsive.fontSize(context, 18), fontWeight: FontWeight.bold)),
        SizedBox(height: Responsive.spacing(context, 12)),
        _serviceTypeChip('in_clinic', 'في المختبر', Icons.business_rounded, '${inClinicTotal.toStringAsFixed(2)} ر.س'),
        if (_homeAvailable) ...[
          SizedBox(height: Responsive.spacing(context, 10)),
          _serviceTypeChip('home_service', 'زيارة منزلية', Icons.home_rounded, '${homeTotal.toStringAsFixed(2)} ر.س'),
        ],
        if (_serviceType == 'home_service') ...[
          SizedBox(height: Responsive.spacing(context, 20)),
          Text('عنوان الزيارة', style: TextStyle(fontSize: Responsive.fontSize(context, 16), fontWeight: FontWeight.w600)),
          SizedBox(height: Responsive.spacing(context, 8)),
          TextField(
            controller: _addressController,
            decoration: InputDecoration(
              labelText: 'العنوان',
              hintText: 'الشارع والحي',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              filled: true,
            ),
          ),
          SizedBox(height: Responsive.spacing(context, 10)),
          TextField(
            controller: _cityController,
            decoration: InputDecoration(
              labelText: 'المدينة',
              hintText: 'مثال: الرياض',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              filled: true,
            ),
          ),
          SizedBox(height: Responsive.spacing(context, 10)),
          TextField(
            controller: _districtController,
            decoration: InputDecoration(
              labelText: 'الحي (اختياري)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              filled: true,
            ),
          ),
        ],
      ],
    );
  }

  Widget _serviceTypeChip(String value, String label, IconData icon, String price) {
    final selected = _serviceType == value;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _serviceType = value),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.all(Responsive.spacing(context, 16)),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primary.withValues(alpha: 0.1) : AppTheme.surfaceVariant.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? AppTheme.primary : Colors.transparent, width: 2),
          ),
          child: Row(
            children: [
              Icon(icon, color: selected ? AppTheme.primary : AppTheme.onSurfaceVariant, size: 28),
              SizedBox(width: Responsive.spacing(context, 12)),
              Expanded(child: Text(label, style: TextStyle(fontWeight: selected ? FontWeight.bold : FontWeight.w500))),
              Text(price, style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepDate() {
    final today = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('اختر التاريخ', style: TextStyle(fontSize: Responsive.fontSize(context, 18), fontWeight: FontWeight.bold)),
        SizedBox(height: Responsive.spacing(context, 12)),
        OutlinedButton.icon(
          onPressed: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: _selectedDate ?? today,
              firstDate: today,
              lastDate: today.add(const Duration(days: 60)),
            );
            if (d != null) setState(() => _selectedDate = d);
          },
          icon: const Icon(Icons.calendar_today),
          label: Text(_selectedDate != null ? DateFormat('yyyy-MM-dd').format(_selectedDate!) : 'اختر اليوم'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ],
    );
  }

  Widget _buildStepTime() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('اختر الوقت', style: TextStyle(fontSize: Responsive.fontSize(context, 18), fontWeight: FontWeight.bold)),
        SizedBox(height: Responsive.spacing(context, 12)),
        if (_loadingSlots)
          const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
        else if (_timeSlots.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: AppTheme.cardDecorationFor(context),
            child: const Text('لا توجد مواعيد متاحة لهذا اليوم. اختر تاريخاً آخر.', textAlign: TextAlign.center),
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _timeSlots.map<Widget>((s) {
              final slot = s is Map ? s as Map<String, dynamic> : <String, dynamic>{};
              final slotId = slot['id'];
              final start = slot['start_time']?.toString() ?? '';
              final selected = _selectedSlot?['id'] == slotId;
              return FilterChip(
                label: Text(start),
                selected: selected,
                onSelected: (_) => setState(() => _selectedSlot = slot),
                selectedColor: AppTheme.primary.withValues(alpha: 0.2),
                checkmarkColor: AppTheme.primary,
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildStepConfirm() {
    final labDisplay = LocaleUtils.localizedBusinessName(_lab, context.watch<AppSettingsProvider>().isArabic);
    final labNameDisplay = labDisplay.isNotEmpty ? labDisplay : (widget.labName ?? '');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ملخص الحجز', style: TextStyle(fontSize: Responsive.fontSize(context, 18), fontWeight: FontWeight.bold)),
        SizedBox(height: Responsive.spacing(context, 12)),
        Container(
          padding: EdgeInsets.all(Responsive.spacing(context, 20)),
          decoration: AppTheme.cardDecorationFor(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _confirmRow('التحليل', _serviceNameAr),
              _confirmRow('المختبر', labNameDisplay),
              _confirmRow('نوع الخدمة', _serviceType == 'home_service' ? 'منزلي' : 'في المختبر'),
              _confirmRow('التاريخ', _selectedDate != null ? DateFormatter.formatDate(_selectedDate!) : ''),
              _confirmRow('الوقت', DateFormatter.formatBookingTime(_selectedSlot?['start_time']?.toString())),
              if (_serviceType == 'home_service') _confirmRow('العنوان', _addressController.text),
              SizedBox(height: Responsive.spacing(context, 12)),
              CheckboxListTile(
                value: _isNonSaudi,
                onChanged: (v) {
                  setState(() => _isNonSaudi = v ?? false);
                  _loadConfirmPreview();
                },
                title: Text('أنا غير سعودي (تُطبّق الضريبة)', style: TextStyle(fontSize: Responsive.fontSize(context, 13))),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
                activeColor: AppTheme.primary,
              ),
              const Divider(height: 24),
              Text('تفاصيل المبلغ', style: TextStyle(fontSize: Responsive.fontSize(context, 14), fontWeight: FontWeight.w600, color: AppTheme.onSurface)),
              SizedBox(height: Responsive.spacing(context, 10)),
              _buildConfirmAmounts(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _confirmRow(String label, String value, {TextStyle? valueStyle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.onSurfaceVariant)),
          Flexible(child: Text(value, style: valueStyle ?? const TextStyle(fontWeight: FontWeight.w600), textAlign: TextAlign.left, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  /// تفاصيل المبلغ في ملخص الحجز: من معاينة الـ API إن وُجدت (نفس الفاتورة)
  Widget _buildConfirmAmounts() {
    final row = _previewConfirm != null && _previewConfirm![_serviceType] is Map
        ? _previewConfirm![_serviceType] as Map<String, dynamic>
        : null;
    if (row != null) {
      final servicePrice = _parseNum(row['service_price']);
      final homeFee = _parseNum(row['home_service_fee']);
      final discount = _parseNum(row['platform_discount']);
      final vatAmount = _parseNum(row['vat_amount']);
      final total = _parseNum(row['total_amount']);
      final discountRate = _parseNum(row['platform_discount_rate']);
      final vatRate = _parseNum(row['vat_rate']);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _confirmRow('سعر التحليل', '${servicePrice.toStringAsFixed(2)} ر.س'),
          if (_serviceType == 'home_service')
            _confirmRow('الخدمة المنزلية', '+ ${homeFee.toStringAsFixed(2)} ر.س'),
          _confirmRow('خصم المنصة ${discountRate.toStringAsFixed(0)}%', '- ${discount.toStringAsFixed(2)} ر.س', valueStyle: TextStyle(color: AppTheme.success, fontWeight: FontWeight.w600)),
          if (_isNonSaudi && vatAmount > 0)
            _confirmRow('الضريبة ${vatRate.toStringAsFixed(0)}%', '+ ${vatAmount.toStringAsFixed(2)} ر.س', valueStyle: TextStyle(color: const Color.fromARGB(255, 255, 0, 0))),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Divider(height: 1, color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5)),
          ),
          _confirmRow('المبلغ الإجمالي', '${total.toStringAsFixed(2)} ر.س', valueStyle: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: Responsive.fontSize(context, 16))),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _confirmRow('سعر التحليل', '${_price.toStringAsFixed(2)} ر.س'),
        if (_serviceType == 'home_service')
          _confirmRow('الخدمة المنزلية', '+ ${_homeServiceFee.toStringAsFixed(2)} ر.س'),
        _confirmRow('خصم المنصة ${_platformDiscountRate.toStringAsFixed(0)}%', '- ${_discountAmount.toStringAsFixed(2)} ر.س', valueStyle: TextStyle(color: AppTheme.success, fontWeight: FontWeight.w600)),
        if (_isNonSaudi)
          _confirmRow('الضريبة ${_vatRate.toStringAsFixed(0)}%', '+ ${_vatAmount.toStringAsFixed(2)} ر.س', valueStyle: TextStyle(color: const Color.fromARGB(255, 255, 0, 0))),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Divider(height: 1, color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5)),
        ),
        _confirmRow('المبلغ الإجمالي', '${_totalAmount.toStringAsFixed(2)} ر.س', valueStyle: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: Responsive.fontSize(context, 16))),
      ],
    );
  }

  Widget _buildNextButton() {
    final isConfirm = _step == 3;
    return GradientFilledButton(
      onPressed: isConfirm ? (_creating ? null : _createBooking) : _nextStep,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: _creating ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(isConfirm ? 'إنشاء الحجز والمتابعة للدفع' : 'التالي'),
    );
  }
}
