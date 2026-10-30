import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:rast/core/api/api_client.dart';
import 'package:rast/core/api/api_services.dart';
import 'package:rast/core/providers/app_settings_provider.dart';
import 'package:rast/core/services/app_events.dart';
import 'package:rast/core/services/location_service.dart';
import 'package:rast/core/widgets/rast_kit.dart';
import 'package:rast/core/widgets/rast_motion.dart';
import 'package:rast/core/widgets/rast_ui.dart';
import 'package:rast/features/addresses/screens/address_picker_screen.dart';
import 'package:rast/features/auth/screens/login_screen.dart';
import 'package:rast/features/auth/services/auth_service.dart';

/// يفتح منتقي العنوان ويُرجع العنوان المختار/المحفوظ (للحجز المنزلي وغيره).
Future<Map<String, dynamic>?> pickAddress(
  BuildContext context, {
  Map<String, dynamic>? initial,
  bool saveToAccount = true,
}) {
  return Navigator.push<Map<String, dynamic>>(
    context,
    MaterialPageRoute(builder: (_) => AddressPickerScreen(initial: initial, saveToAccount: saveToAccount)),
  );
}

IconData addressIcon(String? label) {
  final l = (label ?? '').trim();
  if (l == 'البيت' || l.toLowerCase() == 'home') return Icons.home_rounded;
  if (l == 'العمل' || l.toLowerCase() == 'work') return Icons.work_rounded;
  return Icons.bookmark_rounded;
}

String addressSubtitle(Map<String, dynamic> a) {
  final parts = [a['address_line'], a['district'], a['city']]
      .map((e) => e?.toString().trim() ?? '')
      .where((e) => e.isNotEmpty)
      .toSet()
      .toList();
  return parts.join('، ');
}

/// «عناويني»: قائمة العناوين المحفوظة مع العنوان الافتراضي، تعديل، حذف، واستخدامه كموقع للتصفح.
class AddressesScreen extends StatefulWidget {
  const AddressesScreen({super.key});

