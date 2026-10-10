import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/page_header.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final authState = ref.watch(authProvider);

    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.lg,
            AppSpacing.page,
            AppSpacing.xxl,
          ),
          children: [
            PageHeader(
              title: l10n.home,
              actions: [
                if (authState.isAuthenticated)
                  IconButton(
                    icon: const Icon(Icons.logout_rounded),
                    onPressed: () => ref.read(authProvider.notifier).logout(),
                    tooltip: l10n.logout,
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.login_rounded),
                    onPressed: () => context.go('/login'),
                    tooltip: l10n.login,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            Card(
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: theme.dividerColor),
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.welcomeTitle,
                            style: theme.textTheme.headlineMedium,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            l10n.welcomeSubtitle,
                            style: theme.textTheme.bodyMedium!.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.rocket_launch_rounded,
                        size: 28,
                        color: theme.colorScheme.onPrimary,
                      ),
                    ).animate().scale(
                      duration: 600.ms,
                      curve: Curves.easeOutBack,
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn(delay: 100.ms),
            const SizedBox(height: AppSpacing.xl),
            SectionTitle(l10n.getStarted),
            const SizedBox(height: AppSpacing.md),
            ...[
              (Icons.widgets_outlined, l10n.uiComponents, '/showcase/ui'),
              (
                Icons.view_day_outlined,
                l10n.loadingSkeletons,
                '/showcase/skeletons',
              ),
              (
                Icons.error_outline_rounded,
                l10n.errorHandling,
                '/showcase/errors',
              ),
              (Icons.upload_file_outlined, l10n.fileUpload, '/showcase/upload'),
              (Icons.language_rounded, l10n.language, '/showcase/language'),
              (Icons.edit_note_rounded, l10n.forms, '/forms'),
            ].map(
              (item) => _MenuTile(
                icon: item.$1,
                label: item.$2,
                onTap: () => context.go(item.$3),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SectionTitle(l10n.features),
            const SizedBox(height: AppSpacing.md),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FeatureItem(
                      icon: Icons.palette_outlined,
                      title: l10n.material3Design,
                      description: l10n.material3Description,
                    ),
                    _FeatureItem(
                      icon: Icons.color_lens_outlined,
                      title: l10n.dynamicTheming,
                      description: l10n.dynamicThemingDescription,
                    ),
                    _FeatureItem(
                      icon: Icons.devices_rounded,
                      title: l10n.responsiveLayout,
                      description: l10n.responsiveLayoutDescription,
                    ),
                    _FeatureItem(
                      icon: Icons.security_rounded,
                      title: l10n.authenticationReady,
                      description: l10n.authenticationDescription,
                    ),
                  ],
                ),
              ),
            ).animate().slideY(
              begin: 0.1,
              end: 0,
              delay: 300.ms,
              duration: 400.ms,
              curve: Curves.easeOutCubic,
            ),
          ],
        ),
      ),
    );
  }
}

/// Cadence-style menu row: bordered card with icon, label and chevron.
class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Material(
        color: theme.cardColor,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: theme.dividerColor),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: AppSpacing.lg),
                Expanded(child: Text(label, style: theme.textTheme.titleSmall)),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(description, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
