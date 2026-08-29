import 'dart:ui' show ImageFilter, lerpDouble;
import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/widgets/rast_ui.dart';

class ElasticNavItem {
  const ElasticNavItem({
    required this.icon,
    required this.label,
    this.badgeCount = 0,
    this.key,
  });

  final IconData icon;
  final String label;
  final int badgeCount;
  final Key? key;
}

class ElasticBottomNavBar extends StatefulWidget {
  const ElasticBottomNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.height = 62,
    this.margin = const EdgeInsets.fromLTRB(16, 0, 16, 12),
    this.backgroundColor,
    this.selectedColor = AppTheme.primary,
    this.activeAccentColor = AppTheme.secondary,
    this.unselectedColor = AppTheme.onSurfaceVariant,
    this.duration = const Duration(milliseconds: 350),
  }) : assert(items.length >= 2, 'Provide at least two nav items');

  final List<ElasticNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  final double height;

  final EdgeInsets margin;

  final Color? backgroundColor;

  final Color selectedColor;

  final Color activeAccentColor;

  final Color unselectedColor;

  final Duration duration;

  @override
  State<ElasticBottomNavBar> createState() => _ElasticBottomNavBarState();
}

class _ElasticBottomNavBarState extends State<ElasticBottomNavBar>
    with TickerProviderStateMixin {
  late final AnimationController _snapController;
  late final AnimationController _holdController;

  late double _currentPosition;
  late double _startPosition;
  late double _targetPosition;

  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _currentPosition = widget.currentIndex.toDouble();
    _startPosition = _currentPosition;
    _targetPosition = _currentPosition;

    _snapController = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..addListener(() {
      setState(() {
        final t = Curves.easeOutBack.transform(_snapController.value);
        _currentPosition = lerpDouble(_startPosition, _targetPosition, t)!;
      });
    });

    _holdController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
  }

  @override
  void didUpdateWidget(covariant ElasticBottomNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentIndex != oldWidget.currentIndex && !_isDragging) {
      _animateTo(widget.currentIndex.toDouble());
    }
  }

  @override
  void dispose() {
    _snapController.dispose();
    _holdController.dispose();
    super.dispose();
  }

  void _animateTo(double target) {
    _startPosition = _currentPosition;
    _targetPosition = target;
    _snapController.forward(from: 0);
  }

  void _onPanStart(DragStartDetails details, double barWidth) {
    _holdController.forward();
    _snapController.stop();
    setState(() => _isDragging = true);
    _updatePositionFromX(details.localPosition.dx, barWidth);
  }

  void _onPanUpdate(DragUpdateDetails details, double barWidth) {
    _updatePositionFromX(details.localPosition.dx, barWidth);
  }

  void _onPanEnd(DragEndDetails details, double barWidth) {
    _holdController.reverse();
    setState(() => _isDragging = false);

    final closestIndex = _currentPosition.round().clamp(0, widget.items.length - 1);
    _animateTo(closestIndex.toDouble());
    widget.onTap(closestIndex);
  }

  void _updatePositionFromX(double dx, double barWidth) {
    final count = widget.items.length;
    final slotWidth = barWidth / count;
    final visualPos = ((dx - slotWidth / 2) / slotWidth).clamp(0.0, count - 1.0);
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final logicalPos = isRtl ? (count - 1) - visualPos : visualPos;
    setState(() {
      _currentPosition = logicalPos;
    });
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.items.length;
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return SafeArea(
      top: false,
      minimum: widget.margin,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(widget.height / 2),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                height: widget.height,
                decoration: BoxDecoration(
                  gradient: RastUi.brandGradient,
                  borderRadius: BorderRadius.circular(widget.height / 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.18),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
              ),
            ),
          ),

          LayoutBuilder(
            builder: (context, constraints) {
              final barWidth = constraints.maxWidth;
              final slotWidth = barWidth / count;

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) {
                  _holdController.forward();
                  _updatePositionFromX(details.localPosition.dx, barWidth);
                },
                onTapUp: (details) {
                  _holdController.reverse();
                  final closestIndex = _currentPosition.round().clamp(0, count - 1);
                  _animateTo(closestIndex.toDouble());
                  widget.onTap(closestIndex);
                },
                onTapCancel: () => _holdController.reverse(),
                onPanStart: (details) => _onPanStart(details, barWidth),
                onPanUpdate: (details) => _onPanUpdate(details, barWidth),
                onPanEnd: (details) => _onPanEnd(details, barWidth),
                child: AnimatedBuilder(
                  animation: Listenable.merge([_snapController, _holdController]),
                  builder: (context, _) {
                    final holdProgress = _holdController.value;

                    final baseLensWidth = slotWidth * 0.82;
                    final baseLensHeight = widget.height * 0.92;

                    final lensWidth = baseLensWidth + (holdProgress * (slotWidth * 0.32));
                    final lensHeight = baseLensHeight + (holdProgress * 22.0);
                    final visualPosition =
                    isRtl ? (count - 1) - _currentPosition : _currentPosition;

                    final slotCenter = (visualPosition * slotWidth) + (slotWidth / 2);
                    final lensLeft = slotCenter - (lensWidth / 2);

                    return SizedBox(
                      height: widget.height,
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          Positioned(
                            left: lensLeft,
                            width: lensWidth,
                            top: -(lensHeight - widget.height) / 2,
                            height: lensHeight,
                            child: _LiquidGlassBubble(
                              height: lensHeight,
                              holdProgress: holdProgress,
                            ),
                          ),

                          Row(
                            children: List.generate(count, (i) {
                              final distance = (i - _currentPosition).abs();
                              final selectionFactor = (1.0 - distance).clamp(0.0, 1.0);

                              final baseColor = Color.lerp(
                                widget.unselectedColor,
                                widget.selectedColor,
                                selectionFactor,
                              )!;

                              final activeColor = Color.lerp(
                                baseColor,
                                widget.activeAccentColor,
                                holdProgress * selectionFactor,
                              )!;

                              return Expanded(
                                child: KeyedSubtree(
                                  key: widget.items[i].key,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          Icon(
                                            widget.items[i].icon,
                                            color: activeColor,
                                            size: 22 + (selectionFactor * 2),
                                          ),

                                          if (widget.items[i].badgeCount > 0)
                                            Positioned(
                                              right: -9,
                                              top: -9,
                                              child: Container(
                                                constraints: const BoxConstraints(
                                                  minWidth: 19,
                                                  minHeight: 19,
                                                ),
                                                padding: const EdgeInsets.symmetric(horizontal: 5),
                                                alignment: Alignment.center,
                                                decoration: const BoxDecoration(
                                                  color: Color(0xFFFF3B6B),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Text(
                                                  widget.items[i].badgeCount > 9
                                                      ? '9+'
                                                      : '${widget.items[i].badgeCount}',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        widget.items[i].label,
                                        style: TextStyle(
                                          color: activeColor,
                                          fontSize: 11,
                                          fontWeight: selectionFactor > 0.5
                                              ? FontWeight.bold
                                              : FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LiquidGlassBubble extends StatelessWidget {
  const _LiquidGlassBubble({
    required this.height,
    required this.holdProgress,
  });

  final double height;
  final double holdProgress;

  @override
  Widget build(BuildContext context) {
    final borderAlpha = lerpDouble(0.35, 0.75, holdProgress)!;
    final blurSigma = lerpDouble(14.0, 24.0, holdProgress)!;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(height / 2),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(
              alpha: 0.18 + (holdProgress * 0.14),
            ),
            blurRadius: 10 + (holdProgress * 14),
            spreadRadius: holdProgress * 1.5,
            offset: Offset(0, 4 + (holdProgress * 4)),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: blurSigma,
            sigmaY: blurSigma,
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(height / 2),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: 0.55 + (holdProgress * 0.2)),
                  AppTheme.primaryLight.withValues(alpha: 0.35),
                  AppTheme.primary.withValues(
                    alpha: 0.22 + (holdProgress * 0.14),
                  ),
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
              border: Border.all(
                width: 1.2 + (holdProgress * 0.6),
                color: AppTheme.primary.withValues(alpha: borderAlpha),
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 1,
                  left: 6 - (holdProgress * 2),
                  right: 6 - (holdProgress * 2),
                  height: 2.5 + (holdProgress * 1.5),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.white.withValues(alpha: 0.8 + (holdProgress * 0.2)),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 1,
                  left: 4 - (holdProgress * 2),
                  right: 4 - (holdProgress * 2),
                  height: 3 + (holdProgress * 2),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.secondary.withValues(
                            alpha: 0.5 + (holdProgress * 0.4),
                          ),
                          Colors.white.withValues(
                            alpha: 0.75 + (holdProgress * 0.2),
                          ),
                          AppTheme.primaryDark.withValues(
                            alpha: 0.5 + (holdProgress * 0.4),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}