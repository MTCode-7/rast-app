import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:rast/core/api/api_client.dart';
import 'package:rast/core/api/api_services.dart';
import 'package:rast/core/providers/app_settings_provider.dart';
import 'package:rast/core/services/analytics_service.dart';
import 'package:rast/core/services/location_service.dart';
import 'package:rast/core/widgets/rast_kit.dart';
import 'package:rast/features/lab_details/screens/lab_details_screen.dart';
import 'package:rast/features/map/widgets/map_marker_painter.dart';
import 'package:url_launcher/url_launcher.dart';

/// خريطة المختبرات: دبوس لكل فرع يحمل السعر (أو سعر التحليل المختار)، تجميع عند التصغير،
/// فلاتر أعلى الخريطة، وبطاقات أسفلها تتزامن مع الدبوس المختار.
class LabsMapScreen extends StatefulWidget {
  const LabsMapScreen({super.key, this.serviceId, this.serviceName});

  /// فتح الخريطة على تحليل معيّن: الدبابيس تعرض سعر هذا التحليل لدى كل مختبر
  final int? serviceId;
  final String? serviceName;

  @override
  State<LabsMapScreen> createState() => _LabsMapScreenState();
}

class _LabsMapScreenState extends State<LabsMapScreen> {
  static const _riyadh = LatLng(24.7136, 46.6753);

  GoogleMapController? _map;
  final _pages = PageController(viewportFraction: 0.86);

  List<Map<String, dynamic>> _pins = [];
  bool _loading = true;
  String? _error;

  int? _serviceId;
  String? _serviceName;
  bool _homeOnly = false;
  bool _offersOnly = false;
  bool _topRated = false;
  bool _openNow = false;

  LatLng? _origin; // موقع المستخدم/الافتراضي لحساب المسافة والترتيب
  double _zoom = 11.5;
  String? _selectedId;
  Set<Marker> _markers = {};
  int _markersVersion = 0;
  bool _programmaticPage = false;

  String get _lang => context.read<AppSettingsProvider>().language;

  @override
  void initState() {
    super.initState();
    _serviceId = widget.serviceId;
    _serviceName = widget.serviceName;
    AnalyticsService.logScreen('labs_map');
    _init();
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final saved = await LocationService.getDefaultLocation();
    if (saved != null) _origin = LatLng(saved.lat, saved.lng);
    await _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await Api.growth.mapLabs(
        serviceId: _serviceId,
        homeService: _homeOnly,
        hasOffer: _offersOnly,
        minRating: _topRated ? 4 : null,
      );
      if (!mounted) return;
      setState(() {
        _pins = rows;
        _selectedId = null;
      });
      await _rebuildMarkers();
      _fitToPins();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = L(_lang, 'تعذّر تحميل الخريطة. تحقق من الاتصال.', 'Could not load the map. Check your connection.'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---------------- البيانات المعروضة ----------------

  LatLng _pos(Map<String, dynamic> p) => LatLng(numOf(p['latitude']) ?? 0, numOf(p['longitude']) ?? 0);

  double? _distanceKm(Map<String, dynamic> p) {
    final o = _origin;
    if (o == null) return null;
    final d = _pos(p);
    return Geolocator.distanceBetween(o.latitude, o.longitude, d.latitude, d.longitude) / 1000;
  }

  /// الدبابيس بعد الفلاتر المحلية (مفتوح الآن)، مرتبة حسب القرب
  List<Map<String, dynamic>> get _visible {
    final list = _pins.where((p) => !_openNow || p['open_now'] == true).toList();
    if (_origin != null) {
      list.sort((a, b) => (_distanceKm(a) ?? 0).compareTo(_distanceKm(b) ?? 0));
    }
    return list;
  }

  String _pinText(Map<String, dynamic> p) {
    final price = numOf(p['price']);
    if (price != null && price > 0) return '${fmtPrice(price)} ${L(_lang, 'ر.س', 'SAR')}';
    final rating = numOf(p['rating']) ?? 0;
    return rating > 0 ? '★ ${rating.toStringAsFixed(1)}' : L(_lang, 'مختبر', 'Lab');
  }

  // ---------------- العلامات والتجميع ----------------

  Future<void> _rebuildMarkers() async {
    final version = ++_markersVersion;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final visible = _visible;
    final markers = <Marker>{};

    // تجميع بسيط حسب شبكة تتصغّر مع التكبير (ينفك تماماً عند تكبير 13 فأكثر)
    final cell = _zoom >= 13 ? 0.0 : 0.9 / math.pow(2, _zoom - 8);
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final p in visible) {
      final pos = _pos(p);
      final key = cell == 0 || p['id'] == _selectedId
          ? 'i${p['id']}'
          : '${(pos.latitude / cell).floor()}:${(pos.longitude / cell).floor()}';
      groups.putIfAbsent(key, () => []).add(p);
    }

    for (final entry in groups.entries) {
      final items = entry.value;
      if (items.length > 1) {
        final lat = items.map((e) => _pos(e).latitude).reduce((a, b) => a + b) / items.length;
        final lng = items.map((e) => _pos(e).longitude).reduce((a, b) => a + b) / items.length;
        final icon = await MapMarkerPainter.cluster(count: items.length, dpr: dpr);
        markers.add(Marker(
          markerId: MarkerId('c-${entry.key}'),
          position: LatLng(lat, lng),
          icon: icon,
          anchor: const Offset(0.5, 0.5),
          zIndexInt: 1,
          onTap: () => _map?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(lat, lng), math.min(16, _zoom + 2.2))),
        ));
        continue;
      }
      final p = items.first;
      final selected = p['id'] == _selectedId;
      final icon = await MapMarkerPainter.pill(
        text: _pinText(p),
        selected: selected,
        offer: p['has_offer'] == true,
        dimmed: p['open_now'] == false,
        dpr: dpr,
      );
      markers.add(Marker(
        markerId: MarkerId('${p['id']}'),
        position: _pos(p),
        icon: icon,
        anchor: const Offset(0.5, 1),
        zIndexInt: selected ? 3 : 2,
        onTap: () => _select(p, fromMarker: true),
      ));
    }

