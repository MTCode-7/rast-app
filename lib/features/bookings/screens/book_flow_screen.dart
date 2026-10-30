import 'dart:async';
import 'dart:ui' as ui show TextDirection;
import 'package:firebase_analytics/firebase_analytics.dart' show AnalyticsEventItem;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:rast/core/widgets/rast_kit.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:rast/core/providers/app_settings_provider.dart';
import 'package:rast/core/utils/locale_utils.dart';
import 'package:rast/core/api/api_services.dart';
import 'package:rast/core/services/analytics_service.dart';
import 'package:rast/core/constants/api_config.dart';
import 'package:rast/core/utils/date_formatter.dart';
import 'package:rast/core/api/api_client.dart';
import 'package:rast/core/theme/app_theme.dart';
import 'package:rast/core/utils/responsive.dart';
import 'package:rast/core/onboarding/onboarding_catalog.dart';
import 'package:rast/core/onboarding/onboarding_host.dart';
import 'package:rast/core/onboarding/onboarding_step.dart';
import 'package:rast/core/onboarding/onboarding_tour_ids.dart';
import 'package:rast/core/widgets/rast_ui.dart';
import 'package:rast/features/auth/services/auth_service.dart';
import 'package:rast/features/auth/screens/login_screen.dart';
import 'package:rast/core/services/branches_index_service.dart';
import 'package:rast/core/services/location_service.dart';
import 'package:rast/features/addresses/widgets/home_address_chooser.dart';
import 'package:rast/core/utils/lab_location_utils.dart';
import 'package:rast/core/services/cart_service.dart';
import 'package:rast/core/services/app_events.dart';
import 'package:rast/core/widgets/cart_added_toast.dart';
import 'package:rast/core/widgets/fly_to_cart.dart';
import 'package:rast/core/widgets/rast_motion.dart';
import 'package:rast/features/bookings/screens/booking_detail_screen.dart';
import 'package:rast/features/bookings/screens/payment_webview_screen.dart';
import 'package:rast/features/cart/screens/cart_screen.dart';

import '../../../core/constants/app_strings.dart';

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

