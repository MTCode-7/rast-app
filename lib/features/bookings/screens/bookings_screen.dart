import 'package:flutter/material.dart';
import 'package:rast/core/api/api_services.dart';
import 'package:rast/core/constants/app_strings.dart';
import 'package:rast/core/providers/app_settings_provider.dart';
import 'package:provider/provider.dart';
import 'package:rast/core/utils/date_formatter.dart';
import 'package:rast/core/api/api_client.dart';
import 'package:rast/core/utils/responsive.dart';
import 'package:rast/core/onboarding/onboarding_catalog.dart';
import 'package:rast/core/onboarding/onboarding_host.dart';
import 'package:rast/core/onboarding/onboarding_step.dart';
import 'package:rast/core/onboarding/onboarding_tour_ids.dart';
import 'package:rast/core/widgets/rast_ui.dart';
import 'package:rast/features/auth/services/auth_service.dart';
import 'package:rast/features/bookings/screens/booking_detail_screen.dart';
import 'package:rast/app/main_tab_index_scope.dart';
import 'package:rast/app/main_shell.dart';
import 'package:rast/features/auth/screens/login_screen.dart';
import 'package:rast/core/services/app_events.dart';
import 'package:rast/core/widgets/rast_motion.dart';
import 'package:rast/core/widgets/rast_kit.dart';
import 'package:rast/features/analyses/screens/analyses_screen.dart';
import 'package:rast/features/bookings/list_widgets/booking_card.dart';

class BookingsScreen extends StatefulWidget {
  final bool showBackButton;

  const BookingsScreen({
    super.key,
    this.showBackButton = false,
  });

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen>
    with SingleTickerProviderStateMixin, OnboardingTourHost, WidgetsBindingObserver {
  late TabController _tabController;
  bool _bookingsTourScheduled = false;
  List<dynamic> _upcoming = [];
  List<dynamic> _past = [];
  bool _isLoading = true;
  bool _refreshing = false;
  String? _error;
  DateTime? _lastLoadedAt;
  bool? _wasActiveTab;
  final Set<String> _animatedIds = {};

  @override
  String? get onboardingTourId => OnboardingTourIds.bookings;

  @override
  List<OnboardingStep> buildOnboardingSteps() =>
      OnboardingCatalog.bookingsTour;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addObserver(this);
    AppEvents.bookingsChanged.addListener(_onBookingsChanged);
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      final active = MainTabIndexScope.of(context).currentIndex ==
          MainScaffold.bookingsTabIndex;
      if (active) {
        _maybeScheduleBookingsTour();
        // عند الرجوع لتبويب الحجوزات نحدّثها بصمت (التبويبات لا يُعاد بناؤها)
        if (_wasActiveTab == false) _refreshIfStale(const Duration(seconds: 5));
      }
      _wasActiveTab = active;
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // العودة للتطبيق من الخلفية (مثلاً بعد الدفع في المتصفح أو وصول إشعار)
    if (state == AppLifecycleState.resumed) {
      _refreshIfStale(const Duration(seconds: 20));
    }
  }

  void _onBookingsChanged() => _loadData(showLoading: false);

  void _refreshIfStale(Duration maxAge) {
    final last = _lastLoadedAt;
    if (_refreshing || _isLoading) return;
    if (last == null || DateTime.now().difference(last) > maxAge) {
      _loadData(showLoading: false);
    }
  }

