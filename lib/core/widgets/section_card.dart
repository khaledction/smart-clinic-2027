import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// بطاقة بعنوان اختياري — اللبنة الأساسية لكل شاشات التطبيق.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    this.title,
    this.icon,
    this.trailing,
    this.trailingBesideTitle = false,
    this.padding = const EdgeInsets.all(12),
    this.width,
    required this.child,
  });

  final String? title;
  final IconData? icon;
  final Widget? trailing;

  /// أزرار «الإضافة» تبقى بجانب العنوان؛ غيرها يُحاذى إلى اليسار.
  final bool trailingBesideTitle;
  final EdgeInsets padding;
  final double? width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (title != null) ...[
                Container(
                  // ارتفاع موحّد لكل عناوين البطاقات مهما كان محتوى الطرف.
                  constraints: const BoxConstraints(minHeight: 46),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.headerTint,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 18, color: AppColors.primary),
                        const SizedBox(width: 8),
                      ],
                      if (trailingBesideTitle && trailing != null) ...[
                        Flexible(
                          child: Text(
                            title!,
                            style: Theme.of(context).textTheme.titleMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 14),
                        trailing!,
                        const Spacer(),
                      ] else ...[
                        Expanded(
                          child: Text(
                            title!,
                            style: Theme.of(context).textTheme.titleMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (trailing != null) ...[
                          const SizedBox(width: 10),
                          Flexible(
                            child: Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: trailing!,
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
              child,
            ],
          ),
        ),
      ),
    );
  }
}

