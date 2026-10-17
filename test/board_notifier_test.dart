import 'package:traqker/core/api/api_client.dart';
import 'package:traqker/features/board/data/mock_board_data.dart';
import 'package:traqker/features/board/domain/board_models.dart';
import 'package:traqker/features/board/domain/task_sync.dart';
import 'package:traqker/features/board/presentation/providers/board_provider.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records calls; throws [failWith] instead when it's set.
class _FakeSync implements TaskSync {
  final calls = <String>[];
  String? failWith;
  int _nextId = 0;

  void _maybeFail() {
    if (failWith != null) throw ApiException(failWith!);
  }

  @override
  Future<TaskCard> create({
    required String columnId,
    required String title,
    String? note,
    String? assigneeId,
  }) async {
    _maybeFail();
    calls.add('create $columnId $title');
    return TaskCard(
      id: 'server-${_nextId++}',
      title: title,
      note: note,
      assigneeId: assigneeId,
      createdAt: DateTime(2026, 10, 13),
    );
  }

  @override
  Future<TaskCard> update(
    String cardId, {
    String? title,
    String? Function()? note,
    String? Function()? assigneeId,
    String? columnId,
  }) async {
    _maybeFail();
    calls.add(
      'update $cardId'
      '${title != null ? ' title=$title' : ''}'
      '${assigneeId != null ? ' assignee=${assigneeId()}' : ''}'
      '${columnId != null ? ' column=$columnId' : ''}',
    );
    return TaskCard(
      id: cardId,
      title: title ?? 'unchanged',
      assigneeId: assigneeId?.call(),
      createdAt: DateTime(2026, 10, 13),
    );
  }

  @override
  Future<void> delete(String cardId) async {
    _maybeFail();
    calls.add('delete $cardId');
  }

  @override
  Future<void> complete(String cardId) async {
    _maybeFail();
    calls.add('complete $cardId');
  }

  @override
  Future<TaskCard> reopen(String cardId) async {
    _maybeFail();
    calls.add('reopen $cardId');
    return TaskCard(
      id: cardId,
      title: 'Reopened',
      createdAt: DateTime(2026, 10, 13),
    );
  }

  @override
  Future<void> reorder(List<String> cardIds) async {
    _maybeFail();
    calls.add('reorder ${cardIds.join(',')}');
  }
}

void main() {
  late BoardNotifier board;
  late _FakeSync sync;

  BoardColumn column(String name) =>
      board.state.currentProject.columns.firstWhere((c) => c.name == name);

  setUp(() {
    final now = DateTime(2026, 10, 13);
    sync = _FakeSync();
    board = BoardNotifier(
      BoardState(
        project: MockBoardData.projects(now).first,
        members: MockBoardData.members,
      ),
      sync,
    );
  });

  test('adds the saved card to the end of a column', () async {
    final backlog = column('Backlog');
    final error = await board.addCard(backlog.id, title: 'New thing');

    expect(error, isNull);
    expect(sync.calls, ['create ${backlog.id} New thing']);
    expect(column('Backlog').cards.length, backlog.cards.length + 1);
    expect(column('Backlog').cards.last.id, 'server-0');
  });

  test('leaves the board alone when adding fails', () async {
    final backlog = column('Backlog');
    sync.failWith = 'No access';

    expect(await board.addCard(backlog.id, title: 'Nope'), 'No access');
    expect(column('Backlog').cards.length, backlog.cards.length);
  });

  test('rejects adding to a column at its WIP limit', () async {
    final doing = column('Doing');
    expect(doing.isFull, isTrue);

    final error = await board.addCard(doing.id, title: 'One too many');

    expect(error, contains('limit'));
    expect(sync.calls, isEmpty);
    expect(column('Doing').cards.length, doing.limit);
  });

  test('moves a card and pins it to the end of the new column', () async {
    final card = column('Backlog').cards.first;
    final review = column('Review');

    final error = await board.saveCard(
      card,
      title: card.title,
      note: card.note,
      assigneeId: card.assigneeId,
      columnId: review.id,
    );

    expect(error, isNull);
    expect(column('Backlog').cards.any((c) => c.id == card.id), isFalse);
    expect(column('Review').cards.last.id, card.id);
    expect(sync.calls, [
      'update ${card.id} column=${review.id}',
      'reorder ${[...review.cards.map((c) => c.id), card.id].join(',')}',
    ]);
  });

  test('refuses to move a card into a full column', () async {
    final card = column('Backlog').cards.first;

    final error = await board.saveCard(
      card,
      title: card.title,
      columnId: column('Doing').id,
    );

    expect(error, isNotNull);
    expect(sync.calls, isEmpty);
    expect(column('Backlog').cards.first.id, card.id);
  });

  test('sends only changed fields, and nothing when nothing changed', () async {
    final card = column('Backlog').cards.first;
    final backlog = column('Backlog').id;

    await board.saveCard(
      card,
      title: card.title,
      note: card.note,
      assigneeId: card.assigneeId,
      columnId: backlog,
    );
    expect(sync.calls, isEmpty);

    await board.saveCard(
      card,
      title: 'Renamed',
      note: card.note,
      assigneeId: 'ada',
      columnId: backlog,
    );
    expect(sync.calls, ['update ${card.id} title=Renamed assignee=ada']);
    expect(column('Backlog').cards.first.title, 'Renamed');
    expect(column('Backlog').cards.first.assigneeId, 'ada');
  });

  test('reorders cards and saves the new order', () async {
    final ids = column('Backlog').cards.map((c) => c.id).toList();

    expect(await board.reorderCard(column('Backlog').id, 0, 2), isNull);

    final reordered = [ids[1], ids[2], ids[0], ...ids.skip(3)];
    expect(column('Backlog').cards.map((c) => c.id), reordered);
    expect(sync.calls, ['reorder ${reordered.join(',')}']);
  });

  test('undoes a reorder the server rejects', () async {
    final ids = column('Backlog').cards.map((c) => c.id).toList();
    sync.failWith = 'Only project managers can reorder tasks.';

    final error = await board.reorderCard(column('Backlog').id, 0, 2);

    expect(error, 'Only project managers can reorder tasks.');
    expect(column('Backlog').cards.map((c) => c.id), ids);
  });

  test('deletes cards, keeping them if the server refuses', () async {
    final card = column('Backlog').cards.first;

    sync.failWith = 'Forbidden';
    expect(await board.deleteCard(card.id), 'Forbidden');
    expect(column('Backlog').cards.first.id, card.id);

    sync.failWith = null;
    expect(await board.deleteCard(card.id), isNull);
    expect(column('Backlog').cards.any((c) => c.id == card.id), isFalse);
  });

  test('completing takes a card off the board; undo puts it back', () async {
    final ids = column('Backlog').cards.map((c) => c.id).toList();
    final backlog = column('Backlog').id;

    expect(await board.completeCard(ids[1]), isNull);
    expect(column('Backlog').cards.map((c) => c.id), [ids[0], ...ids.skip(2)]);

    expect(await board.reopenCard(ids[1], backlog, 1), isNull);
    expect(column('Backlog').cards.map((c) => c.id), ids);
    expect(sync.calls, ['complete ${ids[1]}', 'reopen ${ids[1]}']);
  });

  test('keeps a card the server refuses to complete', () async {
    final card = column('Backlog').cards.first;
    sync.failWith = 'Forbidden';

    expect(await board.completeCard(card.id), 'Forbidden');
    expect(column('Backlog').cards.first.id, card.id);
  });
}
