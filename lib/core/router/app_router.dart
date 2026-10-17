import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/users/presentation/pages/users_page.dart';
import '../../features/users/presentation/pages/user_detail_page.dart';
import '../../features/notifications/presentation/pages/notifications_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/onboarding/presentation/pages/onboarding_page.dart';
import '../../features/home/presentation/pages/ui_showcase_page.dart';
import '../../features/home/presentation/pages/skeleton_showcase_page.dart';
import '../../features/home/presentation/pages/error_showcase_page.dart';
import '../../features/home/presentation/pages/file_upload_showcase_page.dart';
import '../../features/home/presentation/pages/language_showcase_page.dart';
import '../../features/forms/presentation/pages/forms_example_page.dart';
import '../../features/board/presentation/pages/board_page.dart';
import '../../features/board/presentation/pages/board_shell.dart';
import '../../features/board/presentation/board_theme.dart';
import '../../features/project_settings/presentation/project_settings_page.dart';
import '../../shared/widgets/responsive_scaffold.dart';

final onboardingCompletedProvider = StateProvider<bool>((ref) {
  // This will be updated when onboarding is completed
  return false;
});

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/board',
    redirect: (context, state) {
      final isAuthenticated = authState.isAuthenticated;
      final isAuthRoute =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      // Everything outside the auth pages requires being logged in
      if (!isAuthenticated && !isAuthRoute) {
        return '/login';
      }

      // Redirect authenticated users away from auth pages
      if (isAuthenticated && isAuthRoute) {
        return '/board';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingPage(),
      ),
      // Full screen over the board, without its bottom nav.
      GoRoute(
        path: '/project-settings',
        builder: (context, state) =>
            Theme(data: BoardTheme.data, child: const ProjectSettingsPage()),
      ),
      ShellRoute(
        builder: (context, state, child) => BoardShell(child: child),
        routes: [
          GoRoute(
            path: '/board',
            builder: (context, state) => const BoardPage(),
          ),
          GoRoute(
            path: '/standup',
            builder: (context, state) => const ComingSoonPage(
              title: 'Standup',
              icon: Icons.record_voice_over_outlined,
              description: "What everyone did yesterday and what's next.",
            ),
          ),
          GoRoute(
            path: '/flow',
            builder: (context, state) => const ComingSoonPage(
              title: 'Flow',
              icon: Icons.air_rounded,
              description: 'How tasks move through the board over time.',
            ),
          ),
          GoRoute(
            path: '/me',
            builder: (context, state) => const SettingsPage(title: 'Me'),
          ),
        ],
      ),
      ShellRoute(
        builder: (context, state, child) => ResponsiveScaffold(child: child),
        routes: [
          GoRoute(path: '/home', builder: (context, state) => const HomePage()),
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardPage(),
          ),
          GoRoute(
            path: '/users',
            builder: (context, state) => const UsersPage(),
            routes: [
              GoRoute(
                path: ':userId',
                builder: (context, state) {
                  final userId = state.pathParameters['userId']!;
                  return UserDetailPage(userId: userId);
                },
              ),
            ],
          ),
          GoRoute(
            path: '/notifications',
            builder: (context, state) => const NotificationsPage(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsPage(),
          ),
          GoRoute(
            path: '/showcase/ui',
            builder: (context, state) => const UIShowcasePage(),
          ),
          GoRoute(
            path: '/showcase/skeletons',
            builder: (context, state) => const SkeletonShowcasePage(),
          ),
          GoRoute(
            path: '/showcase/errors',
            builder: (context, state) => const ErrorShowcasePage(),
          ),
          GoRoute(
            path: '/showcase/upload',
            builder: (context, state) => const FileUploadShowcasePage(),
          ),
          GoRoute(
            path: '/showcase/language',
            builder: (context, state) => const LanguageShowcasePage(),
          ),
          GoRoute(
            path: '/forms',
            builder: (context, state) => const FormsExamplePage(),
          ),
        ],
      ),
    ],
  );
});