  void _maybeScheduleBookingsTour() {
    if (_bookingsTourScheduled) return;
    _bookingsTourScheduled = true;
    scheduleOnboardingTour(delay: const Duration(milliseconds: 600));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AppEvents.bookingsChanged.removeListener(_onBookingsChanged);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData({
    bool showLoading = true,
  }) async {
    if (!AuthService.isLoggedIn) {
      if (mounted) {
        setState(() {
          // بعد تسجيل الخروج لا تبقى حجوزات الحساب السابق
          _upcoming = [];
          _past = [];
          _isLoading = false;
          _refreshing = false;
        });
      }
      return;
    }

    // Only show the full loading screen when we have
    // nothing displayed yet.
    final hasExistingData =
        _upcoming.isNotEmpty || _past.isNotEmpty;

    if (mounted) {
      setState(() {
        if (showLoading && !hasExistingData) {
          _isLoading = true;
        } else {
          _refreshing = true;
        }

        _error = null;
      });
    }
    _lastLoadedAt = DateTime.now();

    try {
      final results = await Future.wait([
        Api.bookings.getUpcoming(),
        Api.bookings.getPast(),
      ]);

      if (!mounted) return;

      final upcoming =
      results[0] as List<dynamic>;

      final pastRes =
      results[1] as Map<String, dynamic>;

      final pastData = pastRes['data'];

      final past = pastData is List
          ? List<dynamic>.from(pastData)
          : (pastData is Map &&
          pastData['data'] is List
          ? List<dynamic>.from(
        pastData['data'],
      )
          : <dynamic>[]);

      setState(() {
        _upcoming = upcoming;
        _past = past;
        _isLoading = false;
        _refreshing = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        // التحديث الصامت لا يمسح الحجوزات المعروضة إن فشل (انقطاع مؤقت مثلاً)
        if (!hasExistingData || showLoading) {
          _error = e is ApiException ? e.message : e.toString();
        }
        _isLoading = false;
        _refreshing = false;
      });
    }
  }

  Map<String, dynamic> _toBookingMap(dynamic b) {
    final booking = b is Map ? b as Map<String, dynamic> : <String, dynamic>{};
    final ps = booking['provider_service'] ?? {};
    final service = ps is Map ? ps['service'] ?? ps : {};
    final provider = booking['provider'] ?? {};
    final timeSlot = booking['time_slot'] ?? {};
    final providerMap = provider is Map
        ? provider as Map<String, dynamic>
        : <String, dynamic>{};
    return {
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
      booking['booking_period_label_en'] ??
          timeSlot['period_label_en'],
      'service_type': booking['service_type'] ?? 'in_clinic',
      'patient_name': booking['patient_name'],
      'service_name_ar': service is Map ? service['name_ar'] : '',
      'service_name_en': service is Map ? service['name_en'] : '',
      'provider_name_ar': providerMap['business_name_ar'] ?? '',
      'provider_name_en': providerMap['business_name_en'] ?? '',
      'provider_logo_url': providerMap['logo_url'] ?? providerMap['logo'],
      'total_amount': booking['total_amount'] ?? 0,
      'branch_name': booking['branch_name'],
      ...booking,
    };
  }

  String _bookingScheduleLine(
      Map<String, dynamic> booking,
      ) {
    final settings = context.read<AppSettingsProvider>();
    final isArabic = settings.isArabic;

    final dateStr = DateFormatter.formatBookingDate(
      booking['booking_date']?.toString(),
    );

    final periodLabel = isArabic
        ? booking['booking_period_label_ar']?.toString().trim()
        : booking['booking_period_label_en']?.toString().trim();

    final timePart =
    periodLabel != null && periodLabel.isNotEmpty
        ? periodLabel
        : DateFormatter.formatBookingTime(
      booking['booking_time']?.toString(),
    );

    return '$dateStr • $timePart';
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();

    Widget content;

    if (!AuthService.isLoggedIn) {
      content = _buildSignedOutState();
    } else if (_isLoading) {
      content = _buildLoadingState();
    } else if (_error != null) {
      content = _buildErrorState();
    } else {
      content = _buildBookingShell(
        child: Column(
          children: [
            const SizedBox(height: 18),
            _buildSegmentedTabs(),
            // شريط رفيع أثناء التحديث الصامت بدل إخفاء الحجوزات
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _refreshing
                  ? Padding(
                      key: const ValueKey('refreshing'),
                      padding: EdgeInsets.fromLTRB(
                        Responsive.spacing(context, 40),
                        8,
                        Responsive.spacing(context, 40),
                        0,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          minHeight: 3,
                          color: RastUi.purple,
                          backgroundColor: RastUi.purple.withValues(alpha: 0.08),
                        ),
                      ),
                    )
                  : const SizedBox(key: ValueKey('idle'), height: 11),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildBookingList(_upcoming),
                  _buildBookingList(
                    _past,
                    isPast: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Directionality(
      textDirection: settings.textDirection,
      child: content,
    );
  }

  Widget _buildBookingShell({required Widget child}) {
    final settings = context.watch<AppSettingsProvider>();
    final lang = settings.language;
    // رأس بنفسجي بتدرج الهوية وجسم أبيض بزاوية علوية دائرية (كالتصميم الأول)
    return Container(
      decoration: const BoxDecoration(gradient: RastUi.headerGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: RastTopBar(
          title: AppStrings.t('bookings', lang),
          showCart: true,
          helpTourId: OnboardingTourIds.bookings,
          helpTourSteps: OnboardingCatalog.bookingsTour,
          iconColor: Colors.white,
          showBack: widget.showBackButton,
        ),
        body: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: Container(color: RastUi.screenSurface(context), child: child),
        ),
      ),
    );
  }

  Widget _buildSegmentedTabs() {
    final settings = context.watch<AppSettingsProvider>();
    final lang = settings.language;

    Widget tab(int index, IconData icon, String label, int count) => Tab(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 6),
              Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
              if (count > 0) ...[
                const SizedBox(width: 6),
                AnimatedBuilder(
                  animation: _tabController,
                  builder: (context, _) {
                    final selected = _tabController.index == index;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                      decoration: BoxDecoration(
                        color: selected ? Colors.white.withValues(alpha: 0.25) : RastTokens.brandSoft(context),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: selected ? Colors.white : RastTokens.brand,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: RastTokens.gutter),
      child: Container(
        height: 50,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: RastTokens.fill(context),
          borderRadius: BorderRadius.circular(16),
        ),
        child: TabBar(
          controller: _tabController,
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          splashBorderRadius: BorderRadius.circular(12),
          overlayColor: WidgetStateProperty.all(Colors.transparent),
          indicator: BoxDecoration(
            gradient: RastTokens.brandGradient,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: RastTokens.brand.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          labelColor: Colors.white,
          unselectedLabelColor: RastTokens.muted(context),
          labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: [
            tab(0, Icons.upcoming_rounded, AppStrings.t('upcoming', lang), _upcoming.length),
            tab(1, Icons.history_rounded, AppStrings.t('past', lang), _past.length),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return _buildBookingShell(
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(RastTokens.gutter, 24, RastTokens.gutter, 24),
        itemCount: 4,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => const BookingCardSkeleton(),
      ),
    );
  }

  Widget _buildErrorState() {
    final lang = context.watch<AppSettingsProvider>().language;

    return _buildBookingShell(
      child: RefreshIndicator(
        color: RastTokens.brand,
        onRefresh: () => _loadData(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 60),
            RastEmptyState(
              icon: Icons.wifi_off_rounded,
              color: RastTokens.danger,
              title: L(lang, 'تعذّر تحميل الحجوزات', 'Could not load bookings'),
              message: _error,
              actionLabel: AppStrings.t('retry', lang),
              onAction: _loadData,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignedOutState() {
    final lang = context.watch<AppSettingsProvider>().language;
    return _buildBookingShell(
      child: ListView(
        children: [
          const SizedBox(height: 60),
          RastEmptyState(
            icon: Icons.lock_person_rounded,
            title: L(lang, 'سجّل دخولك لمتابعة حجوزاتك', 'Sign in to see your bookings'),
            message: AppStrings.t('bookingsSignInPrompt', lang),
            actionLabel: AppStrings.t('signIn', lang),
            onAction: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            ).then((_) => _loadData()),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingList(
      List<dynamic> bookings, {
        bool isPast = false,
      }) {
    // السحب للتحديث متاح دائماً، حتى والقائمة فارغة (أول حجز لم يكن يظهر إلا بإعادة فتح التطبيق)
    if (bookings.isEmpty) {
      return RefreshIndicator(
        color: RastUi.purple,
        onRefresh: () => _loadData(showLoading: false),
        child: _buildEmptyBookings(isPast: isPast),
      );
    }
    return RefreshIndicator(
      color: RastUi.purple,
      onRefresh: () => _loadData(
        showLoading: false,
      ),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(RastTokens.gutter, 8, RastTokens.gutter, 24),
        itemCount: bookings.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final b = _toBookingMap(bookings[index]);

          // عند الرجوع من التفاصيل (دفع/إلغاء/تقييم) نحدّث القائمة بصمت
          void onTap() => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BookingDetailScreen(
                    booking: b,
                  ),
                ),
              ).then((_) => _refreshIfStale(Duration.zero));

          final card = BookingCard(
            key: ValueKey('booking-${b['id']}'),
            booking: b,
            scheduleLine: _bookingScheduleLine(b),
            onTap: onTap,
            isPast: isPast,
          );
          // حركة الدخول مرة واحدة لكل حجز (وليس عند كل تمرير)، فالحجز الجديد يدخل بحركة لافتة
          return _animatedIds.add('$isPast-${b['id']}')
              ? card.entrance(index)
              : card;
        },
      ),
    );
  }

  Widget _buildEmptyBookings({
    required bool isPast,
  }) {
    final lang = context.watch<AppSettingsProvider>().language;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 40),
        RastEmptyState(
          icon: isPast ? Icons.history_rounded : Icons.event_available_rounded,
          title: isPast ? AppStrings.t('noPastBookings', lang) : AppStrings.t('noUpcomingBookings', lang),
          message: isPast
              ? AppStrings.t('noPastBookingsDescription', lang)
              : AppStrings.t('noUpcomingBookingsDescription', lang),
          actionLabel: isPast ? null : L(lang, 'احجز تحليلك الأول', 'Book your first test'),
          onAction: isPast
              ? null
              : () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AnalysesScreen()),
                  ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            L(lang, 'اسحب للأسفل للتحديث', 'Pull down to refresh'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: RastTokens.muted(context)),
          ),
        ),
      ],
    );
  }
}
