import 'package:flutter/material.dart';
import 'package:rast/core/onboarding/onboarding_step.dart';
import 'package:rast/core/services/onboarding_service.dart';
import 'package:rast/core/widgets/rast_ui.dart';

/// جولة إرشادية تفاعلية (تسليط الضوء + شرح).
class OnboardingCoach {
  OnboardingCoach._();

  static Future<void> show(
    BuildContext context, {
    required String tourId,
    required List<OnboardingStep> steps,
    bool force = false,
  }) async {
    if (steps.isEmpty) return;
    if (!force && !await OnboardingService.shouldShow(tourId)) return;
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      useSafeArea: false,
      builder: (ctx) => _OnboardingCoachDialog(
        tourId: tourId,
        steps: steps,
      ),
    );
  }
}

class _OnboardingCoachDialog extends StatefulWidget {
  const _OnboardingCoachDialog({
    required this.tourId,
    required this.steps,
  });

  final String tourId;
  final List<OnboardingStep> steps;

  @override
  State<_OnboardingCoachDialog> createState() => _OnboardingCoachDialogState();
}

class _OnboardingCoachDialogState extends State<_OnboardingCoachDialog> {
  int _index = 0;

  OnboardingStep get _step => widget.steps[_index];
  bool get _isLast => _index >= widget.steps.length - 1;

  Rect? _targetRect() {
    final key = _step.targetKey;
    if (key == null) return null;
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    final offset = box.localToGlobal(Offset.zero);
    return offset & box.size;
  }

  void _next() {
    if (_isLast) {
      OnboardingService.markSeen(widget.tourId);
      Navigator.pop(context);
      return;
    }
    setState(() => _index += 1);
  }

  void _skip() {
    OnboardingService.markSeen(widget.tourId);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final rect = _targetRect();
    final size = MediaQuery.sizeOf(context);
    final tooltip = _buildTooltipCard(context, size, rect);

    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: _SpotlightPainter(hole: rect?.inflate(10)),
            child: const SizedBox.expand(),
          ),
          if (rect != null)
            Positioned(
              left: rect.left - 4,
              top: rect.top - 4,
              width: rect.width + 8,
              height: rect.height + 8,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: RastUi.purple, width: 2.5),
                  ),
                ),
              ),
            ),
          tooltip,
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            left: 12,
            child: TextButton(
              onPressed: _skip,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.black54,
              ),
              child: const Text('تخطي الجولة'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTooltipCard(BuildContext context, Size size, Rect? rect) {
    const margin = 20.0;
    const cardMaxW = 340.0;

    if (rect == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(margin),
          child: _TooltipContent(
            step: _step,
            index: _index,
            total: widget.steps.length,
            isLast: _isLast,
            onNext: _next,
          ),
        ),
      );
    }

    final align = _step.align;
    double top;
    if (align == OnboardingTooltipAlign.above) {
      top = rect.top - 12;
    } else if (align == OnboardingTooltipAlign.below) {
      top = rect.bottom + 12;
    } else {
      final below = rect.bottom + 200 < size.height;
      top = below ? rect.bottom + 12 : rect.top - 12;
    }

    final preferAbove = top > size.height * 0.55;
    if (preferAbove && align == OnboardingTooltipAlign.auto) {
      top = (rect.top - 200).clamp(margin, size.height - margin);
    }

    return Positioned(
      left: margin,
      right: margin,
      top: top.clamp(margin, size.height - margin - 180),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: cardMaxW),
          child: _TooltipContent(
            step: _step,
            index: _index,
            total: widget.steps.length,
            isLast: _isLast,
            onNext: _next,
          ),
        ),
      ),
    );
  }
}

class _TooltipContent extends StatelessWidget {
  const _TooltipContent({
    required this.step,
    required this.index,
    required this.total,
    required this.isLast,
    required this.onNext,
  });

  final OnboardingStep step;
  final int index;
  final int total;
  final bool isLast;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 12,
      borderRadius: BorderRadius.circular(20),
      color: RastUi.cardSurface(context),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: RastUi.brandGradient,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${index + 1} / $total',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                const Icon(Icons.lightbulb_outline_rounded, color: RastUi.purple),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              step.title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: RastUi.primaryText(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              step.body,
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: RastUi.secondaryText(context),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onNext,
              style: FilledButton.styleFrom(
                backgroundColor: RastUi.purple,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(isLast ? 'تم' : 'التالي'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter({this.hole});

  final Rect? hole;

  @override
  void paint(Canvas canvas, Size size) {
    final overlay = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    if (hole != null) {
      final holePath = Path()
        ..addRRect(
          RRect.fromRectAndRadius(hole!, const Radius.circular(14)),
        );
      final combined = Path.combine(PathOperation.difference, overlay, holePath);
      canvas.drawPath(
        combined,
        Paint()..color = Colors.black.withValues(alpha: 0.72),
      );
    } else {
      canvas.drawPath(overlay, Paint()..color = Colors.black.withValues(alpha: 0.72));
    }
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter old) => old.hole != hole;
}
