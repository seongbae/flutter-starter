import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/board_repository.dart';
import '../../domain/board_models.dart';
import '../../domain/task_sync.dart';
import '../board_theme.dart';
import '../providers/board_provider.dart';
import '../../../project_settings/data/project_settings_repository.dart';
import '../widgets/card_editor_sheet.dart';
import '../widgets/create_sheet.dart';
import '../widgets/section_order_sheet.dart';
import '../widgets/board_card.dart';
import '../widgets/task_detail_sheet.dart';
import '../widgets/board_sheet.dart';

/// Kanban board for the user's current project (as set on the server): one
/// column per section, swipe or tap the pills to switch, long-press a card to
/// reorder it, tap to edit or move, pull down to refresh.
class BoardPage extends ConsumerStatefulWidget {
  const BoardPage({super.key});

  @override
  ConsumerState<BoardPage> createState() => _BoardPageState();
}

class _BoardPageState extends ConsumerState<BoardPage> {
  final _pageController = PageController();
  final _tabKeys = <String, GlobalKey>{};
  int _index = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToColumn(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _onPageChanged(int index, List<BoardColumn> columns) {
    setState(() => _index = index);
    final tab = _tabKeys[columns[index].id]?.currentContext;
    if (tab != null) {
      Scrollable.ensureVisible(
        tab,
        alignment: 0.5,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _switchProject() async {
    final currentId = ref.read(currentContextProvider).projectId;
    final picked = await showBoardSheet<int>(
      context,
      builder: (context) => _ProjectSheet(currentProjectId: currentId),
    );
    if (picked == _newProject) return _createProject();
    if (picked == null || picked == currentId) return;
    await _selectProject(picked);
  }

  Future<void> _createProject() async {
    final repo = ref.read(boardRepositoryProvider);
    final id = await showNewProjectSheet(
      context,
      teams: ref.read(projectSettingsRepositoryProvider).teams(),
      currentTeamId: ref.read(currentContextProvider).teamId,
      create: (name, teamId) => repo.createProject(teamId: teamId, name: name),
    );
    if (id == null) return;
    ref.invalidate(projectChoicesProvider);
    await _selectProject(id);
  }

  /// Long-press menu for a section tab: rename, reorder or delete it.
  Future<void> _sectionMenu(BoardColumn column) async {
    final sections = [
      for (final c in ref.read(boardProvider).currentProject.columns)
        if (c.id != unsectionedColumnId) c,
    ];
    final action = await showBoardSheet<_SectionAction>(
      context,
      builder: (context) => _SectionMenu(
        column: column,
        canReorder: sections.length > 1,
        canDelete: sections.length > 1,
        hasUnsectioned:
            sections.length <
            ref.read(boardProvider).currentProject.columns.length,
      ),
    );
    if (!mounted || action == null) return;
    final repo = ref.read(boardRepositoryProvider);
    final projectId = int.parse(ref.read(boardProvider).currentProject.id);

    switch (action) {
      case _SectionAction.rename:
        final renamed = await showRenameSectionSheet(
          context,
          currentName: column.name,
          rename: (name) => repo.renameSection(column.id, name),
        );
        if (renamed == true) await _refresh();
      case _SectionAction.reorder:
        final saved = await showSectionOrderSheet(
          context,
          sections: sections,
          save: (ids) => repo.reorderSections(projectId, ids),
        );
        if (saved != true) return;
        await _refresh();
        _showColumn(column.id);
      case _SectionAction.delete:
        await _deleteSection(column);
    }
  }

  /// Makes "No section" a real section, first in the order, holding the
  /// tasks that were in it.
  Future<void> _turnIntoSection(BoardColumn unsectioned) async {
    final project = ref.read(boardProvider).currentProject;
    final id = await showSectionFromUnsectionedSheet(
      context,
      taskCount: unsectioned.cards.length,
      create: (name) => ref
          .read(boardRepositoryProvider)
          .sectionFromUnsectioned(
            int.parse(project.id),
            name: name,
            taskIds: [for (final c in unsectioned.cards) c.id],
            sectionIds: [
              for (final c in project.columns)
                if (c.id != unsectionedColumnId) c.id,
            ],
          ),
    );
    if (id == null) return;
    await _refresh();
    _showColumn('$id');
  }

  Future<void> _deleteSection(BoardColumn column) async {
    final count = column.cards.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${column.name}"?'),
        content: Text(
          count == 0
              ? 'This section is empty.'
              : 'Its ${count == 1 ? 'task' : '$count tasks'} will move to '
                    '"No section".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(boardRepositoryProvider).deleteSection(column.id);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(ApiException.from(e).message)),
      );
      return;
    }
    await _refresh();
    messenger.showSnackBar(SnackBar(content: Text('Deleted "${column.name}"')));
  }

  /// Switches to the column with [columnId], if it's still on the board.
  void _showColumn(String columnId) {
    if (!mounted) return;
    final columns = ref.read(boardProvider).currentProject.columns;
    final index = columns.indexWhere((c) => c.id == columnId);
    if (index < 0) return;
    setState(() => _index = index);
    if (_pageController.hasClients) _pageController.jumpToPage(index);
  }

  /// Adds a section, reloads the board and shows the new section.
  Future<void> _addSection() async {
    final projectId = int.parse(ref.read(boardProvider).currentProject.id);
    final id = await showNewSectionSheet(
      context,
      create: (name) =>
          ref.read(boardRepositoryProvider).createSection(projectId, name),
    );
    if (id == null) return;
    await _refresh();
    _showColumn('$id');
  }

  Future<void> _selectProject(int projectId) async {
    try {
      await ref.read(authProvider.notifier).selectProject(projectId);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
      return;
    }
    setState(() => _index = 0);
    if (_pageController.hasClients) _pageController.jumpToPage(0);
  }

  /// Picks up a team or project changed elsewhere, then reloads the board.
  Future<void> _refresh() async {
    await ref.read(authProvider.notifier).refreshUser();
    ref.invalidate(boardDataProvider);
    ref.invalidate(projectChoicesProvider);
    try {
      await ref.read(boardDataProvider.future);
    } catch (_) {
      // Shown by the error view.
    }
  }

  @override
  Widget build(BuildContext context) {
    // A restored session waits for its first /me before choosing a project.
    final hasUser = ref.watch(authProvider.select((s) => s.user != null));
    final data = ref.watch(boardDataProvider);

    if (!hasUser || (data.isLoading && !data.hasValue)) {
      return const _StatusScaffold(child: CircularProgressIndicator());
    }
    if (data.hasError && !data.hasValue) {
      return _StatusScaffold(
        child: _Message(
          icon: Icons.cloud_off_rounded,
          title: "Couldn't load your tasks",
          body: ApiException.from(data.error!).message,
          action: FilledButton(onPressed: _refresh, child: const Text('Retry')),
        ),
      );
    }
    if (data.value == null) {
      return _StatusScaffold(
        child: _ChooseProject(
          onSelect: _selectProject,
          onCreate: _createProject,
          onRefresh: _refresh,
        ),
      );
    }
    return _buildBoard(context, reloading: data.isLoading);
  }

  Widget _buildBoard(BuildContext context, {required bool reloading}) {
    final board = ref.watch(boardProvider);
    final project = board.currentProject;
    final columns = project.columns;
    final index = _index.clamp(0, columns.length - 1);

    return Scaffold(
      backgroundColor: BoardColors.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SizedBox(
              height: 2,
              child: reloading ? const LinearProgressIndicator() : null,
            ),
            _Header(
              project: project,
              teamName: board.teamName,
              onSwitchProject: _switchProject,
              onSettings: () => context.push('/project-settings'),
            ),
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.page,
                ),
                itemCount: columns.length + (project.canAddSections ? 1 : 0),
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) => i == columns.length
                    ? _AddSectionTab(onTap: _addSection)
                    : _ColumnTab(
                        key: _tabKeys.putIfAbsent(columns[i].id, GlobalKey.new),
                        column: columns[i],
                        selected: i == index,
                        onTap: () => _goToColumn(i),
                        // "No section" isn't a real section to edit.
                        onLongPress: !project.canAddSections
                            ? null
                            : columns[i].id == unsectionedColumnId
                            ? () => _turnIntoSection(columns[i])
                            : () => _sectionMenu(columns[i]),
                      ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                // Each column's list sits one level inside the PageView.
                notificationPredicate: (n) => n.depth == 1,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: columns.length,
                  onPageChanged: (i) => _onPageChanged(i, columns),
                  itemBuilder: (context, i) => _ColumnPage(
                    key: ValueKey(columns[i].id),
                    column: columns[i],
                    position: i + 1,
                    total: columns.length,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showCardEditor(context, columnId: columns[index].id),
        backgroundColor: BoardColors.green,
        foregroundColor: BoardColors.navy,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        icon: const Icon(Icons.add_rounded, size: 20),
        label: Text(
          'Task',
          style: Theme.of(context).textTheme.labelLarge!.copyWith(
            color: BoardColors.navy,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.project,
    required this.teamName,
    required this.onSwitchProject,
    required this.onSettings,
  });

  final Project project;
  final String? teamName;
  final VoidCallback onSwitchProject;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page - 6,
        AppSpacing.xs,
        AppSpacing.xs,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: InkWell(
                onTap: onSwitchProject,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ProjectDot(color: project.color),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (teamName != null)
                              Text(
                                teamName!,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelSmall!
                                    .copyWith(color: BoardColors.inkSoft),
                              ),
                            Text(
                              project.name,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium!
                                  .copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: BoardColors.ink,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: BoardColors.navy,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Project settings',
            onPressed: onSettings,
            icon: const Icon(
              Icons.settings_outlined,
              size: 24,
              color: BoardColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectDot extends StatelessWidget {
  const _ProjectDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: BoardColors.ink, width: 1.4),
      ),
    );
  }
}

class _ColumnTab extends StatelessWidget {
  const _ColumnTab({
    super.key,
    required this.column,
    required this.selected,
    required this.onTap,
    this.onLongPress,
  });

  final BoardColumn column;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final count = column.limit == null
        ? '${column.cards.length}'
        : '${column.cards.length}/${column.limit}';
    // "No section" isn't a real section, so it's outlined, not filled.
    final virtual = column.id == unsectionedColumnId;
    final color = virtual
        ? (selected ? BoardColors.navy : BoardColors.inkSoft)
        : (selected ? Colors.white : BoardColors.ink);
    final style = Theme.of(
      context,
    ).textTheme.titleSmall!.copyWith(fontSize: 13, color: color);

    return Material(
      color: virtual
          ? Colors.transparent
          : (selected ? BoardColors.navy : BoardColors.chip),
      shape: virtual
          ? StadiumBorder(
              side: BorderSide(
                color: selected ? BoardColors.navy : BoardColors.line,
                width: 1.5,
              ),
            )
          : const StadiumBorder(),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Center(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: column.name),
                  const TextSpan(text: '  '),
                  TextSpan(
                    text: count,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: !selected && column.isFull
                          ? Theme.of(context).colorScheme.error
                          : color,
                    ),
                  ),
                ],
              ),
              style: style,
            ),
          ),
        ),
      ),
    );
  }
}

