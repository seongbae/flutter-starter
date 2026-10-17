import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../domain/auth_user.dart';

class AuthSession {
  const AuthSession(this.token, this.user);

  final String token;
  final AuthUser user;
}

class AuthRepository {
  AuthRepository(this._api);

  final ApiClient _api;

  /// [login] is an email address or username.
  Future<AuthSession> login(String login, String password) async {
    final body = await _api.post(
      '/auth/login',
      data: {'login': login, 'password': password, 'device_name': _deviceName},
    );
    return _session(body);
  }

  Future<AuthSession> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    final body = await _api.post(
      '/auth/register',
      data: {
        'name': name,
        'email': email,
        'password': password,
        'password_confirmation': passwordConfirmation,
        'device_name': _deviceName,
      },
    );
    return _session(body);
  }

  Future<AuthUser> me() async =>
      AuthUser.fromJson(dataObject(await _api.get('/me')));

  /// Sets the team and/or project the app opens to. Sending only a project
  /// also moves the current team to that project's team.
  Future<AuthUser> updateCurrent({int? teamId, int? projectId}) async {
    final body = await _api.put(
      '/me/current',
      data: {
        if (teamId != null) 'current_team_id': teamId,
        if (projectId != null) 'current_project_id': projectId,
      },
    );
    return AuthUser.fromJson(dataObject(body));
  }

  /// Leaves the user with no current project, e.g. after archiving or
  /// deleting it. The current team stays.
  Future<AuthUser> clearCurrentProject() async {
    final body = await _api.put(
      '/me/current',
      data: {'current_project_id': null},
    );
    return AuthUser.fromJson(dataObject(body));
  }

  /// Changes the fields given. A new email needs [currentPassword].
  Future<AuthUser> updateProfile({
    String? name,
    String? email,
    String? currentPassword,
  }) async {
    final body = await _api.put(
      '/me',
      data: {
        'name': ?name,
        'email': ?email,
        'current_password': ?currentPassword,
      },
    );
    return AuthUser.fromJson(dataObject(body));
  }

  /// Uploads the image at [path] as the profile photo.
  Future<AuthUser> updatePhoto(String path) async {
    final body = await _api.post(
      '/me/photo',
      data: FormData.fromMap({'photo': await MultipartFile.fromFile(path)}),
    );
    return AuthUser.fromJson(dataObject(body));
  }

  /// Signs out the user's other devices too.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) => _api.put(
    '/me/password',
    data: {
      'current_password': currentPassword,
      'password': newPassword,
      'password_confirmation': newPassword,
    },
  );

  /// Deletes the account, along with teams and projects the user owns.
  Future<void> deleteAccount(String currentPassword) =>
      _api.delete('/me', data: {'current_password': currentPassword});

  /// Revokes the current token on the server.
  Future<void> logout() => _api.post('/auth/logout');

  AuthSession _session(dynamic body) {
    final map = body as Map<String, dynamic>;
    return AuthSession(
      map['token'] as String,
      AuthUser.fromJson(dataObject(map['user'])),
    );
  }

  /// Names the token on the server, e.g. "Traqker (iOS)".
  static String get _deviceName {
    if (kIsWeb) return 'Traqker (web)';
    return 'Traqker (${defaultTargetPlatform.name})';
  }
}

final authRepositoryProvider = Provider(
  (ref) => AuthRepository(ref.watch(apiClientProvider)),
);
