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
import 'package:rast/core/onboarding/onboarding_catalog.dart';
import 'package:rast/core/onboarding/onboarding_host.dart';
import 'package:rast/core/onboarding/onboarding_step.dart';
import 'package:rast/core/onboarding/onboarding_tour_ids.dart';
import 'package:rast/core/widgets/gradient_button.dart';
import 'package:rast/core/widgets/rast_ui.dart';
import 'package:rast/features/auth/services/auth_service.dart';
import 'package:rast/features/auth/screens/login_screen.dart';
import 'package:rast/core/services/branches_index_service.dart';
import 'package:rast/core/services/location_service.dart';
import 'package:rast/core/utils/lab_location_utils.dart';
import 'package:rast/core/services/cart_service.dart';
import 'package:rast/features/bookings/screens/booking_detail_screen.dart';
import 'package:rast/features/bookings/screens/payment_webview_screen.dart';
import 'package:rast/features/cart/screens/cart_screen.dart';

/// شاشة حجز تحليل: نوع الخدمة → التاريخ → الوقت → تأكيد وإنشاء → الدفع
class BookFlowScreen extends StatefulWidget {
  /// المختبر (إن وُجد) أو نستخدم labId لجلبه
  final Map<String, dynamic>? lab;
  final int labId;
  final String? labName;

  /// فرع محدد مسبقاً (إن وُجد من شاشة سابقة).
  final int? preselectedBranchId;

  /// خريطة provider_service: id, final_price, home_service_price, service.name_ar
  final Map<String, dynamic> providerService;

  const BookFlowScreen({
    super.key,
    this.lab,
    required this.labId,
    this.labName,
    this.preselectedBranchId,
    required this.providerService,
  });

  @override
  State<BookFlowScreen> createState() => _BookFlowScreenState();
}

