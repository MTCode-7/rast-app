import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rast/core/widgets/rast_kit.dart';
import 'package:rast/features/map/screens/labs_map_screen.dart';

/// زر الخريطة في رؤوس الشاشات (الرئيسية، المختبرات، صفحة التحليل): يفتح خريطة المختبرات.
class MapEntryButton extends StatelessWidget {
  const MapEntryButton({super.key, this.color, this.background, this.size = 44, this.serviceId, this.serviceName});

  final Color? color;
  final Color? background;
  final double size;

  /// فتح الخريطة مفلترة على تحليل معيّن (من صفحة التحليل)
  final int? serviceId;
  final String? serviceName;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: L(Localizations.maybeLocaleOf(context)?.languageCode ?? 'ar', 'خريطة المختبرات', 'Labs map'),
      child: Material(
        color: background ?? RastTokens.card(context),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            HapticFeedback.selectionClick();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => LabsMapScreen(serviceId: serviceId, serviceName: serviceName)),
            );
          },
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(Icons.map_outlined, color: color ?? RastTokens.brand, size: size * 0.5),
          ),
        ),
      ),
    );
  }
}
