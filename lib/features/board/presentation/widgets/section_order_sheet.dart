import 'package:flutter/material.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/board_models.dart';
import '../board_theme.dart';
import 'board_sheet.dart';

/// Lets the user drag [sections] into a new order and saves it with [save].
/// Completes with true once saved, or null if dismissed.
Future<bool?> showSectionOrderSheet(
  BuildContext context, {
  required List<BoardColumn> sections,
  required Future<void> Function(List<String> sectionIds) save,
}) {
  return showBoardSheet<bool>(
    context,
    isScrollControlled: true,
    builder: (_) => _SectionOrderSheet(sections: sections, save: save),
  );
}

class _SectionOrderSheet extends StatefulWidget {
  const _SectionOrderSheet({required this.sections, required this.save});

  final List<BoardColumn> sections;
  final Future<void> Function(List<String> sectionIds) save;

  @override
  State<_SectionOrderSheet> createState() => _SectionOrderSheetState();
}

class _SectionOrderSheetState extends State<_SectionOrderSheet> {
  late final _order = [...widget.sections];
  bool _saving = false;
  String? _error;

  bool get _changed {
    for (var i = 0; i < _order.length; i++) {
      if (_order[i].id != widget.sections[i].id) return true;
    }
    return false;
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.save([for (final s in _order) s.id]);
      if (mounted) Navigator.of(context).pop(true);
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

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          0,
          AppSpacing.page,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reorder sections', style: text.headlineSmall),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Drag the handles to change the order.',
              style: text.bodyMedium!.copyWith(color: BoardColors.inkSoft),
            ),
            const SizedBox(height: AppSpacing.md),
            Flexible(
              child: ReorderableListView(
                shrinkWrap: true,
                buildDefaultDragHandles: false,
                onReorderItem: _saving
                    ? (_, __) {}
                    : (from, to) => setState(
                        () => _order.insert(to, _order.removeAt(from)),
                      ),
                children: [
                  for (final (i, s) in _order.indexed)
                    ListTile(
                      key: ValueKey(s.id),
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 6,
                        backgroundColor: s.accent,
                      ),
                      title: Text(s.name),
                      trailing: ReorderableDragStartListener(
                        index: i,
                        child: const Padding(
                          padding: EdgeInsets.all(AppSpacing.sm),
                          child: Icon(Icons.drag_handle_rounded),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                _error!,
                style: text.bodyMedium!.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _changed && !_saving ? _save : null,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save order'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
