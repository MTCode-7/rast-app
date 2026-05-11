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
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: RastUi.cardSurface(context),
        borderRadius: BorderRadius.circular(13),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
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
            color: const Color(0xFFB6B2BD),
            fontSize: Responsive.fontSize(context, 13),
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Icon(
              Icons.search_rounded,
              color: AppTheme.primary,
              size: 20,
            ),
          ),
          suffixIcon: onFilterTap != null
              ? IconButton(
                  onPressed: onFilterTap,
                  icon: Icon(
                    Icons.tune_rounded,
                    color: RastUi.purple,
                    size: 18,
                  ),
                )
              : (onSearchTap != null
                    ? IconButton(
                        onPressed: onSearchTap,
                        icon: Icon(
                          Icons.search_rounded,
                          color: AppTheme.primary,
                          size: 22,
                        ),
                      )
                    : null),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: Responsive.spacing(context, 14),
            vertical: Responsive.spacing(context, 10),
          ),
        ),
      ),
    );
  }
}
