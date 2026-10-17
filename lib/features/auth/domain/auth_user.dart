/// The signed-in user, as returned by `/me` and the auth endpoints.
class AuthUser {
  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
    this.username,
    this.photoUrl,
    this.currentTeamId,
    this.currentProjectId,
  });

  final int id;
  final String name;
  final String email;
  final String? username;
  final String? photoUrl;

  /// The team and project the app opens to; either may be unset.
  final int? currentTeamId;
  final int? currentProjectId;

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    id: json['id'] as int,
    name: json['name'] as String? ?? '',
    email: json['email'] as String? ?? '',
    username: json['username'] as String?,
    photoUrl: json['photo_url'] as String?,
    currentTeamId: json['current_team_id'] as int?,
    currentProjectId: json['current_project_id'] as int?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'username': username,
    'photo_url': photoUrl,
    'current_team_id': currentTeamId,
    'current_project_id': currentProjectId,
  };
}
