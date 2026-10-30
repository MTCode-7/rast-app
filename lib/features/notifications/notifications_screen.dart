import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rast/core/api/api_services.dart';
import 'package:rast/core/providers/app_settings_provider.dart';
import 'package:rast/core/services/app_events.dart';
import 'package:rast/core/services/push_service.dart';
import 'package:rast/core/widgets/rast_kit.dart';
import 'package:rast/core/widgets/rast_motion.dart';
import 'package:rast/core/widgets/rast_ui.dart';

/// صفحة الإشعارات: كل ما وصل للعميل (تحديثات الحجز ورسائل راست) بترتيب زمني.
/// عند فتحها تُعلَّم كلها كمقروءة، والضغط على إشعار حجز يفتح تفاصيل الحجز.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final List<Map<String, dynamic>> _items = [];
  final _scroll = ScrollController();
  bool _loading = true;
  bool _loadingMore = false;
  bool _error = false;
  int _page = 1;
  int _lastPage = 1;

  @override
  void initState() {
    super.initState();
    _load();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) _loadMore();
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _items.isEmpty;
      _error = false;
    });
    try {
      final res = await Api.growth.notifications(page: 1);
      final list = (res['data'] as List? ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(list);
        _page = 1;
        _lastPage = (res['last_page'] as num?)?.toInt() ?? 1;
        _loading = false;
      });
      // فتح الصفحة = قراءة الكل (تبقى العلامة ظاهرة في هذه الجلسة لتمييز الجديد)
      if (list.any((e) => e['read'] != true)) {
        await Api.growth.markAllNotificationsRead();
        AppEvents.notifyNotificationsChanged();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _page >= _lastPage) return;
    setState(() => _loadingMore = true);
    try {
      final res = await Api.growth.notifications(page: _page + 1);
      final list = (res['data'] as List? ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      if (!mounted) return;
      setState(() {
        _items.addAll(list);
        _page++;
        _lastPage = (res['last_page'] as num?)?.toInt() ?? _lastPage;
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _open(Map<String, dynamic> item) {
    if (item['booking_id'] != null) {
      PushService.openFromData({'booking_id': item['booking_id'], 'type': item['type']});
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
          appBar: RastTopBar(
            title: lang == 'en' ? 'Notifications' : 'الإشعارات',
            iconColor: Colors.white,
            showCart: false,
          ),
          body: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: Container(
              color: RastUi.screenSurface(context),
              child: RefreshIndicator(
                color: RastUi.purple,
                onRefresh: _load,
                child: _body(lang),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(String lang) {
    if (_loading) {
      return ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: 6,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, __) => const RastSkeleton(height: 78, radius: 18),
      );
    }
    if (_error && _items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 80),
          RastEmptyState(
            icon: Icons.wifi_off_rounded,
            title: lang == 'en' ? 'Could not load notifications' : 'تعذر تحميل الإشعارات',
            actionLabel: lang == 'en' ? 'Retry' : 'إعادة المحاولة',
            onAction: _load,
          ),
        ],
      );
    }
    if (_items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 80),
          RastEmptyState(
            icon: Icons.notifications_none_rounded,
            title: lang == 'en' ? 'No notifications yet' : 'لا توجد إشعارات',
            message: lang == 'en'
                ? 'Booking updates and offers will appear here.'
                : 'ستظهر هنا تحديثات حجوزاتك وعروضنا.',
          ),
        ],
      );
    }
    return ListView.separated(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: _items.length + (_loadingMore ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        if (i >= _items.length) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
          );
        }
        final item = _items[i];
        return _NotificationTile(item: item, lang: lang, onTap: () => _open(item)).entrance(i);
      },
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item, required this.lang, required this.onTap});

  final Map<String, dynamic> item;
  final String lang;
  final VoidCallback onTap;

  /// أيقونة ولون حسب نوع الإشعار
  (IconData, Color) _style() {
    final type = '${item['type'] ?? ''}';
    if (item['kind'] == 'campaign' || type == 'broadcast') return (Icons.campaign_rounded, const Color(0xFF6A1B68));
    if (type.contains('cancel') || type.contains('reject')) return (Icons.event_busy_rounded, const Color(0xFFDC2626));
    if (type.contains('refund')) return (Icons.currency_exchange_rounded, const Color(0xFF0284C7));
    if (type.contains('paid') || type.contains('payment')) return (Icons.payments_rounded, const Color(0xFF16A34A));
    if (type.contains('confirm')) return (Icons.event_available_rounded, const Color(0xFF16A34A));
    if (type.contains('complete') || type.contains('result')) return (Icons.task_alt_rounded, const Color(0xFF16A34A));
    if (type.contains('review')) return (Icons.star_rounded, const Color(0xFFF59E0B));
    if (type.contains('remind') || type.contains('rebook')) return (Icons.alarm_rounded, const Color(0xFFF59E0B));
    return (Icons.notifications_rounded, const Color(0xFF395395));
  }

  String _time() {
    final dt = DateTime.tryParse('${item['created_at'] ?? ''}')?.toLocal();
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return lang == 'en' ? 'now' : 'الآن';
    if (diff.inMinutes < 60) return lang == 'en' ? '${diff.inMinutes}m' : 'منذ ${diff.inMinutes} د';
    if (diff.inHours < 24) return lang == 'en' ? '${diff.inHours}h' : 'منذ ${diff.inHours} س';
    if (diff.inDays == 1) return lang == 'en' ? 'Yesterday' : 'أمس';
    if (diff.inDays < 7) return lang == 'en' ? '${diff.inDays}d' : 'منذ ${diff.inDays} أيام';
    return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _style();
    final unread = item['read'] != true;
    final title = '${item['title'] ?? ''}'.trim();
    final body = '${item['body'] ?? ''}'.trim();
    final hasBooking = item['booking_id'] != null;
    return Material(
      color: unread ? RastUi.purple.withValues(alpha: 0.05) : RastUi.cardSurface(context),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: hasBooking ? onTap : null,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: RastUi.softBorder(context)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title.isNotEmpty ? title : body,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: unread ? FontWeight.w800 : FontWeight.w700,
                              color: RastUi.primaryText(context),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(_time(), style: TextStyle(fontSize: 11, color: RastUi.secondaryText(context))),
                        if (unread) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(color: Color(0xFFE11D48), shape: BoxShape.circle),
                          ),
                        ],
                      ],
                    ),
                    if (title.isNotEmpty && body.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        body,
                        style: TextStyle(fontSize: 12.5, height: 1.5, color: RastUi.secondaryText(context)),
                      ),
                    ],
                    if (hasBooking) ...[
                      const SizedBox(height: 6),
                      Text(
                        lang == 'en' ? 'View booking' : 'عرض الحجز',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: RastUi.purple),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
