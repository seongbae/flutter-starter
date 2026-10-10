import 'package:flutter/material.dart';
import '../../core/theme/app_spacing.dart';

/// Large screen title used at the top of tab pages in place of an AppBar,
/// with an optional [badge] beside it and icon [actions] on the right.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.badge,
    this.actions = const [],
  });

  final String title;
  final Widget? badge;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.headlineLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: AppSpacing.sm),
                badge!,
              ],
            ],
          ),
        ),
        ...actions,
      ],
    );
  }
}

/// Section heading with an optional trailing label.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(child: Text(text, style: theme.textTheme.titleLarge)),
        if (trailing != null)
          Text(trailing!, style: theme.textTheme.labelMedium),
      ],
    );
  }
}

/// Small pill shown beside a [PageHeader] title (e.g. "Demo data").
class HeaderBadge extends StatelessWidget {
  const HeaderBadge({super.key, required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.secondary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelMedium!.copyWith(color: color),
        ),
      ),
    );
  }
}

/// Bordered card holding a group of rows (e.g. ListTiles), separated by
/// hairline dividers.
class GroupCard extends StatelessWidget {
  const GroupCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(indent: AppSpacing.lg),
            children[i],
          ],
        ],
      ),
    );
  }
}
