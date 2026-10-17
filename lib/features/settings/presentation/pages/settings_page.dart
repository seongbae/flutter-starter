import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../../core/constants/colors.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../shared/widgets/page_header.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key, this.title});

  /// Defaults to "Settings".
  final String? title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeNotifierProvider);
    final authState = ref.watch(authProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: _buildSettings(
          context,
          ref,
          themeState,
          authState.isAuthenticated,
        ),
      ),
    );
  }

  Widget _buildSettings(
    BuildContext context,
    WidgetRef ref,
    ThemeState themeState,
    bool isAuthenticated,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.lg,
        AppSpacing.page,
        AppSpacing.xxl,
      ),
      children: [
        PageHeader(
          title: title ?? AppLocalizations.of(context).settings,
          actions: [
            if (isAuthenticated)
              IconButton(
                icon: const Icon(Icons.logout_rounded),
                onPressed: () {
                  ref.read(authProvider.notifier).logout();
                  context.go('/home');
                },
                tooltip: AppLocalizations.of(context).logout,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),

        SectionTitle(AppLocalizations.of(context).appearance),
        const SizedBox(height: AppSpacing.md),
        GroupCard(
          children: [
            SwitchListTile(
              secondary: const Icon(Icons.dark_mode_outlined, size: 20),
              title: Text(AppLocalizations.of(context).darkMode),
              subtitle: Text(
                isAuthenticated
                    ? AppLocalizations.of(context).useDarkTheme
                    : AppLocalizations.of(context).useDarkThemeNotSaved,
              ),
              value: themeState.themeMode == ThemeMode.dark,
              onChanged: (value) {
                ref
                    .read(themeNotifierProvider.notifier)
                    .setThemeMode(value ? ThemeMode.dark : ThemeMode.light);
              },
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        SectionTitle(AppLocalizations.of(context).themeColor),
        const SizedBox(height: AppSpacing.md),
        GroupCard(
          children: [
            ...[
              ColorSeed.cadence,
              ...ColorSeed.values.where((s) => s != ColorSeed.cadence),
            ].map(
              (seed) => RadioListTile<ColorSeed>(
                title: Text(seed.label),
                secondary: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: seed.color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                ),
                value: seed,
                groupValue: themeState.colorSeed,
                onChanged: (value) {
                  if (value != null) {
                    ref
                        .read(themeNotifierProvider.notifier)
                        .setColorSeed(value);
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        SectionTitle(AppLocalizations.of(context).about),
        const SizedBox(height: AppSpacing.md),
        GroupCard(
          children: [
            ListTile(
              leading: const Icon(Icons.info_outline_rounded, size: 20),
              trailing: const Icon(Icons.chevron_right_rounded, size: 20),
              title: Text(AppLocalizations.of(context).flutterStarterApp),
              subtitle: Text(AppLocalizations.of(context).version),
              onTap: () {
                showAboutDialog(
                  context: context,
                  applicationName: AppLocalizations.of(context).flutterStarter,
                  applicationVersion: '1.0.0',
                  applicationLegalese: AppLocalizations.of(
                    context,
                  ).material3StarterTemplate,
                  children: [
                    const SizedBox(height: 16),
                    Text(AppLocalizations.of(context).starterFeatures),
                  ],
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}
