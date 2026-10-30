import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rast/core/api/api_services.dart';
import 'package:rast/core/providers/app_settings_provider.dart';
import 'package:rast/core/widgets/rast_kit.dart';
import 'package:rast/core/widgets/rast_motion.dart';
import 'package:rast/core/widgets/rast_ui.dart';
import 'package:rast/features/offers/screens/offer_detail_screen.dart';
import 'package:rast/features/offers/widgets/offer_card.dart';
import 'package:rast/features/analyses/widgets/test_row_card.dart' show ViewModeStore, ViewModeToggle;

/// كل عروض المختبرات: شرائح (الكل / مميز)، سحب للتحديث، وتحميل الصفحات عند التمرير.
class OffersScreen extends StatefulWidget {
  const OffersScreen({super.key, this.providerId, this.title});

  /// عروض مختبر واحد فقط (من صفحة المختبر)
  final int? providerId;
  final String? title;

  @override
  State<OffersScreen> createState() => _OffersScreenState();
}

class _OffersScreenState extends State<OffersScreen> {
  final _scroll = ScrollController();
  final List<Map<String, dynamic>> _offers = [];
  bool _featuredOnly = false;
  bool _loading = true;
  bool _loadingMore = false;
  int _page = 1;
  int _lastPage = 1;
  String? _error;
  bool _grid = true;

  @override
  void initState() {
    super.initState();
    ViewModeStore.isGrid('offers').then((g) {
      if (mounted && g != _grid) setState(() => _grid = g);
    });
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 400) _loadMore();
    });
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _offers.isEmpty;
      _error = null;
    });
    try {
      final res = await Api.growth.offers(page: 1, providerId: widget.providerId, featured: _featuredOnly);
      if (!mounted) return;
      setState(() {
        _offers
          ..clear()
          ..addAll(_rows(res));
        _page = 1;
        _lastPage = (numOf(res['last_page']) ?? 1).toInt();
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

  Future<void> _loadMore() async {
    if (_loadingMore || _loading || _page >= _lastPage) return;
    setState(() => _loadingMore = true);
    try {
      final res = await Api.growth.offers(page: _page + 1, providerId: widget.providerId, featured: _featuredOnly);
      if (!mounted) return;
      setState(() {
        _offers.addAll(_rows(res));
        _page++;
        _lastPage = (numOf(res['last_page']) ?? _lastPage).toInt();
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  List<Map<String, dynamic>> _rows(Map<String, dynamic> res) =>
      (res['data'] is List ? res['data'] as List : const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();
    final lang = settings.language;
    return Directionality(
      textDirection: settings.textDirection,
      child: Scaffold(
        backgroundColor: RastTokens.bg(context),
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight + 8),
          child: Container(
            color: RastTokens.card(context),
            child: SafeArea(
              bottom: false,
              child: RastTopBar(
                title: widget.title ?? L(lang, 'العروض', 'Offers'),
                showCart: true,
                useWhiteBackground: true,
                backgroundColor: RastTokens.card(context),
              ),
            ),
          ),
        ),
        body: Column(
          children: [
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: widget.providerId == null
                      ? RastChoiceChips<bool>(
                          items: const [false, true],
                          selected: _featuredOnly,
                          labelOf: (v) => v ? L(lang, 'المميزة', 'Featured') : L(lang, 'كل العروض', 'All offers'),
                          iconOf: (v) => v ? Icons.star_rounded : Icons.local_offer_rounded,
                          onSelected: (v) {
                            setState(() => _featuredOnly = v);
                            _load();
                          },
                        )
                      : const SizedBox.shrink(),
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: RastTokens.gutter),
                  child: ViewModeToggle(
                    grid: _grid,
                    height: 40,
                    onChanged: (g) {
                      setState(() => _grid = g);
                      ViewModeStore.setGrid('offers', g);
                    },
                  ),
                ),
              ],
            ),
            Expanded(child: _content(lang)),
          ],
        ),
      ),
    );
  }

  Widget _content(String lang) {
    if (_loading) {
      return ListView(
        padding: const EdgeInsets.all(RastTokens.gutter),
        children: List.generate(3, (_) => const Padding(padding: EdgeInsets.only(bottom: 14), child: RastSkeleton(height: 290, radius: 20))),
      );
    }
    if (_error != null) {
      return Center(
        child: RastEmptyState(
          icon: Icons.wifi_off_rounded,
          title: L(lang, 'تعذر تحميل العروض', 'Could not load offers'),
          actionLabel: L(lang, 'إعادة المحاولة', 'Retry'),
          onAction: _load,
        ),
      );
    }
    if (_offers.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 60),
            RastEmptyState(
              icon: Icons.local_offer_outlined,
              title: L(lang, 'لا توجد عروض حالياً', 'No offers right now'),
              message: L(lang, 'المختبرات تضيف عروضاً جديدة باستمرار، عد قريباً.', 'Labs add new deals all the time — check back soon.'),
            ),
          ],
        ),
      );
    }
    Widget card(BuildContext context, int i) {
      final offer = _offers[i];
      final c = OfferCard(
        key: ValueKey('offer-${_grid ? 'g' : 'l'}-${offer['id']}'),
        offer: offer,
        lang: lang,
        grid: _grid,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => OfferDetailScreen(offer: offer)),
        ),
      );
      return i < 10 ? c.entrance(i) : c;
    }

    final bottom = 24 + MediaQuery.paddingOf(context).bottom;
    return RefreshIndicator(
      color: RastTokens.brand,
      onRefresh: _load,
      child: CustomScrollView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(RastTokens.gutter, 14, RastTokens.gutter, _loadingMore ? 0 : bottom),
            sliver: _grid
                ? SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      mainAxisExtent: ViewModeStore.gridExtent(MediaQuery.sizeOf(context).width, body: 104),
                    ),
                    delegate: SliverChildBuilderDelegate(card, childCount: _offers.length),
                  )
                : SliverList.separated(
                    itemCount: _offers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: card,
                  ),
          ),
          if (_loadingMore)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: 16, bottom: bottom),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}
