import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../domain/board_models.dart';
import '../domain/task_sync.dart';

/// A team's project, for the project switcher.
class ProjectSummary {
  const ProjectSummary({
    required this.id,
    required this.name,
    required this.color,
    this.teamId,
  });

  final int id;
  final String name;
  final Color color;
  final int? teamId;
}

/// Everything the board shows for one project.
class BoardData {
  const BoardData({
    required this.teamName,
    required this.project,
    required this.members,
    required this.projects,
  });

  final String? teamName;
  final Project project;
  final List<Member> members;

  /// The current team's projects, for switching.
  final List<ProjectSummary> projects;
}

/// Loads a project's sections and active tasks from the API and maps them
/// onto the board: one column per section, in section order.
class BoardRepository {
  BoardRepository(this._api);

  final ApiClient _api;

  // Projects without a color set on the web, and sections (which have
  // none), get one from the logo palette.
  static const _projectColors = [
    Color(0xFF8BC34A),
    Color(0xFF5B8DEF),
    Color(0xFFF0A35E),
    Color(0xFFE57FA6),
    Color(0xFF5CC3CF),
  ];
  static const _columnAccents = [
    Color(0xFFCDD2E6),
    Color(0xFFA9B2D9),
    Color(0xFF8794CC),
    Color(0xFF9BE9C1),
    Color(0xFF1DDB77),
  ];
  static const _memberColors = [
    Color(0xFF5CC3CF),
    Color(0xFF6CC79A),
    Color(0xFFF0A35E),
    Color(0xFFE57FA6),
    Color(0xFF8794CC),
  ];

  /// Projects the user can open, optionally limited to [teamId].
  Future<List<ProjectSummary>> projects({int? teamId}) async {
    final body = await _api.get(
      '/projects',
      query: {if (teamId != null) 'team_id': teamId},
    );
    return [
      for (final p in dataList(body))
        if (p['archived'] != true) _summary(p),
    ];
  }

  Future<BoardData> load({required int projectId, int? teamId}) async {
    final results = await Future.wait([
      _api.get('/projects/$projectId'),
      _api.get('/projects/$projectId/sections'),
      _api.getAll('/projects/$projectId/tasks'),
      _api.get('/projects/$projectId/members'),
      projects(teamId: teamId),
      _teamName(teamId),
    ]);

    final project = dataObject(results[0]);
    final sections = dataList(results[1])
      ..sort(
        (a, b) =>
            ((a['order'] ?? 0) as int).compareTo((b['order'] ?? 0) as int),
      );
    final tasks = results[2] as List<Map<String, dynamic>>;
    final teamName = results[5] as String?;

    // Project members, plus anyone assigned who isn't one (e.g. a team
    // member on a team-visible project).
    final people = <String, String>{
      for (final m in dataList(results[3]))
        '${m['id']}': m['name'] as String? ?? '',
    };
    for (final t in tasks) {
      for (final a in (t['assignees'] as List?) ?? const []) {
        people.putIfAbsent('${a['id']}', () => a['name'] as String? ?? '');
      }
    }
    final members = [
      for (final (i, e) in people.entries.indexed)
        Member(
          id: e.key,
          name: e.value,
          color: _memberColors[i % _memberColors.length],
        ),
    ];

    final cardsBySection = <int?, List<TaskCard>>{};
    for (final t in tasks) {
      cardsBySection
          .putIfAbsent(t['section_id'] as int?, () => [])
          .add(_card(t));
    }

    final columns = <BoardColumn>[
      // Tasks outside any section (or a project with no sections at all).
      if (cardsBySection.containsKey(null) || sections.isEmpty)
        BoardColumn(
          id: unsectionedColumnId,
          name: sections.isEmpty ? 'Tasks' : 'No section',
          accent: _columnAccents.first,
          cards: cardsBySection[null] ?? const [],
        ),
      for (final s in sections)
        BoardColumn(
          id: '${s['id']}',
          name: s['name'] as String? ?? 'Untitled',
          accent: _columnAccents[sections.indexOf(s) % _columnAccents.length],
          cards: cardsBySection[s['id']] ?? const [],
        ),
    ];

    return BoardData(
      teamName: teamName,
      project: Project(
        id: '${project['id']}',
        name: project['name'] as String? ?? 'Untitled project',
        color: projectColor(project),
        columns: columns,
        // Servers from before can_contribute let the add fail instead.
        canAddSections: project['can_contribute'] as bool? ?? true,
      ),
      members: members,
      projects: results[4] as List<ProjectSummary>,
    );
  }

  /// Creates a project in [teamId]; returns its id.
  Future<int> createProject({required int teamId, required String name}) async {
    final body = await _api.post(
      '/projects',
      data: {'team_id': teamId, 'name': name},
    );
    return dataObject(body)['id'] as int;
  }

  /// Adds a section at the end of [projectId]; returns its id.
  Future<int> createSection(int projectId, String name) async {
    final body = await _api.post(
      '/projects/$projectId/sections',
      data: {'name': name},
    );
    return dataObject(body)['id'] as int;
  }