enum _SectionAction { rename, reorder, delete }

class _SectionMenu extends StatelessWidget {
  const _SectionMenu({
    required this.column,
    required this.canReorder,
    required this.canDelete,
    required this.hasUnsectioned,
  });

  final BoardColumn column;
  final bool canReorder;
  final bool canDelete;

  /// Whether the board also shows "No section", which a user may take for
  /// another section.
  final bool hasUnsectioned;

  @override
  Widget build(BuildContext context) {
    void pick(_SectionAction a) => Navigator.of(context).pop(a);
    final error = Theme.of(context).colorScheme.error;

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
            child: Text(
              column.name,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Rename'),
            onTap: () => pick(_SectionAction.rename),
          ),
          if (canReorder)
            ListTile(
              leading: const Icon(Icons.swap_horiz_rounded),
              title: const Text('Reorder sections'),
              onTap: () => pick(_SectionAction.reorder),
            ),
          ListTile(
            enabled: canDelete,
            leading: Icon(
              Icons.delete_outline_rounded,
              color: canDelete ? error : null,
            ),
            title: Text(
              'Delete',
              style: canDelete ? TextStyle(color: error) : null,
            ),
            subtitle: canDelete
                ? null
                : Text(
                    hasUnsectioned
                        ? 'This is the only section, and a project needs one. '
                              '"No section" holds tasks without a section and '
                              "doesn't count."
                        : 'This is the only section, and a project needs one.',
                  ),
            onTap: () => pick(_SectionAction.delete),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}

/// Sits after the last section tab; outlined so it doesn't read as one.
class _AddSectionTab extends StatelessWidget {
  const _AddSectionTab({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Add section',
      child: Material(
        color: Colors.transparent,
        shape: const StadiumBorder(
          side: BorderSide(color: BoardColors.line, width: 1.5),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Icon(Icons.add_rounded, size: 20, color: BoardColors.navy),
          ),
        ),
      ),
    );
  }
}

class _ColumnPage extends ConsumerWidget {
  const _ColumnPage({
    super.key,
    required this.column,
    required this.position,
    required this.total,
  });

