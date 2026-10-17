import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/board_models.dart';
import '../board_theme.dart';
import '../providers/board_provider.dart';
import 'board_sheet.dart';

/// Opens the editor for a new card in [columnId], or for an existing [card].
Future<void> showCardEditor(
  BuildContext context, {
  required String columnId,
  TaskCard? card,
}) {
  return showBoardSheet(
    context,
    isScrollControlled: true,
    builder: (_) => CardEditorSheet(columnId: columnId, card: card),
  );
}

class CardEditorSheet extends ConsumerStatefulWidget {
  const CardEditorSheet({super.key, required this.columnId, this.card});

  final String columnId;
  final TaskCard? card;

  @override
  ConsumerState<CardEditorSheet> createState() => _CardEditorSheetState();
}

class _CardEditorSheetState extends ConsumerState<CardEditorSheet> {
  late final _title = TextEditingController(text: widget.card?.title);
  late final _note = TextEditingController(text: widget.card?.note);
  late String? _assigneeId = widget.card?.assigneeId;
  late String _columnId = widget.columnId;
  String? _error;
  bool _saving = false;

  bool get _isNew => widget.card == null;

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Give the task a title.');
      return;
    }
    final note = _note.text.trim().isEmpty ? null : _note.text.trim();
    final board = ref.read(boardProvider.notifier);

    await _run(
      () => _isNew
          ? board.addCard(
              _columnId,
              title: title,
              note: note,
              assigneeId: _assigneeId,
            )
          : board.saveCard(
              widget.card!,
              title: title,
              note: note,
              assigneeId: _assigneeId,
              columnId: _columnId,
            ),
    );
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this task?'),
        content: Text('"${widget.card!.title}" will be deleted for everyone.'),
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
    if (confirmed != true) return;
    await _run(
      () => ref.read(boardProvider.notifier).deleteCard(widget.card!.id),
    );
  }

  /// Runs a save, closing the sheet on success or showing its error.
  Future<void> _run(Future<String?> Function() save) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await save();
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _saving = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final board = ref.watch(boardProvider);
    final text = Theme.of(context).textTheme;

    Widget label(String s) => Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
      child: Text(s, style: text.labelLarge),
    );

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
            Row(
              children: [
                Expanded(
                  child: Text(
                    _isNew ? 'New task' : 'Edit task',
                    style: text.headlineSmall,
                  ),
                ),
                if (!_isNew)
                  IconButton(
                    tooltip: 'Delete task',
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: _saving ? null : _delete,
                  ),
              ],
            ),
            label('Title'),
            TextField(
              controller: _title,
              autofocus: _isNew,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'What needs doing?'),
            ),
            label('Note'),
            TextField(
              controller: _note,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Optional'),
            ),
            label('Assignee'),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _choice(
                  'Nobody',
                  _assigneeId == null,
                  () => setState(() => _assigneeId = null),
                ),
                for (final m in board.members)
                  _choice(
                    m.name,
                    _assigneeId == m.id,
                    () => setState(() => _assigneeId = m.id),
                    dot: m.color,
                  ),
              ],
            ),
            label('Column'),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final c in board.currentProject.columns)
                  _choice(
                    c.name,
                    _columnId == c.id,
                    () => setState(() => _columnId = c.id),
                    dot: c.accent,
                  ),
              ],
            ),
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
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_isNew ? 'Add task' : 'Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _choice(
    String label,
    bool selected,
    VoidCallback onTap, {
    Color? dot,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      avatar: dot == null
          ? null
          : CircleAvatar(radius: 5, backgroundColor: dot),
      labelStyle: TextStyle(
        color: selected ? Colors.white : BoardColors.ink,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
