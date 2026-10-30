import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:rast/core/api/api_client.dart';
import 'package:rast/core/api/api_services.dart';
import 'package:rast/core/providers/app_settings_provider.dart';
import 'package:rast/core/services/location_service.dart';
import 'package:rast/core/widgets/rast_kit.dart';
import 'package:rast/features/auth/services/auth_service.dart';

/// اختيار عنوان على الخريطة: دبوس ثابت في المنتصف، بحث عن مكان، تعبئة المدينة والحي تلقائياً،
/// واسم للعنوان (البيت/العمل/…). يُرجع العنوان المحفوظ (أو غير المحفوظ للزائر) عبر Navigator.pop.
class AddressPickerScreen extends StatefulWidget {
  const AddressPickerScreen({super.key, this.initial, this.saveToAccount = true});

  /// عنوان موجود للتعديل (يحمل id) أو null لإضافة عنوان جديد
  final Map<String, dynamic>? initial;

  /// حفظ العنوان في الحساب (يتجاهل عند عدم تسجيل الدخول)
  final bool saveToAccount;

  @override
  State<AddressPickerScreen> createState() => _AddressPickerScreenState();
}

class _AddressPickerScreenState extends State<AddressPickerScreen> {
  static const _riyadh = LatLng(24.7136, 46.6753);

  GoogleMapController? _map;
  LatLng _center = _riyadh;
  bool _moving = false;
  bool _resolving = false;
  bool _saving = false;
  Timer? _searchDebounce;
  List<Map<String, dynamic>> _results = [];

  final _search = TextEditingController();
  final _line = TextEditingController();
  final _customLabel = TextEditingController();
  final _notes = TextEditingController();
  String _city = '';
  String _district = '';
  String _resolvedAddress = '';
  String _labelKey = 'home';
  bool _isDefault = false;

