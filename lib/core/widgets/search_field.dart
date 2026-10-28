import 'package:flutter/material.dart';

import '../theme/app_sizes.dart';

/// مربع بحث موحّد بارتفاع [AppSizes.control] في كل الشاشات،
/// بحيث يتساوى مع الأزرار المجاورة له.
class AppSearchField extends StatelessWidget {
  const AppSearchField({
    super.key,
    required this.hint,
    this.controller,
    this.focusNode,
    this.onChanged,
    this.suffixIcon,
    this.showIcon = true,
    this.fieldKey,
  });

  final String hint;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final Widget? suffixIcon;
  final bool showIcon;
  final Key? fieldKey;

  @override
  Widget build(BuildContext context) => Container(
    height: AppSizes.control,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(AppSizes.searchRadius),
      boxShadow: AppSizes.searchShadow,
    ),
    child: TextField(
      key: fieldKey,
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      expands: true,
      maxLines: null,
      minLines: null,
      textAlignVertical: TextAlignVertical.center,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      decoration: AppSizes.search(
        hint,
        prefix: showIcon,
        suffixIcon: suffixIcon,
      ),
    ),
  );
}

