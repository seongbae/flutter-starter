import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_spacing.dart';

enum CardVariant { elevated, filled, outlined }

class CustomCard extends StatelessWidget {
  final Widget child;
  final CardVariant variant;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? color;
  final double? width;
  final double? height;
  final bool animate;
  
  const CustomCard({
    super.key,
    required this.child,
    this.variant = CardVariant.elevated,
    this.padding,
    this.onTap,
    this.color,
    this.width,
    this.height,
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    Widget card = Container(
      width: width,
      height: height,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: _getDecoration(theme),
      child: child,
    );
    
    if (onTap != null) {
      card = InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: card,
      );
    }
    
    if (animate) {
      return card.animate()
        .fadeIn(duration: 300.ms)
        .scale(
          begin: const Offset(0.95, 0.95),
          end: const Offset(1.0, 1.0),
          duration: 300.ms,
          curve: Curves.easeOut,
        );
    }
    
    return card;
  }
  
  BoxDecoration _getDecoration(ThemeData theme) {
    return switch (variant) {
      CardVariant.elevated => BoxDecoration(
          color: color ?? theme.cardColor,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: theme.dividerColor),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.shadow.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      CardVariant.filled => BoxDecoration(
          color: color ?? theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
      CardVariant.outlined => BoxDecoration(
          color: color ?? theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: theme.dividerColor),
        ),
    };
  }
}