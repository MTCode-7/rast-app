import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rast/core/constants/app_strings.dart';
import 'package:rast/core/providers/app_settings_provider.dart';
import 'package:rast/core/services/favorites_service.dart';
import 'package:rast/core/utils/locale_utils.dart';
import 'package:rast/core/utils/responsive.dart';
import 'package:rast/core/widgets/rast_ui.dart';
import 'package:rast/features/analyses/screens/service_detail_screen.dart';
import 'package:rast/features/lab_details/screens/lab_details_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  List<Map<String, dynamic>> _labs = [];
  List<Map<String, dynamic>> _analyses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final labs = await FavoritesService.getLabs();
    final analyses = await FavoritesService.getAnalyses();
    if (!mounted) return;
    setState(() {
      _labs = labs;
      _analyses = analyses;
      _isLoading = false;
    });
  }

  Future<void> _removeLab(Map<String, dynamic> lab) async {
    await FavoritesService.removeLab(FavoritesService.itemId(lab));
    await _load();
  }

  Future<void> _removeAnalysis(Map<String, dynamic> analysis) async {
    await FavoritesService.removeAnalysis(FavoritesService.itemId(analysis));
    await _load();
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
            title: AppStrings.t('favorites', lang),
            showCart: true,
          ),
          body: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: Container(
              color: RastUi.screenSurface(context),
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      Responsive.spacing(context, 18),
                      Responsive.spacing(context, 18),
                      Responsive.spacing(context, 18),
                      0,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: RastUi.cardSurface(context),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: RastUi.softBorder(context)),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        indicator: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: RastUi.brandGradient,
                        ),
                        indicatorSize: TabBarIndicatorSize.tab,
                        dividerColor: Colors.transparent,
                        labelColor: Colors.white,
                        unselectedLabelColor: RastUi.textPurple,
                        tabs: const [
                          Tab(text: 'المختبرات'),
                          Tab(text: 'التحاليل'),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : TabBarView(
                            controller: _tabController,
                            children: [_buildLabsList(), _buildAnalysesList()],
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

  Widget _buildLabsList() {
    if (_labs.isEmpty) return _empty('لا توجد مختبرات في المفضلة');
    final isArabic = context.watch<AppSettingsProvider>().isArabic;
    return ListView.separated(
      padding: EdgeInsets.all(Responsive.spacing(context, 18)),
      itemCount: _labs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final lab = _labs[index];
        final name = LocaleUtils.localizedBusinessName(lab, isArabic);
        return _favoriteTile(
          icon: Icons.business_rounded,
          title: name.isEmpty ? 'مختبر' : name,
          subtitle: lab['city']?.toString() ?? '',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => LabDetailsScreen(lab: lab)),
          ).then((_) => _load()),
          onRemove: () => _removeLab(lab),
        );
      },
    );
  }

  Widget _buildAnalysesList() {
    if (_analyses.isEmpty) return _empty('لا توجد تحاليل في المفضلة');
    final isArabic = context.watch<AppSettingsProvider>().isArabic;
    return ListView.separated(
      padding: EdgeInsets.all(Responsive.spacing(context, 18)),
      itemCount: _analyses.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final analysis = _analyses[index];
        final name = LocaleUtils.localizedName(analysis, isArabic);
        return _favoriteTile(
          icon: Icons.medical_services_outlined,
          title: name.isEmpty ? 'تحليل' : name,
          subtitle: analysis['category'] is Map
              ? LocaleUtils.localizedName(
                  Map<String, dynamic>.from(analysis['category'] as Map),
                  isArabic,
                )
              : '',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ServiceDetailScreen(service: analysis),
            ),
          ).then((_) => _load()),
          onRemove: () => _removeAnalysis(analysis),
        );
      },
    );
  }

  Widget _favoriteTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required VoidCallback onRemove,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.all(Responsive.spacing(context, 14)),
          decoration: BoxDecoration(
            color: RastUi.cardSurface(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: RastUi.softBorder(context)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: RastUi.brandGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: RastUi.primaryText(context),
                        fontSize: Responsive.fontSize(context, 14),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: RastUi.mutedText,
                          fontSize: Responsive.fontSize(context, 11),
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(
                  Icons.favorite_rounded,
                  color: Color(0xFFFF4D61),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _empty(String text) {
    return Center(
      child: Text(
        text,
        style: TextStyle(
          color: RastUi.mutedText,
          fontSize: Responsive.fontSize(context, 14),
        ),
      ),
    );
  }
}
