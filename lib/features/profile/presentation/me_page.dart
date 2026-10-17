import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_spacing.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../../board/presentation/board_theme.dart';
import '../../board/presentation/widgets/board_sheet.dart';
import '../../project_settings/data/project_settings_repository.dart';
import 'profile_widgets.dart';

final _teamsProvider = FutureProvider.autoDispose<List<TeamOption>>(
  (ref) => ref.watch(projectSettingsRepositoryProvider).teams(),
);

/// The Me tab: the user's photo, name and email (tap to edit), the current
/// team (tap to switch), then Settings and Log out.
class MePage extends ConsumerWidget {
  const MePage({super.key});

  Future<void> _switchTeam(
    BuildContext context,
    WidgetRef ref,
    List<TeamOption> teams,
    int? currentTeamId,
  ) async {
    final picked = await showBoardSheet<TeamOption>(
      context,
      isScrollControlled: true,
      builder: (_) => _TeamSheet(teams: teams, currentTeamId: currentTeamId),
    );
    if (picked == null || picked.id == currentTeamId) return;
    try {
      // The board follows the user's current team and project.
      await ref.read(authProvider.notifier).selectTeam(picked.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(ApiException.from(e).message)));
      }
      return;
    }
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Switched to ${picked.name}')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider.select((s) => s.user));
    final teams = ref.watch(_teamsProvider);
    final text = Theme.of(context).textTheme;
    final teamList = teams.valueOrNull;
    final currentTeam = teamList
        ?.where((t) => t.id == user?.currentTeamId)
        .firstOrNull;

    return Scaffold(
      backgroundColor: BoardColors.bg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.page),
          children: [
            Text('Me', style: text.headlineLarge),
            const SizedBox(height: AppSpacing.xl),
            ProfileCard(
              onTap: () => context.push('/me/edit'),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: [
                    UserAvatar(
                      name: user?.name ?? '',
                      photoUrl: user?.photoUrl,
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.name ?? '—',
                            style: text.titleLarge,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            user?.email ?? '',
                            style: text.bodySmall!.copyWith(
                              color: BoardColors.inkSoft,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.edit_rounded,
                      size: 18,
                      color: BoardColors.inkSoft,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            MenuTile(
              icon: Icons.groups_outlined,
              label: 'Team',
              trailing: teams.hasError
                  ? "Couldn't load"
                  : teamList == null
                  ? '…'
                  : currentTeam?.name ?? 'None',
              onTap: teams.hasError
                  ? () => ref.invalidate(_teamsProvider)
                  : teamList == null
                  ? null
                  : () => _switchTeam(
                      context,
                      ref,
                      teamList,
                      user?.currentTeamId,
                    ),
            ),
            MenuTile(
              icon: Icons.settings_outlined,
              label: 'Settings',
              onTap: () => context.push('/me/settings'),
            ),
            MenuTile(
              icon: Icons.logout_rounded,
              label: 'Log out',
              danger: true,
              // Signing out sends the router back to the login page.
              onTap: () => ref.read(authProvider.notifier).logout(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lists the user's teams; pops with the one tapped.
class _TeamSheet extends StatelessWidget {
  const _TeamSheet({required this.teams, required this.currentTeamId});

  final List<TeamOption> teams;
  final int? currentTeamId;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              0,
              AppSpacing.page,
              AppSpacing.sm,
            ),
            child: Text('Teams', style: text.headlineSmall),
          ),
          if (teams.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.page),
              child: Text(
                "You aren't on any teams yet.",
                style: text.bodyMedium!.copyWith(color: BoardColors.inkSoft),
              ),
            ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final t in teams)
                  ListTile(
                    leading: const Icon(Icons.groups_outlined),
                    title: Text(t.name),
                    trailing: t.id == currentTeamId
                        ? const Icon(
                            Icons.check_rounded,
                            color: BoardColors.navy,
                          )
                        : null,
                    onTap: () => Navigator.of(context).pop(t),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}
