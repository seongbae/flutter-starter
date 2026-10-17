import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_client.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/board_repository.dart';
import '../../domain/board_models.dart';
import '../../domain/task_sync.dart';

class BoardState {
  const BoardState({
    required this.project,
    required this.members,
    this.teamName,
  });

  final Project project;
  final List<Member> members;
  final String? teamName;

  Project get currentProject => project;

  Member? memberById(String? id) {
    for (final m in members) {
      if (m.id == id) return m;
    }
    return null;
  }

  BoardState copyWith({Project? project}) => BoardState(
    project: project ?? this.project,
    members: members,
    teamName: teamName,
  );
}

/// The signed-in user's current team and project, as set on the server.
final currentContextProvider = Provider<({int? teamId, int? projectId})>(
  (ref) => ref.watch(
    authProvider.select(
      (s) =>
          (teamId: s.user?.currentTeamId, projectId: s.user?.currentProjectId),
    ),
  ),
);

/// The current project's board, or null when the user has no current
/// project yet. Reloads whenever the current team or project changes.
final boardDataProvider = FutureProvider<BoardData?>((ref) {
  final current = ref.watch(currentContextProvider);
  if (current.projectId == null) return null;
  return ref
      .watch(boardRepositoryProvider)
      .load(projectId: current.projectId!, teamId: current.teamId);
});

/// Projects to choose from: the current team's, or all the user can open.
final projectChoicesProvider = FutureProvider<List<ProjectSummary>>((ref) {
  final teamId = ref.watch(currentContextProvider.select((c) => c.teamId));
  return ref.watch(boardRepositoryProvider).projects(teamId: teamId);
});

/// Holds the loaded board and saves edits through [TaskSync]. Each edit
/// returns null on success or a message to show the user, in which case the
/// board is left as it was. Reordering shows immediately and is undone if
/// the save fails; the rest wait for the server.
class BoardNotifier extends StateNotifier<BoardState> {
  BoardNotifier(super.state, this._sync);

  final TaskSync _sync;

  Future<String?> addCard(
    String columnId, {
    required String title,
    String? note,
    String? assigneeId,
  }) async {
    final column = _column(columnId);
    if (column.isFull) return _fullMessage(column);

    final TaskCard card;
    try {
      card = await _sync.create(
        columnId: columnId,
        title: title,
        note: note,
        assigneeId: assigneeId,
      );
    } catch (e) {
      return ApiException.from(e).message;
    }
    if (!mounted) return null;
    // New tasks go to the end of their section on the server too.
    _updateColumn(columnId, (c) => c.copyWith(cards: [...c.cards, card]));
    return null;
  }

  /// Saves the fields of [card] that differ from what's on the board, and
  /// moves it to the end of [columnId] if that's a different column.
  Future<String?> saveCard(
    TaskCard card, {
    required String title,
    String? note,
    String? assigneeId,
    required String columnId,
  }) async {
    final from = columnOf(card.id);
    final moving = from.id != columnId;
    if (moving && _column(columnId).isFull) {
      return _fullMessage(_column(columnId));
    }
    if (!moving &&
        title == card.title &&
        note == card.note &&
        assigneeId == card.assigneeId) {
      return null;
    }

    final TaskCard saved;
    try {
      saved = await _sync.update(
        card.id,
        title: title == card.title ? null : title,
        note: note == card.note ? null : () => note,
        assigneeId: assigneeId == card.assigneeId ? null : () => assigneeId,
        columnId: moving ? columnId : null,
      );
    } catch (e) {
      return ApiException.from(e).message;
    }
    if (!mounted) return null;

    if (!moving) {
      _replaceCard(from.id, saved);
      return null;
    }
    _updateColumn(
      from.id,
      (c) => c.copyWith(cards: c.cards.where((x) => x.id != card.id).toList()),
    );
    _updateColumn(columnId, (c) => c.copyWith(cards: [...c.cards, saved]));
    // A moved task keeps its old position number; pin it to the end. If
    // this fails the task is still in the right column, just maybe not last.
    try {
      await _sync.reorder(_ids(columnId));
    } catch (_) {}
    return null;
  }

