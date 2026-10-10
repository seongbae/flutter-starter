import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_spacing.dart';

class GuestModeBanner extends StatelessWidget {
  final String? customMessage;
  final List<String>? loginBenefits;
  final bool showActions;
  final EdgeInsetsGeometry margin;

  const GuestModeBanner({
    super.key,
    this.customMessage,
    this.loginBenefits,
    this.showActions = true,
    this.margin = const EdgeInsets.only(bottom: AppSpacing.xl),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.secondary;

    return Container(
      margin: margin,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_outline_rounded, size: 20, color: accent),
              const SizedBox(width: AppSpacing.sm),
              Text('Guest Mode', style: theme.textTheme.titleLarge),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            customMessage ?? 'You\'re browsing as a guest with limited features.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (loginBenefits != null && loginBenefits!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Login to unlock:', style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            ...loginBenefits!.map((benefit) => Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(benefit, style: theme.textTheme.bodySmall),
                  ),
                ],
              ),
            )),
          ],
          if (showActions) ...[
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () => context.go('/login'),
                  icon: const Icon(Icons.login, size: 18),
                  label: const Text('Login'),
                ),
                TextButton(
                  onPressed: () => context.go('/register'),
                  child: const Text('Create Account'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class GuestModeChip extends StatelessWidget {
  final VoidCallback? onTap;
  
  const GuestModeChip({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_outline,
              size: 14,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 4),
            Text(
              'Guest',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}