    if (!mounted || version != _markersVersion) return;
    setState(() => _markers = markers);
  }

  void _fitToPins() {
    final pins = _visible;
    if (_map == null) return;
    if (pins.isEmpty) {
      _map!.animateCamera(CameraUpdate.newLatLngZoom(_origin ?? _riyadh, 11));
      return;
    }
    // نركّز على أقرب المختبرات للمستخدم (حتى 8) بدل كل المملكة
    final near = pins.take(8).map(_pos).toList();
    if (_origin != null) near.add(_origin!);
    if (near.length == 1) {
      _map!.animateCamera(CameraUpdate.newLatLngZoom(near.first, 14));
      return;
    }
    var sw = near.first, ne = near.first;
    for (final p in near) {
      sw = LatLng(math.min(sw.latitude, p.latitude), math.min(sw.longitude, p.longitude));
      ne = LatLng(math.max(ne.latitude, p.latitude), math.max(ne.longitude, p.longitude));
    }
    _map!.animateCamera(CameraUpdate.newLatLngBounds(LatLngBounds(southwest: sw, northeast: ne), 70));
  }

  void _select(Map<String, dynamic> p, {bool fromMarker = false}) {
    HapticFeedback.selectionClick();
    setState(() => _selectedId = '${p['id']}');
    _rebuildMarkers();
    _map?.animateCamera(CameraUpdate.newLatLngZoom(_pos(p), math.max(_zoom, 14)));
    if (fromMarker) {
      final i = _visible.indexWhere((e) => '${e['id']}' == '${p['id']}');
      if (i >= 0 && _pages.hasClients) {
        _programmaticPage = true;
        _pages.animateToPage(i, duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic)
            .whenComplete(() => _programmaticPage = false);
      }
    }
  }

  Future<void> _myLocation() async {
    final loc = await LocationService.getCurrentLocation(saveAsDefault: false);
    if (!mounted) return;
    if (loc == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(L(_lang, 'فعّل الموقع والسماح للتطبيق باستخدامه', 'Enable location and allow the app to use it')),
      ));
      return;
    }
    setState(() => _origin = LatLng(loc.lat, loc.lng));
    _map?.animateCamera(CameraUpdate.newLatLngZoom(_origin!, 13.5));
    _rebuildMarkers();
  }

  Future<void> _openLab(Map<String, dynamic> p) async {
    final id = int.tryParse('${p['provider_id']}');
    if (id == null) return;
    Map<String, dynamic> lab = {
      'id': id,
      'business_name_ar': p['name_ar'],
      'business_name_en': p['name_en'],
      'logo_url': p['logo_url'],
      'avg_rating': p['rating'],
      'total_reviews': p['reviews_count'],
      'home_service_available': p['home_service'],
      'city': p['city'],
      'district': p['district'],
      'latitude': p['latitude'],
      'longitude': p['longitude'],
    };
    try {
      final full = await Api.providers.getProvider(id);
      lab = {...lab, ...full};
    } catch (_) {
      // نفتح بالبيانات المختصرة؛ صفحة المختبر تكمل التحميل بنفسها
    }
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => LabDetailsScreen(lab: lab)));
  }

  Future<void> _directions(Map<String, dynamic> p) async {
    final pos = _pos(p);
    final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${pos.latitude},${pos.longitude}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _pickTest() async {
    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _TestSearchSheet(),
    );
    if (picked == null) return;
    setState(() {
      _serviceId = int.tryParse('${picked['id']}');
      _serviceName = picked['name']?.toString();
    });
    _load();
  }

  // ---------------- الواجهة ----------------

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();
    final lang = settings.language;
    final top = MediaQuery.paddingOf(context).top;
    final visible = _visible;

    return Directionality(
      textDirection: settings.textDirection,
      child: Scaffold(
        backgroundColor: RastTokens.bg(context),
        body: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(target: _origin ?? _riyadh, zoom: _zoom),
              onMapCreated: (c) {
                _map = c;
                if (!_loading) _fitToPins();
              },
              markers: _markers,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              compassEnabled: false,
              padding: EdgeInsets.only(top: top + 120, bottom: visible.isEmpty ? 20 : 190),
              onCameraMove: (p) {
                final crossed = (p.zoom >= 13) != (_zoom >= 13) || (p.zoom - _zoom).abs() > 0.8;
                _zoom = p.zoom;
                if (crossed) _rebuildMarkers();
              },
              onCameraIdle: _rebuildMarkers,
              onTap: (_) {
                if (_selectedId != null) {
                  setState(() => _selectedId = null);
                  _rebuildMarkers();
                }
              },
            ),

            // الرأس: رجوع + اختيار تحليل + فلاتر
            Positioned(
              top: top + 10,
              left: 0,
              right: 0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        _circleButton(
                          settings.isArabic ? Icons.arrow_forward_ios_rounded : Icons.arrow_back_ios_new_rounded,
                          () => Navigator.maybePop(context),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: RastSearchField(
                            hint: _serviceName ?? L(lang, 'ابحث عن تحليل لترى سعره على الخريطة', 'Search a test to see its price on the map'),
                            onTap: _pickTest,
                            onDark: true,
                            trailing: _serviceId == null
                                ? null
                                : IconButton(
                                    tooltip: L(lang, 'إزالة التحليل', 'Clear test'),
                                    icon: const Icon(Icons.close_rounded, size: 20),
                                    onPressed: () {
                                      setState(() {
                                        _serviceId = null;
                                        _serviceName = null;
                                      });
                                      _load();
                                    },
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 38,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                        _filterChip(L(lang, 'سحب منزلي', 'Home collection'), Icons.home_rounded, _homeOnly, () {
                          setState(() => _homeOnly = !_homeOnly);
                          _load();
                        }),
                        _filterChip(L(lang, 'فيه عرض', 'Has offer'), Icons.local_offer_rounded, _offersOnly, () {
                          setState(() => _offersOnly = !_offersOnly);
                          _load();
                        }),
                        _filterChip(L(lang, 'الأعلى تقييماً', 'Top rated'), Icons.star_rounded, _topRated, () {
                          setState(() => _topRated = !_topRated);
                          _load();
                        }),
                        _filterChip(L(lang, 'مفتوح الآن', 'Open now'), Icons.schedule_rounded, _openNow, () {
                          setState(() {
                            _openNow = !_openNow;
                            _selectedId = null;
                          });
                          _rebuildMarkers();
                        }),
                      ],
                    ),
                  ),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(60, 10, 60, 0),
                      child: LinearProgressIndicator(minHeight: 3, color: RastTokens.brand),
                    ),
                ],
              ),
            ),

            // زر موقعي
            PositionedDirectional(
              end: 14,
              bottom: visible.isEmpty ? 24 : 200,
              child: _circleButton(Icons.my_location_rounded, _myLocation, accent: true),
            ),

            // البطاقات أو الحالات
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildBottom(lang, visible),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottom(String lang, List<Map<String, dynamic>> visible) {
    if (_error != null) {
      return _messageCard(Icons.wifi_off_rounded, _error!, L(lang, 'إعادة المحاولة', 'Retry'), _load);
    }
    if (!_loading && visible.isEmpty) {
      return _messageCard(
        Icons.location_off_rounded,
        L(lang, 'لا توجد مختبرات تطابق الفلاتر', 'No labs match these filters'),
        L(lang, 'إزالة الفلاتر', 'Clear filters'),
        () {
          setState(() {
            _homeOnly = _offersOnly = _topRated = _openNow = false;
            _serviceId = null;
            _serviceName = null;
          });
          _load();
        },
      );
    }
    if (visible.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 178,
      child: PageView.builder(
        controller: _pages,
        itemCount: visible.length,
        onPageChanged: (i) {
          if (_programmaticPage) return;
          _select(visible[i]);
        },
        itemBuilder: (_, i) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: _labCard(visible[i], lang),
        ),
      ),
    );
  }

  Widget _labCard(Map<String, dynamic> p, String lang) {
    final selected = '${p['id']}' == _selectedId;
    final km = _distanceKm(p);
    final rating = numOf(p['rating']) ?? 0;
    final price = numOf(p['price']);
    final name = lang == 'en' ? (p['name_en'] ?? p['name_ar']) : p['name_ar'];
    final branch = p['branch_name']?.toString();
    final place = [p['district'], p['city']].map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).join('، ');

    Widget meta(IconData icon, Color color, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 3),
            Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: RastTokens.ink(context))),
          ],
        );

    return AnimatedScale(
      scale: selected || _selectedId == null ? 1 : 0.95,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(RastTokens.radius + 2),
          border: Border.all(color: selected ? RastTokens.brand : Colors.transparent, width: 2),
        ),
        child: RastCard(
          onTap: () => _select(p),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 3))],
                    ),
                    child: RastNetImage(url: p['logo_url']?.toString(), radius: 12, fit: BoxFit.contain, fallbackIcon: Icons.apartment_rounded),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$name', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5, color: RastTokens.ink(context))),
                        const SizedBox(height: 2),
                        Text(
                          [if (branch != null && branch.isNotEmpty && branch != name) branch, place].where((e) => e.isNotEmpty).join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: RastTokens.muted(context), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  if (price != null && price > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: RastTokens.brandSoft(context),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: RastPrice(amount: price, lang: lang, from: p['price_is_service'] != true, size: 15, crossAxisAlignment: CrossAxisAlignment.end),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  meta(Icons.star_rounded, RastTokens.gold, rating > 0 ? '${rating.toStringAsFixed(1)} (${p['reviews_count'] ?? 0})' : L(lang, 'جديد', 'New')),
                  if (km != null) meta(Icons.near_me_rounded, RastTokens.brand2, km < 1 ? '${(km * 1000).round()} ${L(lang, 'م', 'm')}' : '${km.toStringAsFixed(1)} ${L(lang, 'كم', 'km')}'),
                  if (p['open_now'] == true) meta(Icons.circle, RastTokens.success, L(lang, 'مفتوح الآن', 'Open now')),
                  if (p['open_now'] == false) meta(Icons.circle, RastTokens.danger, L(lang, 'مغلق الآن', 'Closed')),
                  if (p['home_service'] == true) meta(Icons.home_rounded, RastTokens.success, L(lang, 'سحب منزلي', 'Home')),
                  if (p['has_offer'] == true) meta(Icons.local_offer_rounded, RastTokens.danger, L(lang, 'عرض', 'Deal')),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: RastButton(label: L(lang, 'عرض المختبر', 'View lab'), height: 42, onPressed: () => _openLab(p)),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 48,
                    height: 42,
                    child: Material(
                      color: RastTokens.brandSoft(context),
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => _directions(p),
                        child: const Icon(Icons.directions_rounded, size: 21, color: RastTokens.brand),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _messageCard(IconData icon, String text, String action, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: RastCard(
        child: Row(
          children: [
            RastIconBox(icon: icon, size: 42),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: TextStyle(fontWeight: FontWeight.w700, color: RastTokens.ink(context)))),
            TextButton(onPressed: onTap, child: Text(action)),
          ],
        ),
      ),
    );
  }

  Widget _circleButton(IconData icon, VoidCallback onTap, {bool accent = false}) {
    return Material(
      color: RastTokens.card(context),
      shape: const CircleBorder(),
      elevation: 4,
      shadowColor: Colors.black26,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(width: 48, height: 48, child: Icon(icon, size: 20, color: accent ? RastTokens.brand : RastTokens.ink(context))),
      ),
    );
  }

  Widget _filterChip(String label, IconData icon, bool on, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            gradient: on ? RastTokens.brandGradient : null,
            color: on ? null : RastTokens.card(context),
            borderRadius: BorderRadius.circular(999),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 8, offset: const Offset(0, 3))],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: on ? Colors.white : RastTokens.brand),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: on ? Colors.white : RastTokens.ink(context))),
            ],
          ),
        ),
      ),
    );
  }
}

