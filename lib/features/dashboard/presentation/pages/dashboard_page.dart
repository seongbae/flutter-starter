import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/stat_card.dart';
import '../widgets/chart_card.dart';
import '../widgets/activity_list.dart';
import '../../../../shared/widgets/skeletons/page_skeletons.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/page_header.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardState = ref.watch(dashboardStatsProvider);
    final authState = ref.watch(authProvider);
    final isAuthenticated = authState.isAuthenticated;

    final l10n = AppLocalizations.of(context);
    final header = PageHeader(
      title: l10n.dashboard,
      badge: isAuthenticated
          ? null
          : HeaderBadge(
              label: l10n.demoData,
              onTap: () => showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(AppLocalizations.of(context).guestMode),
                  content: Text(AppLocalizations.of(context).viewingDemoData),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(AppLocalizations.of(context).close),
                    ),
                  ],
                ),
              ),
            ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: () => ref.invalidate(dashboardStatsProvider),
        ),
      ],
    );
    final top = <Widget>[header, const SizedBox(height: AppSpacing.xl)];
    const pagePadding = EdgeInsets.fromLTRB(
      AppSpacing.page,
      AppSpacing.lg,
      AppSpacing.page,
      AppSpacing.xxl,
    );

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: dashboardState.when(
          data: (stats) => RefreshIndicator(
            onRefresh: () async => ref.invalidate(dashboardStatsProvider),
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 1200) {
                  return Padding(
                    padding: pagePadding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ...top,
                        Expanded(child: _buildDesktopLayout(context, stats)),
                      ],
                    ),
                  );
                }
                return ListView(
                  padding: pagePadding,
                  children: [
                    ...top,
                    if (constraints.maxWidth >= 600)
                      ..._buildTabletLayout(context, stats)
                    else
                      ..._buildMobileLayout(context, stats),
                  ],
                );
              },
            ),
          ),
          loading: () => const DashboardSkeleton(),
          error: (error, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('${l10n.error}: $error'),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => ref.invalidate(dashboardStatsProvider),
                  child: Text(l10n.retry),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Stat tiles laid out [perRow] to a row, each row as tall as its
  /// tallest tile.
  List<Widget> _statRows(BuildContext context, stats, int perRow) {
    final tiles = _statCards(context, stats);
    return [
      for (var r = 0; r < tiles.length; r += perRow) ...[
        if (r > 0) const SizedBox(height: AppSpacing.md),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = r; i < r + perRow && i < tiles.length; i++) ...[
                if (i > r) const SizedBox(width: AppSpacing.md),
                Expanded(child: tiles[i]),
              ],
            ],
          ),
        ),
      ],
    ];
  }

  List<Widget> _statCards(BuildContext context, stats) => [
    StatCard(
      title: AppLocalizations.of(context).totalUsers,
      value: stats.totalUsers.toString(),
      icon: Icons.people_rounded,
      color: Theme.of(context).colorScheme.primary,
    ),
    StatCard(
      title: AppLocalizations.of(context).activeUsers,
      value: stats.activeUsers.toString(),
      icon: Icons.verified_user_rounded,
      color: Colors.green,
    ),
    StatCard(
      title: AppLocalizations.of(context).totalRevenue,
      value: '\$${(stats.totalRevenue / 1000).toStringAsFixed(1)}K',
      icon: Icons.attach_money_rounded,
      color: Colors.blue,
    ),
    StatCard(
      title: AppLocalizations.of(context).growthRate,
      value: '${stats.growthRate.toStringAsFixed(1)}%',
      icon: stats.growthRate >= 0
          ? Icons.trending_up_rounded
          : Icons.trending_down_rounded,
      color: stats.growthRate >= 0 ? Colors.green : Colors.red,
    ),
  ];

  Widget _buildDesktopLayout(BuildContext context, stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._statRows(context, stats, 4),
        const SizedBox(height: AppSpacing.xl),
        // Charts Row
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    Expanded(
                      child: ChartCard(
                        title: AppLocalizations.of(context).userGrowth,
                        data: stats.userGrowthData,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Expanded(
                      child: ChartCard(
                        title: AppLocalizations.of(context).revenueTrend,
                        data: stats.revenueData,
                        color: Colors.green,
                        showCurrency: true,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: ActivityList(activities: stats.recentActivities)),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildTabletLayout(BuildContext context, stats) =>
      _buildStackedLayout(context, stats, statsPerRow: 4, chartHeight: 300);

  List<Widget> _buildMobileLayout(BuildContext context, stats) =>
      _buildStackedLayout(context, stats, statsPerRow: 2, chartHeight: 220);

  List<Widget> _buildStackedLayout(
    BuildContext context,
    stats, {
    required int statsPerRow,
    required double chartHeight,
  }) {
    return [
      ..._statRows(context, stats, statsPerRow),
      const SizedBox(height: AppSpacing.xl),
      // Charts
      SizedBox(
        height: chartHeight,
        child: ChartCard(
          title: AppLocalizations.of(context).userGrowth,
          data: stats.userGrowthData,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      SizedBox(
        height: chartHeight,
        child: ChartCard(
          title: AppLocalizations.of(context).revenueTrend,
          data: stats.revenueData,
          color: Colors.green,
          showCurrency: true,
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      SizedBox(
        height: 400,
        child: ActivityList(activities: stats.recentActivities),
      ),
    ];
  }
}
