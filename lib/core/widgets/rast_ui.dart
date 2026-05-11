import 'package:flutter/material.dart';
import 'package:rast/core/theme/app_theme.dart';

class RastUi {
  const RastUi._();

  static const Color purple = AppTheme.primary;
  static const Color blue = AppTheme.secondary;
  static const Color textPurple = Color(0xFF5B2B63);
  static const Color mutedText = Color(0xFF9A9AA8);
  static const Color chipFill = Color(0xFFECEEFF);
  static const Color darkSurface = Color(0xFF07131A);
  static const Color darkCard = Color(0xFF0F1D27);
  static const Color darkPanel = Color(0xFF101B27);

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color screenSurface(BuildContext context) =>
      isDark(context) ? darkSurface : Colors.white;

  static Color cardSurface(BuildContext context) =>
      isDark(context) ? darkCard : Colors.white;

  static Color panelSurface(BuildContext context) =>
      isDark(context) ? darkPanel : Colors.white;

  static Color primaryText(BuildContext context) =>
      isDark(context) ? const Color(0xFFE8EAF2) : textPurple;

  static Color secondaryText(BuildContext context) =>
      isDark(context) ? const Color(0xFFB6BECE) : mutedText;

  static Color subtleFill(BuildContext context) =>
      isDark(context) ? const Color(0xFF182635) : const Color(0xFFF8F8FC);

  static Color softBorder(BuildContext context) =>
      isDark(context) ? const Color(0xFF26384A) : const Color(0xFFECEAF2);

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [blue, purple],
  );

  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [purple, Color(0xFF5B469D), blue],
  );

  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.11),
      blurRadius: 14,
      offset: const Offset(0, 5),
    ),
  ];

  static BoxDecoration cardDecoration({
    double radius = 16,
    Color border = const Color(0xFFECECF3),
  }) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: border),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.07),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ],
    );
  }
}

class RastLogo extends StatelessWidget {
  const RastLogo({super.key, this.size = 150, this.light = false});

  final double size;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final color = light ? Colors.white : RastUi.blue;
    final purple = light ? Colors.white : RastUi.purple;
    return SizedBox(
      width: size,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size * 0.48,
            height: size * 0.40,
            child: CustomPaint(
              painter: _LogoFramePainter(color: color, purple: purple),
              child: Center(
                child: Text(
                  'R',
                  style: TextStyle(
                    fontSize: size * 0.20,
                    height: 1,
                    color: purple,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: size * 0.09),
          Text(
            'R A S T',
            style: TextStyle(
              color: purple,
              fontSize: size * 0.16,
              fontWeight: FontWeight.w600,
              letterSpacing: size * 0.07,
              height: 1,
            ),
          ),
          SizedBox(height: size * 0.06),
          Text(
            'A L L   M E D I C A L   L A B S',
            maxLines: 1,
            style: TextStyle(
              color: color,
              fontSize: size * 0.058,
              fontWeight: FontWeight.w600,
              letterSpacing: size * 0.025,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _LogoFramePainter extends CustomPainter {
  const _LogoFramePainter({required this.color, required this.purple});

  final Color color;
  final Color purple;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [purple, color],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.square;

    final path = Path()
      ..moveTo(0, size.height * 0.68)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width * 0.50, size.height);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _LogoFramePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.purple != purple;
}

class RastSupportBubble extends StatelessWidget {
  const RastSupportBubble({
    super.key,
    this.bottom = 34,
    this.left = 28,
    this.onTap,
  });

  final double bottom;
  final double left;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      bottom: bottom,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RastUi.brandGradient,
              boxShadow: [
                BoxShadow(
                  color: RastUi.purple.withValues(alpha: 0.28),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(Icons.support_agent_rounded, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class RastTopBar extends StatelessWidget implements PreferredSizeWidget {
  const RastTopBar({
    super.key,
    required this.title,
    this.showMenu = true,
    this.onBack,
    this.onMenuTap,
  });

  final String title;
  final bool showMenu;
  final VoidCallback? onBack;
  final VoidCallback? onMenuTap;

  @override
  Size get preferredSize => const Size.fromHeight(82);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: preferredSize.height + MediaQuery.of(context).padding.top,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      decoration: const BoxDecoration(gradient: RastUi.headerGradient),
      child: Stack(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 20),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap:
                      onBack ??
                      () {
                        if (Navigator.of(context).canPop()) {
                          Navigator.pop(context);
                        }
                      },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (showMenu)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 24),
                child: Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap:
                        onMenuTap ??
                        () {
                          showModalBottomSheet(
                            context: context,
                            backgroundColor: Colors.transparent,
                            builder: (ctx) => Container(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                10,
                                16,
                                20,
                              ),
                              decoration: BoxDecoration(
                                color: RastUi.cardSurface(ctx),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(20),
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 40,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: RastUi.softBorder(ctx),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  ListTile(
                                    leading: const Icon(
                                      Icons.arrow_back_rounded,
                                    ),
                                    title: const Text('رجوع'),
                                    onTap: () {
                                      Navigator.pop(ctx);
                                      if (Navigator.of(context).canPop()) {
                                        Navigator.pop(context);
                                      }
                                    },
                                  ),
                                  ListTile(
                                    leading: const Icon(Icons.close_rounded),
                                    title: const Text('إغلاق'),
                                    onTap: () => Navigator.pop(ctx),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: RastUi.cardSurface(context),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.more_vert,
                        color: RastUi.primaryText(context),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