  Future<void> renameSection(String sectionId, String name) =>
      _api.put('/sections/$sectionId', data: {'name': name});

  /// Deletes the section; the server moves its tasks out of any section.
  Future<void> deleteSection(String sectionId) =>
      _api.delete('/sections/$sectionId');

  /// Puts all of [projectId]'s sections in the order of [sectionIds].
  Future<void> reorderSections(int projectId, List<String> sectionIds) =>
      _api.put(
        '/projects/$projectId/sections/order',
        data: {'section_ids': sectionIds.map(int.parse).toList()},
      );

  /// Turns the tasks outside any section into a new section named [name],
  /// placed before [sectionIds] (the project's existing sections, in
  /// order). Returns the new section's id. Tasks keep their order.
  Future<int> sectionFromUnsectioned(
    int projectId, {
    required String name,
    required List<String> taskIds,
    required List<String> sectionIds,
  }) async {
    final id = await createSection(projectId, name);
    await reorderSections(projectId, ['$id', ...sectionIds]);
    for (final taskId in taskIds) {
      await _api.put('/tasks/$taskId', data: {'section_id': id});
    }
    return id;
  }

  /// The team's name, or null if it can't be shown (e.g. no longer a member).
  Future<String?> _teamName(int? teamId) async {
    if (teamId == null) return null;
    try {
      return dataObject(await _api.get('/teams/$teamId'))['name'] as String?;
    } on ApiException {
      return null;
    }
  }

  ProjectSummary _summary(Map<String, dynamic> p) => ProjectSummary(
    id: p['id'] as int,
    name: p['name'] as String? ?? 'Untitled project',
    color: projectColor(p),
    teamId: p['team_id'] as int?,
  );

  /// Saves edits to [projectId]'s tasks.
  TaskSync tasksOf(int projectId) => _ProjectTasks(this, projectId);

  static String? _blankToNull(String? s) =>
      s == null || s.trim().isEmpty ? null : s.trim();

  TaskCard _card(Map<String, dynamic> t) {
    final assignees = (t['assignees'] as List?) ?? const [];
    return TaskCard(
      id: '${t['id']}',
      title: t['name'] as String? ?? '',
      note: _blankToNull(t['description'] as String?),
      assigneeId: assignees.isEmpty
          ? null
          : '${(assignees.first as Map)['id']}',
      createdAt:
          DateTime.tryParse(t['created_at'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
    );
  }

  /// The project's color as set on the web ("#rrggbb"), or one from the
  /// palette if it has none.
  static Color projectColor(Map<String, dynamic> project) =>
      parseHexColor(project['color'] as String?) ??
      _projectColors[(project['id'] as int) % _projectColors.length];
}

class _ProjectTasks implements TaskSync {
  _ProjectTasks(this._repo, this._projectId);

  final BoardRepository _repo;
  final int _projectId;

  ApiClient get _api => _repo._api;

  static int? _sectionId(String columnId) =>
      columnId == unsectionedColumnId ? null : int.parse(columnId);

  static List<int> _assignees(String? id) => [if (id != null) int.parse(id)];

  @override
  Future<TaskCard> create({
    required String columnId,
    required String title,
    String? note,
    String? assigneeId,
  }) async {
    final body = await _api.post(
      '/tasks',
      data: {
        'project_id': _projectId,
        'name': title,
        'description': note,
        'section_id': _sectionId(columnId),
        'assignees': _assignees(assigneeId),
      },
    );
    return _repo._card(dataObject(body));
  }

  @override
  Future<TaskCard> update(
    String cardId, {
    String? title,
    String? Function()? note,
    String? Function()? assigneeId,
    String? columnId,
  }) async {
    final body = await _api.put(
      '/tasks/$cardId',
      data: {
        'name': ?title,
        if (note != null) 'description': note(),
        if (assigneeId != null) 'assignees': _assignees(assigneeId()),
        if (columnId != null) 'section_id': _sectionId(columnId),
      },
    );
    return _repo._card(dataObject(body));
  }

  @override
  Future<void> delete(String cardId) => _api.delete('/tasks/$cardId');

  @override
  Future<void> complete(String cardId) => _api.post('/tasks/$cardId/complete');

  @override
  Future<TaskCard> reopen(String cardId) async =>
      _repo._card(dataObject(await _api.post('/tasks/$cardId/reopen')));

  @override
  Future<void> reorder(List<String> cardIds) => _api.put(
    '/projects/$_projectId/tasks/order',
    data: {'task_ids': cardIds.map(int.parse).toList()},
  );
}

/// Parses "#rrggbb"; null if [hex] is missing or malformed.
Color? parseHexColor(String? hex) {
  if (hex == null || !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(hex)) return null;
  return Color(0xFF000000 | int.parse(hex.substring(1), radix: 16));
}

/// [color] as "#RRGGBB", the format the server stores.
String toHexColor(Color color) =>
    '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

final boardRepositoryProvider = Provider(
  (ref) => BoardRepository(ref.watch(apiClientProvider)),
);
