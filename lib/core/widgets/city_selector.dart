import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:rast/core/api/api_services.dart';
import 'package:rast/core/models/region.dart';
import 'package:rast/core/providers/app_settings_provider.dart';
import 'package:rast/core/services/app_events.dart';
import 'package:rast/core/services/location_service.dart';
import 'package:rast/core/widgets/rast_kit.dart';
import 'package:rast/features/addresses/screens/addresses_screen.dart';
import 'package:rast/features/auth/services/auth_service.dart';

/// محدد المدينة/الموقع في رأس الرئيسية: يعرض الموقع المعتمد ويفتح ورقة اختيار
/// (موقعي الحالي، عناويني، مدن التطبيق). الاختيار يحفظ الموقع الافتراضي ويُبلغ الشاشات لإعادة الترتيب.
class CitySelectorChip extends StatefulWidget {
  const CitySelectorChip({super.key, this.onDark = false});

  final bool onDark;

  @override
  State<CitySelectorChip> createState() => _CitySelectorChipState();
}

class _CitySelectorChipState extends State<CitySelectorChip> {
  String? _label;

  @override
  void initState() {
    super.initState();
    _refresh();
    AppEvents.locationChanged.addListener(_refresh);
  }

  @override
  void dispose() {
    AppEvents.locationChanged.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _refresh() async {
    final loc = await LocationService.getDefaultLocation();
    if (mounted) setState(() => _label = loc?.label);
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppSettingsProvider>().language;
    final fg = widget.onDark ? Colors.white : RastTokens.ink(context);
    final label = (_label == null || _label!.trim().isEmpty) ? L(lang, 'حدّد موقعك', 'Set location') : _label!;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () async {
          HapticFeedback.selectionClick();
          await showLocationPickerSheet(context);
          _refresh();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_on_rounded, size: 16, color: widget.onDark ? Colors.white : RastTokens.brand),
              const SizedBox(width: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 150),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Text(
                    label,
                    key: ValueKey(label),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
              ),
              Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: fg),
            ],
          ),
        ),
      ),
    );
  }
}

/// ورقة اختيار الموقع (تُستخدم من محدد المدينة أو من أي شاشة أخرى)
Future<void> showLocationPickerSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _LocationSheet(),
  );
}

class _LocationSheet extends StatefulWidget {
  const _LocationSheet();

  @override
  State<_LocationSheet> createState() => _LocationSheetState();
}

class _LocationSheetState extends State<_LocationSheet> {
  List<Region> _regions = [];
  List<Map<String, dynamic>> _addresses = [];
  bool _loading = true;
  bool _locating = false;
  String? _currentLabel;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loc = await LocationService.getDefaultLocation();
    _currentLabel = loc?.label;
    try {
      final results = await Future.wait([
        Api.providers.getRegions(),
        if (AuthService.isLoggedIn) Api.growth.addresses(),
      ]);
      if (!mounted) return;
      setState(() {
        _regions = results[0] as List<Region>;
        if (results.length > 1) _addresses = results[1] as List<Map<String, dynamic>>;
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _select(double lat, double lng, String label) async {
    HapticFeedback.selectionClick();
    await LocationService.setDefaultLocation(latitude: lat, longitude: lng, label: label);
    AppEvents.notifyLocationChanged();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _gps(String lang) async {
    setState(() => _locating = true);
    final loc = await LocationService.getCurrentLocation(saveAsDefault: false);
    if (!mounted) return;
    setState(() => _locating = false);
    if (loc == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(L(lang, 'فعّل الموقع والسماح للتطبيق باستخدامه', 'Enable location and allow the app to use it')),
      ));
      return;
    }
    String label = L(lang, 'موقعي الحالي', 'My location');
    try {
      final rows = await Api.growth.geocode(lat: loc.lat, lng: loc.lng, lang: lang);
      final r = rows.isNotEmpty ? rows.first : null;
      final place = [r?['district'], r?['city']].map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).join('، ');
      if (place.isNotEmpty) label = place;
    } catch (_) {}
    await _select(loc.lat, loc.lng, label);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();
    final lang = settings.language;
    final maxH = MediaQuery.sizeOf(context).height * 0.78;

    return Directionality(
      textDirection: settings.textDirection,
      child: Container(
        constraints: BoxConstraints(maxHeight: maxH),
        decoration: BoxDecoration(
          color: RastTokens.bg(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              Center(
                child: Container(width: 42, height: 4, decoration: BoxDecoration(color: RastTokens.line(context), borderRadius: BorderRadius.circular(4))),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                child: Text(L(lang, 'أين تريد التحليل؟', 'Where do you need the test?'),
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: RastTokens.ink(context))),
              ),
              const SizedBox(height: 4),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    _tile(
                      icon: Icons.my_location_rounded,
                      title: L(lang, 'موقعي الحالي', 'My current location'),
                      subtitle: null,
                      trailing: _locating ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : null,
                      onTap: _locating ? null : () => _gps(lang),
                    ),
                    if (AuthService.isLoggedIn) ...[
                      _groupTitle(L(lang, 'عناويني', 'My addresses')),
                      ..._addresses.map((a) => _tile(
                            icon: addressIcon(a['label']?.toString()),
                            title: a['label']?.toString() ?? '',
                            subtitle: addressSubtitle(a),
                            selected: _currentLabel == a['label'],
                            onTap: () {
                              final lat = numOf(a['latitude']);
                              final lng = numOf(a['longitude']);
                              if (lat != null && lng != null) _select(lat, lng, a['label']?.toString() ?? '');
                            },
                          )),
                      _tile(
                        icon: Icons.add_location_alt_rounded,
                        title: L(lang, 'إضافة عنوان', 'Add address'),
                        onTap: () async {
                          final a = await pickAddress(context);
                          final lat = numOf(a?['latitude']);
                          final lng = numOf(a?['longitude']);
                          if (a != null && lat != null && lng != null) {
                            await _select(lat, lng, a['label']?.toString() ?? '');
                          }
                        },
                      ),
                    ],
                    _groupTitle(L(lang, 'المدن', 'Cities')),
                    if (_loading)
                      ...List.generate(4, (_) => const Padding(padding: EdgeInsets.only(bottom: 8), child: RastSkeleton(height: 54, radius: 16)))
                    else
                      ..._regions.map((r) {
                        final name = r.displayName(settings.isArabic);
                        return _tile(
                          icon: Icons.location_city_rounded,
                          title: name,
                          selected: _currentLabel == name,
                          onTap: () => _select(r.latitude, r.longitude, name),
                        );
                      }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _groupTitle(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
        child: Text(t, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: RastTokens.muted(context))),
      );

  Widget _tile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    bool selected = false,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RastCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        borderColor: selected ? RastTokens.brand : null,
        child: Row(
          children: [
            RastIconBox(icon: icon, size: 38),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, color: RastTokens.ink(context))),
                  if (subtitle != null && subtitle.isNotEmpty)
                    Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: RastTokens.muted(context))),
                ],
              ),
            ),
            trailing ?? (selected ? const Icon(Icons.check_circle_rounded, color: RastTokens.brand) : const SizedBox.shrink()),
          ],
        ),
      ),
    );
  }
}
