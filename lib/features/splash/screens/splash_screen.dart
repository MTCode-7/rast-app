import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:rast/app/main_shell.dart';
import 'package:rast/core/constants/app_assets.dart';
import 'package:rast/core/constants/app_strings.dart';
import 'package:rast/core/providers/app_settings_provider.dart';
import 'package:rast/core/services/catalog_cache_service.dart';
import 'package:rast/core/widgets/rast_ui.dart';

/// شاشة افتتاحية قصيرة مع الشعار ثم الانتقال للتطبيق الرئيسي.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const Duration _minDisplay = Duration(milliseconds: 1600);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _precacheAndGo());
  }

  Future<void> _precacheAndGo() async {
    final start = DateTime.now();
    final ctx = context;
    try {
      await Future.wait<void>([
        precacheImage(const AssetImage(AppAssets.appIcon), ctx),
        CatalogCacheService.warmDuringSplash(),
      ]);
    } catch (_) {}
    final elapsed = DateTime.now().difference(start);
    final wait = _minDisplay - elapsed;
    if (wait > Duration.zero) await Future<void>.delayed(wait);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const MainScaffold()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppSettingsProvider>().language;
    final appName = AppStrings.t('appName', lang);

    return Directionality(
      textDirection: lang == 'en' ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF4A1A52),
                RastUi.purple,
                Color(0xFF5B469D),
                RastUi.blue,
              ],
              stops: [0.0, 0.35, 0.72, 1.0],
            ),
          ),
          child: Stack(
            children: [
              SafeArea(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.22),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 32,
                                  offset: const Offset(0, 16),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: Image.asset(
                                AppAssets.appIcon,
                                width: 96,
                                height: 96,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const SizedBox(
                                  width: 96,
                                  height: 96,
                                  child: Center(
                                    child: Icon(
                                      Icons.medical_services_rounded,
                                      color: Colors.white,
                                      size: 48,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          )
                          .animate()
                          .fadeIn(duration: 500.ms, curve: Curves.easeOut)
                          .scale(
                            begin: const Offset(0.7, 0.7),
                            duration: 800.ms,
                            curve: Curves.elasticOut,
                          ),
                      const SizedBox(height: 28),
                      Text(
                        appName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      )
                          .animate()
                          .fadeIn(delay: 200.ms, duration: 500.ms)
                          .slideY(begin: 0.12, end: 0, curve: Curves.easeOutCubic),
                      const SizedBox(height: 48),
                      SizedBox(
                        width: 120,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            minHeight: 4,
                            color: Colors.white,
                            backgroundColor: Colors.white.withValues(alpha: 0.18),
                          ),
                        ),
                      )
                          .animate()
                          .fadeIn(delay: 500.ms, duration: 400.ms),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
