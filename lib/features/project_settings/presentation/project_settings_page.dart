import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_spacing.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../../board/presentation/board_theme.dart';
import '../../board/presentation/providers/board_provider.dart';
import '../../board/presentation/widgets/board_sheet.dart';
import '../data/project_settings_repository.dart';

/// Swatches for the project color; the first five are the board's palette.
const _swatches = [
  Color(0xFF8BC34A),
  Color(0xFF5B8DEF),
  Color(0xFFF0A35E),
  Color(0xFFE57FA6),
  Color(0xFF5CC3CF),
  Color(0xFF253060),
  Color(0xFF1DDB77),
  Color(0xFFE5534B),
  Color(0xFF9B6BDF),
  Color(0xFFF2C94C),
  Color(0xFF8A93A6),
];

/// Settings for the current project: name, description, color, permission
/// and members, plus moving, archiving and deleting it. Only managers can
/// change anything; everyone else sees it read-only.
class ProjectSettingsPage extends ConsumerStatefulWidget {
  const ProjectSettingsPage({super.key});

  @override
  ConsumerState<ProjectSettingsPage> createState() =>
      _ProjectSettingsPageState();
}

class _ProjectSettingsPageState extends ConsumerState<ProjectSettingsPage> {
  bool _busy = false;

  ProjectSettingsRepository get _repo =>
      ref.read(projectSettingsRepositoryProvider);

