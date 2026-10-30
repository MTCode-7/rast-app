import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:rast/core/api/api_services.dart';
import 'package:rast/core/providers/app_settings_provider.dart';
import 'package:rast/core/services/location_service.dart';
import 'package:rast/core/widgets/rast_kit.dart';
import 'package:rast/features/addresses/screens/addresses_screen.dart';
import 'package:rast/features/auth/services/auth_service.dart';

/// اختيار عنوان السحب المنزلي في خطوات الحجز: العناوين المحفوظة (بطاقات اختيار)،
/// «موقعي الحالي»، و«إضافة عنوان جديد». يُرجع العنوان المختار عبر onChanged
/// بالمفاتيح: label, address_line, city, district, latitude, longitude.
class HomeAddressChooser extends StatefulWidget {
  const HomeAddressChooser({super.key, required this.onChanged, this.selectedKey});

  final ValueChanged<Map<String, dynamic>> onChanged;

  /// مفتاح الاختيار الحالي (id العنوان، أو 'gps'، أو 'new') ليبقى محدداً عند إعادة البناء
  final String? selectedKey;

  @override
  State<HomeAddressChooser> createState() => _HomeAddressChooserState();
}

class _HomeAddressChooserState extends State<HomeAddressChooser> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _locating = false;
  String? _selected;
  Map<String, dynamic>? _custom; // عنوان جديد غير محفوظ (للزائر) أو موقع GPS

  @override
  void initState() {
    super.initState();
    _selected = widget.selectedKey;
    _load();
  }

  Future<void> _load() async {
    if (!AuthService.isLoggedIn) {
      setState(() => _loading = false);
      return;
    }
    try {
      final rows = await Api.growth.addresses();
      if (!mounted) return;
      setState(() => _items = rows);
      // اختيار العنوان الافتراضي تلقائياً إن لم يُختر شيء بعد
      if (_selected == null && rows.isNotEmpty) {
        final def = rows.firstWhere((e) => e['is_default'] == true, orElse: () => rows.first);
        _choose(def);
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _choose(Map<String, dynamic> a, {String? key}) {
    HapticFeedback.selectionClick();
    setState(() => _selected = key ?? '${a['id']}');
    widget.onChanged({
      'label': a['label'],
      'address_line': a['address_line'],
      'city': a['city'],
      'district': a['district'],
      'latitude': numOf(a['latitude']),
      'longitude': numOf(a['longitude']),
    });
  }

  Future<void> _useGps(String lang) async {
    setState(() => _locating = true);
    try {
      final loc = await LocationService.getCurrentLocation(saveAsDefault: false);
      if (loc == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(L(lang, 'فعّل الموقع والسماح للتطبيق باستخدامه', 'Enable location and allow the app to use it')),
          ));
        }
        return;
      }
      Map<String, dynamic> a = {'label': L(lang, 'موقعي الحالي', 'My location'), 'latitude': loc.lat, 'longitude': loc.lng};
      try {
        final rows = await Api.growth.geocode(lat: loc.lat, lng: loc.lng, lang: lang);
        if (rows.isNotEmpty) {
          a = {...a, 'address_line': rows.first['address'], 'city': rows.first['city'], 'district': rows.first['district']};
        }
      } catch (_) {}
      if (!mounted) return;
      setState(() => _custom = a);
      _choose(a, key: 'gps');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _addNew() async {
    final r = await pickAddress(context);
    if (r == null || !mounted) return;
    if (r['id'] != null) {
      setState(() => _items = [r, ..._items.where((e) => '${e['id']}' != '${r['id']}')]);
      _choose(r);
    } else {
      setState(() => _custom = r);
      _choose(r, key: 'new');
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppSettingsProvider>().language;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_loading)
          const RastSkeleton(height: 72, radius: 18)
        else
          ..._items.map((a) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _option(
                  key: '${a['id']}',
                  icon: addressIcon(a['label']?.toString()),
                  title: a['label']?.toString() ?? '',
                  subtitle: addressSubtitle(a),
                  onTap: () => _choose(a),
                ),
              )),
        if (_custom != null && (_selected == 'gps' || _selected == 'new'))
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _option(
              key: _selected!,
              icon: _selected == 'gps' ? Icons.my_location_rounded : Icons.place_rounded,
              title: _custom!['label']?.toString() ?? '',
              subtitle: addressSubtitle(_custom!),
              onTap: () {},
            ),
          ),
        Row(
          children: [
            Expanded(
              child: _action(
                icon: Icons.my_location_rounded,
                label: L(lang, 'موقعي الحالي', 'My location'),
                busy: _locating,
                onTap: () => _useGps(lang),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _action(
                icon: Icons.add_location_alt_rounded,
                label: L(lang, 'عنوان جديد', 'New address'),
                onTap: _addNew,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _option({
    required String key,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final on = _selected == key;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: on ? RastTokens.brandSoft(context) : RastTokens.card(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: on ? RastTokens.brand : RastTokens.line(context), width: on ? 1.6 : 1),
        ),
        child: Row(
          children: [
            RastIconBox(icon: icon, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, color: RastTokens.ink(context))),
                  if (subtitle.isNotEmpty)
                    Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: RastTokens.muted(context))),
                ],
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                on ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                key: ValueKey(on),
                color: on ? RastTokens.brand : RastTokens.muted(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _action({required IconData icon, required String label, required VoidCallback onTap, bool busy = false}) {
    return OutlinedButton.icon(
      onPressed: busy ? null : onTap,
      icon: busy
          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
          : Icon(icon, size: 18),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        foregroundColor: RastTokens.brand,
        minimumSize: const Size.fromHeight(46),
        side: BorderSide(color: RastTokens.brand.withValues(alpha: 0.3)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