/// ورقة البحث عن تحليل لتصفية الخريطة به
class _TestSearchSheet extends StatefulWidget {
  const _TestSearchSheet();

  @override
  State<_TestSearchSheet> createState() => _TestSearchSheetState();
}

class _TestSearchSheetState extends State<_TestSearchSheet> {
  final _q = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _rows = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _q.dispose();
    super.dispose();
  }

  void _search(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      setState(() => _loading = true);
      try {
        final res = await Api.services.getServices(search: q.trim().isEmpty ? null : q.trim(), perPage: 25);
        final data = res['data'];
        final list = data is Map ? data['data'] : data;
        if (!mounted || _q.text != q) return;
        setState(() => _rows = list is List ? list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : []);
      } catch (_) {
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();
    final lang = settings.language;
    return Directionality(
      textDirection: settings.textDirection,
      child: Container(
        height: MediaQuery.sizeOf(context).height * 0.8,
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        decoration: BoxDecoration(
          color: RastTokens.bg(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(width: 42, height: 4, decoration: BoxDecoration(color: RastTokens.line(context), borderRadius: BorderRadius.circular(4))),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: RastSearchField(
                hint: L(lang, 'اسم التحليل: فيتامين د، صورة الدم…', 'Test name: Vitamin D, CBC…'),
                controller: _q,
                autofocus: true,
                onChanged: _search,
              ),
            ),
            if (_loading) const LinearProgressIndicator(minHeight: 2, color: RastTokens.brand),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                itemCount: _rows.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final s = _rows[i];
                  final name = lang == 'en' ? (s['name_en'] ?? s['name_ar']) : s['name_ar'];
                  final price = numOf(s['min_price']) ?? numOf(s['price']);
                  final labs = numOf(s['labs_count'])?.toInt();
                  final available = labs == null ? (price != null && price > 0) : labs > 0;
                  return Opacity(
                    opacity: available ? 1 : 0.5,
                    child: RastCard(
                      padding: const EdgeInsets.all(10),
                      onTap: available ? () => Navigator.pop(context, {'id': s['id'], 'name': '$name'}) : null,
                      child: Row(
                        children: [
                          RastNetImage(url: s['image_url']?.toString(), width: 46, height: 46, radius: 12),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('$name', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, color: RastTokens.ink(context))),
                                if (labs != null && labs > 0)
                                  Text(L(lang, 'متوفر لدى $labs مختبرات', 'At $labs labs'), style: TextStyle(fontSize: 12, color: RastTokens.muted(context))),
                              ],
                            ),
                          ),
                          RastPrice(amount: available ? price : null, lang: lang, from: true, size: 14, crossAxisAlignment: CrossAxisAlignment.end),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
