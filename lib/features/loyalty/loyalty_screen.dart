import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:rast/core/api/api_services.dart';
import 'package:rast/core/providers/app_settings_provider.dart';
import 'package:rast/core/widgets/rast_kit.dart';
import 'package:rast/core/widgets/rast_motion.dart';
import 'package:rast/core/widgets/rast_ui.dart';
import 'package:rast/features/auth/screens/login_screen.dart';
import 'package:rast/features/auth/services/auth_service.dart';
import 'package:url_launcher/url_launcher.dart';

/// «نقاطي»: الرصيد والمستوى، التقدم للمستوى التالي، طرق الكسب، كود الدعوة، وسجل الحركات.
class LoyaltyScreen extends StatefulWidget {
  const LoyaltyScreen({super.key});

  @override
  State<LoyaltyScreen> createState() => _LoyaltyScreenState();
}

class _LoyaltyScreenState extends State<LoyaltyScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  String get _lang => context.read<AppSettingsProvider>().language;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!AuthService.isLoggedIn) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = _data == null;
      _error = null;
    });
    try {
      final d = await Api.growth.loyalty(lang: _lang);
      if (!mounted) return;
      setState(() {
        _data = d;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();
    final lang = settings.language;
    return Directionality(
      textDirection: settings.textDirection,
      child: Scaffold(
        backgroundColor: RastTokens.bg(context),
        appBar: RastTopBar(title: L(lang, 'نقاطي', 'My points')),
        body: _body(lang),
      ),
    );
  }

  Widget _body(String lang) {
    if (!AuthService.isLoggedIn) {
      return Center(
        child: RastEmptyState(
          icon: Icons.stars_rounded,
          title: L(lang, 'سجّل الدخول لتجمع النقاط', 'Sign in to collect points'),
          actionLabel: L(lang, 'تسجيل الدخول', 'Sign in'),
          onAction: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
            if (mounted) _load();
          },
        ),
      );
    }
    if (_loading) {
      return ListView(
        padding: const EdgeInsets.all(RastTokens.gutter),
        children: const [
          RastSkeleton(height: 190, radius: 24),
          SizedBox(height: 16),
          RastSkeleton(height: 120, radius: 20),
          SizedBox(height: 16),
          RastSkeleton(height: 260, radius: 20),
        ],
      );
    }
    if (_error != null || _data == null) {
      return Center(
        child: RastEmptyState(
          icon: Icons.wifi_off_rounded,
          title: L(lang, 'تعذر تحميل النقاط', 'Could not load points'),
          message: _error,
          actionLabel: L(lang, 'إعادة المحاولة', 'Retry'),
          onAction: _load,
        ),
      );
    }
    final d = _data!;
    final rules = d['rules'] is Map ? Map<String, dynamic>.from(d['rules']) : <String, dynamic>{};
    final txData = d['transactions'] is Map ? (d['transactions']['data'] as List? ?? const []) : const [];

    return RefreshIndicator(
      color: RastTokens.brand,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(RastTokens.gutter, 12, RastTokens.gutter, 32 + MediaQuery.paddingOf(context).bottom),
        children: [
          _balanceCard(d, lang).entrance(0),
          const SizedBox(height: 16),
          _referralCard(d, rules, lang).entrance(1),
          const SizedBox(height: 22),
          Text(L(lang, 'طرق كسب النقاط', 'Ways to earn'),
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: RastTokens.ink(context))),
          const SizedBox(height: 10),
          _earnGrid(rules, lang).entrance(2),
          if (rules['redeem_enabled'] != true) ...[
            const SizedBox(height: 12),
            RastCard(
              color: RastTokens.brandSoft(context),
              child: Row(
                children: [
                  const RastIconBox(icon: Icons.redeem_rounded, size: 36),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      L(lang, 'استبدال النقاط بخصم على الحجز متاح قريباً لدى المختبرات المشاركة.',
                          'Redeeming points on bookings is coming soon at participating labs.'),
                      style: TextStyle(fontSize: 12.5, height: 1.5, color: RastTokens.ink(context)),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 22),
          Text(L(lang, 'سجل النقاط', 'Points history'),
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: RastTokens.ink(context))),
          const SizedBox(height: 10),
          if (txData.isEmpty)
            RastCard(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Center(
                  child: Text(L(lang, 'لا توجد حركات بعد. احجز تحليلك الأول لتبدأ.', 'No activity yet. Book your first test to start.'),
                      style: TextStyle(color: RastTokens.muted(context))),
                ),
              ),
            )
          else
            RastCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Column(
                children: [
                  for (var i = 0; i < txData.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: RastTokens.line(context)),
                    _txRow(Map<String, dynamic>.from(txData[i] as Map), lang),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _balanceCard(Map<String, dynamic> d, String lang) {
    final points = (numOf(d['points']) ?? 0).toInt();
    final value = numOf(d['points_value_sar']) ?? 0;
    final tier = d['tier'] is Map ? Map<String, dynamic>.from(d['tier']) : <String, dynamic>{};
    final next = d['next_tier'] is Map ? Map<String, dynamic>.from(d['next_tier']) : null;
    final toNext = (numOf(d['points_to_next_tier']) ?? 0).toInt();
    final progress = (numOf(d['tier_progress']) ?? 0).clamp(0.0, 1.0).toDouble();
    final tierName = (lang == 'en' ? tier['name_en'] : tier['name_ar'])?.toString() ?? '';
    final tierColor = switch (tier['key']) {
      'gold' => RastTokens.gold,
      'silver' => const Color(0xFFCBD5E1),
      _ => const Color(0xFFE0A574),
    };

    // بطاقة الرصيد: لون الهوية بهدوء، والمستوى يظهر في الشارة وشريط التقدم فقط
    return Container(
      decoration: BoxDecoration(
        gradient: RastTokens.brandGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(20),
      child: _balanceContent(points, value, tierName, tierColor, next, toNext, progress, lang),
    );
  }

  Widget _balanceContent(int points, num value, String tierName, Color tierColor, Map<String, dynamic>? next,
      int toNext, double progress, String lang) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(L(lang, 'رصيد النقاط', 'Points balance'),
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13, fontWeight: FontWeight.w600)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: tierColor.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: tierColor.withValues(alpha: 0.6))),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.workspace_premium_rounded, size: 15, color: tierColor),
                    const SizedBox(width: 4),
                    Text(L(lang, 'مستوى $tierName', '$tierName tier'),
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: points.toDouble()),
                duration: const Duration(milliseconds: 1100),
                curve: Curves.easeOutCubic,
                builder: (_, v, __) => Text('${v.round()}',
                    style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900, height: 1.1)),
              ),
              const SizedBox(width: 6),
              Text(L(lang, 'نقطة', 'pts'), style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
            ],
          ),
          Text(L(lang, 'تعادل ${fmtPrice(value)} ر.س', 'Worth ${fmtPrice(value)} SAR'),
              style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13)),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: next == null ? 1 : progress),
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeOutCubic,
              builder: (_, v, __) => LinearProgressIndicator(
                value: v,
                minHeight: 8,
                color: tierColor,
                backgroundColor: Colors.white.withValues(alpha: 0.18),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            next == null
                ? L(lang, 'أعلى مستوى', 'Top tier')
                : L(lang, 'باقي $toNext نقطة للمستوى ${next['name_ar']}', '$toNext pts to ${next['name_en']}'),
            style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12),
          ),
        ],
      );
  }

  Widget _referralCard(Map<String, dynamic> d, Map<String, dynamic> rules, String lang) {
    final code = d['referral_code']?.toString() ?? '';
    final bonus = (numOf(rules['referral_bonus']) ?? 0).toInt();
    if (code.isEmpty) return const SizedBox.shrink();
    final link = 'https://rast-labs.com/register?ref=$code';
    final shareText = L(
      lang,
      'سجّل في راست لابس بكود الدعوة $code واحصل على $bonus نقطة بعد أول حجز:\n$link',
      'Join Rast Labs with my code $code and get $bonus points after your first booking:\n$link',
    );

    return RastCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const RastIconBox(icon: Icons.card_giftcard_rounded, color: RastTokens.success),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(L(lang, 'ادعُ صديقك واربحا $bonus نقطة', 'Invite a friend, both get $bonus pts'),
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: RastTokens.ink(context))),
                    Text(L(lang, 'تُضاف النقاط لكما بعد أول حجز مدفوع لصديقك', 'Added for both after your friend\'s first paid booking'),
                        style: TextStyle(fontSize: 12, color: RastTokens.muted(context))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: code));
                    HapticFeedback.selectionClick();
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(L(lang, 'تم نسخ الكود', 'Code copied'))));
                  },
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: RastTokens.fill(context),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: RastTokens.brand.withValues(alpha: 0.35), style: BorderStyle.solid),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(code,
                            textDirection: TextDirection.ltr,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2, color: RastTokens.brand)),
                        const SizedBox(width: 8),
                        const Icon(Icons.copy_rounded, size: 18, color: RastTokens.brand),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 130,
                child: RastButton(
                  label: L(lang, 'مشاركة', 'Share'),
                  icon: Icons.ios_share_rounded,
                  height: 50,
                  onPressed: () => launchUrl(
                    Uri.parse('https://wa.me/?text=${Uri.encodeComponent(shareText)}'),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _earnGrid(Map<String, dynamic> rules, String lang) {
    final perSar = numOf(rules['points_per_sar']) ?? 1;
    final items = <(IconData, Color, String, String)>[
      (Icons.receipt_long_rounded, RastTokens.brand, L(lang, 'كل حجز مدفوع', 'Every paid booking'),
          L(lang, '${fmtPrice(perSar)} نقطة لكل ريال', '${fmtPrice(perSar)} pt per SAR')),
      (Icons.person_add_alt_1_rounded, RastTokens.success, L(lang, 'دعوة صديق', 'Invite a friend'),
          L(lang, '+${fmtPrice(numOf(rules['referral_bonus']))} نقطة لكل منكما', '+${fmtPrice(numOf(rules['referral_bonus']))} each')),
      (Icons.star_rounded, RastTokens.gold, L(lang, 'تقييم زيارتك', 'Rate your visit'),
          L(lang, '+${fmtPrice(numOf(rules['review_bonus']))} نقطة', '+${fmtPrice(numOf(rules['review_bonus']))} pts')),
      (Icons.workspace_premium_rounded, RastTokens.info, L(lang, 'مستويات أعلى', 'Higher tiers'),
          L(lang, 'الفضي ×1.25 والذهبي ×1.5', 'Silver ×1.25, Gold ×1.5')),
    ];
    // قائمة مختصرة بدل شبكة بطاقات
    return RastCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) Divider(height: 1, color: RastTokens.line(context)),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 11),
              child: Row(
                children: [
                  Icon(items[i].$1, size: 20, color: items[i].$2),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(items[i].$3,
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: RastTokens.ink(context))),
                  ),
                  Text(items[i].$4,
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: RastTokens.muted(context))),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _txRow(Map<String, dynamic> t, String lang) {
    final pts = (numOf(t['points']) ?? 0).toInt();
    final positive = pts >= 0;
    final date = DateTime.tryParse(t['created_at']?.toString() ?? '')?.toLocal();
    final dateText = date == null ? '' : '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          RastIconBox(
            icon: positive ? Icons.add_circle_outline_rounded : Icons.remove_circle_outline_rounded,
            color: positive ? RastTokens.success : RastTokens.danger,
            size: 36,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t['label']?.toString() ?? '', style: TextStyle(fontWeight: FontWeight.w700, color: RastTokens.ink(context))),
                if ((t['description']?.toString() ?? '').isNotEmpty || dateText.isNotEmpty)
                  Text(
                    [t['description']?.toString() ?? '', dateText].where((s) => s.isNotEmpty).join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: RastTokens.muted(context)),
                  ),
              ],
            ),
          ),
          Text(
            '${positive ? '+' : ''}$pts',
            textDirection: TextDirection.ltr,
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: positive ? RastTokens.success : RastTokens.danger),
          ).animate().fadeIn(),
        ],
      ),
    );
  }
}
