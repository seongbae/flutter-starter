import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/auth_user.dart';

/// Persists the API token (in the platform keychain/keystore) and a cached
/// copy of the user (in preferences) so the app opens signed in, even
/// offline, until the user logs out.
class SessionStorage {
  SessionStorage(this._prefs, [FlutterSecureStorage? secure])
    : _secure = secure ?? const FlutterSecureStorage();

  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';

  final SharedPreferences _prefs;
  final FlutterSecureStorage _secure;

  Future<String?> readToken() async {
    try {
      return await _secure.read(key: _tokenKey);
    } catch (_) {
      // An unreadable keychain entry just means signing in again.
      return null;
    }
  }

  AuthUser? readUser() {
    final raw = _prefs.getString(_userKey);
    if (raw == null) return null;
    try {
      return AuthUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(String token, AuthUser user) async {
    await _secure.write(key: _tokenKey, value: token);
    await saveUser(user);
  }

  Future<void> saveUser(AuthUser user) =>
      _prefs.setString(_userKey, jsonEncode(user.toJson()));

  Future<void> clear() async {
    await _prefs.remove(_userKey);
    try {
      await _secure.delete(key: _tokenKey);
    } catch (_) {}
  }
}

/// Overridden in main() once preferences are ready.
final sessionStorageProvider = Provider<SessionStorage>(
  (ref) => throw UnimplementedError(),
);

/// The token read from storage at launch; overridden in main().
final initialAuthTokenProvider = Provider<String?>((ref) => null);
