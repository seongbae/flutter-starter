import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_spacing.dart';

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  value,
                  style: theme.textTheme.headlineSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(title, style: theme.textTheme.labelSmall),
              ],
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 600.ms)
        .slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic);
  }
}
