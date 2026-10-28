import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// بطاقة سطر تتلوّن خلفيتها بهدوء عند مرور المؤشر فوقها.
class HoverCard extends StatefulWidget {
  const HoverCard({
    super.key,
    required this.child,
    this.margin = const EdgeInsets.only(bottom: 8),
  });

  final Widget child;
  final EdgeInsetsGeometry margin;

  @override
  State<HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<HoverCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hover = true),
    onExit: (_) => setState(() => _hover = false),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      margin: widget.margin,
      decoration: BoxDecoration(
        color: _hover ? AppColors.hoverTint : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _hover ? AppColors.frameHover : AppColors.frame,
        ),
      ),
      child: widget.child,
    ),
  );
}

