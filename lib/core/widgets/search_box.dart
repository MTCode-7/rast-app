import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:rast/core/theme/app_theme.dart';
import 'package:rast/core/utils/responsive.dart';
import 'package:rast/core/widgets/rast_ui.dart';

/// صندوق بحث أنيق موحّد للاستخدام في الصفحة الرئيسية والمختبرات والتحاليل
class SearchBox extends StatelessWidget {
  const SearchBox({
    super.key,
    required this.controller,
    this.hintText = 'ابحث عن تحليل أو مختبر...',
    this.onSubmitted,
    this.onFilterTap,
    this.onSearchTap,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onFilterTap;
  final VoidCallback? onSearchTap;

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    final prefixIcon = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.rotationY(isRtl ? math.pi : 0),
        child: Icon(
          Icons.search_rounded,
          color: AppTheme.onSurfaceVariant,
          size: 20,
        ),
      ),
    );

    final Widget? suffixIcon = onFilterTap != null
        ? IconButton(
      onPressed: onFilterTap,
      icon: const Icon(
        Icons.tune_rounded,
        color: RastUi.purple,
        size: 20,
      ),
    )
        : null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(13),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xDAF3F4F6),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: Colors.grey,
            width: 0.5,
          ),
        ),
        child: TextField(
          controller: controller,
          onSubmitted: onSubmitted != null ? (v) => onSubmitted!(v) : null,
          style: TextStyle(
            fontSize: Responsive.fontSize(context, 13),
            color: RastUi.primaryText(context),
            fontWeight: FontWeight.w400,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(
              color: const Color(0xFF9CA3AF),
              fontSize: Responsive.fontSize(context, 13),
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,

            // Important
            filled: false,

            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,

            contentPadding: EdgeInsets.symmetric(
              horizontal: Responsive.spacing(context, 14),
              vertical: Responsive.spacing(context, 10),
            ),
          ),
        ),
      ),
    );
  }
}