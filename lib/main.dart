import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'core/providers/theme_provider.dart';
import 'core/error/error_handler.dart';
import 'features/auth/data/session_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize global error handling
  GlobalErrorHandler.initialize();

  // Remove the hash from URLs on web
  usePathUrlStrategy();

  // Initialize SharedPreferences
  final prefs = await SharedPreferences.getInstance();

  // Restore the signed-in session, if any
  final session = SessionStorage(prefs);
  final token = await session.readToken();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        sessionStorageProvider.overrideWithValue(session),
        initialAuthTokenProvider.overrideWithValue(token),
      ],
      child: const App(),
    ),
  );
}
