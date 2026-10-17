import 'package:flutter/material.dart';
import '../domain/board_models.dart';

/// Sample crew and projects, used as fixtures by the board tests.
class MockBoardData {
  MockBoardData._();

  static const members = [
    Member(id: 'ada', name: 'Ada', color: Color(0xFF5CC3CF)),
    Member(id: 'ben', name: 'Ben', color: Color(0xFF6CC79A)),
    Member(id: 'cleo', name: 'Cleo', color: Color(0xFFF0A35E)),
    Member(id: 'dev', name: 'Dev', color: Color(0xFFE57FA6)),
  ];

  // Column accents shared by every project: logo navy tints moving to logo
  // green as work gets done.
  static const _backlog = Color(0xFFCDD2E6);
  static const _thisWeek = Color(0xFFA9B2D9);
  static const _doing = Color(0xFF8794CC);
  static const _review = Color(0xFF9BE9C1);
  static const _done = Color(0xFF1DDB77);

  static List<Project> projects(DateTime now) {
    TaskCard card(
      String id,
      String title,
      CardSize size,
      int ageDays, {
      String? note,
      String? assignee,
    }) => TaskCard(
      id: id,
      title: title,
      size: size,
      note: note,
      assigneeId: assignee,
      createdAt: now.subtract(Duration(days: ageDays)),
    );

    List<BoardColumn> columns(String p, List<List<TaskCard>> cards) => [
      BoardColumn(
        id: '$p-backlog',
        name: 'Backlog',
        accent: _backlog,
        cards: cards[0],
      ),
      BoardColumn(
        id: '$p-week',
        name: 'This week',
        accent: _thisWeek,
        cards: cards[1],
      ),
      BoardColumn(
        id: '$p-doing',
        name: 'Doing',
        accent: _doing,
        limit: 3,
        cards: cards[2],
      ),
      BoardColumn(
        id: '$p-review',
        name: 'Review',
        accent: _review,
        limit: 3,
        cards: cards[3],
      ),
      BoardColumn(id: '$p-done', name: 'Done', accent: _done, cards: cards[4]),
    ];

    return [
      Project(
        id: 'studio',
        name: 'Studio Website Relaunch',
        color: const Color(0xFF8BC34A),
        columns: columns('studio', [
          [
            card('s1', 'Search box on the blog', CardSize.m, 16),
            card(
              's2',
              'Dark mode colors for the site',
              CardSize.l,
              15,
              note: 'After launch, not before',
            ),
            card('s3', 'Testimonials block', CardSize.s, 14, assignee: 'ada'),
            card('s4', 'Sitemap for the new pages', CardSize.s, 12),
            card(
              's5',
              'Portfolio grid filters',
              CardSize.m,
              11,
              assignee: 'ben',
            ),
            card('s6', 'Cookie banner copy', CardSize.s, 9),
            card(
              's7',
              'Newsletter signup in footer',
              CardSize.s,
              8,
              assignee: 'cleo',
            ),
            card(
              's8',
              '404 page illustration',
              CardSize.m,
              6,
              note: 'Ask Dev for sketches',
            ),
            card('s9', 'Image lazy loading', CardSize.s, 3),
          ],
          [
            card('s10', 'Homepage hero copy', CardSize.s, 7, assignee: 'cleo'),
            card('s11', 'Team page photos', CardSize.m, 6, assignee: 'dev'),
            card(
              's12',
              'Contact form validation',
              CardSize.s,
              5,
              assignee: 'ben',
            ),
            card('s13', 'Case study template', CardSize.l, 5),
            card(
              's14',
              'Redirects from old URLs',
              CardSize.m,
              4,
              assignee: 'ada',
              note: 'Export list from analytics first',
            ),
            card('s15', 'Favicon set', CardSize.s, 2),
          ],
          [
            card('s16', 'Navigation redesign', CardSize.l, 10, assignee: 'ada'),
            card('s17', 'Services page layout', CardSize.m, 8, assignee: 'dev'),
            card('s18', 'CMS content model', CardSize.m, 6, assignee: 'ben'),
          ],
          [
            card('s19', 'Brand color tokens', CardSize.s, 9, assignee: 'cleo'),
            card(
              's20',
              'About page draft',
              CardSize.m,
              7,
              assignee: 'dev',
              note: 'Needs a second read',
            ),
          ],
          [
            card('s21', 'Domain and hosting', CardSize.s, 21, assignee: 'ben'),
            card('s22', 'Wireframes', CardSize.l, 20, assignee: 'ada'),
            card('s23', 'Moodboard', CardSize.m, 19, assignee: 'dev'),
          ],
        ]),
      ),
      Project(
        id: 'app',
        name: 'Mobile App v2',
        color: const Color(0xFF5B8DEF),
        columns: columns('app', [
          [
            card('a1', 'Offline mode', CardSize.l, 12),
            card(
              'a2',
              'Haptics on swipe actions',
              CardSize.s,
              4,
              note: 'Nice to have',
            ),
          ],
          [
            card(
              'a3',
              'Push notification settings',
              CardSize.m,
              5,
              assignee: 'ben',
            ),
          ],
          [card('a4', 'New onboarding flow', CardSize.l, 9, assignee: 'ada')],
          [],
          [card('a5', 'Crash reporting', CardSize.s, 14, assignee: 'dev')],
        ]),
      ),
      Project(
        id: 'marketing',
        name: 'Q4 Marketing',
        color: const Color(0xFFF0A35E),
        columns: columns('marketing', [
          [card('m1', 'Holiday email series', CardSize.m, 3, assignee: 'cleo')],
          [],
          [],
          [],
          [],
        ]),
      ),
    ];
  }
}