  final BoardColumn column;
  final int position;
  final int total;

  /// Shows the task; if it gets completed, offers to undo that.
  Future<void> _openTask(
    BuildContext context,
    WidgetRef ref,
    TaskCard card,
    String columnId,
    int index,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(boardProvider.notifier);
    final completed = await showTaskDetail(context, cardId: card.id);
    if (completed != true) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text('Completed "${card.title}"'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            final error = await notifier.reopenCard(card.id, columnId, index);
            if (error != null) {
              messenger.showSnackBar(SnackBar(content: Text(error)));
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final board = ref.watch(boardProvider);
    final now = DateTime.now();

    final banner = Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: _ColumnBanner(column: column, position: position, total: total),
    );

    if (column.cards.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
        children: [
          banner,
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
            child: Text(
              'No tasks here yet.\nTap + Task to add one.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium!.copyWith(color: BoardColors.inkSoft),
            ),
          ),
        ],
      );
    }

    return ReorderableListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      // Leaves room under the last card for the floating "+ Task" button.
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        0,
        AppSpacing.page,
        96,
      ),
      header: banner,
      itemCount: column.cards.length,
      onReorderItem: (from, to) async {
        final messenger = ScaffoldMessenger.of(context);
        final error = await ref
            .read(boardProvider.notifier)
            .reorderCard(column.id, from, to);
        if (error != null) {
          messenger.showSnackBar(SnackBar(content: Text(error)));
        }
      },
      proxyDecorator: (child, _, __) =>
          Material(color: Colors.transparent, child: child),
      itemBuilder: (context, i) {
        final card = column.cards[i];
        return Padding(
          key: ValueKey(card.id),
          padding: const EdgeInsets.only(top: 10),
          child: BoardCard(
            card: card,
            accent: column.accent,
            assignee: board.memberById(card.assigneeId),
            now: now,
            onTap: () => _openTask(context, ref, card, column.id, i),
          ),
        );
      },
    );
  }
}

