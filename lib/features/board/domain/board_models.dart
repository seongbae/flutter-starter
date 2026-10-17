import 'package:flutter/material.dart';

/// T-shirt size estimate shown as a badge on each card.
enum CardSize {
  s('S'),
  m('M'),
  l('L');

  const CardSize(this.label);
  final String label;
}

/// A teammate who can be assigned to cards. [color] marks them in pickers.
class Member {
  const Member({required this.id, required this.name, required this.color});

  final String id;
  final String name;
  final Color color;
}

class TaskCard {
  const TaskCard({
    required this.id,
    required this.title,
    required this.createdAt,
    this.size,
    this.note,
    this.assigneeId,
  });

  final String id;
  final String title;

  /// Short handwritten-style aside, e.g. "After launch, not before".
  final String? note;

  /// Null for tasks that haven't been sized (e.g. loaded from the server).
  final CardSize? size;
  final String? assigneeId;
  final DateTime createdAt;

  TaskCard copyWith({
    String? title,
    String? Function()? note,
    CardSize? Function()? size,
    String? Function()? assigneeId,
  }) {
    return TaskCard(
      id: id,
      title: title ?? this.title,
      note: note != null ? note() : this.note,
      size: size != null ? size() : this.size,
      assigneeId: assigneeId != null ? assigneeId() : this.assigneeId,
      createdAt: createdAt,
    );
  }
}

class BoardColumn {
  const BoardColumn({
    required this.id,
    required this.name,
    required this.accent,
    this.limit,
    this.cards = const [],
  });

  final String id;
  final String name;

  /// Banner fill and the rule along the top of each card.
  final Color accent;

  /// Work-in-progress limit; null means unlimited.
  final int? limit;
  final List<TaskCard> cards;

  bool get isFull => limit != null && cards.length >= limit!;

  BoardColumn copyWith({List<TaskCard>? cards}) => BoardColumn(
    id: id,
    name: name,
    accent: accent,
    limit: limit,
    cards: cards ?? this.cards,
  );
}

class Project {
  const Project({
    required this.id,
    required this.name,
    required this.color,
    required this.columns,
    this.canAddSections = true,
  });

  final String id;
  final String name;
  final Color color;
  final List<BoardColumn> columns;

  /// Whether the user may add sections (any project contributor can).
  final bool canAddSections;

  Project copyWith({List<BoardColumn>? columns}) => Project(
    id: id,
    name: name,
    color: color,
    columns: columns ?? this.columns,
    canAddSections: canAddSections,
  );
}