  /// Runs [action], then reloads this page and the board. Returns whether it
  /// succeeded; failures are shown in a snackbar.
  Future<bool> _run(int projectId, Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(projectDetailsProvider(projectId));
      ref.invalidate(projectMembersProvider(projectId));
      ref.invalidate(boardDataProvider);
      ref.invalidate(projectChoicesProvider);
      return true;
    } catch (e) {
      _snack(ApiException.from(e).message);
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickVisibility(ProjectDetails project) async {
    final picked = await showBoardSheet<ProjectVisibility>(
      context,
      builder: (context) => _ChoiceSheet<ProjectVisibility>(
        title: 'Permission',
        options: ProjectVisibility.values,
        selected: project.visibility,
        label: (v) => v.label,
        description: (v) => v.description,
      ),
    );
    if (picked == null || picked == project.visibility) return;
    await _run(project.id, () => _repo.update(project.id, visibility: picked));
  }

  Future<void> _manageMember(
    ProjectDetails project,
    ProjectMember member,
  ) async {
    final result = await showBoardSheet<Object>(
      context,
      builder: (context) => _ChoiceSheet<MemberAccess>(
        title: member.name,
        options: MemberAccess.values,
        selected: member.access,
        label: (v) => v.label,
        description: (v) => v.description,
        footer: ListTile(
          leading: const Icon(Icons.person_remove_outlined, color: _danger),
          title: const Text(
            'Remove from project',
            style: TextStyle(color: _danger),
          ),
          onTap: () => Navigator.of(context).pop(_remove),
        ),
      ),
    );
    if (result == _remove) {
      final confirmed = await _confirm(
        title: 'Remove ${member.name}?',
        body:
            "They'll lose access to this project and be unassigned from its tasks.",
        action: 'Remove',
      );
      if (!confirmed) return;
      await _run(project.id, () => _repo.removeMember(project.id, member.id));
    } else if (result is MemberAccess && result != member.access) {
      await _run(
        project.id,
        () => _repo.setAccess(project.id, member.id, result),
      );
    }
  }

  Future<void> _addMember(
    ProjectDetails project,
    List<ProjectMember> current,
  ) async {
    final teamId = project.teamId;
    if (teamId == null) return;
    final picked = await showBoardSheet<ProjectMember>(
      context,
      isScrollControlled: true,
      builder: (context) => _AddMemberSheet(
        teamMembers: _repo.teamMembers(teamId),
        excludeIds: {for (final m in current) m.id},
      ),
    );
    if (picked == null) return;
    final added = await _run(
      project.id,
      () => _repo.addMember(project.id, picked.id),
    );
    if (added) _snack('Added ${picked.name}');
  }

  Future<void> _move(ProjectDetails project) async {
    final picked = await showBoardSheet<TeamOption>(
      context,
      isScrollControlled: true,
      builder: (context) =>
          _MoveSheet(teams: _repo.teams(), currentTeamId: project.teamId),
    );
    if (picked == null) return;
    final confirmed = await _confirm(
      title: 'Move to ${picked.name}?',
      body:
          '"${project.name}" and its tasks will belong to ${picked.name}. '
          'Its members keep their access.',
      action: 'Move',
    );
    if (!confirmed) return;
    final moved = await _run(project.id, () async {
      await _repo.move(project.id, picked.id);
      // Follow the project to its new team.
      await ref.read(authProvider.notifier).selectProject(project.id);
    });
    if (moved) _snack('Moved to ${picked.name}');
  }

  Future<void> _archive(ProjectDetails project) async {
    final confirmed = await _confirm(
      title: 'Archive "${project.name}"?',
      body:
          "It'll be hidden from project lists. You can unarchive it on "
          'traqker.com.',
      action: 'Archive',
    );
    if (!confirmed) return;
    await _close(project, () => _repo.archive(project.id), 'Project archived');
  }

  Future<void> _delete(ProjectDetails project) async {
    final confirmed = await _confirm(
      title: 'Delete "${project.name}"?',
      body: 'The project and all of its tasks will be deleted for everyone.',
      action: 'Delete',
    );
    if (!confirmed) return;
    await _close(project, () => _repo.delete(project.id), 'Project deleted');
  }

  /// Archives or deletes the project, then returns to the board, which asks
  /// for another project.
  Future<void> _close(
    ProjectDetails project,
    Future<void> Function() action,
    String done,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final closed = await _run(project.id, () async {
      await action();
      await ref.read(authProvider.notifier).clearProject();
    });
    if (!closed || !mounted) return;
    context.pop();
    messenger.showSnackBar(SnackBar(content: Text(done)));
  }

  Future<bool> _confirm({
    required String title,
    required String body,
    required String action,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Theme(
        data: BoardTheme.data,
        child: AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(action),
            ),
          ],
        ),
      ),
    );
    return confirmed == true;
  }

  @override
  Widget build(BuildContext context) {
    final projectId = ref.watch(currentContextProvider).projectId;

    return Scaffold(
      backgroundColor: BoardColors.bg,
      appBar: AppBar(
        backgroundColor: BoardColors.bg,
        title: const Text('Project settings'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: SizedBox(
            height: 2,
            child: _busy ? const LinearProgressIndicator() : null,
          ),
        ),
      ),
      body: projectId == null
          ? const SizedBox.shrink()
          : _body(context, projectId),
    );
  }

  Widget _body(BuildContext context, int projectId) {
    final details = ref.watch(projectDetailsProvider(projectId));
    final members = ref.watch(projectMembersProvider(projectId));

    if (!details.hasValue) {
      return Center(
        child: details.hasError
            ? Padding(
                padding: const EdgeInsets.all(AppSpacing.page),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      ApiException.from(details.error!).message,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton(
                      onPressed: () =>
                          ref.invalidate(projectDetailsProvider(projectId)),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            : const CircularProgressIndicator(),
      );
    }

    final project = details.requireValue;
    final manage = project.canManage && !_busy;
    final myId = ref.watch(authProvider.select((s) => s.user?.id));
    final text = Theme.of(context).textTheme;

    return AbsorbPointer(
      absorbing: _busy,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          AppSpacing.sm,
          AppSpacing.page,
          AppSpacing.xxl,
        ),
        children: [
          if (!project.canManage)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Text(
                'Only project managers can change these settings.',
                style: text.bodyMedium!.copyWith(color: BoardColors.inkSoft),
              ),
            ),
          _Section(
            title: 'General',
            child: _GeneralForm(
              // Rebuilt from the server's values after each save.
              key: ValueKey('${project.name}\n${project.description}'),
              project: project,
              enabled: manage,
              onSave: (name, description) => _run(
                project.id,
                () => _repo.update(
                  project.id,
                  name: name == project.name ? null : name,
                  description: description == project.description
                      ? null
                      : () => description,
                ),
              ),
            ),
          ),
          _Section(
            title: 'Color',
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: _ColorPicker(
                selected: project.color,
                onPick: manage
                    ? (c) => _run(
                        project.id,
                        () => _repo.update(project.id, color: c),
                      )
                    : null,
              ),
            ),
          ),
          _Section(
            title: 'Permission',
            child: ListTile(
              title: Text(project.visibility.label),
              subtitle: Text(project.visibility.description),
              trailing: manage ? const Icon(Icons.chevron_right_rounded) : null,
              onTap: manage ? () => _pickVisibility(project) : null,
            ),
          ),
          _Section(
            title: 'Members',
            child: members.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) =>
                  ListTile(title: Text(ApiException.from(e).message)),
              data: (list) => Column(
                children: [
                  for (final m in list)
                    ListTile(
                      leading: _Avatar(name: m.name),
                      title: Text(m.id == myId ? '${m.name} (you)' : m.name),
                      subtitle: m.email == null ? null : Text(m.email!),
                      trailing: Text(
                        m.access.label,
                        style: text.labelLarge!.copyWith(
                          color: BoardColors.inkSoft,
                        ),
                      ),
                      onTap: manage && m.id != myId
                          ? () => _manageMember(project, m)
                          : null,
                    ),
                  if (manage && project.teamId != null)
                    ListTile(
                      leading: const Icon(
                        Icons.person_add_alt_1_outlined,
                        color: BoardColors.navy,
                      ),
                      title: const Text(
                        'Add member',
                        style: TextStyle(color: BoardColors.navy),
                      ),
                      onTap: () => _addMember(project, list),
                    ),
                ],
              ),
            ),
          ),
          _Section(
            title: 'About',
            child: Column(
              children: [
                _InfoRow(label: 'Team', value: project.teamName ?? '—'),
                _InfoRow(label: 'Created by', value: project.ownerName ?? '—'),
                _InfoRow(
                  label: 'Created',
                  value: project.createdAt == null
                      ? '—'
                      : DateFormat.yMMMd().format(project.createdAt!),
                ),
              ],
            ),
          ),
          if (project.canManage)
            _Section(
              title: 'Manage project',
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.drive_file_move_outline),
                    title: const Text('Move to another team'),
                    onTap: () => _move(project),
                  ),
                  ListTile(
                    leading: const Icon(Icons.archive_outlined),
                    title: const Text('Archive project'),
                    onTap: () => _archive(project),
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete_outline, color: _danger),
                    title: const Text(
                      'Delete project',
                      style: TextStyle(color: _danger),
                    ),
                    onTap: () => _delete(project),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