  String get _lang => context.read<AppSettingsProvider>().language;
  bool get _editing => widget.initial?['id'] != null;

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    if (init != null) {
      final lat = numOf(init['latitude']);
      final lng = numOf(init['longitude']);
      if (lat != null && lng != null) _center = LatLng(lat, lng);
      _line.text = init['address_line']?.toString() ?? '';
      _notes.text = init['notes']?.toString() ?? '';
      _city = init['city']?.toString() ?? '';
      _district = init['district']?.toString() ?? '';
      _isDefault = init['is_default'] == true;
      final label = init['label']?.toString() ?? '';
      if (label == 'البيت' || label == 'Home') {
        _labelKey = 'home';
      } else if (label == 'العمل' || label == 'Work') {
        _labelKey = 'work';
      } else if (label.isNotEmpty) {
        _labelKey = 'other';
        _customLabel.text = label;
      }
    } else {
      _initCenter();
    }
  }

  Future<void> _initCenter() async {
    final saved = await LocationService.getDefaultLocation();
    if (saved != null && mounted) {
      _moveTo(LatLng(saved.lat, saved.lng), animate: false);
    }
    _resolve();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _search.dispose();
    _line.dispose();
    _customLabel.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _moveTo(LatLng p, {bool animate = true}) {
    setState(() => _center = p);
    final update = CameraUpdate.newLatLngZoom(p, 16.5);
    if (animate) {
      _map?.animateCamera(update);
    } else {
      _map?.moveCamera(update);
    }
  }

  Future<void> _resolve() async {
    setState(() => _resolving = true);
    try {
      final rows = await Api.growth.geocode(lat: _center.latitude, lng: _center.longitude, lang: _lang);
      if (!mounted) return;
      if (rows.isNotEmpty) {
        final r = rows.first;
        setState(() {
          _resolvedAddress = r['address']?.toString() ?? '';
          _city = r['city']?.toString() ?? _city;
          _district = r['district']?.toString() ?? _district;
        });
      }
    } catch (_) {
      // البحث العكسي اختياري: يبقى المستخدم قادراً على الحفظ بالموقع وحده
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  void _onSearchChanged(String q) {
    _searchDebounce?.cancel();
    if (q.trim().length < 2) {
      setState(() => _results = []);
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 450), () async {
      try {
        final rows = await Api.growth.geocode(query: q.trim(), lang: _lang);
        if (mounted && _search.text.trim() == q.trim()) setState(() => _results = rows);
      } catch (_) {}
    });
  }

  Future<void> _useMyLocation() async {
    final loc = await LocationService.getCurrentLocation(saveAsDefault: false);
    if (!mounted) return;
    if (loc == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(L(_lang, 'فعّل الموقع والسماح للتطبيق باستخدامه', 'Enable location and allow the app to use it')),
      ));
      return;
    }
    _moveTo(LatLng(loc.lat, loc.lng));
  }

  String _labelText() => switch (_labelKey) {
        'home' => L(_lang, 'البيت', 'Home'),
        'work' => L(_lang, 'العمل', 'Work'),
        _ => _customLabel.text.trim().isEmpty ? L(_lang, 'عنوان آخر', 'Other') : _customLabel.text.trim(),
      };

  Future<void> _save() async {
    final line = _line.text.trim().isNotEmpty ? _line.text.trim() : _resolvedAddress;
    final body = <String, dynamic>{
      'label': _labelText(),
      'city': _city.isEmpty ? null : _city,
      'district': _district.isEmpty ? null : _district,
      'address_line': line.isEmpty ? null : (line.length > 250 ? line.substring(0, 250) : line),
      'latitude': double.parse(_center.latitude.toStringAsFixed(7)),
      'longitude': double.parse(_center.longitude.toStringAsFixed(7)),
      'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      'is_default': _isDefault,
    };

    if (!widget.saveToAccount || !AuthService.isLoggedIn) {
      HapticFeedback.lightImpact();
      Navigator.pop(context, body);
      return;
    }

    setState(() => _saving = true);
    try {
      final saved = _editing
          ? await Api.growth.updateAddress(int.parse('${widget.initial!['id']}'), body)
          : await Api.growth.createAddress(body);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.pop(context, saved.isEmpty ? body : saved);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(L(_lang, 'تعذّر حفظ العنوان، حاول مرة أخرى', 'Could not save the address'))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();
    final lang = settings.language;
    final top = MediaQuery.paddingOf(context).top;

    return Directionality(
      textDirection: settings.textDirection,
      child: Scaffold(
        backgroundColor: RastTokens.bg(context),
        resizeToAvoidBottomInset: true,
        body: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: CameraPosition(target: _center, zoom: 15.5),
                    onMapCreated: (c) => _map = c,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                    compassEnabled: false,
                    onCameraMoveStarted: () => setState(() {
                      _moving = true;
                      _results = [];
                    }),
                    onCameraMove: (p) => _center = p.target,
                    onCameraIdle: () {
                      if (!_moving) return;
                      setState(() => _moving = false);
                      _resolve();
                    },
                  ),
                  // الدبوس الثابت في المنتصف (يرتفع أثناء التحريك)
                  IgnorePointer(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 44),
                        child: AnimatedSlide(
                          duration: const Duration(milliseconds: 180),
                          offset: Offset(0, _moving ? -0.25 : 0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  gradient: RastTokens.brandGradient,
                                  shape: BoxShape.circle,
                                  boxShadow: [BoxShadow(color: RastTokens.brand.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 6))],
                                ),
                                child: const Icon(Icons.home_rounded, color: Colors.white, size: 22),
                              ),
                              Container(width: 3, height: 16, color: RastTokens.brand),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  IgnorePointer(
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: _moving ? 10 : 6,
                        height: _moving ? 4 : 3,
                        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                  ),
                  // الرأس: رجوع + بحث
                  Positioned(
                    top: top + 10,
                    left: 12,
                    right: 12,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            _roundButton(
                              icon: settings.isArabic ? Icons.arrow_forward_ios_rounded : Icons.arrow_back_ios_new_rounded,
                              onTap: () => Navigator.maybePop(context),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: RastSearchField(
                                hint: L(lang, 'ابحث عن حي، شارع أو مكان…', 'Search a district, street or place…'),
                                controller: _search,
                                onChanged: _onSearchChanged,
                                onDark: true,
                                trailing: _search.text.isEmpty
                                    ? null
                                    : IconButton(
                                        icon: const Icon(Icons.close_rounded, size: 20),
                                        onPressed: () => setState(() {
                                          _search.clear();
                                          _results = [];
                                        }),
                                      ),
                              ),
                            ),
                          ],
                        ),
                        if (_results.isNotEmpty) _buildResults(lang),
                      ],
                    ),
                  ),
                  PositionedDirectional(
                    end: 14,
                    bottom: 14,
                    child: _roundButton(icon: Icons.my_location_rounded, onTap: _useMyLocation, accent: true),
                  ),
                ],
              ),
            ),
            _buildPanel(lang),
          ],
        ),
      ),
    );
  }

  Widget _roundButton({required IconData icon, required VoidCallback onTap, bool accent = false}) {
    return Material(
      color: RastTokens.card(context),
      shape: const CircleBorder(),
      elevation: 4,
      shadowColor: Colors.black26,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon, color: accent ? RastTokens.brand : RastTokens.ink(context), size: 20),
        ),
      ),
    );
  }

  Widget _buildResults(String lang) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      constraints: const BoxConstraints(maxHeight: 260),
      decoration: BoxDecoration(
        color: RastTokens.card(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: RastTokens.shadow(context, strength: 2),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 6),
        itemCount: _results.length,
        separatorBuilder: (_, __) => Divider(height: 1, color: RastTokens.line(context)),
        itemBuilder: (_, i) {
          final r = _results[i];
          return ListTile(
            dense: true,
            leading: const Icon(Icons.place_outlined, color: RastTokens.brand),
            title: Text(r['address']?.toString() ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
            onTap: () {
              final lat = numOf(r['latitude']);
              final lng = numOf(r['longitude']);
              FocusScope.of(context).unfocus();
              setState(() {
                _results = [];
                _resolvedAddress = r['address']?.toString() ?? _resolvedAddress;
                _city = r['city']?.toString() ?? _city;
                _district = r['district']?.toString() ?? _district;
              });
              if (lat != null && lng != null) _moveTo(LatLng(lat, lng));
            },
          );
        },
      ),
    );
  }

  Widget _buildPanel(String lang) {
    final place = [_district, _city].where((e) => e.trim().isNotEmpty).join('، ');
    return Container(
      decoration: BoxDecoration(
        color: RastTokens.card(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 18, offset: const Offset(0, -4))],
      ),
      padding: EdgeInsets.fromLTRB(16, 16, 16, 12 + MediaQuery.paddingOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const RastIconBox(icon: Icons.location_on_rounded, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        place.isEmpty ? L(lang, 'حرّك الخريطة لتحديد الموقع', 'Move the map to set the spot') : place,
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: RastTokens.ink(context)),
                      ),
                      const SizedBox(height: 2),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Text(
                          _resolving ? L(lang, 'جارٍ تحديد العنوان…', 'Finding the address…') : (_resolvedAddress.isEmpty ? '—' : _resolvedAddress),
                          key: ValueKey('$_resolving$_resolvedAddress'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: RastTokens.muted(context)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _labelChip('home', Icons.home_rounded, L(lang, 'البيت', 'Home')),
                _labelChip('work', Icons.work_rounded, L(lang, 'العمل', 'Work')),
                _labelChip('other', Icons.bookmark_rounded, L(lang, 'أخرى', 'Other')),
              ],
            ),
            if (_labelKey == 'other') ...[
              const SizedBox(height: 10),
              _field(_customLabel, L(lang, 'اسم العنوان (مثلاً: بيت أهلي)', 'Address name (e.g. Parents)'), Icons.edit_rounded),
            ],
            const SizedBox(height: 10),
            _field(_line, L(lang, 'تفاصيل: المبنى، الشقة، أقرب معلم', 'Details: building, flat, landmark'), Icons.apartment_rounded),
            const SizedBox(height: 10),
            _field(_notes, L(lang, 'ملاحظة لفريق السحب (اختياري)', 'Note for the collection team (optional)'), Icons.sticky_note_2_outlined),
            if (AuthService.isLoggedIn && widget.saveToAccount)
              CheckboxListTile(
                value: _isDefault,
                onChanged: (v) => setState(() => _isDefault = v ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: RastTokens.brand,
                title: Text(L(lang, 'اجعله عنواني الافتراضي', 'Make it my default address'), style: const TextStyle(fontSize: 13.5)),
              ),
            const SizedBox(height: 6),
            RastButton(
              label: _editing ? L(lang, 'حفظ التعديلات', 'Save changes') : L(lang, 'تأكيد العنوان', 'Confirm address'),
              icon: Icons.check_rounded,
              loading: _saving,
              onPressed: _moving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }

  Widget _labelChip(String key, IconData icon, String label) {
    final on = _labelKey == key;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _labelKey = key);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          gradient: on ? RastTokens.brandGradient : null,
          color: on ? null : RastTokens.fill(context),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: on ? Colors.white : RastTokens.brand),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: on ? Colors.white : RastTokens.ink(context), fontWeight: FontWeight.w700, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String hint, IconData icon) {
    return TextField(
      controller: c,
      maxLength: 250,
      style: TextStyle(fontSize: 14, color: RastTokens.ink(context)),
      decoration: InputDecoration(
        counterText: '',
        hintText: hint,
        hintStyle: TextStyle(fontSize: 13, color: RastTokens.muted(context)),
        prefixIcon: Icon(icon, size: 20, color: RastTokens.brand),
        filled: true,
        fillColor: RastTokens.fill(context),
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: RastTokens.brand)),
      ),
    );
  }
}
