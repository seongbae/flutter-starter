import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../board/data/board_repository.dart';

/// Who can see and edit a project, as on the web settings page.
enum ProjectVisibility {
  open('open', 'Open', 'Team members have full access'),
  readonly('readonly', 'Read-only', 'Team members can view but not edit'),
  private('private', 'Private', 'Only project members have access'),
  public('public', 'Public', 'Anyone can view it, without signing in');

  const ProjectVisibility(this.value, this.label, this.description);

  final String value;
  final String label;
  final String description;

  static ProjectVisibility from(String? value) => values.firstWhere(
    (v) => v.value == value,
    orElse: () => ProjectVisibility.private,
  );
}

/// A project member's access level.
enum MemberAccess {
  manager('manager', 'Manager', 'Can change project settings'),
  editor('editor', 'Editor', 'Can edit tasks'),
  user('user', 'User', 'Can work on tasks');

  const MemberAccess(this.value, this.label, this.description);

  final String value;
  final String label;
  final String description;

  static MemberAccess from(String? value) => values.firstWhere(
    (v) => v.value == value,
    orElse: () => MemberAccess.user,
  );
}

class ProjectDetails {
  const ProjectDetails({
    required this.id,
    required this.name,
    required this.description,
    required this.visibility,
    required this.color,
    required this.canManage,
    required this.teamId,
    required this.teamName,
    required this.ownerName,
    required this.createdAt,
  });

  final int id;
  final String name;
  final String description;
  final ProjectVisibility visibility;
  final Color color;
  final bool canManage;
  final int? teamId;
  final String? teamName;
  final String? ownerName;
  final DateTime? createdAt;
}

class ProjectMember {
  const ProjectMember({
    required this.id,
    required this.name,
    required this.email,
    required this.access,
  });

  final int id;
  final String name;
  final String? email;
  final MemberAccess access;
}

/// A team the user belongs to, for moving a project there.
class TeamOption {
  const TeamOption({
    required this.id,
    required this.name,
    required this.canManage,
  });

  final int id;
  final String name;
  final bool canManage;
}

/// Reads and changes a project's settings, members and team.
class ProjectSettingsRepository {
  ProjectSettingsRepository(this._api);

  final ApiClient _api;

  Future<ProjectDetails> details(int projectId) async =>
      _details(dataObject(await _api.get('/projects/$projectId')));

  /// The project's own members; team members who see it through the team
  /// aren't listed.
  Future<List<ProjectMember>> members(int projectId) async => [
    for (final m in dataList(await _api.get('/projects/$projectId/members')))
      _member(m),
  ];

  /// Members of [teamId], who can be added to its projects.
  Future<List<ProjectMember>> teamMembers(int teamId) async => [
    for (final m in dataList(await _api.get('/teams/$teamId/members')))
      _member(m),
  ];

  Future<List<TeamOption>> teams() async => [
    for (final t in dataList(await _api.get('/teams')))
      TeamOption(
        id: t['id'] as int,
        name: t['name'] as String? ?? 'Untitled team',
        // Servers from before can_manage leave the check to the request.
        canManage: t['can_manage'] as bool? ?? true,
      ),
  ];

  /// Changes only the fields given.
  Future<void> update(
    int projectId, {
    String? name,
    String? Function()? description,
    ProjectVisibility? visibility,
    Color? color,
  }) => _api.put(
    '/projects/$projectId',
    data: {
      'name': ?name,
      if (description != null) 'description': description(),
      if (visibility != null) 'visibility': visibility.value,
      if (color != null) 'color': toHexColor(color),
    },
  );

  Future<void> archive(int projectId) =>
      _api.post('/projects/$projectId/archive');

  Future<void> move(int projectId, int teamId) =>
      _api.post('/projects/$projectId/move', data: {'team_id': teamId});

  Future<void> delete(int projectId) => _api.delete('/projects/$projectId');

  Future<void> addMember(int projectId, int userId) => _api.post(
    '/projects/$projectId/members',
    data: {'user_id': userId, 'access': MemberAccess.user.value},
  );

  Future<void> setAccess(int projectId, int userId, MemberAccess access) =>
      _api.put(
        '/projects/$projectId/members/$userId',
        data: {'access': access.value},
      );

  Future<void> removeMember(int projectId, int userId) =>
      _api.delete('/projects/$projectId/members/$userId');

  Future<ProjectDetails> _details(Map<String, dynamic> p) async {
    final teamId = p['team_id'] as int?;
    final owner = p['owner'];
    return ProjectDetails(
      id: p['id'] as int,
      name: p['name'] as String? ?? 'Untitled project',
      description: p['description'] as String? ?? '',
      visibility: ProjectVisibility.from(p['visibility'] as String?),
      color: BoardRepository.projectColor(p),
      canManage: p['can_manage'] == true,
      teamId: teamId,
      teamName: await _teamName(teamId),
      ownerName: owner is Map ? owner['name'] as String? : null,
      createdAt: DateTime.tryParse(p['created_at'] as String? ?? '')?.toLocal(),
    );
  }

  Future<String?> _teamName(int? teamId) async {
    if (teamId == null) return null;
    try {
      return dataObject(await _api.get('/teams/$teamId'))['name'] as String?;
    } on ApiException {
      return null;
    }
  }

  static ProjectMember _member(Map<String, dynamic> m) => ProjectMember(
    id: m['id'] as int,
    name: m['name'] as String? ?? '',
    email: m['email'] as String?,
    access: MemberAccess.from(m['access'] as String?),
  );
}

final projectSettingsRepositoryProvider = Provider(
  (ref) => ProjectSettingsRepository(ref.watch(apiClientProvider)),
);

final projectDetailsProvider = FutureProvider.autoDispose
    .family<ProjectDetails, int>(
      (ref, projectId) =>
          ref.watch(projectSettingsRepositoryProvider).details(projectId),
    );

final projectMembersProvider = FutureProvider.autoDispose
    .family<List<ProjectMember>, int>(
      (ref, projectId) =>
          ref.watch(projectSettingsRepositoryProvider).members(projectId),
    );