const _danger = Color(0xFFD64545);

/// Popped from the member sheet to mean "remove this member".
const _remove = #remove;

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.sm),
            child: Text(title, style: Theme.of(context).textTheme.labelLarge),
          ),
          Material(
            color: BoardColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            clipBehavior: Clip.antiAlias,
            child: child,
          ),
        ],
      ),
    );
  }
}

class _GeneralForm extends StatefulWidget {
  const _GeneralForm({
    super.key,
    required this.project,
    required this.enabled,
    required this.onSave,
  });

  final ProjectDetails project;
  final bool enabled;
  final Future<bool> Function(String name, String description) onSave;

  @override
  State<_GeneralForm> createState() => _GeneralFormState();
}

class _GeneralFormState extends State<_GeneralForm> {
  late final _name = TextEditingController(text: widget.project.name);
  late final _description = TextEditingController(
    text: widget.project.description,
  );

  @override
  void initState() {
    super.initState();
    _name.addListener(_changed);
    _description.addListener(_changed);
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  void _changed() => setState(() {});

  bool get _dirty =>
      _name.text.trim() != widget.project.name ||
      _description.text.trim() != widget.project.description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _name,
            enabled: widget.enabled,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _description,
            enabled: widget.enabled,
            minLines: 2,
            maxLines: 6,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Description'),
          ),
          if (widget.enabled && _dirty) ...[
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: _name.text.trim().isEmpty
                  ? null
                  : () {
                      FocusScope.of(context).unfocus();
                      widget.onSave(
                        _name.text.trim(),
                        _description.text.trim(),
                      );
                    },
              child: const Text('Save'),
            ),
          ],
        ],
      ),
    );
  }
}

class _ColorPicker extends StatelessWidget {
  const _ColorPicker({required this.selected, required this.onPick});

  final Color selected;
  final ValueChanged<Color>? onPick;