  /// [newIndex] is the card's final position (after it's been removed).
  Future<String?> reorderCard(
    String columnId,
    int oldIndex,
    int newIndex,
  ) async {
    if (oldIndex == newIndex) return null;
    final before = _column(columnId).cards;
    final cards = [...before];
    cards.insert(newIndex, cards.removeAt(oldIndex));
    _updateColumn(columnId, (c) => c.copyWith(cards: cards));

    try {
      await _sync.reorder([for (final c in cards) c.id]);
      return null;
    } catch (e) {
      if (mounted) _updateColumn(columnId, (c) => c.copyWith(cards: before));
      return ApiException.from(e).message;
    }
  }

  Future<String?> deleteCard(String cardId) async {
    try {
      await _sync.delete(cardId);
    } catch (e) {
      return ApiException.from(e).message;
    }
    if (!mounted) return null;
    _updateColumn(
      columnOf(cardId).id,
      (c) => c.copyWith(cards: c.cards.where((x) => x.id != cardId).toList()),
    );
    return null;
  }

  /// Completes the task and takes it off the board, which only shows open
  /// tasks.
  Future<String?> completeCard(String cardId) async {
    try {
      await _sync.complete(cardId);
    } catch (e) {
      return ApiException.from(e).message;
    }
    if (!mounted) return null;
    _updateColumn(
      columnOf(cardId).id,
      (c) => c.copyWith(cards: c.cards.where((x) => x.id != cardId).toList()),
    );
    return null;
  }

  /// Undoes [completeCard], putting the card back at [index] in [columnId].
  Future<String?> reopenCard(String cardId, String columnId, int index) async {
    final TaskCard card;
    try {
      card = await _sync.reopen(cardId);
    } catch (e) {
      return ApiException.from(e).message;
    }
    if (!mounted) return null;
    _updateColumn(columnId, (c) {
      final cards = [...c.cards];
      cards.insert(index.clamp(0, cards.length), card);
      return c.copyWith(cards: cards);
    });
    return null;
  }

  /// The column (in the current project) containing [cardId].
  BoardColumn columnOf(String cardId) => state.currentProject.columns
      .firstWhere((c) => c.cards.any((x) => x.id == cardId));

  BoardColumn _column(String columnId) =>
      state.currentProject.columns.firstWhere((c) => c.id == columnId);

  List<String> _ids(String columnId) => [
    for (final c in _column(columnId).cards) c.id,
  ];

  String _fullMessage(BoardColumn c) =>
      '${c.name} is at its limit (${c.limit}). Finish something first.';

  void _replaceCard(String columnId, TaskCard card) => _updateColumn(
    columnId,
    (c) => c.copyWith(
      cards: [for (final x in c.cards) x.id == card.id ? card : x],
    ),
  );

  void _updateColumn(String columnId, BoardColumn Function(BoardColumn) fn) {
    final project = state.currentProject;
    state = state.copyWith(
      project: project.copyWith(
        columns: [
          for (final c in project.columns) c.id == columnId ? fn(c) : c,
        ],
      ),
    );
  }
}

/// Only read once [boardDataProvider] has a board. Rebuilt only when a new
/// board arrives: a reload keeps the previous value while loading, and
/// rebuilding from that would undo edits made since it was fetched.
final boardProvider = StateNotifierProvider<BoardNotifier, BoardState>((ref) {
  final data = ref.watch(boardDataProvider.select((a) => a.valueOrNull))!;
  return BoardNotifier(
    BoardState(
      project: data.project,
      members: data.members,
      teamName: data.teamName,
    ),
    ref.watch(boardRepositoryProvider).tasksOf(int.parse(data.project.id)),
  );
});