  @override
  State<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends State<AddressesScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!AuthService.isLoggedIn) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = _items.isEmpty;
      _error = null;
    });
    try {
      final rows = await Api.growth.addresses();
      if (mounted) setState(() => _items = rows);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _add() async {
    final r = await pickAddress(context);
    if (r != null) _load();
  }

  Future<void> _edit(Map<String, dynamic> a) async {
    final r = await pickAddress(context, initial: a);
    if (r != null) _load();
  }

  Future<void> _setDefault(Map<String, dynamic> a) async {
    final id = int.tryParse('${a['id']}');
    if (id == null) return;
    HapticFeedback.selectionClick();
    try {
      await Api.growth.updateAddress(id, {...a, 'is_default': true});
      _load();
    } catch (_) {}
  }

  Future<void> _useForBrowsing(Map<String, dynamic> a, String lang) async {
    final lat = numOf(a['latitude']);
    final lng = numOf(a['longitude']);
    if (lat == null || lng == null) return;
    await LocationService.setDefaultLocation(latitude: lat, longitude: lng, label: a['label']?.toString());
    AppEvents.notifyLocationChanged();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(L(lang, 'سنعرض لك المختبرات الأقرب إلى «${a['label']}»', 'Showing labs nearest to "${a['label']}"')),
    ));
  }

  Future<void> _delete(Map<String, dynamic> a, String lang) async {
    final id = int.tryParse('${a['id']}');
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(L(lang, 'حذف العنوان؟', 'Delete address?')),
        content: Text('«${a['label']}»'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(L(lang, 'إلغاء', 'Cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: RastTokens.danger),
            child: Text(L(lang, 'حذف', 'Delete')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _items.removeWhere((e) => '${e['id']}' == '$id'));
    try {
      await Api.growth.deleteAddress(id);
    } catch (_) {}
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();
    final lang = settings.language;

    Widget body;
    if (!AuthService.isLoggedIn) {
      body = Center(
        child: RastEmptyState(
          icon: Icons.lock_person_rounded,
          title: L(lang, 'سجّل دخولك لحفظ عناوينك', 'Sign in to save your addresses'),
          actionLabel: L(lang, 'تسجيل الدخول', 'Sign in'),
          onAction: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
            _load();
          },
        ),
      );
    } else if (_loading) {
      body = ListView(
        padding: const EdgeInsets.all(16),
        children: List.generate(3, (_) => const Padding(padding: EdgeInsets.only(bottom: 12), child: RastSkeleton(height: 92, radius: 20))),
      );
    } else if (_error != null && _items.isEmpty) {
      body = Center(
        child: RastEmptyState(
          icon: Icons.wifi_off_rounded,
          title: L(lang, 'تعذّر تحميل العناوين', 'Could not load addresses'),
          message: _error,
          actionLabel: L(lang, 'إعادة المحاولة', 'Retry'),
          onAction: _load,
        ),
      );
    } else if (_items.isEmpty) {
      body = Center(
        child: RastEmptyState(
          icon: Icons.add_location_alt_rounded,
          title: L(lang, 'لا توجد عناوين بعد', 'No addresses yet'),
          message: L(lang, 'أضف عنوانك مرة واحدة، واختره بلمسة عند كل حجز منزلي.', 'Add an address once and pick it with a tap on every home booking.'),
          actionLabel: L(lang, 'إضافة عنوان', 'Add address'),
          onAction: _add,
        ),
      );
    } else {
      body = RefreshIndicator(
        color: RastTokens.brand,
        onRefresh: _load,
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
          itemCount: _items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) => _card(_items[i], lang).entrance(i),
        ),
      );
    }

    return Directionality(
      textDirection: settings.textDirection,
      child: Scaffold(
        backgroundColor: RastTokens.bg(context),
        appBar: RastTopBar(title: L(lang, 'عناويني', 'My addresses'), showMenu: false),
        body: body,
        floatingActionButton: AuthService.isLoggedIn && _items.isNotEmpty
            ? FloatingActionButton.extended(
                onPressed: _add,
                backgroundColor: RastTokens.brand,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.add_location_alt_rounded),
                label: Text(L(lang, 'إضافة عنوان', 'Add address'), style: const TextStyle(fontWeight: FontWeight.w800)),
              )
            : null,
      ),
    );
  }

  Widget _card(Map<String, dynamic> a, String lang) {
    final isDefault = a['is_default'] == true;
    return RastCard(
      onTap: () => _edit(a),
      borderColor: isDefault ? RastTokens.brand.withValues(alpha: 0.5) : null,
      child: Row(
        children: [
          RastIconBox(icon: addressIcon(a['label']?.toString()), size: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        a['label']?.toString() ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: RastTokens.ink(context)),
                      ),
                    ),
                    if (isDefault) ...[
                      const SizedBox(width: 8),
                      RastPill(label: L(lang, 'الافتراضي', 'Default'), icon: Icons.star_rounded, dense: true),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  addressSubtitle(a),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, height: 1.5, color: RastTokens.muted(context)),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: RastTokens.muted(context)),
            onSelected: (v) => switch (v) {
              'edit' => _edit(a),
              'default' => _setDefault(a),
              'browse' => _useForBrowsing(a, lang),
              _ => _delete(a, lang),
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'edit', child: Text(L(lang, 'تعديل', 'Edit'))),
              if (!isDefault) PopupMenuItem(value: 'default', child: Text(L(lang, 'اجعله الافتراضي', 'Make default'))),
              PopupMenuItem(value: 'browse', child: Text(L(lang, 'اعرض المختبرات القريبة منه', 'Show labs near it'))),
              PopupMenuItem(value: 'delete', child: Text(L(lang, 'حذف', 'Delete'), style: const TextStyle(color: RastTokens.danger))),
            ],
          ),
        ],
      ),
    );
  }
}