  @override
  Widget build(BuildContext context) {
    // A color set on the web that isn't a swatch still shows as chosen.
    final colors = [
      ..._swatches,
      if (!_swatches.any((c) => c.toARGB32() == selected.toARGB32())) selected,
    ];
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final c in colors)
          Semantics(
            button: true,
            selected: c.toARGB32() == selected.toARGB32(),
            child: InkResponse(
              onTap: onPick == null || c.toARGB32() == selected.toARGB32()
                  ? null
                  : () => onPick!(c),
              radius: 22,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: c.toARGB32() == selected.toARGB32()
                      ? Border.all(color: BoardColors.ink, width: 3)
                      : null,
                ),
                child: c.toARGB32() == selected.toARGB32()
                    ? const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 18,
                      )
                    : null,
              ),
            ),
          ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: text.bodyMedium!.copyWith(color: BoardColors.inkSoft),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: text.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 18,
      backgroundColor: BoardColors.chip,
      child: Text(
        name.isEmpty ? '?' : name.characters.first.toUpperCase(),
        style: const TextStyle(
          color: BoardColors.navy,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Picks one of [options]; pops with the choice, or with whatever [footer]
/// pops.
class _ChoiceSheet<T> extends StatelessWidget {
  const _ChoiceSheet({
    required this.title,
    required this.options,
    required this.selected,
    required this.label,
    required this.description,
    this.footer,
  });

  final String title;
  final List<T> options;
  final T selected;
  final String Function(T) label;
  final String Function(T) description;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
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
              title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          for (final o in options)
            ListTile(
              title: Text(label(o)),
              subtitle: Text(description(o)),
              trailing: o == selected
                  ? const Icon(Icons.check_rounded, color: BoardColors.navy)
                  : null,
              onTap: () => Navigator.of(context).pop(o),
            ),
          if (footer != null) ...[const Divider(), footer!],
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}

/// Lists team members who aren't on the project yet; pops with the one
/// tapped.
class _AddMemberSheet extends StatelessWidget {
  const _AddMemberSheet({required this.teamMembers, required this.excludeIds});

  final Future<List<ProjectMember>> teamMembers;
  final Set<int> excludeIds;

  @override
  Widget build(BuildContext context) {
    final soft = Theme.of(
      context,
    ).textTheme.bodyMedium!.copyWith(color: BoardColors.inkSoft);
    return _ListSheet(
      title: 'Add member',
      child: FutureBuilder(
        future: teamMembers,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _SheetMessage(
              ApiException.from(snapshot.error!).message,
              style: soft,
            );
          }
          if (!snapshot.hasData) return const _SheetLoading();
          final candidates = [
            for (final m in snapshot.data!)
              if (!excludeIds.contains(m.id)) m,
          ];
          if (candidates.isEmpty) {
            return _SheetMessage(
              'Everyone on the team is already a member. Invite new people '
              'on traqker.com.',
              style: soft,
            );
          }
          return ListView(
            shrinkWrap: true,
            children: [
              for (final m in candidates)
                ListTile(
                  leading: _Avatar(name: m.name),
                  title: Text(m.name),
                  subtitle: m.email == null ? null : Text(m.email!),
                  onTap: () => Navigator.of(context).pop(m),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Lists the other teams the user manages; pops with the one tapped.
class _MoveSheet extends StatelessWidget {
  const _MoveSheet({required this.teams, required this.currentTeamId});

  final Future<List<TeamOption>> teams;
  final int? currentTeamId;

  @override
  Widget build(BuildContext context) {
    final soft = Theme.of(
      context,
    ).textTheme.bodyMedium!.copyWith(color: BoardColors.inkSoft);
    return _ListSheet(
      title: 'Move to team',
      child: FutureBuilder(
        future: teams,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _SheetMessage(
              ApiException.from(snapshot.error!).message,
              style: soft,
            );
          }
          if (!snapshot.hasData) return const _SheetLoading();
          final targets = [
            for (final t in snapshot.data!)
              if (t.canManage && t.id != currentTeamId) t,
          ];
          if (targets.isEmpty) {
            return _SheetMessage(
              "You don't manage any other teams.",
              style: soft,
            );
          }
          return ListView(
            shrinkWrap: true,
            children: [
              for (final t in targets)
                ListTile(
                  leading: const Icon(Icons.groups_outlined),
                  title: Text(t.name),
                  onTap: () => Navigator.of(context).pop(t),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ListSheet extends StatelessWidget {
  const _ListSheet({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
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
              title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          Flexible(child: child),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}

class _SheetLoading extends StatelessWidget {
  const _SheetLoading();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(AppSpacing.xl),
    child: Center(child: CircularProgressIndicator()),
  );
}

class _SheetMessage extends StatelessWidget {
  const _SheetMessage(this.message, {required this.style});

  final String message;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSpacing.page),
    child: Text(message, style: style),
  );
}
