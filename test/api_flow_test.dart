import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:traqker/core/api/api_client.dart';
import 'package:traqker/features/auth/data/session_storage.dart';
import 'package:traqker/features/auth/presentation/providers/auth_provider.dart';
import 'package:traqker/features/board/data/board_repository.dart';
import 'package:traqker/features/board/domain/task_sync.dart';
import 'package:traqker/features/board/presentation/providers/board_provider.dart';

/// Answers requests from a table of `METHOD /path` → (status, body) and
/// records what was sent.
class _FakeServer implements HttpClientAdapter {
  _FakeServer(this.routes);

  final Map<String, (int, Object?)> routes;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final key = '${options.method} ${options.uri.path}';
    final (status, body) = routes[key] ?? (404, {'message': 'Not found'});
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, Object?> _user({int? team, int? project}) => {
  'id': 7,
  'name': 'Jane',
  'username': 'jane',
  'email': 'jane@example.com',
  'timezone': 'UTC',
  'photo_url': null,
  'current_team_id': team,
  'current_project_id': project,
};

Map<String, Object?> _task(int id, int? section, {List<Object?>? assignees}) =>
    {
      'id': id,
      'project_id': 3,
      'section_id': section,
      'name': 'Task $id',
      'created_at': '2026-10-01T12:00:00+00:00',
      'assignees': assignees ?? [],
    };

void main() {
  late _FakeServer server;
  late ApiClient api;

  ApiClient client(Map<String, (int, Object?)> routes) {
    server = _FakeServer(routes);
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test/api/v1'))
      ..httpClientAdapter = server;
    return api = ApiClient(dio: dio);
  }

  test('maps sections to columns and tasks to cards', () async {
    client({
      'GET /api/v1/projects/3': (
        200,
        {'id': 3, 'team_id': 1, 'name': 'Launch'},
      ),
      // Unpaginated collections come back as bare arrays.
      'GET /api/v1/projects/3/sections': (
        200,
        [
          {'id': 21, 'name': 'Doing', 'order': 2},
          {'id': 20, 'name': 'To do', 'order': 1},
        ],
      ),
      'GET /api/v1/projects/3/tasks': (
        200,
        {
          'data': [
            _task(1, 20),
            _task(
              2,
              21,
              assignees: [
                {'id': 99, 'name': 'Outside Olly'},
              ],
            ),
            _task(3, null),
          ],
          'meta': {'current_page': 1, 'last_page': 1},
        },
      ),
      'GET /api/v1/projects/3/members': (
        200,
        [
          {'id': 7, 'name': 'Jane'},
        ],
      ),
      'GET /api/v1/projects': (
        200,
        [
          {'id': 3, 'team_id': 1, 'name': 'Launch', 'archived': false},
          {'id': 4, 'team_id': 1, 'name': 'Old', 'archived': true},
        ],
      ),
      'GET /api/v1/teams/1': (200, {'id': 1, 'name': 'Acme'}),
    });

    final data = await BoardRepository(api).load(projectId: 3, teamId: 1);

    expect(data.teamName, 'Acme');
    expect(data.project.name, 'Launch');
    expect(data.project.columns.map((c) => c.name), [
      'No section',
      'To do',
      'Doing',
    ]);
    expect(data.project.columns.map((c) => c.cards.length), [1, 1, 1]);
    expect(data.projects.map((p) => p.name), ['Launch']);
    // Assignees outside the member list still resolve to a name.
    final card = data.project.columns[2].cards.single;
    expect(
      data.members.firstWhere((m) => m.id == card.assigneeId).name,
      'Outside Olly',
    );
    // Projects are filtered to the current team.
    final projectsCall = server.requests.firstWhere(
      (r) => r.uri.path == '/api/v1/projects',
    );
    expect(projectsCall.uri.queryParameters['team_id'], '1');
  });

  test('follows task pagination', () async {
    var page = 0;
    final paged = _PagingServer((p) {
      page = p;
      return {
        'data': [_task(p, null)],
        'meta': {'current_page': p, 'last_page': 3},
      };
    });
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test/api/v1'))
      ..httpClientAdapter = paged;
    final tasks = await ApiClient(dio: dio).getAll('/projects/3/tasks');

    expect(tasks.map((t) => t['id']), [1, 2, 3]);
    expect(page, 3);
  });

  test('saves board edits with the expected requests', () async {
    client({
      'POST /api/v1/tasks': (201, _task(10, 20)),
      'PUT /api/v1/tasks/10': (200, _task(10, null)),
      'DELETE /api/v1/tasks/10': (204, null),
      'PUT /api/v1/projects/3/tasks/order': (204, null),
      'POST /api/v1/tasks/10/complete': (200, _task(10, 20)),
      'POST /api/v1/tasks/10/reopen': (200, _task(10, 20)),
    });
    final tasks = BoardRepository(api).tasksOf(3);

    final created = await tasks.create(
      columnId: '20',
      title: 'Ship it',
      assigneeId: '7',
    );
    expect(created.id, '10');
    expect(server.requests.last.data, {
      'project_id': 3,
      'name': 'Ship it',
      'description': null,
      'section_id': 20,
      'assignees': [7],
    });

    // Only the fields passed are sent; unassigning sends an empty list.
    await tasks.update(
      '10',
      assigneeId: () => null,
      columnId: unsectionedColumnId,
    );
    expect(server.requests.last.data, {'assignees': [], 'section_id': null});

    await tasks.reorder(['12', '10']);
    expect(server.requests.last.data, {
      'task_ids': [12, 10],
    });

    await tasks.complete('10');
    expect(server.requests.last.uri.path, '/api/v1/tasks/10/complete');

    expect((await tasks.reopen('10')).id, '10');
    expect(server.requests.last.uri.path, '/api/v1/tasks/10/reopen');

    await tasks.delete('10');
    expect(server.requests.last.method, 'DELETE');
  });

  group('auth', () {
    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});
    });

    Future<ProviderContainer> container({String? token}) async {
      final prefs = await SharedPreferences.getInstance();
      return ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          sessionStorageProvider.overrideWithValue(SessionStorage(prefs)),
          initialAuthTokenProvider.overrideWithValue(token),
        ],
      );
    }

    test(
      'login stores the token, sends it, and exposes the current context',
      () async {
        client({
          'POST /api/v1/auth/login': (
            200,
            {'token': '1|abc', 'user': _user(team: 1, project: 3)},
          ),
          'POST /api/v1/auth/logout': (204, null),
        });
        final c = await container();

        await c.read(authProvider.notifier).login('jane', 'secret123');

        expect(c.read(authProvider).isAuthenticated, isTrue);
        expect(c.read(currentContextProvider), (teamId: 1, projectId: 3));
        final sent = server.requests.single.data as Map;
        expect(sent['login'], 'jane');
        expect(sent['device_name'], startsWith('Traqker'));
        expect(
          await SessionStorage(
            await SharedPreferences.getInstance(),
          ).readToken(),
          '1|abc',
        );

        await c.read(authProvider.notifier).logout();
        expect(server.requests.last.headers['Authorization'], 'Bearer 1|abc');
        expect(c.read(authProvider).isAuthenticated, isFalse);
        expect(
          await SessionStorage(
            await SharedPreferences.getInstance(),
          ).readToken(),
          isNull,
        );
      },
    );

    test('shows the validation message on bad credentials', () async {
      client({
        'POST /api/v1/auth/login': (
          422,
          {
            'message': 'The provided credentials are incorrect.',
            'errors': {
              'login': ['The provided credentials are incorrect.'],
            },
          },
        ),
      });
      final c = await container();

      await c.read(authProvider.notifier).login('jane', 'nope');

      expect(c.read(authProvider).isAuthenticated, isFalse);
      expect(
        c.read(authProvider).error,
        'The provided credentials are incorrect.',
      );
    });

    test(
      'a restored session refreshes the user; a revoked token signs out',
      () async {
        client({
          'GET /api/v1/me': (401, {'message': 'Unauthenticated.'}),
        });
        final c = await container(token: 'old');
        expect(c.read(authProvider).isAuthenticated, isTrue);

        await pumpEventQueue();
        await pumpEventQueue();

        expect(c.read(authProvider).isAuthenticated, isFalse);
      },
    );

    test('selecting a project updates the current context', () async {
      client({
        'GET /api/v1/me': (200, _user()),
        'PUT /api/v1/me/current': (200, _user(team: 2, project: 5)),
      });
      final c = await container(token: 't');
      await pumpEventQueue();
      expect(c.read(currentContextProvider), (teamId: null, projectId: null));

      await c.read(authProvider.notifier).selectProject(5);

      expect(server.requests.last.data, {'current_project_id': 5});
      expect(c.read(currentContextProvider), (teamId: 2, projectId: 5));
    });
  });
}

class _PagingServer implements HttpClientAdapter {
  _PagingServer(this.page);

  final Object Function(int page) page;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final p = int.parse(options.uri.queryParameters['page']!);
    return ResponseBody.fromString(
      jsonEncode(page(p)),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
