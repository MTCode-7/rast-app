import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:rast/core/api/api_services.dart';
import 'package:rast/core/constants/api_config.dart';
import 'package:rast/core/constants/app_strings.dart';
import 'package:rast/core/providers/app_settings_provider.dart';
import 'package:rast/core/utils/locale_utils.dart';
import 'package:provider/provider.dart';
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
import 'package:rast/features/bookings/screens/booking_detail_screen.dart';
import 'package:rast/app/main_tab_index_scope.dart';
import 'package:rast/app/main_shell.dart';
import 'package:rast/features/auth/screens/login_screen.dart';
import 'package:shimmer/shimmer.dart';

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
    with SingleTickerProviderStateMixin, OnboardingTourHost {
  late TabController _tabController;
  bool _bookingsTourScheduled = false;
  List<dynamic> _upcoming = [];
  List<dynamic> _past = [];
  bool _isLoading = true;
  String? _error;

  @override
  String? get onboardingTourId => OnboardingTourIds.bookings;

  @override
  List<OnboardingStep> buildOnboardingSteps() =>
      OnboardingCatalog.bookingsTour;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      if (MainTabIndexScope.of(context).currentIndex ==
          MainScaffold.bookingsTabIndex) {
        _maybeScheduleBookingsTour();
      }
    } catch (_) {}
  }

  void _maybeScheduleBookingsTour() {
    if (_bookingsTourScheduled) return;
    _bookingsTourScheduled = true;
    scheduleOnboardingTour(delay: const Duration(milliseconds: 600));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData({
    bool showLoading = true,
  }) async {
    if (!AuthService.isLoggedIn) {
      if (mounted) {
        setState(() {
          _isLoading = false;
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
        }

        _error = null;
      });
    }

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
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

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
    final lang = settings.language;

    Widget content;

    if (!AuthService.isLoggedIn) {
      content = _buildBookingShell(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(
              Responsive.spacing(context, 24),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildEmptyBookingIcon(),

                SizedBox(
                  height: Responsive.spacing(context, 24),
                ),

                Text(
                  AppStrings.t(
                    'bookingsSignInPrompt',
                    lang,
                  ),
                  style: TextStyle(
                    fontSize:
                    Responsive.fontSize(context, 18),
                    color: AppTheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),

                SizedBox(
                  height: Responsive.spacing(context, 24),
                ),

                GradientFilledButtonIcon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LoginScreen(),
                    ),
                  ).then((_) => setState(() {})),
                  icon: const Icon(
                    Icons.login_rounded,
                  ),
                  label: Text(
                    AppStrings.t('signIn', lang),
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else if (_isLoading) {
      content = _buildLoadingState();
    } else if (_error != null) {
      content = _buildErrorState();
    } else {
      content = _buildBookingShell(
        child: Column(
          children: [
            SizedBox(
              height: Responsive.spacing(context, 34),
            ),
            _buildSegmentedTabs(),
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

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.spacing(context, 18),
      ),
      child: Container(
        width: double.infinity,
        height: 56,
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: RastUi.cardSurface(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: RastUi.softBorder(context).withValues(alpha: 0.8),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: TabBar(
          controller: _tabController,
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          splashBorderRadius: BorderRadius.circular(14),
          overlayColor: WidgetStateProperty.all(
            Colors.transparent,
          ),
          indicator: BoxDecoration(
            gradient: RastUi.brandGradient,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: RastUi.purple.withValues(alpha: 0.25),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          labelColor: Colors.white,
          unselectedLabelColor: RastUi.textPurple,
          labelStyle: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: Responsive.fontSize(context, 13),
          ),
          unselectedLabelStyle: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: Responsive.fontSize(context, 13),
          ),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.upcoming_rounded,
                    size: 18,
                  ),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      AppStrings.t('upcoming', lang),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.history_rounded,
                    size: 18,
                  ),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      AppStrings.t('past', lang),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return _buildBookingShell(
      child: ListView.builder(
        padding: EdgeInsets.all(
          Responsive.spacing(context, 16),
        ),
        itemCount: 4,
        itemBuilder: (_, __) => Shimmer.fromColors(
          baseColor: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest,
          highlightColor:
          Theme.of(context).colorScheme.surface,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            height: 150,
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    final lang =
        context.watch<AppSettingsProvider>().language;

    return _buildBookingShell(
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(
            Responsive.spacing(context, 24),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 64,
                color: AppTheme.error,
              ),

              SizedBox(
                height: Responsive.spacing(context, 16),
              ),

              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize:
                  Responsive.fontSize(context, 15),
                ),
              ),

              SizedBox(
                height: Responsive.spacing(context, 20),
              ),

              GradientFilledButtonIcon(
                onPressed: _loadData,
                icon: const Icon(
                  Icons.refresh_rounded,
                ),
                label: Text(
                  AppStrings.t('retry', lang),
                ),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBookingList(
      List<dynamic> bookings, {
        bool isPast = false,
      }) {
    if (bookings.isEmpty) {
      return _buildEmptyBookings(
        isPast: isPast,
      );
    }
    return RefreshIndicator(
      onRefresh: () => _loadData(
        showLoading: false,
      ),
      child: ListView.separated(
        padding: EdgeInsets.all(Responsive.spacing(context, 16)),
        itemCount: bookings.length,
        separatorBuilder: (_, __) =>
            SizedBox(height: Responsive.spacing(context, 12)),
        itemBuilder: (context, index) {
          final b = _toBookingMap(bookings[index]);

          final onTap = () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BookingDetailScreen(
                booking: b,
              ),
            ),
          );

          if (isPast) {
            return _PastBookingCard(
              booking: b,
              scheduleLine: _bookingScheduleLine(b),
              onTap: onTap,
            );
          }

          return _UpcomingBookingCard(
            booking: b,
            scheduleLine: _bookingScheduleLine(b),
            onTap: onTap,
          );
        },
      ),
    );
  }

  Widget _buildEmptyBookings({
    required bool isPast,
  }) {
    final settings = context.watch<AppSettingsProvider>();
    final lang = settings.language;

    final title = isPast
        ? AppStrings.t('noPastBookings', lang)
        : AppStrings.t('noUpcomingBookings', lang);

    final description = isPast
        ? AppStrings.t('noPastBookingsDescription', lang)
        : AppStrings.t('noUpcomingBookingsDescription', lang);

    final icon = isPast
        ? Icons.history_rounded
        : Icons.event_available_rounded;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          Responsive.spacing(context, 20),
          Responsive.spacing(context, 70),
          Responsive.spacing(context, 20),
          Responsive.spacing(context, 30),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 380,
            ),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.spacing(
                  context,
                  24,
                ),
                vertical: Responsive.spacing(
                  context,
                  30,
                ),
              ),
              decoration: BoxDecoration(
                color: RastUi.cardSurface(context),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: RastUi.softBorder(context)
                      .withValues(alpha: 0.75),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: 0.07,
                    ),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 112,
                    height: 112,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                        colors: [
                          RastUi.purple.withValues(
                            alpha: 0.12,
                          ),
                          RastUi.blue.withValues(
                            alpha: 0.10,
                          ),
                        ],
                      ),
                    ),
                    child: Center(
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          gradient: RastUi.brandGradient,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: RastUi.purple
                                  .withValues(alpha: 0.23),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Icon(
                          icon,
                          color: Colors.white,
                          size: 34,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(
                    height: Responsive.spacing(
                      context,
                      24,
                    ),
                  ),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: RastUi.purple.withValues(
                        alpha: 0.08,
                      ),
                      borderRadius:
                      BorderRadius.circular(999),
                    ),
                    child: Text(
                      isPast
                          ? AppStrings.t(
                        'pastBookings',
                        lang,
                      )
                          : AppStrings.t(
                        'upcomingBookings',
                        lang,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: RastUi.purple,
                        fontSize: Responsive.fontSize(
                          context,
                          11,
                        ),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),

                  SizedBox(
                    height: Responsive.spacing(
                      context,
                      14,
                    ),
                  ),

                  // TITLE
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: RastUi.primaryText(context),
                      fontSize: Responsive.fontSize(
                        context,
                        19,
                      ),
                      fontWeight: FontWeight.w800,
                      height: 1.3,
                    ),
                  ),

                  SizedBox(
                    height: Responsive.spacing(
                      context,
                      10,
                    ),
                  ),

                  // DESCRIPTION
                  Text(
                    description,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: RastUi.secondaryText(context),
                      fontSize: Responsive.fontSize(
                        context,
                        13,
                      ),
                      fontWeight: FontWeight.w400,
                      height: 1.6,
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

  Widget _buildEmptyBookingIcon() {
    return Container(
      width: 160,
      height: 160,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            RastUi.blue.withValues(alpha: 0.45),
            RastUi.purple.withValues(alpha: 0.42),
          ],
        ),
      ),
      child: Center(
        child: Container(
          width: 88,
          height: 88,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: RastUi.brandGradient,
          ),
          child: const Icon(
            Icons.event_busy_outlined,
            color: Colors.white,
            size: 48,
          ),
        ),
      ),
    );
  }
}

class _PastBookingCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  final String scheduleLine;
  final VoidCallback onTap;

  const _PastBookingCard({
    required this.booking,
    required this.scheduleLine,
    required this.onTap,
  });

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

  String _statusText(
      String status,
      String lang,
      ) {
    switch (status) {
      case 'confirmed':
        return AppStrings.t(
          'bookingStatusConfirmed',
          lang,
        );

      case 'pending':
        return AppStrings.t(
          'bookingStatusPending',
          lang,
        );

      case 'completed':
        return AppStrings.t(
          'bookingStatusCompleted',
          lang,
        );

      case 'cancelled':
        return AppStrings.t(
          'bookingStatusCancelled',
          lang,
        );

      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings =
    context.watch<AppSettingsProvider>();

    final isArabic = settings.isArabic;
    final lang = settings.language;

    final serviceName = LocaleUtils.localizedName(
      booking,
      isArabic,
      arKey: 'service_name_ar',
      enKey: 'service_name_en',
    );

    final providerName = LocaleUtils.localizedName(
      booking,
      isArabic,
      arKey: 'provider_name_ar',
      enKey: 'provider_name_en',
    );

    final status =
    (booking['status'] ?? 'pending').toString();

    final paymentPending =
        (booking['payment_status'] ?? 'pending') != 'paid';

    final amount = booking['total_amount'] is num
        ? (booking['total_amount'] as num).toDouble()
        : double.tryParse(
      booking['total_amount']?.toString() ?? '',
    ) ??
        0.0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: RastUi.cardSurface(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: RastUi.softBorder(context)
              .withValues(alpha: 0.7),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.075),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: EdgeInsets.all(
              Responsive.spacing(context, 14),
            ),
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.stretch,
              children: [
                // IMAGE + BOOKING INFORMATION
                Row(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    _BookingImages(
                      booking: booking,
                    ),

                    SizedBox(
                      width:
                      Responsive.spacing(context, 12),
                    ),

                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Text(
                            serviceName.isEmpty
                                ? AppStrings.t('booking', lang)
                                : serviceName,
                            maxLines: 2,
                            overflow:
                            TextOverflow.ellipsis,
                            style: TextStyle(
                              color:
                              RastUi.primaryText(context),
                              fontSize:
                              Responsive.fontSize(
                                context,
                                14,
                              ),
                              fontWeight:
                              FontWeight.w800,
                              height: 1.25,
                            ),
                          ),

                          if (providerName.isNotEmpty) ...[
                            const SizedBox(height: 5),

                            Row(
                              children: [
                                Icon(
                                  Icons
                                      .business_outlined,
                                  size: 14,
                                  color:
                                  RastUi.secondaryText(
                                    context,
                                  ),
                                ),

                                const SizedBox(width: 5),

                                Expanded(
                                  child: Text(
                                    providerName,
                                    maxLines: 1,
                                    overflow:
                                    TextOverflow
                                        .ellipsis,
                                    style: TextStyle(
                                      color: RastUi
                                          .secondaryText(
                                        context,
                                      ),
                                      fontSize:
                                      Responsive
                                          .fontSize(
                                        context,
                                        11,
                                      ),
                                      fontWeight:
                                      FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],

                          const SizedBox(height: 9),

                          // STATUS BADGES
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _statusBadge(
                                context,
                                status,
                                lang,
                              ),

                              if (paymentPending)
                                _paymentBadge(
                                  context,
                                  lang,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 6),

                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: RastUi.subtleFill(context),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isArabic
                            ? Icons.arrow_back_ios_new_rounded
                            : Icons.arrow_forward_ios_rounded,
                        textDirection: TextDirection.ltr,
                        size: 13,
                        color: RastUi.secondaryText(context),
                      ),
                    ),
                  ],
                ),

                SizedBox(
                  height:
                  Responsive.spacing(context, 14),
                ),

                Divider(
                  height: 1,
                  color: RastUi.softBorder(context),
                ),

                SizedBox(
                  height:
                  Responsive.spacing(context, 12),
                ),

                // DATE / TIME
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: RastUi.subtleFill(context),
                    borderRadius:
                    BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: RastUi.purple
                              .withValues(alpha: 0.09),
                          borderRadius:
                          BorderRadius.circular(9),
                        ),
                        child: const Icon(
                          Icons.calendar_month_outlined,
                          size: 16,
                          color: RastUi.purple,
                        ),
                      ),

                      const SizedBox(width: 8),

                      Expanded(
                        child: Text(
                          scheduleLine,
                          maxLines: 2,
                          overflow:
                          TextOverflow.ellipsis,
                          style: TextStyle(
                            color:
                            RastUi.primaryText(context),
                            fontSize:
                            Responsive.fontSize(
                              context,
                              11,
                            ),
                            fontWeight:
                            FontWeight.w600,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(
                  height:
                  Responsive.spacing(context, 12),
                ),

                // BOOKING NUMBER + PRICE
                Row(
                  crossAxisAlignment:
                  CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: booking['booking_number'] !=
                          null
                          ? Row(
                        children: [
                          Icon(
                            Icons
                                .confirmation_number_outlined,
                            size: 15,
                            color: RastUi
                                .secondaryText(
                              context,
                            ),
                          ),

                          const SizedBox(width: 6),

                          Expanded(
                            child: Text(
                              booking[
                              'booking_number']
                                  .toString(),
                              maxLines: 1,
                              overflow:
                              TextOverflow
                                  .ellipsis,
                              style: TextStyle(
                                color: RastUi
                                    .secondaryText(
                                  context,
                                ),
                                fontSize:
                                Responsive
                                    .fontSize(
                                  context,
                                  10,
                                ),
                                fontWeight:
                                FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      )
                          : const SizedBox.shrink(),
                    ),

                    const SizedBox(width: 10),

                    Flexible(
                      child: Text(
                        '${amount.toStringAsFixed(2)} '
                            '${AppStrings.t('sar', lang)}',
                        maxLines: 1,
                        overflow:
                        TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          color: RastUi.purple,
                          fontSize:
                          Responsive.fontSize(
                            context,
                            15,
                          ),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(
      BuildContext context,
      String status,
      String lang,
      ) {
    final color = _statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withValues(alpha: 0.15),
        ),
      ),
      child: Text(
        _statusText(status, lang),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: Responsive.fontSize(context, 10),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _paymentBadge(
      BuildContext context,
      String lang,
      ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.orange.withValues(alpha: 0.15),
        ),
      ),
      child: Text(
        AppStrings.t('unpaid', lang),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.orange.shade700,
          fontSize: Responsive.fontSize(context, 10),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

}

class _UpcomingBookingCard extends StatelessWidget {

  final Map<String, dynamic> booking;
  final String scheduleLine;
  final VoidCallback onTap;

  const _UpcomingBookingCard({
    required this.booking,
    required this.scheduleLine,
    required this.onTap,
  });

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

  String _statusText(
      String status,
      String lang,
      ) {
    switch (status) {
      case 'confirmed':
        return AppStrings.t(
          'bookingStatusConfirmed',
          lang,
        );

      case 'pending':
        return AppStrings.t(
          'bookingStatusPending',
          lang,
        );

      case 'completed':
        return AppStrings.t(
          'bookingStatusCompleted',
          lang,
        );

      case 'cancelled':
        return AppStrings.t(
          'bookingStatusCancelled',
          lang,
        );

      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings =
    context.watch<AppSettingsProvider>();

    final isArabic = settings.isArabic;
    final lang = settings.language;

    final serviceName = LocaleUtils.localizedName(
      booking,
      isArabic,
      arKey: 'service_name_ar',
      enKey: 'service_name_en',
    );

    final providerName = LocaleUtils.localizedName(
      booking,
      isArabic,
      arKey: 'provider_name_ar',
      enKey: 'provider_name_en',
    );

    final status =
    (booking['status'] ?? 'pending').toString();

    final paymentPending =
        (booking['payment_status'] ?? 'pending') != 'paid';

    final amount = booking['total_amount'] is num
        ? (booking['total_amount'] as num).toDouble()
        : double.tryParse(
      booking['total_amount']?.toString() ?? '',
    ) ??
        0.0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: RastUi.cardSurface(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: RastUi.purple.withValues(alpha: 0.13),
        ),
        boxShadow: [
          BoxShadow(
            color: RastUi.purple.withValues(alpha: 0.10),
            blurRadius: 20,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: EdgeInsets.all(
              Responsive.spacing(context, 14),
            ),
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.stretch,
              children: [
                // TOP
                Row(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    _BookingImages(
                      booking: booking,
                    ),

                    SizedBox(
                      width: Responsive.spacing(
                        context,
                        12,
                      ),
                    ),

                    // MAIN INFORMATION
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Text(
                            serviceName.isEmpty
                                ? AppStrings.t('booking', lang)
                                : serviceName,
                            maxLines: 2,
                            overflow:
                            TextOverflow.ellipsis,
                            style: TextStyle(
                              color:
                              RastUi.primaryText(context),
                              fontSize:
                              Responsive.fontSize(
                                context,
                                14,
                              ),
                              fontWeight:
                              FontWeight.w800,
                              height: 1.25,
                            ),
                          ),

                          if (providerName.isNotEmpty) ...[
                            const SizedBox(height: 5),

                            Row(
                              children: [
                                Icon(
                                  Icons.business_outlined,
                                  size: 14,
                                  color:
                                  RastUi.secondaryText(
                                    context,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    providerName,
                                    maxLines: 1,
                                    overflow:
                                    TextOverflow
                                        .ellipsis,
                                    style: TextStyle(
                                      color: RastUi
                                          .secondaryText(
                                        context,
                                      ),
                                      fontSize:
                                      Responsive
                                          .fontSize(
                                        context,
                                        11,
                                      ),
                                      fontWeight:
                                      FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],

                          const SizedBox(height: 9),

                          // STATUS
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _statusBadge(
                                context,
                                status,
                                lang,
                              ),

                              if (paymentPending)
                                _paymentBadge(
                                  context,
                                  lang,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 6),

                    // OPEN DETAILS
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: RastUi.purple
                            .withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isArabic
                            ? Icons.arrow_back_ios_new_rounded
                            : Icons.arrow_forward_ios_rounded,
                        textDirection: TextDirection.ltr,
                        size: 13,
                        color: RastUi.purple,
                      ),
                    ),
                  ],
                ),

                SizedBox(
                  height:
                  Responsive.spacing(context, 14),
                ),

                // UPCOMING DATE HIGHLIGHT
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal:
                    Responsive.spacing(context, 12),
                    vertical:
                    Responsive.spacing(context, 11),
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        RastUi.purple
                            .withValues(alpha: 0.08),
                        RastUi.blue
                            .withValues(alpha: 0.06),
                      ],
                    ),
                    borderRadius:
                    BorderRadius.circular(14),
                    border: Border.all(
                      color: RastUi.purple
                          .withValues(alpha: 0.10),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: RastUi.brandGradient,
                          borderRadius:
                          BorderRadius.circular(11),
                        ),
                        child: const Icon(
                          Icons.event_available_rounded,
                          size: 19,
                          color: Colors.white,
                        ),
                      ),

                      const SizedBox(width: 10),

                      Expanded(
                        child: Text(
                          scheduleLine,
                          maxLines: 2,
                          overflow:
                          TextOverflow.ellipsis,
                          style: TextStyle(
                            color:
                            RastUi.primaryText(context),
                            fontSize:
                            Responsive.fontSize(
                              context,
                              12,
                            ),
                            fontWeight:
                            FontWeight.w700,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(
                  height:
                  Responsive.spacing(context, 12),
                ),

                Divider(
                  height: 1,
                  color: RastUi.softBorder(context),
                ),

                SizedBox(
                  height:
                  Responsive.spacing(context, 11),
                ),

                // NUMBER + PRICE
                Row(
                  children: [
                    Expanded(
                      child:
                      booking['booking_number'] != null
                          ? Row(
                        children: [
                          Icon(
                            Icons
                                .confirmation_number_outlined,
                            size: 15,
                            color: RastUi
                                .secondaryText(
                              context,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              booking[
                              'booking_number']
                                  .toString(),
                              maxLines: 1,
                              overflow:
                              TextOverflow
                                  .ellipsis,
                              style: TextStyle(
                                color: RastUi
                                    .secondaryText(
                                  context,
                                ),
                                fontSize:
                                Responsive
                                    .fontSize(
                                  context,
                                  10,
                                ),
                                fontWeight:
                                FontWeight
                                    .w600,
                              ),
                            ),
                          ),
                        ],
                      )
                          : const SizedBox
                          .shrink(),
                    ),

                    const SizedBox(width: 10),

                    Flexible(
                      child: Text(
                        '${amount.toStringAsFixed(2)} '
                        '${AppStrings.t('sar', lang)}',
                        maxLines: 1,
                        overflow:
                        TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          color: RastUi.purple,
                          fontSize:
                          Responsive.fontSize(
                            context,
                            15,
                          ),
                          fontWeight:
                          FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(
      BuildContext context,
      String status,
      String lang,
      ) {
    final color = _statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withValues(alpha: 0.15),
        ),
      ),
      child: Text(
        _statusText(status, lang),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize:
          Responsive.fontSize(context, 10),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _paymentBadge(BuildContext context,  String lang,) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.orange.withValues(alpha: 0.15),
        ),
      ),
      child: Text(
        AppStrings.t(
          'unpaid',
          lang,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.orange.shade700,
          fontSize:
          Responsive.fontSize(context, 10),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _BookingImages extends StatelessWidget {
  final Map<String, dynamic> booking;

  const _BookingImages({
    required this.booking,
  });

  @override
  Widget build(BuildContext context) {
    final providerService =
    booking['provider_service'] is Map
        ? Map<String, dynamic>.from(
      booking['provider_service'] as Map,
    )
        : <String, dynamic>{};

    final rawService =
        providerService['service'] ??
            providerService;

    final service = rawService is Map
        ? Map<String, dynamic>.from(
      rawService,
    )
        : <String, dynamic>{};

    final testImageUrl =
    ApiConfig.analysisImageUrl(
      service,
      providerService,
    );

    final labImageUrl =
    ApiConfig.resolveImageUrl(
      booking['provider_logo_url'],
      booking['provider_logo'],
    );

    return SizedBox(
      width: 78,
      height: 78,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // TEST IMAGE
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              borderRadius:
              BorderRadius.circular(18),
              color: AppTheme.primary
                  .withValues(alpha: 0.08),
              boxShadow: [
                BoxShadow(
                  color: Colors.black
                      .withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset:
                  const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius:
              BorderRadius.circular(18),
              child: testImageUrl != null &&
                  testImageUrl.isNotEmpty
                  ? CachedNetworkImage(
                imageUrl:
                testImageUrl,
                width: 70,
                height: 70,
                fit: BoxFit.cover,
                placeholder: (_, __) =>
                    _testFallback(labImageUrl),

                errorWidget: (_, __, ___) =>
                    _testFallback(labImageUrl),
              )
                  : _testFallback(labImageUrl),
            ),
          ),

          // LAB IMAGE
          PositionedDirectional(
            end: 0,
            bottom: 0,
            child: Container(
              width: 34,
              height: 34,
              padding:
              const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black
                        .withValues(
                      alpha: 0.16,
                    ),
                    blurRadius: 7,
                    offset:
                    const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipOval(
                child: labImageUrl != null &&
                    labImageUrl.isNotEmpty
                    ? CachedNetworkImage(
                  imageUrl:
                  labImageUrl,
                  width: 30,
                  height: 30,
                  fit: BoxFit.cover,

                  placeholder:
                      (_, __) =>
                      _labFallback(),

                  errorWidget:
                      (_, __, ___) =>
                      _labFallback(),
                )
                    : _labFallback(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _testFallback(String? labImageUrl) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: AppTheme.primary.withValues(
        alpha: 0.08,
      ),
      child: labImageUrl != null &&
          labImageUrl.isNotEmpty
          ? CachedNetworkImage(
        imageUrl: labImageUrl,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          alignment: Alignment.center,
          color: AppTheme.primary.withValues(
            alpha: 0.08,
          ),
          child: const CircularProgressIndicator(
            strokeWidth: 2,
          ),
        ),
        errorWidget: (_, __, ___) => Container(
          alignment: Alignment.center,
          color: AppTheme.primary.withValues(
            alpha: 0.08,
          ),
          child: const Icon(
            Icons.business_rounded,
            size: 30,
            color: AppTheme.primary,
          ),
        ),
      )
          : const Center(
        child: Icon(
          Icons.business_rounded,
          size: 30,
          color: AppTheme.primary,
        ),
      ),
    );
  }

  Widget _labFallback() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      alignment: Alignment.center,
      color: AppTheme.surfaceVariant,
      child: const Icon(
        Icons.business_rounded,
        size: 16,
        color: AppTheme.primary,
      ),
    );
  }
}