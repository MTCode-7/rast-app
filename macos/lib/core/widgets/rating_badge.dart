import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:rast/core/theme/app_theme.dart';

/// شارة تقييم موحّدة: نجوم + رقم + عدد التقييمات (اختياري)
class RatingBadge extends StatelessWidget {
  const RatingBadge({
    super.key,
    required this.rating,
    this.reviewCount,
    this.size = RatingBadgeSize.medium,
    this.showLabel = true,
  });

  final double rating;
  final int? reviewCount;
  final RatingBadgeSize size;
  final bool showLabel;

  double get _starSize {
    switch (size) {
      case RatingBadgeSize.small:
        return 12;
      case RatingBadgeSize.medium:
        return 16;
      case RatingBadgeSize.large:
        return 20;
    }
  }

  double get _fontSize {
    switch (size) {
      case RatingBadgeSize.small:
        return 11;
      case RatingBadgeSize.medium:
        return 13;
      case RatingBadgeSize.large:
        return 15;
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveRating = rating.clamp(0.0, 5.0);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: size == RatingBadgeSize.small ? 6 : 10,
        vertical: size == RatingBadgeSize.small ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.25), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          RatingBarIndicator(
            rating: effectiveRating,
            itemBuilder: (_, __) => const Icon(Icons.star_rounded, color: Colors.amber),
            itemCount: 5,
            itemSize: _starSize,
            unratedColor: Colors.amber.withValues(alpha: 0.25),
          ),
          SizedBox(width: size == RatingBadgeSize.small ? 4 : 6),
          Text(
            effectiveRating.toStringAsFixed(1),
            style: TextStyle(
              fontSize: _fontSize,
              fontWeight: FontWeight.w700,
              color: AppTheme.onSurface,
            ),
          ),
          if (showLabel && reviewCount != null) ...[
            SizedBox(width: size == RatingBadgeSize.small ? 2 : 4),
            Text(
              '($reviewCount)',
              style: TextStyle(
                fontSize: _fontSize - 1,
                color: AppTheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

enum RatingBadgeSize { small, medium, large }

/// تقييم مضغوط للنص فقط (نجوم + رقم) بدون إطار
class RatingInline extends StatelessWidget {
  const RatingInline({
    super.key,
    required this.rating,
    this.reviewCount,
    this.starSize = 14,
    this.fontSize = 12,
  });

  final double rating;
  final int? reviewCount;
  final double starSize;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final effectiveRating = rating.clamp(0.0, 5.0);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        RatingBarIndicator(
          rating: effectiveRating,
          itemBuilder: (_, __) => const Icon(Icons.star_rounded, color: Colors.amber),
          itemCount: 5,
          itemSize: starSize,
          unratedColor: Colors.amber.withValues(alpha: 0.3),
        ),
        SizedBox(width: 4),
        Text(
          effectiveRating.toStringAsFixed(1),
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            color: AppTheme.onSurface,
          ),
        ),
        if (reviewCount != null) ...[
          SizedBox(width: 2),
          Text(
            '($reviewCount تقييم)',
            style: TextStyle(
              fontSize: fontSize - 1,
              color: AppTheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
