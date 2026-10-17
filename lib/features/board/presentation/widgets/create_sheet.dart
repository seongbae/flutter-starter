import 'package:flutter/material.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../project_settings/data/project_settings_repository.dart';
import '../board_theme.dart';
import 'board_sheet.dart';

/// Asks for a section name and creates it with [create]. Completes with the
/// new section's id, or null if dismissed.
Future<int?> showNewSectionSheet(
  BuildContext context, {
  required Future<int> Function(String name) create,
}) {
  return showBoardSheet<int>(
    context,
    isScrollControlled: true,
    builder: (_) => _CreateSheet(
      title: 'New section',
      hint: 'e.g. In review',
      action: 'Add section',
      create: (name, _) => create(name),
    ),
  );
}

/// Asks for a new name for a section and saves it with [rename]. Completes
/// with true once renamed, or null if dismissed.
Future<bool?> showRenameSectionSheet(
  BuildContext context, {
  required String currentName,
  required Future<void> Function(String name) rename,
}) async {
  final done = await showBoardSheet<int>(
    context,
    isScrollControlled: true,
    builder: (_) => _CreateSheet(
      title: 'Rename section',
      hint: currentName,
      action: 'Save',
      initialName: currentName,
      create: (name, _) async {
        await rename(name);
        return 0;
      },
    ),
  );
  return done == null ? null : true;
}

/// Asks for a project name and team, starting with [currentTeamId], and
/// creates it with [create]. Completes with the new project's id, or null if
/// dismissed.
Future<int?> showNewProjectSheet(
  BuildContext context, {
  required Future<List<TeamOption>> teams,
  required int? currentTeamId,
  required Future<int> Function(String name, int teamId) create,
}) {
  return showBoardSheet<int>(
    context,
    isScrollControlled: true,
    builder: (_) => _CreateSheet(
      title: 'New project',
      hint: 'e.g. Website relaunch',
      action: 'Create project',
      teams: teams,
      currentTeamId: currentTeamId,
      create: (name, teamId) => create(name, teamId!),
    ),
  );
}

class _CreateSheet extends StatefulWidget {
  const _CreateSheet({
    required this.title,
    required this.hint,
    required this.action,
    required this.create,
    this.teams,
    this.currentTeamId,
    this.initialName,
  });

  final String title;
  final String hint;
  final String action;

  /// Prefills the name when renaming; saving needs a different name.
  final String? initialName;

  /// Teams to create in; null when there's no team to choose.
  final Future<List<TeamOption>>? teams;
  final int? currentTeamId;
  final Future<int> Function(String name, int? teamId) create;

  @override
  State<_CreateSheet> createState() => _CreateSheetState();
}

class _CreateSheetState extends State<_CreateSheet> {
  late final _name = TextEditingController(text: widget.initialName);
  List<TeamOption>? _teams;
  String? _teamsError;
  int? _teamId;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
    widget.teams?.then(
      (all) {
        if (!mounted) return;
        final teams = [
          for (final t in all)
            if (t.canManage) t,
        ];
        setState(() {
          _teams = teams;
          // Default to the current team, or the only one there is.
          _teamId = teams.any((t) => t.id == widget.currentTeamId)
              ? widget.currentTeamId
              : teams.length == 1
              ? teams.single.id
              : null;
        });
      },
      onError: (Object e) {
        if (mounted) setState(() => _teamsError = ApiException.from(e).message);
      },
    );
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _ready =>
      _name.text.trim().isNotEmpty &&
      _name.text.trim() != widget.initialName &&
      (widget.teams == null || _teamId != null);

  Future<void> _submit() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final id = await widget.create(_name.text.trim(), _teamId);
      if (mounted) Navigator.of(context).pop(id);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = ApiException.from(e).message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          0,
          AppSpacing.page,
          AppSpacing.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.title, style: text.headlineSmall),
            Padding(
              padding: const EdgeInsets.only(
                top: AppSpacing.lg,
                bottom: AppSpacing.sm,
              ),
              child: Text('Name', style: text.labelLarge),
            ),
            TextField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _ready && !_saving ? _submit() : null,
              decoration: InputDecoration(hintText: widget.hint),
            ),
            if (widget.teams != null) _teamPicker(text),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(
                _error!,
                style: text.bodyMedium!.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _ready && !_saving ? _submit : null,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(widget.action),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _teamPicker(TextTheme text) {
    final soft = text.bodyMedium!.copyWith(color: BoardColors.inkSoft);
    final teams = _teams;
    final Widget body;
    if (_teamsError != null) {
      body = Text(_teamsError!, style: soft);
    } else if (teams == null) {
      body = const LinearProgressIndicator();
    } else if (teams.isEmpty) {
      body = Text(
        "You can only create projects in teams you manage, and you don't "
        'manage any.',
        style: soft,
      );
    } else {
      body = Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final t in teams)
            ChoiceChip(
              label: Text(t.name),
              selected: _teamId == t.id,
              onSelected: (_) => setState(() => _teamId = t.id),
              showCheckmark: false,
              labelStyle: TextStyle(
                color: _teamId == t.id ? Colors.white : BoardColors.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            top: AppSpacing.lg,
            bottom: AppSpacing.sm,
          ),
          child: Text('Team', style: text.labelLarge),
        ),
        body,
      ],
    );
  }
}
