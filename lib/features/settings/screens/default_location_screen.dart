import 'package:flutter/material.dart';
import 'package:rast/core/services/location_service.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:rast/core/providers/app_settings_provider.dart';
import 'package:rast/core/widgets/rast_kit.dart';
import 'package:rast/core/widgets/rast_motion.dart';
import 'package:rast/core/widgets/rast_ui.dart';
import 'package:rast/core/services/app_events.dart';
import 'package:rast/core/widgets/city_selector.dart';
import 'package:rast/features/addresses/screens/addresses_screen.dart';
import 'package:rast/features/auth/services/auth_service.dart';

/// شاشة إعداد الموقع الافتراضي - للعثور على المختبرات القريبة
class DefaultLocationScreen extends StatefulWidget {
  const DefaultLocationScreen({super.key});

  @override
  State<DefaultLocationScreen> createState() => _DefaultLocationScreenState();
}

class _DefaultLocationScreenState extends State<DefaultLocationScreen> {
  ({double lat, double lng, String? label})? _savedLocation;
  bool _isLoading = false;
  String? _message;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final loc = await LocationService.getDefaultLocation();
    if (mounted) {
      setState(() => _savedLocation = loc);
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _isLoading = true;
      _message = null;
    });
    try {
      final location = await LocationService.getCurrentLocation();
      if (location == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _message = 'السماح بالموقع وتفعيل خدمة الموقع مطلوبان للعثور على المختبرات القريبة';
            _isSuccess = false;
          });
        }
        return;
      }
      AppEvents.notifyLocationChanged();
      if (mounted) {
        setState(() {
          _savedLocation = location;
          _isLoading = false;
          _message = 'تم حفظ موقعك الافتراضي';
          _isSuccess = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _message = 'تعذر الحصول على الموقع: ${e.toString().split('\n').first}';
        });
      }
    }
  }

  Future<void> _pickOnMap() async {
    final a = await pickAddress(context, saveToAccount: false);
    final lat = numOf(a?['latitude']);
    final lng = numOf(a?['longitude']);
    if (a == null || lat == null || lng == null) return;
    final place = [a['district'], a['city']].map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).join('، ');
    await LocationService.setDefaultLocation(
      latitude: lat,
      longitude: lng,
      label: place.isNotEmpty ? place : a['label']?.toString(),
    );
    AppEvents.notifyLocationChanged();
    await _loadSaved();
    if (mounted) {
      setState(() {
        _message = 'تم حفظ موقعك الافتراضي';
        _isSuccess = true;
      });
    }
  }

  Future<void> _clearLocation() async {
    await LocationService.clearDefaultLocation();
    AppEvents.notifyLocationChanged();
    if (mounted) {
      setState(() {
        _savedLocation = null;
        _message = 'تم إلغاء الموقع الافتراضي';
        _isSuccess = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();
    final lang = settings.language;
    return Directionality(
      textDirection: settings.textDirection,
      child: Container(
        decoration: const BoxDecoration(gradient: RastUi.headerGradient),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: RastTopBar(title: L(lang, 'الموقع الافتراضي', 'Default location')),
          body: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: Container(
              color: RastTokens.bg(context),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  RastCard(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        const RastIconBox(icon: Icons.location_on_rounded, size: 52),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                L(lang, 'العثور على المختبرات القريبة', 'Find nearby labs'),
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: RastTokens.ink(context)),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                L(lang, 'احفظ موقعك لعرض المختبرات الأقرب لك وأقرب فرع لكل مختبر',
                                    'Save your location to see the closest labs and branches'),
                                style: TextStyle(fontSize: 12.5, height: 1.5, color: RastTokens.muted(context)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ).entrance(0),
                  const SizedBox(height: 14),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 260),
                    child: _savedLocation == null
                        ? const SizedBox(width: double.infinity)
                        : Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: RastCard(
                              padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                              child: Row(
                                children: [
                                  const RastIconBox(icon: Icons.check_circle_rounded, color: RastTokens.success, size: 42),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _savedLocation!.label ?? L(lang, 'موقع محفوظ', 'Saved location'),
                                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: RastTokens.ink(context)),
                                        ),
                                        Text(
                                          '${_savedLocation!.lat.toStringAsFixed(4)}, ${_savedLocation!.lng.toStringAsFixed(4)}',
                                          textDirection: TextDirection.ltr,
                                          style: TextStyle(fontSize: 11.5, color: RastTokens.muted(context)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: _isLoading ? null : _clearLocation,
                                    style: TextButton.styleFrom(foregroundColor: RastTokens.danger),
                                    child: Text(L(lang, 'إلغاء', 'Clear')),
                                  ),
                                ],
                              ),
                            ),
                          ),
                  ),
                  RastButton(
                    label: _savedLocation != null
                        ? L(lang, 'تحديث بموقعي الحالي', 'Update to my current location')
                        : L(lang, 'استخدم موقعي الحالي', 'Use my current location'),
                    icon: Icons.my_location_rounded,
                    loading: _isLoading,
                    onPressed: _isLoading ? null : _useCurrentLocation,
                  ),
                  const SizedBox(height: 10),
                  // اختيار مدينة أو عنوان محفوظ، أو تحديد نقطة على الخريطة (مثلاً حجز منزلي لأهلك في مدينة أخرى)
                  RastButton(
                    label: L(lang, 'اختر مدينة أو عنواناً محفوظاً', 'Choose a city or saved address'),
                    icon: Icons.location_city_rounded,
                    secondary: true,
                    onPressed: _isLoading
                        ? null
                        : () async {
                            await showLocationPickerSheet(context);
                            _loadSaved();
                          },
                  ),
                  const SizedBox(height: 10),
                  RastButton(
                    label: L(lang, 'حدّد على الخريطة', 'Pick on the map'),
                    icon: Icons.map_rounded,
                    secondary: true,
                    onPressed: _isLoading ? null : _pickOnMap,
                  ),
                  if (AuthService.isLoggedIn) ...[
                    const SizedBox(height: 4),
                    TextButton.icon(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddressesScreen())),
                      icon: const Icon(Icons.bookmarks_rounded, size: 18),
                      label: Text(L(lang, 'إدارة عناويني', 'Manage my addresses')),
                      style: TextButton.styleFrom(foregroundColor: RastTokens.brand),
                    ),
                  ],
                  if (_message != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: (_isSuccess ? RastTokens.success : RastTokens.danger).withValues(alpha: 0.09),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _isSuccess ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                            color: _isSuccess ? RastTokens.success : RastTokens.danger,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _message!,
                              style: TextStyle(fontSize: 13, color: _isSuccess ? RastTokens.success : RastTokens.danger),
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn().slideY(begin: 0.2, end: 0),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