class _ColumnBanner extends StatelessWidget {
  const _ColumnBanner({
    required this.column,
    required this.position,
    required this.total,
  });

  final BoardColumn column;
  final int position;
  final int total;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final limit = column.limit == null ? 'No limit' : 'Limit ${column.limit}';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: column.accent,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  column.name,
                  style: text.titleLarge!.copyWith(color: BoardColors.ink),
                ),
                const SizedBox(height: 4),
                Text(
                  '$position of $total · $limit',
                  style: text.labelSmall!.copyWith(color: BoardColors.ink),
                ),
              ],
            ),
          ),
          Text(
            '${column.cards.length}',
            style: text.headlineLarge!.copyWith(color: BoardColors.ink),
          ),
        ],
      ),
    );
  }
}

/// The current team's projects; pops the chosen project's id.
class _ProjectSheet extends ConsumerWidget {
  const _ProjectSheet({required this.currentProjectId});

  final int? currentProjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final choices = ref.watch(projectChoicesProvider);

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
            child: Text('Projects', style: text.headlineSmall),
          ),
          Flexible(
            child: _ProjectList(
              choices: choices,
              currentProjectId: currentProjectId,
              onSelect: (id) => Navigator.of(context).pop(id),
              onCreate: () => Navigator.of(context).pop(_newProject),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}

class _ProjectList extends StatelessWidget {
  const _ProjectList({
    required this.choices,
    required this.onSelect,
    required this.onCreate,
    this.currentProjectId,
  });

  final AsyncValue<List<ProjectSummary>> choices;
  final int? currentProjectId;
  final ValueChanged<int> onSelect;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final soft = Theme.of(
      context,
    ).textTheme.bodyMedium!.copyWith(color: BoardColors.inkSoft);

    return choices.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(AppSpacing.page),
        child: Text(ApiException.from(e).message, style: soft),
      ),
      data: (projects) => ListView(
        shrinkWrap: true,
        children: [
          if (projects.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.page),
              child: Text('No projects yet.', style: soft),
            ),
          for (final p in projects)
            ListTile(
              leading: _ProjectDot(color: p.color),
              title: Text(p.name),
              trailing: p.id == currentProjectId
                  ? const Icon(Icons.check_rounded, color: BoardColors.navy)
                  : null,
              onTap: () => onSelect(p.id),
            ),
          ListTile(
            leading: const Icon(Icons.add_rounded, color: BoardColors.navy),
            title: const Text(
              'New project',
              style: TextStyle(color: BoardColors.navy),
            ),
            onTap: onCreate,
          ),
        ],
      ),
    );
  }
}

/// Popped from the project sheet to mean "create a new project".
const _newProject = -1;

/// Shown when the user has no current project: pick one to open.
class _ChooseProject extends ConsumerWidget {
  const _ChooseProject({
    required this.onSelect,
    required this.onCreate,
    required this.onRefresh,
  });

  final ValueChanged<int> onSelect;
  final VoidCallback onCreate;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Message(
            icon: Icons.push_pin_rounded,
            title: 'Pick a project',
            body: "Choose the project whose tasks you'd like to see.",
            action: TextButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Refresh'),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Flexible(
            child: _ProjectList(
              choices: ref.watch(projectChoicesProvider),
              onSelect: onSelect,
              onCreate: onCreate,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusScaffold extends StatelessWidget {
  const _StatusScaffold({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BoardColors.bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.page),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 40, color: BoardColors.navy),
        const SizedBox(height: AppSpacing.md),
        Text(title, style: text.titleLarge, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.xs),
        Text(
          body,
          textAlign: TextAlign.center,
          style: text.bodyMedium!.copyWith(color: BoardColors.inkSoft),
        ),
        if (action != null) ...[const SizedBox(height: AppSpacing.md), action!],
      ],
    );
  }
}