class _BookFlowScreenState extends State<BookFlowScreen>
    with OnboardingTourHost {
  String get _lang => context.read<AppSettingsProvider>().language;

  bool get _isArabic => context.read<AppSettingsProvider>().isArabic;

  String _tr(String key) {
    return AppStrings.t(key, _lang);
  }

  String _sar(double value) {
    return '${value.toStringAsFixed(2)} ${AppStrings.t('sar', _lang)}';
  }

  Map<String, dynamic>? _lab;
  int _step = 0;
  String _serviceType = 'in_clinic';
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _districtController = TextEditingController();

  /// الحجز لشخص آخر (أخ، ابن...): يُرسل اسمه مع الحجز، ويمكن إضافة نفس التحليل لعدة أشخاص في السلة
  bool _forOther = false;
  final TextEditingController _patientNameController = TextEditingController();
  DateTime? _selectedDate;
  Map<String, dynamic>? _selectedSlot;
  List<dynamic> _timeSlots = [];
  bool _loadingSlots = false;
  bool _creating = false;
  bool _addingToCart = false;
  final _addToCartButtonKey = GlobalKey();
  String? _error;
  String? _timeSlotsError;
  Map<String, dynamic>? _createdBooking;
  NearestBranchInfo? _nearestBranch;
  double? _userLat;
  double? _userLng;

  /// موقع السحب المنزلي المختار (عنوان محفوظ أو جديد أو GPS) — قد يختلف عن موقع المستخدم الحالي
  double? _homeLat;
  double? _homeLng;
  String? _homeAddressKey;

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

  /// عنصر التحليلات لهذا الحجز (لأحداث بدء الدفع والشراء)
  AnalyticsEventItem _analyticsItem(double amount) => AnalyticsService.item(
        id: _providerServiceId,
        name: _serviceNameDisplay(),
        price: amount > 0 ? amount : null,
        lab: widget.labName,
        variant: _serviceType,
      );

  String _serviceNameDisplay() {
    final service = widget.providerService['service'];

    if (service is Map) {
      final map = Map<String, dynamic>.from(service);

      final localized = LocaleUtils.localizedName(
        map,
        _isArabic,
        arKey: 'name_ar',
        enKey: 'name_en',
      );

      if (localized.isNotEmpty) {
        return localized;
      }
    }

    return LocaleUtils.localizedName(
      widget.providerService,
      _isArabic,
      arKey: 'name_ar',
      enKey: 'name_en',
    );
  }

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

  /// استخراج رسوم الخدمة المنزلية (مطابق للباكند: provider_service ثم المختبر).
  static double _extractHomeFee(
    Map<String, dynamic> map, {
    Map<String, dynamic>? lab,
  }) {
    var v =
        map['home_service_price'] ??
        map['home_price'] ??
        map['home_service_fee'];
    if (v is num && v.toDouble() > 0) return v.toDouble();
    if (v != null) {
      final parsed = double.tryParse(v.toString().trim().replaceAll(',', ''));
      if (parsed != null && parsed > 0) return parsed;
    }
    final ps = map['provider_service'] ?? map['providerService'];
    if (ps is Map<String, dynamic>) {
      final fromPs = _extractHomeFee(ps);
      if (fromPs > 0) return fromPs;
    }
    final provider = map['provider'];
    if (provider is Map<String, dynamic>) {
      final fee =
          provider['home_service_fee'] ?? provider['home_service_price'];
      if (fee is num && fee.toDouble() > 0) return fee.toDouble();
      if (fee != null) {
        final parsed = double.tryParse(fee.toString());
        if (parsed != null && parsed > 0) return parsed;
      }
    }
    if (lab != null) {
      final fee = lab['home_service_fee'] ?? lab['home_service_price'];
      if (fee is num && fee.toDouble() > 0) return fee.toDouble();
      if (fee != null) {
        final parsed = double.tryParse(fee.toString());
        if (parsed != null && parsed > 0) return parsed;
      }
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
  bool get _homeAvailable =>
      _isHomeOnly || _lab?['home_service_available'] == true;

  @override
  String? get onboardingTourId => OnboardingTourIds.bookFlow;

  @override
  List<OnboardingStep> buildOnboardingSteps() => OnboardingCatalog.bookFlowTour;

  @override
  void initState() {
    super.initState();
    AnalyticsService.logScreen('booking_flow');
    scheduleOnboardingTour(delay: const Duration(milliseconds: 700));
    _resolvedPrice = _extractPrice(widget.providerService);
    _resolvedHomeServiceFeeRaw = _extractHomeFee(
      widget.providerService,
      lab: widget.lab ?? _lab,
    );
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
      _syncHomeServiceFeeFromContext();
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
    _patientNameController.dispose();
    super.dispose();
  }

  void _syncHomeServiceFeeFromContext() {
    var fee = _extractHomeFee(widget.providerService, lab: _lab ?? widget.lab);
    final homeRow = _previewData?['home_service'];
    if (homeRow is Map<String, dynamic>) {
      final fromPreview = _parseNum(homeRow['home_service_fee']);
      if (fromPreview > fee) fee = fromPreview;
    }
    if (fee > 0 && fee != _resolvedHomeServiceFeeRaw && mounted) {
      setState(() => _resolvedHomeServiceFeeRaw = fee);
    }
  }

  /// إجمالي العرض لنوع الزيارة — يضيف رسوم المنزل إن غابت من معاينة الـ API.
  double _displayTotalForServiceType(String serviceType) {
    final previewKey = serviceType == 'home_service'
        ? 'home_service'
        : 'in_clinic';
    final row = _previewData?[previewKey];
    if (row is Map<String, dynamic>) {
      final total = _parseNum(row['total_amount']);
      if (serviceType == 'in_clinic' && total > 0) return total;

      if (serviceType == 'home_service') {
        final inClinicRow = _previewData?['in_clinic'];
        final inClinicTotal = inClinicRow is Map<String, dynamic>
            ? _parseNum(inClinicRow['total_amount'])
            : 0.0;
        final previewHomeFee = _parseNum(row['home_service_fee']);
        final homeFee = previewHomeFee > 0
            ? previewHomeFee
            : _homeServiceFeeRaw;

        if (total > 0) {
          if (homeFee > 0 &&
              inClinicTotal > 0 &&
              total <= inClinicTotal + 0.01) {
            return (inClinicTotal + homeFee).roundToDouble();
          }
          if (homeFee > 0 && inClinicTotal <= 0 && total <= _price + 0.01) {
            return (_afterDiscountForBase(_price + homeFee)).roundToDouble();
          }
          return total;
        }
      }
    }
    if (serviceType == 'home_service') return _homeTotal;
    return _price;
  }

  double _afterDiscountForBase(double base) {
    final rate = _platformDiscountRate;
    if (rate <= 0 || _price <= 0) return base;
    final discount = _price * (rate / 100);
    return (base - discount.roundToDouble()).roundToDouble();
  }

  Future<void> _loadLab() async {
    try {
      final lab = await Api.providers.getProvider(widget.labId);
      if (!mounted) return;
      setState(() => _lab = lab);
      _syncHomeServiceFeeFromContext();
      _syncServiceTypeWithLabMode();
      await _resolveNearestBranch();
    } catch (_) {
      setState(() => _error = _tr('labLoadFailed'));
    }
  }

  Future<void> _resolveNearestBranch() async {
    final labMap = _lab ?? widget.lab;

    if (labMap == null) {
      return;
    }

    final labJson = Map<String, dynamic>.from(labMap);

    if (widget.preselectedBranchId != null) {
      print('🔵 Trying preselected branch...');

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

        if (_step == 2 && _selectedDate != null) {
          _loadTimeSlots();
        }
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
      } catch (e) {}
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
      setState(() {
        _nearestBranch = nearest;
      });

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
    if (d > 0) return d <= 1 ? d * 100 : d;
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_tr('enterHomeAddressCity'))));
        return;
      }
    }
    if (_step == 1 && _selectedDate == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_tr('selectDate'))));
      return;
    }
    if (_step == 2 && _selectedSlot == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_tr('selectVisitTime'))));
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
      _timeSlotsError = null;
    });
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate!);
      final branchId = _bookingBranchId;
      List<dynamic> slots;

      try {
        slots = await Api.providers.getTimeSlots(
          widget.labId,
          dateStr,
          branchId: branchId,
        );
      } on ApiException {
        if (branchId != null) {
          slots = await Api.providers.getTimeSlots(widget.labId, dateStr);
        } else {
          rethrow;
        }
      }

      if (!mounted) return;
      setState(() {
        _timeSlots = slots;
        _loadingSlots = false;
        _timeSlotsError = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingSlots = false;
        _timeSlotsError = e.message.isNotEmpty
            ? e.message
            : _tr('timeSlotsLoadError');
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingSlots = false;
        _timeSlotsError = _tr('timeSlotsConnectionError');
      });
    }
  }

  Future<Map<String, dynamic>> _buildBookingBody() async {
    final savedLoc = await LocationService.getDefaultLocation();
    // السحب المنزلي: موقع العنوان المختار هو المرجع (لاختيار أقرب فرع ولزيارة فريق السحب)
    final useHome = _serviceType == 'home_service' && _homeLat != null && _homeLng != null;
    final lat = useHome ? _homeLat : (_userLat ?? savedLoc?.lat);
    final lng = useHome ? _homeLng : (_userLng ?? savedLoc?.lng);

    if (_serviceType == 'in_clinic' &&
        _bookingBranchId == null &&
        (lat == null || lng == null)) {
      throw ApiException(_tr('locationRequiredForBranch'));
    }

    final patientName = _patientNameController.text.trim();
    if (_forOther && patientName.length < 2) {
      throw ApiException(_tr('patientNameRequired'));
    }

    final body = <String, dynamic>{
      'provider_service_id': _providerServiceId,
      'time_slot_id': _selectedSlot!['id'],
      'service_type': _serviceType,
      if (_forOther) 'patient_name': patientName,
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

      if (ok == true && mounted) {
        setState(() {});
      }

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

      // نحتفظ بالـ Navigator وطبقته قبل إغلاق هذه الشاشة: بعد pop يصبح context هذه الشاشة غير صالح
      final navigator = Navigator.of(context);
      final overlay = navigator.overlay!;
      final lang = context.read<AppSettingsProvider>().language;
      final from = FlyToCart.rectOf(_addToCartButtonKey);
      final service = widget.providerService['service'];
      final imageUrl = ApiConfig.imageFromMap(widget.providerService) ??
          (service is Map ? ApiConfig.imageFromMap(Map<String, dynamic>.from(service)) : null);

      Navigator.pop(context);

      // العنصر يطير من زر الإضافة إلى أيقونة السلة، ثم يظهر إشعار أنيق فيه «عرض السلة»
      unawaited(FlyToCart.run(overlay: overlay, from: from, imageUrl: imageUrl));
      CartAddedToast.show(
        overlay: overlay,
        lang: lang,
        onViewCart: () => navigator.push(
          MaterialPageRoute(builder: (_) => const CartScreen()),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString().contains('SocketException')
            ? _tr('checkConnectionShort')
            : e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _addingToCart = false;
        });
      }
    }
  }

  Future<void> _createBooking() async {
    if (!AuthService.isLoggedIn) {
      final ok = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );

      if (ok == true && mounted) {
        setState(() {});
      }

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
      // الحجز الجديد يظهر في «حجوزاتي» فوراً حتى قبل الدفع
      AppEvents.notifyBookingsChanged();

      if (!mounted) return;

      setState(() {
        _creating = false;
        _createdBooking = b;
        _step = 4;
      });
    } on ApiException catch (e) {
      if (!mounted) return;

      setState(() {
        _creating = false;

        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _creating = false;

        _error = e.toString().contains('SocketException')
            ? _tr('checkConnectionShort')
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
        ? Map<String, dynamic>.from(provider)
        : <String, dynamic>{};

    String serviceNameAr = '';
    String serviceNameEn = '';

    if (service is Map) {
      serviceNameAr = service['name_ar']?.toString() ?? '';

      serviceNameEn = service['name_en']?.toString() ?? '';
    }

    final branchObj = booking['branch'];

    String? branchLabel;

    if (branchObj is Map) {
      final bm = Map<String, dynamic>.from(branchObj);

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

    final fallbackBranchName = _serviceType == 'home_service'
        ? AppStrings.t('homeServiceLabel', isArabic ? 'ar' : 'en')
        : AppStrings.t('branchFallback', isArabic ? 'ar' : 'en');

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

      'booking_period_label_en':
          booking['booking_period_label_en'] ?? timeSlot['period_label_en'],

      'service_type': booking['service_type'] ?? 'in_clinic',

      'service_name_ar': serviceNameAr.isNotEmpty
          ? serviceNameAr
          : (isArabic ? _serviceNameDisplay() : ''),

      'service_name_en': serviceNameEn.isNotEmpty
          ? serviceNameEn
          : (!isArabic ? _serviceNameDisplay() : ''),

      'provider_name_ar':
          providerMap['business_name_ar'] ?? widget.labName ?? '',

      'provider_name_en': providerMap['business_name_en'],

      'provider_logo_url': providerMap['logo_url'] ?? providerMap['logo'],

      'branch_name':
          booking['branch_name'] ??
          branchLabel ??
          _nearestBranch?.displayLine(isArabic) ??
          fallbackBranchName,

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
        final checkoutValue = _parseNum(_createdBooking?['total_amount']);
        await AnalyticsService.logCheckoutStarted(
          itemCount: 1,
          value: checkoutValue > 0 ? checkoutValue : null,
          items: [_analyticsItem(checkoutValue)],
        );
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
          final isPaid =
              paid == true ||
              paymentStatus == 'paid' ||
              bookingStatus == 'confirmed';
          if (isPaid) {
            final amount = _parseNum(
              refreshed?['total_amount'] ?? _createdBooking?['total_amount'],
            );
            await AnalyticsService.logPurchase(
              transactionId: 'booking_$bookingId',
              value: amount > 0 ? amount : null,
              itemCount: 1,
              items: [_analyticsItem(amount)],
            );
          }
          AppEvents.notifyBookingsChanged();
          if (!mounted) return;
          if (isPaid) {
            setState(
              () => _createdBooking = {
                ...?_createdBooking,
                'payment_status': 'paid',
                if (bookingStatus != null) 'status': bookingStatus,
              },
            );
            Celebration.show(context);
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isPaid ? _tr('paymentSuccess') : _tr('paymentReviewMessage'),
              ),
            ),
          );
        }
      } else {
        final msg = res['message']?.toString() ?? _tr('paymentSessionFailed');
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
            content: Text(
              '${_tr('unableOpenPayment')}: '
              '${e.toString().split('\n').first}',
            ),
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
    final settings = context.watch<AppSettingsProvider>();

    final lang = settings.language;
    if (!AuthService.isLoggedIn) {
      return Directionality(
        textDirection: settings.textDirection,
        child: Scaffold(
          backgroundColor: RastTokens.bg(context),
          appBar: RastTopBar(
            title: AppStrings.t('bookFlowTitle', lang),
            helpTourId: OnboardingTourIds.bookFlow,
            helpTourSteps: OnboardingCatalog.bookFlowTour,
          ),
          body: Center(
            child: SingleChildScrollView(
              child: RastEmptyState(
                icon: Icons.lock_person_rounded,
                title: AppStrings.t('signInToBook', lang),
                message: L(
                  lang,
                  'سجّل دخولك برقم جوالك لإكمال الحجز ومتابعة نتائجك.',
                  'Sign in with your phone number to complete the booking and follow your results.',
                ),
                actionLabel: AppStrings.t('signIn', lang),
                onAction: () async {
                  final ok = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LoginScreen(),
                    ),
                  );
                  if (ok == true && mounted) setState(() {});
                },
              ),
            ),
          ),
        ),
      );
    }

    final showActions =
        !(_error != null && _step < 4) && _createdBooking == null && _step < 4;

    return Directionality(
      textDirection: settings.textDirection,
      child: Scaffold(
          backgroundColor: RastTokens.bg(context),
          appBar: RastTopBar(
            title: _createdBooking != null
                ? AppStrings.t('bookingCompletedTitle', lang)
                : AppStrings.t('bookFlowTitle', lang),
            helpTourId: OnboardingTourIds.bookFlow,
            helpTourSteps: OnboardingCatalog.bookFlowTour,
            iconColor: Colors.white,
          ),
          // أزرار التنقل ثابتة أسفل الشاشة: متاحة دائماً دون تمرير
          bottomNavigationBar: showActions
              ? RastStickyBar(child: _buildNextButton())
              : null,
          body: _error != null && _step < 4
              ? _buildErrorBody()
              : _createdBooking != null
              ? _buildSuccessBody()
              : SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    Responsive.spacing(context, 16),
                    Responsive.spacing(context, 14),
                    Responsive.spacing(context, 16),
                    Responsive.spacing(context, 24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildBookingSummaryHeader()
                          .animate()
                          .fadeIn(duration: 350.ms)
                          .slideY(begin: -0.06, end: 0, curve: Curves.easeOutCubic),

                      SizedBox(height: Responsive.spacing(context, 12)),

                      _buildStepIndicator(),

                      SizedBox(height: Responsive.spacing(context, 12)),

                      _buildStepCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // الانتقال بين الخطوات: الخطوة الجديدة تنزلق وتظهر بدل التبديل المفاجئ
                            AnimatedSize(
                              duration: const Duration(milliseconds: 320),
                              curve: Curves.easeOutCubic,
                              alignment: Alignment.topCenter,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 340),
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeInCubic,
                                layoutBuilder: (current, previous) => Stack(
                                  alignment: Alignment.topCenter,
                                  children: [...previous, ?current],
                                ),
                                transitionBuilder: (child, anim) => FadeTransition(
                                  opacity: anim,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(0, 0.04),
                                      end: Offset.zero,
                                    ).animate(anim),
                                    child: child,
                                  ),
                                ),
                                child: KeyedSubtree(
                                  key: ValueKey('step-$_step'),
                                  child: switch (_step) {
                                    0 => _buildStepServiceType(),
                                    1 => _buildStepDate(),
                                    2 => _buildStepTime(),
                                    3 => _buildStepConfirm(),
                                    _ => const SizedBox.shrink(),
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
      ),
    );
  }

  /// بطاقة «ماذا تحجز»: صورة التحليل، اسمه، المختبر والفرع، والسعر حسب نوع الزيارة.
  Widget _buildBookingSummaryHeader() {
    final isArabic = context.watch<AppSettingsProvider>().isArabic;
    final service = widget.providerService['service'];
    final imageUrl = ApiConfig.imageFromMap(widget.providerService) ??
        (service is Map
            ? ApiConfig.imageFromMap(Map<String, dynamic>.from(service))
            : null);
    final labDisplay = LocaleUtils.localizedBusinessName(_lab, isArabic);
    final labName = labDisplay.isNotEmpty ? labDisplay : (widget.labName ?? '');
    final branchLine = _serviceType == 'in_clinic' && _nearestBranch != null
        ? _nearestBranch!.displayLine(isArabic)
        : (_serviceType == 'home_service'
            ? L(_lang, 'سحب العينة من منزلك', 'Sample collected at your home')
            : '');
    final total = _displayTotalForServiceType(_serviceType);

    return RastCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          RastNetImage(url: imageUrl, width: 58, height: 58, radius: 16),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _serviceNameDisplay(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                    color: RastTokens.ink(context),
                  ),
                ),
                if (labName.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.apartment_rounded, size: 14, color: RastTokens.brand),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          labName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: RastTokens.muted(context)),
                        ),
                      ),
                    ],
                  ),
                ],
                if (branchLine.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        _serviceType == 'home_service' ? Icons.home_rounded : Icons.location_on_rounded,
                        size: 14,
                        color: RastTokens.muted(context),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          branchLine,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11.5, color: RastTokens.muted(context)),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            transitionBuilder: (c, a) => FadeTransition(
              opacity: a,
              child: ScaleTransition(scale: Tween(begin: 0.9, end: 1.0).animate(a), child: c),
            ),
            child: RastPrice(
              key: ValueKey('$_serviceType-$total'),
              amount: total,
              lang: _lang,
              size: 18,
              crossAxisAlignment: CrossAxisAlignment.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.spacing(context, 16),
        vertical: Responsive.spacing(context, 20),
      ),
      decoration: BoxDecoration(
        color: RastTokens.card(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: RastTokens.line(context)),
        boxShadow: RastTokens.shadow(context),
      ),
      child: child,
    );
  }

  Widget _buildErrorBody() {
    return Center(
      child: SingleChildScrollView(
        child: RastEmptyState(
          icon: Icons.error_outline_rounded,
          color: RastTokens.danger,
          title: L(_lang, 'تعذّر إكمال الطلب', 'Could not complete the request'),
          message: _error,
          actionLabel: _tr('retry'),
          onAction: () => setState(() => _error = null),
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

    final bookingNumber = _createdBooking?['booking_number']?.toString() ?? '';
    final statusColor = paid ? RastTokens.success : RastTokens.warning;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        Responsive.spacing(context, 16),
        Responsive.spacing(context, 18),
        Responsive.spacing(context, 16),
        Responsive.spacing(context, 28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // بطاقة النجاح: علامة تنبض، رقم الحجز قابل للنسخ، وحالة الدفع
          RastCard(
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.spacing(context, 18),
              vertical: Responsive.spacing(context, 24),
            ),
            child: Column(
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: statusColor.withValues(alpha: 0.12),
                  ),
                  child: Center(
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: statusColor,
                        boxShadow: [
                          BoxShadow(
                            color: statusColor.withValues(alpha: 0.35),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Icon(
                        paid ? Icons.check_rounded : Icons.event_available_rounded,
                        size: 34,
                        color: Colors.white,
                      ),
                    ),
                  ),
                )
                    .animate()
                    .scale(begin: const Offset(0.4, 0.4), duration: 650.ms, curve: Curves.elasticOut)
                    .fadeIn(duration: 250.ms),

                SizedBox(height: Responsive.spacing(context, 16)),

                Text(
                  paid ? _tr('paymentSuccess') : _tr('bookingCreatedSuccessfully'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: RastTokens.ink(context),
                    fontSize: Responsive.fontSize(context, 19),
                    fontWeight: FontWeight.w900,
                    height: 1.3,
                  ),
                ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.3, end: 0),

                SizedBox(height: Responsive.spacing(context, 10)),

                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (bookingNumber.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: bookingNumber));
                          HapticFeedback.selectionClick();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(L(_lang, 'تم نسخ رقم الحجز', 'Booking number copied'))),
                          );
                        },
                        child: RastPill(label: bookingNumber, icon: Icons.copy_rounded),
                      ),
                    RastPill(
                      label: paid
                          ? L(_lang, 'مدفوع', 'Paid')
                          : L(_lang, 'بانتظار الدفع', 'Awaiting payment'),
                      icon: paid ? Icons.verified_rounded : Icons.hourglass_top_rounded,
                      color: statusColor,
                    ),
                  ],
                ),

                if (!paid) ...[
                  SizedBox(height: Responsive.spacing(context, 18)),
                  RastButton(
                    label: _tr('payNow'),
                    icon: Icons.lock_rounded,
                    onPressed: _openPayment,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    L(_lang, 'أكمل الدفع لتأكيد موعدك لدى المختبر.', 'Complete payment to confirm your appointment.'),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: RastTokens.muted(context)),
                  ),
                ],
              ],
            ),
          ),

          SizedBox(height: Responsive.spacing(context, 14)),

          RastCard(
            padding: EdgeInsets.all(Responsive.spacing(context, 16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.receipt_long_rounded, size: 18, color: RastTokens.brand),
                    const SizedBox(width: 6),
                    Text(
                      _tr('invoiceDetails'),
                      style: TextStyle(
                        color: RastTokens.ink(context),
                        fontSize: Responsive.fontSize(context, 15),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: Responsive.spacing(context, 10)),

                _successInvoiceRow(
                  label: _tr('testPrice'),
                  value: _sar(servicePrice),
                ),

                if (isHomeService)
                  _successInvoiceRow(
                    label: _tr('homeServiceFee'),
                    value: '+ ${_sar(homeFee)}',
                  ),

                if (discountAmount > 0)
                  _successInvoiceRow(
                    label: _tr('platformDiscount'),
                    value: '- ${_sar(discountAmount)}',
                    valueColor: RastTokens.success,
                  ),

                if (vatAmount > 0)
                  _successInvoiceRow(
                    label: _tr('vat'),
                    value: '+ ${_sar(vatAmount)}',
                  ),

                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1, color: RastTokens.line(context)),
                ),

                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _tr('totalAmount'),
                        style: TextStyle(
                          color: RastTokens.ink(context),
                          fontSize: Responsive.fontSize(context, 14),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      _sar(totalAmount),
                      style: TextStyle(
                        color: RastTokens.brand,
                        fontSize: Responsive.fontSize(context, 18),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          SizedBox(height: Responsive.spacing(context, 18)),

          RastButton(
            label: _tr('viewBookingDetails'),
            icon: Icons.format_list_bulleted_rounded,
            secondary: true,
            onPressed: _goToBookingDetail,
          ),
        ],
      ),
    );
  }

  Widget _successInvoiceRow({
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: RastTokens.muted(context),
                fontSize: Responsive.fontSize(context, 13),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            maxLines: 1,
            style: TextStyle(
              color: valueColor ?? RastTokens.ink(context),
              fontSize: Responsive.fontSize(context, 13),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    final lang = context.watch<AppSettingsProvider>().language;

    final labels = [
      AppStrings.t('stepService', lang),
      AppStrings.t('stepDate', lang),
      AppStrings.t('stepTime', lang),
      AppStrings.t('stepConfirm', lang),
    ];
    final icons = [
      Icons.medical_services_rounded,
      Icons.calendar_month_rounded,
      Icons.schedule_rounded,
      Icons.receipt_long_rounded,
    ];

    // مؤشر تقدّم: دوائر مرقّمة يربطها خط يمتلئ بالتدرج كلما تقدّمت الخطوات
    return RastCard(
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
      child: Column(
        children: [
          Row(
            children: List.generate(7, (k) {
              if (k.isOdd) {
                final filled = (k ~/ 2) < _step;
                return Expanded(
                  child: Container(
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: RastTokens.fill(context),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: AnimatedFractionallySizedBox(
                      duration: const Duration(milliseconds: 420),
                      curve: Curves.easeOutCubic,
                      alignment: AlignmentDirectional.centerStart,
                      widthFactor: filled ? 1 : 0,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: RastTokens.brandGradient,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                );
              }
              final i = k ~/ 2;
              final active = i == _step;
              final done = i < _step;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutBack,
                width: active ? 42 : 34,
                height: active ? 42 : 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: active ? RastTokens.brandGradient : null,
                  color: active
                      ? null
                      : done
                      ? RastTokens.success
                      : RastTokens.fill(context),
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: RastTokens.brand.withValues(alpha: 0.32),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                    child: done
                        ? const Icon(Icons.check_rounded, key: ValueKey('done'), size: 18, color: Colors.white)
                        : Icon(
                            icons[i],
                            key: ValueKey('i$i$active'),
                            size: active ? 20 : 16,
                            color: active ? Colors.white : RastTokens.muted(context),
                          ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                L(lang, 'الخطوة ${_step + 1} من 4', 'Step ${_step + 1} of 4'),
                style: TextStyle(fontSize: 11.5, color: RastTokens.muted(context), fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 6),
              Container(width: 4, height: 4, decoration: BoxDecoration(shape: BoxShape.circle, color: RastTokens.line(context))),
              const SizedBox(width: 6),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  layoutBuilder: (current, previous) => Stack(
                    alignment: AlignmentDirectional.centerStart,
                    children: [...previous, ?current],
                  ),
                  child: Text(
                    labels[_step.clamp(0, 3)],
                    key: ValueKey(_step),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: RastTokens.ink(context)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _applyHomeAddress(Map<String, dynamic> a) {
    final line = a['address_line']?.toString().trim() ?? '';
    final label = a['label']?.toString().trim() ?? '';
    setState(() {
      _homeLat = numOf(a['latitude']);
      _homeLng = numOf(a['longitude']);
      _homeAddressKey = a['id']?.toString();
      _addressController.text = line.isNotEmpty ? line : label;
      final city = a['city']?.toString().trim() ?? '';
      if (city.isNotEmpty) _cityController.text = city;
      _districtController.text = a['district']?.toString().trim() ?? '';
    });
  }

  Widget _buildStepServiceType() {
    final inClinicTotal = _displayTotalForServiceType('in_clinic');

    final homeTotal = _displayTotalForServiceType('home_service');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionTitle(_tr('visitType'), Icons.medical_services_outlined),

        SizedBox(height: Responsive.spacing(context, 16)),

        if (!_isHomeOnly)
          _serviceTypeOption(
            value: 'in_clinic',
            label: _tr('inLab'),
            subtitle: _tr('inLabSubtitle'),
            icon: Icons.apartment_rounded,
            price: _sar(inClinicTotal),
          ),

        if (_homeAvailable && !_isClinicOnly) ...[
          SizedBox(height: Responsive.spacing(context, 12)),

          _serviceTypeOption(
            value: 'home_service',
            label: _tr('homeVisit'),
            subtitle: _tr('homeVisitSubtitle'),
            icon: Icons.home_rounded,
            price: _sar(homeTotal),
          ),
        ],

        if (_serviceType == 'home_service') ...[
          SizedBox(height: Responsive.spacing(context, 24)),

          _buildSectionTitle(_tr('visitAddress'), Icons.location_on_outlined),

          SizedBox(height: Responsive.spacing(context, 14)),

          // عناويني المحفوظة / موقعي الحالي / عنوان جديد من الخريطة — تملأ الحقول أدناه تلقائياً
          HomeAddressChooser(
            selectedKey: _homeAddressKey,
            onChanged: _applyHomeAddress,
          ),

          SizedBox(height: Responsive.spacing(context, 14)),

          _modernBookingField(
            controller: _addressController,
            label: _tr('address'),
            hint: _tr('addressHint'),
            icon: Icons.location_on_outlined,
          ),

          SizedBox(height: Responsive.spacing(context, 12)),

          _modernBookingField(
            controller: _cityController,
            label: _tr('city'),
            hint: _tr('cityHint'),
            icon: Icons.location_city_outlined,
          ),

          SizedBox(height: Responsive.spacing(context, 12)),

          _modernBookingField(
            controller: _districtController,
            label: _tr('districtOptional'),
            hint: null,
            icon: Icons.map_outlined,
          ),
        ],
      ],
    );
  }

  Widget _serviceTypeOption({
    required String value,
    required String label,
    required String subtitle,
    required IconData icon,
    required String price,
  }) {
    final selected = _serviceType == value;
    final r = BorderRadius.circular(20);

    // بطاقة اختيار كبيرة: توهج وحد بالهوية عند الاختيار، وعلامة صح تظهر بحركة
    return Pressable(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: selected ? RastTokens.brandSoft(context) : RastTokens.card(context),
          borderRadius: r,
          border: Border.all(
            color: selected ? RastTokens.brand : RastTokens.line(context),
            width: selected ? 1.8 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: RastTokens.brand.withValues(alpha: 0.16),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ]
              : RastTokens.shadow(context, strength: 0.5),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: r,
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _serviceType = value;
              });
            },
            child: Padding(
              padding: EdgeInsets.all(Responsive.spacing(context, 14)),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: selected ? RastTokens.brandGradient : null,
                      color: selected ? null : RastTokens.fill(context),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      icon,
                      size: 26,
                      color: selected ? Colors.white : RastTokens.muted(context),
                    ),
                  ),
                  SizedBox(width: Responsive.spacing(context, 12)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: RastTokens.ink(context),
                            fontSize: Responsive.fontSize(context, 15),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: RastTokens.muted(context),
                            fontSize: Responsive.fontSize(context, 11.5),
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          price,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: selected ? RastTokens.brand : RastTokens.ink(context),
                            fontSize: Responsive.fontSize(context, 14),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? RastTokens.brand : Colors.transparent,
                      border: Border.all(
                        color: selected ? RastTokens.brand : RastTokens.line(context),
                        width: 2,
                      ),
                    ),
                    child: AnimatedScale(
                      scale: selected ? 1 : 0,
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutBack,
                      child: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _modernBookingField({
    required TextEditingController controller,
    required String label,
    String? hint,
    required IconData icon,
  }) {
    final r = BorderRadius.circular(16);
    return TextField(
      controller: controller,
      style: TextStyle(color: RastTokens.ink(context), fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20, color: RastTokens.brand),
        filled: true,
        fillColor: RastTokens.fill(context),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: r, borderSide: BorderSide(color: RastTokens.line(context))),
        enabledBorder: OutlineInputBorder(borderRadius: r, borderSide: BorderSide(color: RastTokens.line(context))),
        focusedBorder: OutlineInputBorder(borderRadius: r, borderSide: const BorderSide(color: RastTokens.brand, width: 1.6)),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        RastIconBox(icon: icon, size: 36),
        SizedBox(width: Responsive.spacing(context, 10)),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: RastTokens.ink(context),
              fontSize: Responsive.fontSize(context, 17),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStepDate() {
    final today = DateTime.now();
    final days = List.generate(14, (i) => today.add(Duration(days: i)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionTitle(_tr('chooseDate'), Icons.calendar_month_outlined),

        SizedBox(height: Responsive.spacing(context, 16)),

        // شريط أيام أفقي: اليوم وغداً بأسماء واضحة، والمختار بتدرج الهوية
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: days.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final day = days[index];
              final selected =
                  _selectedDate != null && DateUtils.isSameDay(_selectedDate, day);
              final top = index == 0
                  ? L(_lang, 'اليوم', 'Today')
                  : index == 1
                  ? L(_lang, 'غداً', 'Tomorrow')
                  : _weekdayLabel(day);

              return Pressable(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _selectedDate = day;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                    width: 68,
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                    decoration: BoxDecoration(
                      gradient: selected ? RastTokens.brandGradient : null,
                      color: selected ? null : RastTokens.fill(context),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: selected
                            ? Colors.transparent
                            : index == 0
                            ? RastTokens.brand.withValues(alpha: 0.35)
                            : RastTokens.line(context),
                      ),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: RastTokens.brand.withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 5),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          top,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: selected ? Colors.white.withValues(alpha: 0.9) : RastTokens.muted(context),
                            fontSize: Responsive.fontSize(context, 10.5),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('d').format(day),
                          style: TextStyle(
                            color: selected ? Colors.white : RastTokens.ink(context),
                            fontSize: Responsive.fontSize(context, 22),
                            fontWeight: FontWeight.w900,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _monthLabel(day),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: selected ? Colors.white.withValues(alpha: 0.85) : RastTokens.muted(context),
                            fontSize: Responsive.fontSize(context, 9.5),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ).entrance(index, offset: 0.2);
            },
          ),
        ),

        SizedBox(height: Responsive.spacing(context, 14)),

        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                locale: Locale(_lang),
                initialDate: _selectedDate ?? today,
                firstDate: today,
                lastDate: today.add(const Duration(days: 60)),
              );

              if (d != null) {
                setState(() {
                  _selectedDate = d;
                });
              }
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: RastTokens.fill(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: RastTokens.line(context)),
              ),
              child: Row(
                children: [
                  const RastIconBox(icon: Icons.event_available_rounded, size: 38),
                  SizedBox(width: Responsive.spacing(context, 12)),
                  Expanded(
                    child: Text(
                      _selectedDate != null
                          ? DateFormat('EEEE d MMMM yyyy', _isArabic ? 'ar' : 'en').format(_selectedDate!)
                          : _tr('chooseFromCalendar'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _selectedDate != null ? RastTokens.ink(context) : RastTokens.muted(context),
                        fontSize: Responsive.fontSize(context, 13),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.edit_calendar_rounded, size: 18, color: RastTokens.brand),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _weekdayLabel(DateTime day) {
    return DateFormat('EEEE', _isArabic ? 'ar' : 'en').format(day);
  }

  String _monthLabel(DateTime day) {
    return DateFormat('MMM', _isArabic ? 'ar' : 'en').format(day);
  }

  String _timeSlotPrimaryLabel(Map<String, dynamic> slot) {
    final ar = slot['period_label_ar']?.toString().trim();

    if (ar != null && ar.isNotEmpty) {
      return ar;
    }

    return DateFormatter.formatBookingTime(slot['start_time']?.toString());
  }

  Widget _buildStepTime() {
    Widget chips() {
      return LayoutBuilder(
        builder: (context, c) {
          final w = (c.maxWidth - 10) / 2;
          var i = 0;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _timeSlots.map<Widget>((s) {
              final slot = s is Map ? s as Map<String, dynamic> : <String, dynamic>{};
              final selected = _selectedSlot?['id'] == slot['id'];
              final primary = _timeSlotPrimaryLabel(slot);
              final rawTime = DateFormatter.formatBookingTime(slot['start_time']?.toString());
              final secondary = rawTime.isNotEmpty && rawTime != primary ? rawTime : null;
              final index = i++;

              return SizedBox(
                width: w,
                child: Pressable(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _selectedSlot = slot;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOutCubic,
                      constraints: const BoxConstraints(minHeight: 58),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: selected ? RastTokens.brandGradient : null,
                        color: selected ? null : RastTokens.fill(context),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: selected ? Colors.transparent : RastTokens.line(context)),
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                  color: RastTokens.brand.withValues(alpha: 0.28),
                                  blurRadius: 12,
                                  offset: const Offset(0, 5),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            selected ? Icons.check_circle_rounded : Icons.access_time_rounded,
                            size: 18,
                            color: selected ? Colors.white : RastTokens.brand,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  primary,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: selected ? Colors.white : RastTokens.ink(context),
                                    fontSize: Responsive.fontSize(context, 12.5),
                                    fontWeight: FontWeight.w800,
                                    height: 1.25,
                                  ),
                                ),
                                if (secondary != null)
                                  Text(
                                    secondary,
                                    maxLines: 1,
                                    style: TextStyle(
                                      color: selected ? Colors.white.withValues(alpha: 0.85) : RastTokens.muted(context),
                                      fontSize: Responsive.fontSize(context, 10.5),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ).entrance(index, offset: 0.15);
            }).toList(),
          );
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionTitle(_tr('chooseTime'), Icons.schedule_rounded),
        if (_selectedDate != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 46),
            child: Text(
              DateFormat('EEEE d MMMM', _isArabic ? 'ar' : 'en').format(_selectedDate!),
              style: TextStyle(fontSize: 12, color: RastTokens.muted(context), fontWeight: FontWeight.w600),
            ),
          ),
        ],
        SizedBox(height: Responsive.spacing(context, 14)),
        if (_timeSlotsError != null)
          RastEmptyState(
            icon: Icons.wifi_off_rounded,
            color: RastTokens.danger,
            title: _timeSlotsError!,
            actionLabel: _tr('retry'),
            onAction: _loadingSlots ? null : _loadTimeSlots,
          )
        else if (_loadingSlots)
          LayoutBuilder(
            builder: (context, c) => Wrap(
              spacing: 10,
              runSpacing: 10,
              children: List.generate(
                6,
                (_) => RastSkeleton(width: (c.maxWidth - 10) / 2, height: 58, radius: 16),
              ),
            ),
          )
        else if (_timeSlots.isEmpty)
          RastEmptyState(
            icon: Icons.event_busy_rounded,
            title: _tr('noTimeSlots'),
            message: L(
              _lang,
              'جرّب يوماً آخر من الخطوة السابقة.',
              'Try another day from the previous step.',
            ),
            actionLabel: L(_lang, 'اختر يوماً آخر', 'Pick another day'),
            onAction: _backStep,
          )
        else
          chips(),
      ],
    );
  }

  Widget _buildStepConfirm() {
    final settings = context.watch<AppSettingsProvider>();

    final isArabic = settings.isArabic;

    final labDisplay = LocaleUtils.localizedBusinessName(
      _lab,
      context.watch<AppSettingsProvider>().isArabic,
    );
    final labNameDisplay = labDisplay.isNotEmpty
        ? labDisplay
        : (widget.labName ?? '');

    Widget detail(IconData icon, String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          RastIconBox(icon: icon, size: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: RastTokens.muted(context))),
                Text(
                  value.isEmpty ? '—' : value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: RastTokens.ink(context)),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionTitle(_tr('bookingSummary'), Icons.receipt_long_outlined),
        SizedBox(height: Responsive.spacing(context, 12)),

        // تفاصيل الموعد
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: RastTokens.fill(context),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              detail(Icons.biotech_rounded, _tr('test'), _serviceNameDisplay()),
              detail(Icons.apartment_rounded, _tr('lab'), labNameDisplay),
              if (_serviceType == 'in_clinic' && _nearestBranch != null)
                detail(Icons.location_on_rounded, _tr('branch'), _nearestBranch!.displayLine(isArabic)),
              detail(
                _serviceType == 'home_service' ? Icons.home_rounded : Icons.storefront_rounded,
                _tr('serviceType'),
                _serviceType == 'home_service' ? _tr('homeServiceLabel') : _tr('inLab'),
              ),
              detail(
                Icons.event_rounded,
                '${_tr('date')} · ${_tr('time')}',
                [
                  if (_selectedDate != null)
                    DateFormat('EEEE d MMMM', isArabic ? 'ar' : 'en').format(_selectedDate!),
                  if (_selectedSlot != null) _timeSlotPrimaryLabel(_selectedSlot!),
                ].join(' · '),
              ),
              if (_serviceType == 'home_service')
                detail(Icons.signpost_rounded, _tr('address'), _addressController.text),
            ],
          ),
        ),

        SizedBox(height: Responsive.spacing(context, 16)),
        _buildBookingFor(),

        Container(
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(
            color: RastTokens.fill(context),
            borderRadius: BorderRadius.circular(14),
          ),
          child: CheckboxListTile(
            value: _isNonSaudi,
            onChanged: (v) {
              setState(() => _isNonSaudi = v ?? false);
              _loadConfirmPreview();
            },
            title: Text(
              _tr('nonSaudiVat'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: Responsive.fontSize(context, 13), color: RastTokens.ink(context)),
            ),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: const EdgeInsetsDirectional.only(start: 4, end: 10),
            dense: true,
            activeColor: RastTokens.brand,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),

        SizedBox(height: Responsive.spacing(context, 16)),

        // الفاتورة: صفوف واضحة وإجمالي بارز
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: RastTokens.card(context),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: RastTokens.brand.withValues(alpha: 0.18)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.payments_rounded, size: 18, color: RastTokens.brand),
                  const SizedBox(width: 6),
                  Text(
                    _tr('amountDetails'),
                    style: TextStyle(
                      fontSize: Responsive.fontSize(context, 14),
                      fontWeight: FontWeight.w800,
                      color: RastTokens.ink(context),
                    ),
                  ),
                  const Spacer(),
                  if (_loadingPreview)
                    const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                ],
              ),
              const SizedBox(height: 8),
              _buildConfirmAmounts(),
            ],
          ),
        ),
      ],
    );
  }

  /// لمن التحليل؟ لي / لشخص آخر + اسمه
  Widget _buildBookingFor() {
    final myName = AuthService.currentUser?.name.trim() ?? '';
    Widget option(bool other, String label, IconData icon) {
      final selected = _forOther == other;
      return Expanded(
        child: GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _forOther = other);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(
              color: selected ? RastTokens.brandSoft(context) : RastTokens.card(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? RastTokens.brand : RastTokens.line(context),
                width: selected ? 1.6 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: selected ? RastTokens.brand : RastTokens.muted(context)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      color: selected ? RastTokens.brand : RastTokens.ink(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _tr('bookingForTitle'),
          style: TextStyle(
            fontSize: Responsive.fontSize(context, 14),
            fontWeight: FontWeight.w800,
            color: RastTokens.ink(context),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            option(false, myName.isNotEmpty ? '${_tr('bookingForShort')} $myName' : _tr('bookingForMe'), Icons.person_rounded),
            const SizedBox(width: 8),
            option(true, _tr('bookingForOther'), Icons.group_rounded),
          ],
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          child: _forOther
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    _modernBookingField(
                      controller: _patientNameController,
                      label: _tr('patientNameLabel'),
                      hint: _tr('patientNameHint'),
                      icon: Icons.badge_outlined,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _tr('patientNameCartHint'),
                      style: TextStyle(fontSize: Responsive.fontSize(context, 11), color: RastTokens.muted(context)),
                    ),
                  ],
                )
              : const SizedBox(width: double.infinity),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _confirmRow(String label, String value, {TextStyle? valueStyle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.start,
              style: TextStyle(color: RastTokens.muted(context), fontSize: 13),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: valueStyle ??
                  TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: RastTokens.ink(context)),
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

      final effectiveHomeFee = homeFee > 0
          ? homeFee
          : (_serviceType == 'home_service' ? _homeServiceFeeRaw : 0.0);

      final disc = _previewPlatformDiscountAndRate(row, servicePrice);

      final discount = disc.discount;
      final discountRate = disc.ratePercent;

      final vatAmount = _parseNum(row['vat_amount']);

      final total = (servicePrice + effectiveHomeFee - discount + vatAmount)
          .roundToDouble();

      var vatRate = _parseNum(row['vat_rate']);

      if (vatRate <= 0 && _isNonSaudi) {
        vatRate = _vatRate;
      }

      if (vatRate > 0 && vatRate <= 1) {
        vatRate *= 100;
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _confirmRow(_tr('testPrice'), _sar(servicePrice)),

          if (_serviceType == 'home_service')
            _confirmRow(_tr('homeServiceFee'), '+ ${_sar(effectiveHomeFee)}'),

          _confirmRow(
            '${_tr('platformDiscount')} '
                '${discountRate.toStringAsFixed(0)}%',
            '- ${_sar(discount)}',
            valueStyle: TextStyle(
              color: AppTheme.success,
              fontWeight: FontWeight.w600,
            ),
          ),

          if (_isNonSaudi && vatAmount > 0)
            _confirmRow(
              '${_tr('vat')} '
                  '${vatRate.toStringAsFixed(0)}%',
              '+ ${_sar(vatAmount)}',
              valueStyle: const TextStyle(
                color: RastTokens.danger,
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
            _tr('totalAmount'),
            _sar(total),
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
        _confirmRow(_tr('testPrice'), _sar(_price)),

        if (_serviceType == 'home_service')
          _confirmRow(_tr('homeServiceFee'), '+ ${_sar(_homeServiceFee)}'),

        _confirmRow(
          '${_tr('platformDiscount')} '
              '${_platformDiscountRate.toStringAsFixed(0)}%',
          '- ${_sar(_discountAmount)}',
          valueStyle: TextStyle(
            color: AppTheme.success,
            fontWeight: FontWeight.w600,
          ),
        ),

        if (_isNonSaudi)
          _confirmRow(
            '${_tr('vat')} '
                '${_vatRate.toStringAsFixed(0)}%',
            '+ ${_sar(_vatAmount)}',
            valueStyle: const TextStyle(color: RastTokens.danger, fontWeight: FontWeight.w700),
          ),

        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Divider(
            height: 1,
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
          ),
        ),

        _confirmRow(
          _tr('totalAmount'),
          _sar(_totalAmount),
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

    Widget backButton() {
      return SizedBox(
        width: 52,
        height: 52,
        child: Material(
          color: RastTokens.fill(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: RastTokens.line(context)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              HapticFeedback.selectionClick();
              _backStep();
            },
            child: Icon(
              Directionality.of(context) == ui.TextDirection.rtl
                  ? Icons.arrow_forward_rounded
                  : Icons.arrow_back_rounded,
              size: 20,
              color: RastTokens.brand,
            ),
          ),
        ),
      );
    }

    if (!isConfirm) {
      // زر «التالي» يتفعّل بصرياً فقط عند اكتمال اختيار الخطوة الحالية
      final ready = switch (_step) {
        1 => _selectedDate != null,
        2 => _selectedSlot != null,
        _ => true,
      };
      return Row(
        children: [
          if (_step > 0) ...[backButton(), const SizedBox(width: 10)],
          Expanded(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 220),
              opacity: ready ? 1 : 0.6,
              child: RastButton(
                label: _tr('next'),
                icon: Directionality.of(context) == ui.TextDirection.rtl
                    ? Icons.arrow_back_rounded
                    : Icons.arrow_forward_rounded,
                onPressed: _nextStep,
              ),
            ),
          ),
        ],
      );
    }

    final busy = _creating || _addingToCart;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // الإجراء الأساسي: حجز ودفع مباشر
        RastButton(
          label: _tr('instantBookPay'),
          icon: Icons.flash_on_rounded,
          loading: _creating,
          onPressed: busy ? null : _createBooking,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            backButton(),
            const SizedBox(width: 10),
            // يبقى المفتاح على زر الإضافة: منه تنطلق حركة «الطيران إلى السلة»
            Expanded(
              child: SizedBox(
                key: _addToCartButtonKey,
                height: 52,
                child: RastButton(
                  label: _tr('addToCart'),
                  icon: Icons.add_shopping_cart_rounded,
                  secondary: true,
                  loading: _addingToCart,
                  onPressed: busy ? null : _addToCart,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