class _BookFlowScreenState extends State<BookFlowScreen> with OnboardingTourHost {
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
  bool _addingToCart = false;
  String? _error;
  Map<String, dynamic>? _createdBooking;
  NearestBranchInfo? _nearestBranch;
  double? _userLat;
  double? _userLng;

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
  String get _serviceNameAr =>
      (widget.providerService['service'] is Map
              ? (widget.providerService['service'] as Map)['name_ar']
              : widget.providerService['name_ar'])
          ?.toString() ??
      '';
  static double _extractPrice(Map<String, dynamic> map) {
    var v =
        map['final_price'] ??
        map['price'] ??
        map['base_price'] ??
        map['sale_price'] ??
        map['finalPrice'] ??
        map['basePrice'] ??
        map['salePrice'];
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
    var v =
        map['home_service_price'] ??
        map['home_price'] ??
        map['home_service_fee'];
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
  String get _serviceMode =>
      (_lab?['service_mode'] ?? '').toString().trim().toLowerCase();
  bool get _isHomeOnly => _serviceMode == 'home_only';
  bool get _isClinicOnly => _serviceMode == 'clinic_only';
  bool get _homeAvailable => _isHomeOnly || _lab?['home_service_available'] == true;

  @override
  String? get onboardingTourId => OnboardingTourIds.bookFlow;

  @override
  List<OnboardingStep> buildOnboardingSteps() =>
      OnboardingCatalog.bookFlowTour;

  @override
  void initState() {
    super.initState();
    scheduleOnboardingTour(delay: const Duration(milliseconds: 700));
    _resolvedPrice = _extractPrice(widget.providerService);
    _resolvedHomeServiceFeeRaw = _extractHomeFee(widget.providerService);
    _lab = widget.lab;
    _syncServiceTypeWithLabMode(silent: true);
    if (_lab == null) {
      _loadLab();
    } else {
      _resolveNearestBranch();
    }
    _loadBookingConfig();
    _loadPreview();
  }

  void _syncServiceTypeWithLabMode({bool silent = false}) {
    String next = _serviceType;
    if (_isHomeOnly) {
      next = 'home_service';
    } else if (_isClinicOnly) {
      next = 'in_clinic';
    } else if (next == 'home_service' && !_homeAvailable) {
      next = 'in_clinic';
    }
    if (next == _serviceType) return;
    if (silent) {
      _serviceType = next;
      return;
    }
    if (!mounted) return;
    setState(() => _serviceType = next);
  }

  /// جلب معاينة الأسعار من الباكند (نفس منطق الفاتورة)
  Future<void> _loadPreview() async {
    if (_loadingPreview) return;
    setState(() => _loadingPreview = true);
    try {
      final data = await Api.bookings.getBookingPreview(
        _providerServiceId,
        nationality: 'saudi',
      );
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
      final data = await Api.bookings.getBookingPreview(
        _providerServiceId,
        nationality: nationality,
      );
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
      _syncServiceTypeWithLabMode();
      await _resolveNearestBranch();
    } catch (_) {
      setState(() => _error = 'تعذر تحميل بيانات المختبر');
    }
  }

  Future<void> _resolveNearestBranch() async {
    final labMap = _lab ?? widget.lab;
    if (labMap == null) return;

    final labJson = Map<String, dynamic>.from(labMap);

    if (widget.preselectedBranchId != null) {
      final branches = await _branchesForLab(labMap);
      for (final b in branches) {
        if (b is! Map) continue;
        final m = Map<String, dynamic>.from(b);
        final id = m['id'] ?? m['branch_id'];
        final parsed = id is int ? id : int.tryParse(id?.toString() ?? '');
        if (parsed == widget.preselectedBranchId) {
          if (mounted) {
            setState(() {
              _nearestBranch = NearestBranchInfo(
                branchId: parsed,
                nameAr: m['name_ar']?.toString() ?? '',
                nameEn: m['name_en']?.toString() ?? '',
                city: m['city']?.toString() ?? '',
                district: m['district']?.toString() ?? '',
              );
            });
          }
          return;
        }
      }
    }

    final fromApi = LabLocationUtils.nearestFromApi(labJson);
    if (fromApi != null &&
        (fromApi.hasBranchId ||
            fromApi.nameAr.isNotEmpty ||
            fromApi.city.isNotEmpty)) {
      if (mounted) {
        setState(() => _nearestBranch = fromApi);
        if (_step == 2 && _selectedDate != null) _loadTimeSlots();
      }
      return;
    }

    double? lat = _userLat;
    double? lng = _userLng;
    if (lat == null || lng == null) {
      try {
        final current = await LocationService.getCurrentLocation(
          saveAsDefault: false,
        );
        lat = current?.lat;
        lng = current?.lng;
      } catch (_) {}
    }
    if (lat == null || lng == null) {
      final saved = await LocationService.getDefaultLocation();
      lat ??= saved?.lat;
      lng ??= saved?.lng;
    }
    _userLat = lat;
    _userLng = lng;

    final branches = await _branchesForLab(labMap);
    final nearest = LabLocationUtils.resolveForDisplay(
      lab: labJson,
      userLat: lat,
      userLng: lng,
      branches: branches,
    );
    if (mounted) {
      setState(() => _nearestBranch = nearest);
      if (_step == 2 && _selectedDate != null) {
        _loadTimeSlots();
      }
    }
  }

  Future<List<dynamic>> _branchesForLab(Map<String, dynamic> lab) async {
    final cached = BranchesIndexService.instance.branchesFor(lab);
    if (cached != null && cached.isNotEmpty) return cached;
    if (lab['branches'] is List && (lab['branches'] as List).isNotEmpty) {
      return lab['branches'] as List<dynamic>;
    }
    try {
      return await Api.providers.getProviderBranches(widget.labId);
    } catch (_) {
      return [];
    }
  }

  int? get _bookingBranchId {
    if (widget.preselectedBranchId != null) {
      return widget.preselectedBranchId;
    }
    return _nearestBranch?.branchId;
  }

  /// نسبة خصم المنصة (٪): من API أو 7% افتراضي. يدعم API يعيد 7 أو 0.07 أو نصاً
  double get _platformDiscountRate {
    final v =
        _bookingConfig?['platform_discount_rate'] ??
        _bookingConfig?['platformDiscountRate'];
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
  double get _basePrice =>
      _serviceType == 'home_service' ? (_price + _homeServiceFeeRaw) : _price;

  double get _discountAmount {
    final rate = _platformDiscountRate;
    if (rate <= 0 || _price <= 0) return 0;
    final amount = _price * (rate / 100);
    return amount.roundToDouble();
  }

  double get _afterDiscount => (_basePrice - _discountAmount).roundToDouble();

  double get _vatAmount => _isNonSaudi && _vatRate > 0
      ? (_afterDiscount * (_vatRate / 100)).roundToDouble()
      : 0.0;

  double get _totalAmount => (_afterDiscount + _vatAmount).roundToDouble();

  void _nextStep() {
    if (_step == 0) {
      if (_serviceType == 'home_service' &&
          (_addressController.text.trim().isEmpty ||
              _cityController.text.trim().isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('أدخل العنوان والمدينة للخدمة المنزلية'),
          ),
        );
        return;
      }
    }
    if (_step == 1 && _selectedDate == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('اختر التاريخ')));
      return;
    }
    if (_step == 2 && _selectedSlot == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('اختر وقت الزيارة')));
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
      final slots = await Api.providers.getTimeSlots(
        widget.labId,
        dateStr,
        branchId: _bookingBranchId,
      );
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

  Future<Map<String, dynamic>> _buildBookingBody() async {
    final savedLoc = await LocationService.getDefaultLocation();
    final lat = _userLat ?? savedLoc?.lat;
    final lng = _userLng ?? savedLoc?.lng;

    if (_serviceType == 'in_clinic' &&
        _bookingBranchId == null &&
        (lat == null || lng == null)) {
      throw ApiException(
        'يرجى تحديد موقعك من الإعدادات لاختيار أقرب فرع، أو انتظر اكتمال تحميل بيانات المختبر.',
      );
    }

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

    final branchId = _bookingBranchId;
    if (branchId != null) body['branch_id'] = branchId;
    if (lat != null && lng != null) {
      body['latitude'] = lat;
      body['longitude'] = lng;
      if (_serviceType == 'home_service') {
        body['home_latitude'] = lat;
        body['home_longitude'] = lng;
      }
    }
    return body;
  }

  Future<void> _addToCart() async {
    if (!AuthService.isLoggedIn) {
      final ok = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      if (ok == true && mounted) setState(() {});
      return;
    }
    setState(() {
      _addingToCart = true;
      _error = null;
    });
    try {
      final body = await _buildBookingBody();
      if (!mounted) return;
      await context.read<CartService>().addItem(body);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('تمت الإضافة إلى السلة'),
          action: SnackBarAction(
            label: 'عرض السلة',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CartScreen()),
            ),
          ),
        ),
      );
      Navigator.pop(context);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() {
        _error = e.toString().contains('SocketException')
            ? 'تحقق من الاتصال'
            : e.toString();
      });
    } finally {
      if (mounted) setState(() => _addingToCart = false);
    }
  }

  Future<void> _createBooking() async {
    if (!AuthService.isLoggedIn) {
      final ok = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      if (ok == true && mounted) setState(() {});
      return;
    }
    setState(() {
      _creating = true;
      _error = null;
    });
    final isArabic = context.read<AppSettingsProvider>().isArabic;
    try {
      final body = await _buildBookingBody();
      final booking = await Api.bookings.create(body);
      final b = _toBookingMap(booking, isArabic: isArabic);
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
        _error = e.toString().contains('SocketException')
            ? 'تحقق من الاتصال'
            : e.toString();
      });
    }
  }

  Map<String, dynamic> _toBookingMap(
    Map<String, dynamic> booking, {
    bool isArabic = true,
  }) {
    final summary = booking['summary'] is Map
        ? booking['summary'] as Map<String, dynamic>
        : null;
    final ps = booking['provider_service'] ?? {};
    final service = ps is Map ? ps['service'] ?? ps : {};
    final provider = booking['provider'] ?? {};
    final timeSlot = booking['time_slot'] ?? {};
    final providerMap = provider is Map
        ? provider as Map<String, dynamic>
        : <String, dynamic>{};
    final branchObj = booking['branch'];
    String? branchLabel;
    if (branchObj is Map) {
      final bm = branchObj as Map<String, dynamic>;
      branchLabel = LocaleUtils.localizedName(
        bm,
        isArabic,
        arKey: 'name_ar',
        enKey: 'name_en',
      );
      final city = bm['city']?.toString() ?? '';
      final district = bm['district']?.toString() ?? '';
      final loc = LabLocationLine(city: city, district: district).formatted;
      if (branchLabel.isNotEmpty && loc.isNotEmpty) {
        branchLabel = '$branchLabel · $loc';
      } else if (loc.isNotEmpty) {
        branchLabel = loc;
      }
    }
    final base = <String, dynamic>{
      'id': booking['id'],
      'booking_number': booking['booking_number'] ?? 'RST-${booking['id']}',
      'status': booking['status'] ?? 'pending',
      'payment_status': booking['payment_status'] ?? 'pending',
      'booking_date': booking['booking_date'] ?? timeSlot['date'] ?? '',
      'booking_time': booking['booking_time'] ?? timeSlot['start_time'] ?? '',
      'booking_period_key':
          booking['booking_period_key'] ?? timeSlot['period_key'],
      'booking_period_label_ar':
          booking['booking_period_label_ar'] ?? timeSlot['period_label_ar'],
      'service_type': booking['service_type'] ?? 'in_clinic',
      'service_name_ar': service is Map ? service['name_ar'] : _serviceNameAr,
      'service_name_en': service is Map ? service['name_en'] : null,
      'provider_name_ar':
          providerMap['business_name_ar'] ?? widget.labName ?? '',
      'provider_name_en': providerMap['business_name_en'],
      'provider_logo_url': providerMap['logo_url'] ?? providerMap['logo'],
      'branch_name':
          booking['branch_name'] ??
          branchLabel ??
          _nearestBranch?.displayLine(isArabic) ??
          (_serviceType == 'home_service' ? 'خدمة منزلية' : 'الفرع'),
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
      final res = await Api.bookings.createPaymentSession(
        bid is int ? bid : int.parse(bid.toString()),
      );
      final success = res['success'] == true;
      final paymentUrl = res['payment_url']?.toString();

      if (success && paymentUrl != null && paymentUrl.isNotEmpty) {
        if (!mounted) return;
        final bookingId = bid is int ? bid : int.parse(bid.toString());
        final paid = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentWebViewScreen(
              paymentUrl: paymentUrl,
              bookingId: bookingId,
            ),
          ),
        );
        if (mounted) {
          Map<String, dynamic>? refreshed;
          try {
            refreshed = await Api.bookings.getPaymentStatus(bookingId);
          } catch (_) {}
          final paymentStatus =
              refreshed?['payment_status']?.toString() ??
              refreshed?['status']?.toString();
          final bookingStatus = refreshed?['booking_status']?.toString();
          final isPaid = paid == true ||
              paymentStatus == 'paid' ||
              bookingStatus == 'confirmed';
          if (!mounted) return;
          if (isPaid) {
            setState(
              () => _createdBooking = {
                ...?_createdBooking,
                'payment_status': 'paid',
                if (bookingStatus != null) 'status': bookingStatus,
              },
            );
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isPaid
                    ? 'تم تأكيد الدفع بنجاح'
                    : 'بعد إتمام الدفع يمكنك مراجعة الحجز من حجوزاتي',
              ),
            ),
          );
        }
      } else {
        final msg = res['message']?.toString() ?? 'فشل إنشاء جلسة الدفع';
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(msg)));
        }
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر فتح الدفع: ${e.toString().split('\n').first}'),
          ),
        );
      }
    }
  }

  void _goToBookingDetail() {
    if (_createdBooking == null) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => BookingDetailScreen(booking: _createdBooking!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!AuthService.isLoggedIn) {
      return Directionality(
        textDirection: ui.TextDirection.rtl,
        child: Container(
          decoration: const BoxDecoration(gradient: RastUi.headerGradient),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: RastTopBar(
              title: 'حجز تحليل',
              helpTourId: OnboardingTourIds.bookFlow,
              helpTourSteps: OnboardingCatalog.bookFlowTour,
            ),
            body: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              child: Container(
                color: RastUi.screenSurface(context),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 104,
                          height: 104,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RastUi.brandGradient,
                            boxShadow: RastUi.softShadow,
                          ),
                          child: const Icon(
                            Icons.login_rounded,
                            size: 54,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'سجّل الدخول لحجز التحليل',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: RastUi.primaryText(context),
                            fontSize: Responsive.fontSize(context, 20),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 24),
                        GradientFilledButtonIcon(
                          onPressed: () async {
                            final ok = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LoginScreen(),
                              ),
                            );
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
            ),
          ),
        ),
      );
    }

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Container(
        decoration: const BoxDecoration(gradient: RastUi.headerGradient),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: RastTopBar(
            title: _createdBooking != null ? 'تم الحجز' : 'حجز تحليل',
            helpTourId: OnboardingTourIds.bookFlow,
            helpTourSteps: OnboardingCatalog.bookFlowTour,
          ),
          body: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: Container(
              color: RastUi.screenSurface(context),
              child: _error != null && _step < 4
                  ? _buildErrorBody()
                  : _createdBooking != null
                  ? _buildSuccessBody()
                  : SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        Responsive.spacing(context, 20),
                        Responsive.spacing(context, 24),
                        Responsive.spacing(context, 20),
                        Responsive.spacing(context, 28),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildStepIndicator(),
                          SizedBox(height: Responsive.spacing(context, 22)),
                          _buildStepCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (_step == 0) _buildStepServiceType(),
                                if (_step == 1) _buildStepDate(),
                                if (_step == 2) _buildStepTime(),
                                if (_step == 3) _buildStepConfirm(),
                              ],
                            ),
                          ),
                          SizedBox(height: Responsive.spacing(context, 24)),
                          if (_step < 4 && _createdBooking == null)
                            _buildNextButton(),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepCard({required Widget child}) {
    return Container(
      padding: EdgeInsets.all(Responsive.spacing(context, 18)),
      decoration: BoxDecoration(
        color: RastUi.cardSurface(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: RastUi.softBorder(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
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
            FilledButton.icon(
              onPressed: () => setState(() => _error = null),
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
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
    final summary = _createdBooking?['summary'] is Map
        ? _createdBooking!['summary'] as Map<String, dynamic>
        : null;
    final servicePrice = summary != null
        ? _parseNum(summary['service_price'])
        : _parseNum(_createdBooking?['service_price']);
    final homeFee = summary != null
        ? _parseNum(summary['home_service_fee'])
        : _parseNum(_createdBooking?['home_service_fee']);
    final discountAmount = summary != null
        ? (_parseNum(summary['discount_amount']) > 0
              ? _parseNum(summary['discount_amount'])
              : _parseNum(summary['platform_discount']))
        : _parseNum(_createdBooking?['discount_amount']);
    final totalAmount = summary != null
        ? _parseNum(summary['total_amount'])
        : _parseNum(_createdBooking?['total_amount']);
    final vatAmount = summary != null
        ? _parseNum(summary['vat_amount'])
        : (() {
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
                Text(
                  'تم إنشاء الحجز بنجاح',
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 20),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: Responsive.spacing(context, 8)),
                Text(
                  _createdBooking?['booking_number']?.toString() ?? '',
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 16),
                    color: AppTheme.primary,
                  ),
                ),
                SizedBox(height: Responsive.spacing(context, 20)),
                if (!paid) ...[
                  GradientFilledButtonIcon(
                    onPressed: _openPayment,
                    icon: const Icon(Icons.payment),
                    label: const Text('ادفع الآن'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
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
                Text(
                  'تفاصيل الفاتورة',
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 15),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: Responsive.spacing(context, 12)),
                _confirmRow(
                  'سعر التحليل',
                  '${servicePrice.toStringAsFixed(2)} ر.س',
                ),
                if (isHomeService)
                  _confirmRow(
                    'رسوم الخدمة المنزلية',
                    '+ ${homeFee.toStringAsFixed(2)} ر.س',
                  ),
                _confirmRow(
                  'خصم المنصة',
                  '- ${discountAmount.toStringAsFixed(2)} ر.س',
                  valueStyle: TextStyle(
                    color: AppTheme.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                _confirmRow(
                  'ضريبة القيمة المضافة',
                  '+ ${vatAmount.toStringAsFixed(2)} ر.س',
                  valueStyle: TextStyle(color: AppTheme.onSurfaceVariant),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Divider(
                    height: 1,
                    color: Theme.of(
                      context,
                    ).colorScheme.outline.withValues(alpha: 0.5),
                  ),
                ),
                _confirmRow(
                  'المبلغ الإجمالي',
                  '${totalAmount.toStringAsFixed(2)} ر.س',
                  valueStyle: TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    const labels = ['الخدمة', 'التاريخ', 'الوقت', 'التأكيد'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: RastUi.subtleFill(context),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: List.generate(4, (i) {
          final active = i == _step;
          final done = i < _step;
          return Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: active ? 34 : 28,
                  height: active ? 34 : 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: active || done ? RastUi.brandGradient : null,
                    color: active || done ? null : const Color(0xFFE5E7F2),
                    boxShadow: active ? RastUi.softShadow : null,
                  ),
                  child: Center(
                    child: done
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : Text(
                            '${i + 1}',
                            style: TextStyle(
                              color: active
                                  ? Colors.white
                                  : RastUi.primaryText(context),
                              fontSize: Responsive.fontSize(context, 12),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  labels[i],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: active ? RastUi.purple : RastUi.mutedText,
                    fontSize: Responsive.fontSize(context, 10),
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStepServiceType() {
    final inClinicTotal =
        _previewData != null && _previewData!['in_clinic'] is Map
        ? _parseNum((_previewData!['in_clinic'] as Map)['total_amount'])
        : _price;
    final homeTotal =
        _previewData != null && _previewData!['home_service'] is Map
        ? _parseNum((_previewData!['home_service'] as Map)['total_amount'])
        : _homeTotal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('نوع الزيارة', Icons.medical_services_outlined),
        SizedBox(height: Responsive.spacing(context, 12)),
        if (!_isHomeOnly)
          _serviceTypeChip(
            'in_clinic',
            'في المختبر',
            Icons.business_rounded,
            '${inClinicTotal.toStringAsFixed(2)} ر.س',
          ),
        if (_homeAvailable && !_isClinicOnly) ...[
          SizedBox(height: Responsive.spacing(context, 10)),
          _serviceTypeChip(
            'home_service',
            'زيارة منزلية',
            Icons.home_rounded,
            '${homeTotal.toStringAsFixed(2)} ر.س',
          ),
        ],
        if (_serviceType == 'home_service') ...[
          SizedBox(height: Responsive.spacing(context, 20)),
          _buildSectionTitle('عنوان الزيارة', Icons.location_on_outlined),
          SizedBox(height: Responsive.spacing(context, 8)),
          TextField(
            controller: _addressController,
            decoration: InputDecoration(
              labelText: 'العنوان',
              hintText: 'الشارع والحي',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              filled: true,
              fillColor: RastUi.subtleFill(context),
            ),
          ),
          SizedBox(height: Responsive.spacing(context, 10)),
          TextField(
            controller: _cityController,
            decoration: InputDecoration(
              labelText: 'المدينة',
              hintText: 'مثال: الرياض',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              filled: true,
              fillColor: RastUi.subtleFill(context),
            ),
          ),
          SizedBox(height: Responsive.spacing(context, 10)),
          TextField(
            controller: _districtController,
            decoration: InputDecoration(
              labelText: 'الحي (اختياري)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              filled: true,
              fillColor: RastUi.subtleFill(context),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            gradient: RastUi.brandGradient,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        SizedBox(width: Responsive.spacing(context, 10)),
        Text(
          title,
          style: TextStyle(
            color: RastUi.primaryText(context),
            fontSize: Responsive.fontSize(context, 18),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _serviceTypeChip(
    String value,
    String label,
    IconData icon,
    String price,
  ) {
    final selected = _serviceType == value;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _serviceType = value),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.all(Responsive.spacing(context, 16)),
          decoration: BoxDecoration(
            color: selected ? null : RastUi.subtleFill(context),
            gradient: selected ? RastUi.brandGradient : null,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? Colors.transparent : RastUi.softBorder(context),
              width: 1,
            ),
            boxShadow: selected ? RastUi.softShadow : null,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: selected ? Colors.white : RastUi.purple,
                size: 28,
              ),
              SizedBox(width: Responsive.spacing(context, 12)),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected
                        ? Colors.white
                        : RastUi.primaryText(context),
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              Text(
                price,
                style: TextStyle(
                  color: selected ? Colors.white : RastUi.purple,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepDate() {
    final today = DateTime.now();
    final days = List.generate(10, (i) => today.add(Duration(days: i)));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('اختر التاريخ', Icons.calendar_month_outlined),
        SizedBox(height: Responsive.spacing(context, 16)),
        SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: days.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final day = days[index];
              final selected =
                  _selectedDate != null &&
                  DateUtils.isSameDay(_selectedDate, day);
              return InkWell(
                onTap: () => setState(() => _selectedDate = day),
                borderRadius: BorderRadius.circular(18),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 68,
                  decoration: BoxDecoration(
                    gradient: selected ? RastUi.brandGradient : null,
                    color: selected ? null : RastUi.subtleFill(context),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: selected
                          ? Colors.transparent
                          : RastUi.softBorder(context),
                    ),
                    boxShadow: selected ? RastUi.softShadow : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _weekdayLabel(day),
                        style: TextStyle(
                          color: selected ? Colors.white : RastUi.mutedText,
                          fontSize: Responsive.fontSize(context, 11),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        DateFormat('d').format(day),
                        style: TextStyle(
                          color: selected
                              ? Colors.white
                              : RastUi.primaryText(context),
                          fontSize: Responsive.fontSize(context, 22),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        _monthLabel(day),
                        style: TextStyle(
                          color: selected ? Colors.white : RastUi.mutedText,
                          fontSize: Responsive.fontSize(context, 10),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        SizedBox(height: Responsive.spacing(context, 14)),
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
          icon: const Icon(Icons.event_available_rounded),
          label: Text(
            _selectedDate != null
                ? DateFormat('yyyy-MM-dd').format(_selectedDate!)
                : 'اختيار من التقويم',
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: RastUi.purple,
            side: const BorderSide(color: Color(0xFFE2E0EA)),
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
      ],
    );
  }

  String _weekdayLabel(DateTime day) {
    const labels = [
      'الاثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
      'الأحد',
    ];
    return labels[day.weekday - 1];
  }

  String _monthLabel(DateTime day) {
    const labels = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];
    return labels[day.month - 1];
  }

  String _timeSlotPrimaryLabel(Map<String, dynamic> slot) {
    final ar = slot['period_label_ar']?.toString().trim();
    if (ar != null && ar.isNotEmpty) return ar;
    return DateFormatter.formatBookingTime(slot['start_time']?.toString());
  }

  Widget _buildStepTime() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('اختر الوقت', Icons.schedule_rounded),
        SizedBox(height: Responsive.spacing(context, 12)),
        if (_loadingSlots)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_timeSlots.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: AppTheme.cardDecorationFor(context),
            child: const Text(
              'لا توجد مواعيد متاحة لهذا اليوم. اختر تاريخاً آخر.',
              textAlign: TextAlign.center,
            ),
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _timeSlots.map<Widget>((s) {
              final slot = s is Map
                  ? s as Map<String, dynamic>
                  : <String, dynamic>{};
              final slotId = slot['id'];
              final selected = _selectedSlot?['id'] == slotId;
              return ChoiceChip(
                label: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  child: Text(
                    _timeSlotPrimaryLabel(slot),
                    style: TextStyle(
                      color: selected ? Colors.white : RastUi.primaryText(context),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                selected: selected,
                showCheckmark: false,
                onSelected: (_) => setState(() => _selectedSlot = slot),
                selectedColor: RastUi.purple,
                backgroundColor: RastUi.subtleFill(context),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(
                    color: selected
                        ? Colors.transparent
                        : RastUi.softBorder(context),
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildStepConfirm() {
    final labDisplay = LocaleUtils.localizedBusinessName(
      _lab,
      context.watch<AppSettingsProvider>().isArabic,
    );
    final labNameDisplay = labDisplay.isNotEmpty
        ? labDisplay
        : (widget.labName ?? '');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('ملخص الحجز', Icons.receipt_long_outlined),
        SizedBox(height: Responsive.spacing(context, 12)),
        Container(
          padding: EdgeInsets.all(Responsive.spacing(context, 20)),
          decoration: BoxDecoration(
            color: RastUi.panelSurface(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: RastUi.softBorder(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _confirmRow('التحليل', _serviceNameAr),
              _confirmRow('المختبر', labNameDisplay),
              if (_serviceType == 'in_clinic' && _nearestBranch != null)
                _confirmRow(
                  'الفرع',
                  _nearestBranch!.displayLine(
                    context.watch<AppSettingsProvider>().isArabic,
                  ),
                ),
              _confirmRow(
                'نوع الخدمة',
                _serviceType == 'home_service' ? 'خدمة منزلية' : 'في المختبر',
              ),
              _confirmRow(
                'التاريخ',
                _selectedDate != null
                    ? DateFormatter.formatDate(_selectedDate!)
                    : '',
              ),
              _confirmRow(
                'الوقت',
                _selectedSlot != null
                    ? _timeSlotPrimaryLabel(_selectedSlot!)
                    : '',
              ),
              if (_serviceType == 'home_service')
                _confirmRow('العنوان', _addressController.text),
              SizedBox(height: Responsive.spacing(context, 12)),
              CheckboxListTile(
                value: _isNonSaudi,
                onChanged: (v) {
                  setState(() => _isNonSaudi = v ?? false);
                  _loadConfirmPreview();
                },
                title: Text(
                  'أنا غير سعودي (تُطبّق الضريبة)',
                  style: TextStyle(fontSize: Responsive.fontSize(context, 13)),
                ),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
                activeColor: AppTheme.primary,
              ),
              const Divider(height: 24),
              Text(
                'تفاصيل المبلغ',
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 14),
                  fontWeight: FontWeight.w600,
                  color: AppTheme.onSurface,
                ),
              ),
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
          Flexible(
            child: Text(
              value,
              style: valueStyle ?? const TextStyle(fontWeight: FontWeight.w600),
              textAlign: TextAlign.left,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// خصم المنصة ونسبته من استجابة معاينة الحجز (نفس ترتيب حقول `summary` بعد الإنشاء).
  ({double discount, double ratePercent}) _previewPlatformDiscountAndRate(
    Map<String, dynamic> row,
    double servicePrice,
  ) {
    var discount = _parseNum(row['discount_amount']);
    if (discount <= 0) discount = _parseNum(row['platform_discount']);
    if (discount <= 0) discount = _parseNum(row['platformDiscount']);

    var rateRaw = _parseNum(row['platform_discount_rate']);
    if (rateRaw <= 0) rateRaw = _parseNum(row['platformDiscountRate']);
    final ratePercent = rateRaw <= 0
        ? _platformDiscountRate
        : (rateRaw <= 1 ? rateRaw * 100 : rateRaw);

    if (discount <= 0 && servicePrice > 0 && ratePercent > 0) {
      discount = (servicePrice * (ratePercent / 100)).roundToDouble();
    }
    return (discount: discount, ratePercent: ratePercent);
  }

  /// تفاصيل المبلغ في ملخص الحجز: من معاينة الـ API إن وُجدت (نفس الفاتورة)
  Widget _buildConfirmAmounts() {
    final row = _previewConfirm != null && _previewConfirm![_serviceType] is Map
        ? _previewConfirm![_serviceType] as Map<String, dynamic>
        : null;
    if (row != null) {
      final servicePrice = _parseNum(row['service_price']);
      final homeFee = _parseNum(row['home_service_fee']);
      final disc = _previewPlatformDiscountAndRate(row, servicePrice);
      final discount = disc.discount;
      final discountRate = disc.ratePercent;
      final vatAmount = _parseNum(row['vat_amount']);
      final total =
          (servicePrice + homeFee - discount + vatAmount).roundToDouble();
      var vatRate = _parseNum(row['vat_rate']);
      if (vatRate <= 0 && _isNonSaudi) vatRate = _vatRate;
      if (vatRate > 0 && vatRate <= 1) vatRate *= 100;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _confirmRow('سعر التحليل', '${servicePrice.toStringAsFixed(2)} ر.س'),
          if (_serviceType == 'home_service')
            _confirmRow(
              'الخدمة المنزلية',
              '+ ${homeFee.toStringAsFixed(2)} ر.س',
            ),
          _confirmRow(
            'خصم المنصة ${discountRate.toStringAsFixed(0)}%',
            '- ${discount.toStringAsFixed(2)} ر.س',
            valueStyle: TextStyle(
              color: AppTheme.success,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (_isNonSaudi && vatAmount > 0)
            _confirmRow(
              'الضريبة ${vatRate.toStringAsFixed(0)}%',
              '+ ${vatAmount.toStringAsFixed(2)} ر.س',
              valueStyle: TextStyle(
                color: const Color.fromARGB(255, 255, 0, 0),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Divider(
              height: 1,
              color: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.5),
            ),
          ),
          _confirmRow(
            'المبلغ الإجمالي',
            '${total.toStringAsFixed(2)} ر.س',
            valueStyle: TextStyle(
              color: AppTheme.primary,
              fontWeight: FontWeight.bold,
              fontSize: Responsive.fontSize(context, 16),
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _confirmRow('سعر التحليل', '${_price.toStringAsFixed(2)} ر.س'),
        if (_serviceType == 'home_service')
          _confirmRow(
            'الخدمة المنزلية',
            '+ ${_homeServiceFee.toStringAsFixed(2)} ر.س',
          ),
        _confirmRow(
          'خصم المنصة ${_platformDiscountRate.toStringAsFixed(0)}%',
          '- ${_discountAmount.toStringAsFixed(2)} ر.س',
          valueStyle: TextStyle(
            color: AppTheme.success,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (_isNonSaudi)
          _confirmRow(
            'الضريبة ${_vatRate.toStringAsFixed(0)}%',
            '+ ${_vatAmount.toStringAsFixed(2)} ر.س',
            valueStyle: TextStyle(color: const Color.fromARGB(255, 255, 0, 0)),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Divider(
            height: 1,
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
          ),
        ),
        _confirmRow(
          'المبلغ الإجمالي',
          '${_totalAmount.toStringAsFixed(2)} ر.س',
          valueStyle: TextStyle(
            color: AppTheme.primary,
            fontWeight: FontWeight.bold,
            fontSize: Responsive.fontSize(context, 16),
          ),
        ),
      ],
    );
  }

  Widget _buildNextButton() {
    final isConfirm = _step == 3;
    if (!isConfirm) {
      return Row(
        children: [
          if (_step > 0) ...[
            SizedBox(
              width: 56,
              height: 56,
              child: OutlinedButton(
                onPressed: _backStep,
                style: OutlinedButton.styleFrom(
                  foregroundColor: RastUi.purple,
                  side: const BorderSide(color: Color(0xFFE2E0EA)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  padding: EdgeInsets.zero,
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: GradientFilledButton(
              onPressed: _nextStep,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 17),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
              ),
              child: const Text('التالي'),
            ),
          ),
        ],
      );
    }

    final busy = _creating || _addingToCart;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: OutlinedButton(
                onPressed: _backStep,
                style: OutlinedButton.styleFrom(
                  foregroundColor: RastUi.purple,
                  side: const BorderSide(color: Color(0xFFE2E0EA)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  padding: EdgeInsets.zero,
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GradientFilledButton(
                onPressed: busy ? null : _addToCart,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 17),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
                child: _addingToCart
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('إضافة إلى السلة'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: busy ? null : _createBooking,
          style: OutlinedButton.styleFrom(
            foregroundColor: RastUi.purple,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            side: const BorderSide(color: Color(0xFFE2E0EA)),
          ),
          child: _creating
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('حجز فوري والدفع'),
        ),
      ],
    );
  }
}
