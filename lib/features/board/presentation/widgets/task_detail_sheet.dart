import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_spacing.dart';
import '../board_theme.dart';
import '../providers/board_provider.dart';
import 'card_editor_sheet.dart';
import 'board_sheet.dart';

/// Opens the details of [cardId]. Completes with true if the user marked
/// the task complete.
Future<bool?> showTaskDetail(BuildContext context, {required String cardId}) {
  return showBoardSheet<bool>(
    context,
    isScrollControlled: true,
    builder: (_) => TaskDetailSheet(cardId: cardId),
  );
}

/// Read-only view of a task, with Edit in the corner and Mark complete at
/// the bottom.
class TaskDetailSheet extends ConsumerStatefulWidget {
  const TaskDetailSheet({super.key, required this.cardId});

  final String cardId;

  @override
  ConsumerState<TaskDetailSheet> createState() => _TaskDetailSheetState();
}

class _TaskDetailSheetState extends ConsumerState<TaskDetailSheet> {
  bool _completing = false;
  String? _error;

  Future<void> _complete() async {
    setState(() {
      _completing = true;
      _error = null;
    });
    final error = await ref
        .read(boardProvider.notifier)
        .completeCard(widget.cardId);
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _completing = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final board = ref.watch(boardProvider);
    final column = board.currentProject.columns
        .where((c) => c.cards.any((x) => x.id == widget.cardId))
        .firstOrNull;
    if (column == null) {
      // Deleted from the editor; close once this frame is done. Remove this
      // sheet's own route rather than popping: after Mark complete the sheet
      // is already closing, and a pop would close the screen beneath it.
      final route = ModalRoute.of(context);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && route != null && route.isActive) {
          Navigator.of(context).removeRoute(route);
        }
      });
      return const SizedBox.shrink();
    }
    final card = column.cards.firstWhere((x) => x.id == widget.cardId);
    final assignee = board.memberById(card.assigneeId);
    final text = Theme.of(context).textTheme;
    final age = DateTime.now().difference(card.createdAt).inDays;

    Widget label(String s) => Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.xs),
      child: Text(s, style: text.labelLarge),
    );

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          0,
          AppSpacing.page,
          AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                CircleAvatar(radius: 5, backgroundColor: column.accent),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    column.name,
                    style: text.labelLarge!.copyWith(
                      color: BoardColors.inkSoft,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Edit task',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: _completing
                      ? null
                      : () => showCardEditor(
                          context,
                          columnId: column.id,
                          card: card,
                        ),
                ),
              ],
            ),
            Text(card.title, style: text.headlineSmall),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    label('Note'),
                    Text(
                      card.note ?? 'No note',
                      style: text.bodyMedium!.copyWith(
                        color: card.note == null
                            ? BoardColors.inkSoft
                            : BoardColors.ink,
                      ),
                    ),
                    label('Assignee'),
                    Text(
                      assignee?.name ?? 'Nobody yet',
                      style: text.bodyMedium!.copyWith(
                        color: assignee == null
                            ? BoardColors.inkSoft
                            : BoardColors.ink,
                      ),
                    ),
                    label('Created'),
                    Text(
                      age <= 0
                          ? 'Today'
                          : '$age ${age == 1 ? 'day' : 'days'} ago',
                      style: text.bodyMedium!.copyWith(color: BoardColors.ink),
                    ),
                  ],
                ),
              ),
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
              child: ElevatedButton.icon(
                onPressed: _completing ? null : _complete,
                icon: _completing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded),
                label: const Text('Mark complete'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
