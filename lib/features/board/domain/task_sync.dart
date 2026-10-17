import 'board_models.dart';

/// Saves board edits for one project. Column ids are section ids (or
/// [unsectionedColumnId]); card ids are task ids.
abstract interface class TaskSync {
  Future<TaskCard> create({
    required String columnId,
    required String title,
    String? note,
    String? assigneeId,
  });

  /// Sends only the fields passed; a null-returning function clears one.
  Future<TaskCard> update(
    String cardId, {
    String? title,
    String? Function()? note,
    String? Function()? assigneeId,
    String? columnId,
  });

  Future<void> delete(String cardId);

  Future<void> complete(String cardId);

  /// Marks a completed task active again.
  Future<TaskCard> reopen(String cardId);

  /// Stores [cardIds] in this order (one column's cards).
  Future<void> reorder(List<String> cardIds);
}

/// The column holding tasks that aren't in any section.
const unsectionedColumnId = 'unsectioned';
