import 'dart:ui' as ui show TextDirection;
import 'package:flutter/material.dart';
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
  DateTime? _selectedDate;
  Map<String, dynamic>? _selectedSlot;
  List<dynamic> _timeSlots = [];
  bool _loadingSlots = false;
  bool _creating = false;
  bool _addingToCart = false;
  String? _error;
  String? _timeSlotsError;
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
    final lat = _userLat ?? savedLoc?.lat;
    final lng = _userLng ?? savedLoc?.lng;

    if (_serviceType == 'in_clinic' &&
        _bookingBranchId == null &&
        (lat == null || lng == null)) {
      throw ApiException(_tr('locationRequiredForBranch'));
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

      final messenger = ScaffoldMessenger.of(context);

      messenger.hideCurrentSnackBar();

      messenger.showSnackBar(
        SnackBar(
          content: Text(_tr('addedToCart')),
          action: SnackBarAction(
            label: _tr('viewCart'),
            onPressed: () {
              messenger.hideCurrentSnackBar();

              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CartScreen()),
              );
            },
          ),
        ),
      );

      Future.delayed(const Duration(seconds: 3), () {
        messenger.hideCurrentSnackBar();
      });

      Navigator.pop(context);
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
        await AnalyticsService.logCheckoutStarted(itemCount: 1);
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
            await AnalyticsService.logPurchase(
              transactionId: bookingId.toString(),
              itemCount: 1,
            );
          }
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
        child: Container(
          decoration: const BoxDecoration(color: Color(0xFF1A0665)),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: RastTopBar(
              title: AppStrings.t('bookFlowTitle', lang),
              helpTourId: OnboardingTourIds.bookFlow,
              helpTourSteps: OnboardingCatalog.bookFlowTour,
              backgroundColor: const Color(0xFF1A0665),
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
                          AppStrings.t('signInToBook', lang),
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
                          label: Text(AppStrings.t('signIn', lang)),
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
      textDirection: settings.textDirection,
      child: Container(
        decoration: const BoxDecoration(color: Color(0xFF1A0665)),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: RastTopBar(
            title: _createdBooking != null
                ? AppStrings.t('bookingCompletedTitle', lang)
                : AppStrings.t('bookFlowTitle', lang),
            helpTourId: OnboardingTourIds.bookFlow,
            helpTourSteps: OnboardingCatalog.bookFlowTour,
            iconColor: Colors.white,
            backgroundColor: const Color(0xFF1A0665),
          ),
          body: _error != null && _step < 4
              ? _buildErrorBody()
              : _createdBooking != null
              ? _buildSuccessBody()
              : SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    Responsive.spacing(context, 20),
                    Responsive.spacing(context, 16),
                    Responsive.spacing(context, 20),
                    Responsive.spacing(context, 28),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildStepIndicator(),

                      SizedBox(height: Responsive.spacing(context, 24)),

                      _buildStepCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_step == 0) _buildStepServiceType(),
                            if (_step == 1) _buildStepDate(),
                            if (_step == 2) _buildStepTime(),
                            if (_step == 3) _buildStepConfirm(),

                            if (_step < 4 && _createdBooking == null) ...[
                              SizedBox(height: Responsive.spacing(context, 28)),
                              _buildNextButton(),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildStepCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.spacing(context, 18),
        vertical: Responsive.spacing(context, 24),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
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
            const Icon(
              Icons.error_outline_rounded,
              size: 56,
              color: Colors.white,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: Responsive.fontSize(context, 14),
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
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

    final bookingNumber = _createdBooking?['booking_number']?.toString() ?? '';

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        Responsive.spacing(context, 18),
        Responsive.spacing(context, 18),
        Responsive.spacing(context, 18),
        Responsive.spacing(context, 28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // SUCCESS CARD
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.spacing(context, 18),
              vertical: Responsive.spacing(context, 24),
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFF0EEF5)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 66,
                  height: 66,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF7B39F5), Color(0xFF5A1BC8)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6C2BE3).withValues(alpha: 0.28),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.4),
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 19,
                      color: Colors.white,
                    ),
                  ),
                ),

                SizedBox(height: Responsive.spacing(context, 18)),

                Text(
                  _tr('bookingCreatedSuccessfully'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: const Color(0xFF211D46),
                    fontSize: Responsive.fontSize(context, 19),
                    fontWeight: FontWeight.w900,
                    height: 1.25,
                  ),
                ),

                SizedBox(height: Responsive.spacing(context, 6)),

                if (bookingNumber.isNotEmpty)
                  Text(
                    bookingNumber,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: const Color(0xFFC9A7FF),
                      fontSize: Responsive.fontSize(context, 13),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),

                if (!paid) ...[
                  SizedBox(height: Responsive.spacing(context, 18)),

                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 150),
                    child: GradientFilledButtonIcon(
                      onPressed: _openPayment,
                      icon: const Icon(Icons.credit_card_rounded, size: 18),
                      label: Text(
                        _tr('payNow'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(170, 54),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 12,
                        ),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          SizedBox(height: Responsive.spacing(context, 22)),

          Container(
            width: double.infinity,
            padding: EdgeInsets.all(Responsive.spacing(context, 18)),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F7FB),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _tr('invoiceDetails'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.start,
                  style: TextStyle(
                    color: const Color(0xFF17142C),
                    fontSize: Responsive.fontSize(context, 15),
                    fontWeight: FontWeight.w900,
                  ),
                ),

                SizedBox(height: Responsive.spacing(context, 16)),

                _successInvoiceRow(
                  label: _tr('testPrice'),
                  value: _sar(servicePrice),
                ),

                if (isHomeService)
                  _successInvoiceRow(
                    label: _tr('homeServiceFee'),
                    value: '+ ${_sar(homeFee)}',
                  ),

                _successInvoiceRow(
                  label: _tr('platformDiscount'),
                  value: '- ${_sar(discountAmount)}',
                  valueColor: const Color(0xFF009B69),
                ),

                _successInvoiceRow(
                  label: _tr('vat'),
                  value: '+ ${_sar(vatAmount)}',
                  valueColor: const Color(0xFF28234D),
                ),

                Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: Responsive.spacing(context, 7),
                  ),
                  child: const Divider(
                    height: 1,
                    thickness: 1,
                    color: Color(0xFFDDE3ED),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            _tr('totalAmount'),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.start,
                            style: TextStyle(
                              color: const Color(0xFF17142C),
                              fontSize: Responsive.fontSize(context, 14),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      Flexible(
                        child: Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: Text(
                            _sar(totalAmount),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              color: const Color(0xFF6D28D9),
                              fontSize: Responsive.fontSize(context, 17),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: Responsive.spacing(context, 28)),

          // BOOKING DETAILS BUTTON
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 220, maxWidth: 290),
              child: OutlinedButton.icon(
                onPressed: _goToBookingDetail,
                icon: const Icon(Icons.format_list_bulleted_rounded, size: 19),
                label: Text(
                  _tr('viewBookingDetails'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 13),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF762FE9),
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  side: const BorderSide(color: Color(0xFFDCC8FF), width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
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
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.start,
                style: TextStyle(
                  color: const Color(0xFF3E4050),
                  fontSize: Responsive.fontSize(context, 12),
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          Flexible(
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: TextStyle(
                  color: valueColor ?? const Color(0xFF17142C),
                  fontSize: Responsive.fontSize(context, 12),
                  fontWeight: FontWeight.w900,
                  height: 1.35,
                ),
              ),
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

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.spacing(context, 14),
        vertical: Responsive.spacing(context, 16),
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
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
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done
                        ? const Color(0xFF444DF8)
                        : active
                        ? Color(0xFF444DF8)
                        : Colors.white,
                    boxShadow: active
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.10),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: done
                        ? const Icon(
                            Icons.check_rounded,
                            size: 18,
                            color: Colors.white,
                          )
                        : Text(
                            '${i + 1}',
                            style: TextStyle(
                              color: active ? Colors.white : Colors.black,
                              fontSize: Responsive.fontSize(context, 12),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 7),

                Text(
                  labels[i],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: active
                        ? const Color(0xFF8FA0FF)
                        : done
                        ? const Color(0xFFB8C0FF)
                        : Colors.white.withValues(alpha: 0.95),
                    fontSize: Responsive.fontSize(context, 10),
                    fontWeight: FontWeight.bold,
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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _serviceType = value;
          });
        },
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: double.infinity,
          padding: EdgeInsets.all(Responsive.spacing(context, 14)),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFF3F1FF) : const Color(0xFFF8F8FB),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? const Color(0xFF6254E7)
                  : const Color(0xFFE4E3EA),
              width: selected ? 1.6 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: const Color(0xFF6254E7).withValues(alpha: 0.14),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ICON
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF6254E7)
                      : const Color(0xFFEDECF2),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  size: 24,
                  color: selected ? Colors.white : const Color(0xFF686577),
                ),
              ),

              SizedBox(width: Responsive.spacing(context, 12)),

              // TEXT
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
                        color: const Color(0xFF242230),
                        fontSize: Responsive.fontSize(context, 14),
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: const Color(0xFF777486),
                        fontSize: Responsive.fontSize(context, 11),
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(width: Responsive.spacing(context, 10)),

              // PRICE + SELECTED INDICATOR
              SizedBox(
                width: 88,
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        price,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          color: selected
                              ? const Color(0xFF6254E7)
                              : const Color(0xFF242230),
                          fontSize: Responsive.fontSize(context, 13),
                          fontWeight: FontWeight.w900,
                        ),
                      ),

                      const SizedBox(height: 8),

                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: selected
                              ? const Color(0xFF6254E7)
                              : Colors.transparent,
                          border: Border.all(
                            color: selected
                                ? const Color(0xFF6254E7)
                                : const Color(0xFFB8B6C2),
                            width: 1.5,
                          ),
                        ),
                        child: selected
                            ? const Icon(
                                Icons.check_rounded,
                                size: 15,
                                color: Colors.white,
                              )
                            : null,
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

  Widget _modernBookingField({
    required TextEditingController controller,
    required String label,
    String? hint,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,

        prefixIcon: Icon(icon, size: 20, color: const Color(0xFF6254E7)),

        filled: true,
        fillColor: const Color(0xFFF8F8FB),

        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),

        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE4E3EA)),
        ),

        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE4E3EA)),
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF6254E7), width: 1.5),
        ),
      ),
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

  Widget _buildStepDate() {
    final today = DateTime.now();
    final days = List.generate(10, (i) => today.add(Duration(days: i)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionTitle(_tr('chooseDate'), Icons.calendar_month_outlined),

        SizedBox(height: Responsive.spacing(context, 18)),

        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.spacing(context, 12),
            vertical: Responsive.spacing(context, 14),
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F8FB),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE5E3EA)),
          ),
          child: SizedBox(
            height: 106,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: days.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final day = days[index];

                final selected =
                    _selectedDate != null &&
                    DateUtils.isSameDay(_selectedDate, day);

                final isToday = DateUtils.isSameDay(today, day);

                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedDate = day;
                    });
                  },
                  borderRadius: BorderRadius.circular(18),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 72,
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 6,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFF6254E7) : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFF6254E7)
                            : isToday
                            ? const Color(0xFF6254E7).withValues(alpha: 0.40)
                            : const Color(0xFFE5E3EA),
                        width: selected ? 1.5 : 1,
                      ),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: const Color(
                                  0xFF6254E7,
                                ).withValues(alpha: 0.22),
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
                          _weekdayLabel(day),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: selected
                                ? Colors.white.withValues(alpha: 0.85)
                                : const Color(0xFF777486),
                            fontSize: Responsive.fontSize(context, 10),
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        const SizedBox(height: 6),

                        Text(
                          DateFormat('d').format(day),
                          maxLines: 1,
                          style: TextStyle(
                            color: selected
                                ? Colors.white
                                : const Color(0xFF262333),
                            fontSize: Responsive.fontSize(context, 22),
                            fontWeight: FontWeight.w900,
                          ),
                        ),

                        const SizedBox(height: 3),

                        Text(
                          _monthLabel(day),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: selected
                                ? Colors.white.withValues(alpha: 0.80)
                                : const Color(0xFF8A8795),
                            fontSize: Responsive.fontSize(context, 9),
                            fontWeight: FontWeight.w500,
                          ),
                        ),

                        if (isToday) ...[
                          const SizedBox(height: 5),

                          Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: selected
                                  ? Colors.white
                                  : const Color(0xFF6254E7),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        SizedBox(height: Responsive.spacing(context, 16)),

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
            borderRadius: BorderRadius.circular(18),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F8FB),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE3E1E9)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6254E7).withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.event_available_rounded,
                      size: 20,
                      color: Color(0xFF6254E7),
                    ),
                  ),

                  SizedBox(width: Responsive.spacing(context, 12)),

                  Expanded(
                    child: Text(
                      _selectedDate != null
                          ? DateFormat('yyyy-MM-dd').format(_selectedDate!)
                          : _tr('chooseFromCalendar'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _selectedDate != null
                            ? const Color(0xFF262333)
                            : const Color(0xFF777486),
                        fontSize: Responsive.fontSize(context, 13),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: Color(0xFF8B8797),
                  ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(_tr('chooseTime'), Icons.schedule_rounded),
        SizedBox(height: Responsive.spacing(context, 12)),
        if (_timeSlotsError != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.cardDecorationFor(context),
            child: Column(
              children: [
                Icon(Icons.error_outline, color: AppTheme.error, size: 40),
                const SizedBox(height: 10),
                Text(
                  _timeSlotsError!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _loadingSlots ? null : _loadTimeSlots,
                  icon: const Icon(Icons.refresh),
                  label: Text(_tr('retry')),
                ),
              ],
            ),
          ),
        ] else if (_loadingSlots)
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
            child: Text(_tr('noTimeSlots'), textAlign: TextAlign.center),
          )
        else
          Column(
            children: _timeSlots.map<Widget>((s) {
              final slot = s is Map
                  ? s as Map<String, dynamic>
                  : <String, dynamic>{};

              final slotId = slot['id'];
              final selected = _selectedSlot?['id'] == slotId;

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedSlot = slot;
                      });
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: double.infinity,
                      constraints: const BoxConstraints(minHeight: 60),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFF6254E7)
                            : const Color(0xFFF8F8FB),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: selected
                              ? const Color(0xFF6254E7)
                              : const Color(0xFFE4E2E9),
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: selected
                                  ? Colors.white.withValues(alpha: 0.16)
                                  : const Color(
                                      0xFF6254E7,
                                    ).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Icon(
                              Icons.access_time_rounded,
                              size: 18,
                              color: selected
                                  ? Colors.white
                                  : const Color(0xFF6254E7),
                            ),
                          ),

                          const SizedBox(width: 12),

                          Expanded(
                            child: Text(
                              _timeSlotPrimaryLabel(slot),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.start,
                              style: TextStyle(
                                color: selected
                                    ? Colors.white
                                    : RastUi.primaryText(context),
                                fontSize: Responsive.fontSize(context, 13),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),

                          const SizedBox(width: 10),

                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 25,
                            height: 25,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: selected
                                  ? Colors.white
                                  : Colors.transparent,
                              border: Border.all(
                                color: selected
                                    ? Colors.white
                                    : const Color(0xFFB8B6C2),
                                width: 1.5,
                              ),
                            ),
                            child: selected
                                ? const Icon(
                                    Icons.check_rounded,
                                    size: 15,
                                    color: Color(0xFF6254E7),
                                  )
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(_tr('bookingSummary'), Icons.receipt_long_outlined),
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
              _confirmRow(_tr('test'), _serviceNameDisplay()),
              _confirmRow(_tr('lab'), labNameDisplay),
              if (_serviceType == 'in_clinic' && _nearestBranch != null)
                _confirmRow(
                  _tr('branch'),
                  _nearestBranch!.displayLine(isArabic),
                ),
              _confirmRow(
                _tr('serviceType'),
                _serviceType == 'home_service'
                    ? _tr('homeServiceLabel')
                    : _tr('inLab'),
              ),
              _confirmRow(
                _tr('date'),
                _selectedDate != null
                    ? DateFormat('yyyy-MM-dd', _lang).format(_selectedDate!)
                    : '',
              ),
              _confirmRow(
                _tr('time'),
                _selectedSlot != null
                    ? _timeSlotPrimaryLabel(_selectedSlot!)
                    : '',
              ),
              if (_serviceType == 'home_service')
                _confirmRow(_tr('address'), _addressController.text),
              SizedBox(height: Responsive.spacing(context, 12)),
              CheckboxListTile(
                value: _isNonSaudi,
                onChanged: (v) {
                  setState(() => _isNonSaudi = v ?? false);
                  _loadConfirmPreview();
                },
                title: Text(
                  _tr('nonSaudiVat'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: Responsive.fontSize(context, 13)),
                ),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
                activeColor: AppTheme.primary,
              ),
              const Divider(height: 24),
              Text(
                _tr('amountDetails'),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.start,
                style: const TextStyle(color: AppTheme.onSurfaceVariant),
              ),
            ),
          ),

          const SizedBox(width: 12),

          Flexible(
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Text(
                value,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style:
                    valueStyle ?? const TextStyle(fontWeight: FontWeight.w600),
              ),
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
                color: Color.fromARGB(255, 255, 0, 0),
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
            valueStyle: const TextStyle(color: Color.fromARGB(255, 255, 0, 0)),
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
        width: 54,
        height: 54,
        child: OutlinedButton(
          onPressed: _backStep,
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF6254E7),
            backgroundColor: const Color(0xFFF8F8FB),
            side: const BorderSide(color: Color(0xFFE3E1E9)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            padding: EdgeInsets.zero,
          ),
          child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
        ),
      );
    }

    if (!isConfirm) {
      return Row(
        children: [
          if (_step > 0) ...[backButton(), const SizedBox(width: 12)],

          Expanded(
            child: SizedBox(
              height: 54,
              child: GradientFilledButton(
                onPressed: _nextStep,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  _tr('next'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 14),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
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
            backButton(),

            const SizedBox(width: 12),

            Expanded(
              child: SizedBox(
                height: 54,
                child: GradientFilledButton(
                  onPressed: busy ? null : _addToCart,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _addingToCart
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.shopping_cart_outlined,
                              size: 19,
                              color: Colors.white,
                            ),

                            const SizedBox(width: 8),

                            Flexible(
                              child: Text(
                                _tr('addToCart'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: Responsive.fontSize(context, 13),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // SECONDARY ACTION
        SizedBox(
          height: 52,
          child: OutlinedButton(
            onPressed: busy ? null : _createBooking,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF6254E7),
              backgroundColor: const Color(0xFFF8F8FB),
              side: const BorderSide(color: Color(0xFFDCD9E7), width: 1.2),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: _creating
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.flash_on_rounded, size: 19),

                      const SizedBox(width: 8),

                      Flexible(
                        child: Text(
                          _tr('instantBookPay'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: Responsive.fontSize(context, 13),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
