import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_client.dart';
import '../../data/auth_repository.dart';
import '../../data/session_storage.dart';
import '../../domain/auth_user.dart';

class AuthState {
  const AuthState({
    this.isAuthenticated = false,
    this.isLoading = false,
    this.user,
    this.error,
  });

  final bool isAuthenticated;
  final bool isLoading;

  /// Null while a restored session waits for its first `/me`.
  final AuthUser? user;
  final String? error;
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._repository, this._api, this._storage, {String? token})
    : super(
        token == null
            ? const AuthState()
            : AuthState(isAuthenticated: true, user: _storage.readUser()),
      ) {
    _api.token = token;
    _api.onUnauthorized = _expireSession;
    if (token != null) refreshUser();
  }

  final AuthRepository _repository;
  final ApiClient _api;
  final SessionStorage _storage;

  Future<void> login(String login, String password) =>
      _signIn(() => _repository.login(login, password));

  Future<void> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) => _signIn(
    () => _repository.register(
      name: name,
      email: email,
      password: password,
      passwordConfirmation: passwordConfirmation,
    ),
  );

  /// Re-fetches the user, e.g. to pick up a team or project chosen on the
  /// web. Failures keep the cached user; a revoked token signs out.
  Future<void> refreshUser() async {
    try {
      _setUser(await _repository.me());
    } on ApiException {
      // 401s are handled by [_expireSession]; anything else is transient.
    }
  }

  /// Opens [projectId] (and its team) on this and every other device.
  Future<void> selectProject(int projectId) async {
    _setUser(await _repository.updateCurrent(projectId: projectId));
  }

  /// Closes the current project, so the board asks for another.
  Future<void> clearProject() async {
    _setUser(await _repository.clearCurrentProject());
  }

  Future<void> logout() async {
    try {
      await _repository.logout();
    } on ApiException {
      // Already revoked or offline; forget it locally either way.
    }
    await _clearSession();
  }

  Future<void> _signIn(Future<AuthSession> Function() request) async {
    state = const AuthState(isLoading: true);
    try {
      final session = await request();
      _api.token = session.token;
      await _storage.save(session.token, session.user);
      state = AuthState(isAuthenticated: true, user: session.user);
    } catch (e) {
      state = AuthState(error: ApiException.from(e).message);
    }
  }

  void _setUser(AuthUser user) {
    if (!state.isAuthenticated) return;
    state = AuthState(isAuthenticated: true, user: user);
    _storage.saveUser(user);
  }

  void _expireSession() {
    if (state.isAuthenticated) _clearSession();
  }

  Future<void> _clearSession() async {
    _api.token = null;
    state = const AuthState();
    await _storage.clear();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    ref.watch(authRepositoryProvider),
    ref.watch(apiClientProvider),
    ref.watch(sessionStorageProvider),
    token: ref.watch(initialAuthTokenProvider),
  );
});
