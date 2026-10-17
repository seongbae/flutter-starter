import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../board_theme.dart';

class _Destination {
  const _Destination(this.path, this.label, this.icon);

  final String path;
  final String label;
  final IconData icon;
}

const _destinations = [
  _Destination('/board', 'Tasks', Icons.push_pin_rounded),
  _Destination('/standup', 'Standup', Icons.record_voice_over_outlined),
  _Destination('/flow', 'Flow', Icons.air_rounded),
  _Destination('/me', 'Me', Icons.person_outline_rounded),
];

/// Bottom-nav shell for the task app (Tasks / Standup / Flow / Me), always
/// drawn with [BoardTheme].
class BoardShell extends StatelessWidget {
  const BoardShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final selected = _destinations.indexWhere(
      (d) => location.startsWith(d.path),
    );

    return Theme(
      data: BoardTheme.data,
      child: Scaffold(
        backgroundColor: BoardColors.bg,
        body: child,
        bottomNavigationBar: _BoardNavBar(
          selected: selected,
          onSelect: (i) => context.go(_destinations[i].path),
        ),
      ),
    );
  }
}

class _BoardNavBar extends StatelessWidget {
  const _BoardNavBar({required this.selected, required this.onSelect});

  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final label = Theme.of(context).textTheme.labelSmall!;

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: BoardColors.surface,
        border: Border(top: BorderSide(color: BoardColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              for (var i = 0; i < _destinations.length; i++)
                Expanded(
                  child: InkResponse(
                    onTap: () => onSelect(i),
                    highlightShape: BoxShape.rectangle,
                    containedInkWell: true,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 56,
                          height: 28,
                          decoration: BoxDecoration(
                            color: i == selected
                                ? BoardColors.navy
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            _destinations[i].icon,
                            size: 19,
                            color: i == selected
                                ? Colors.white
                                : BoardColors.inkSoft,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _destinations[i].label,
                          style: label.copyWith(
                            color: i == selected
                                ? BoardColors.navy
                                : BoardColors.inkSoft,
                            fontWeight: i == selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Stand-in for tabs that haven't been built yet.
class ComingSoonPage extends StatelessWidget {
  const ComingSoonPage({
    super.key,
    required this.title,
    required this.icon,
    required this.description,
  });

  final String title;
  final IconData icon;
  final String description;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: BoardColors.navy),
              const SizedBox(height: 16),
              Text(title, style: text.headlineMedium),
              const SizedBox(height: 8),
              Text(
                description,
                textAlign: TextAlign.center,
                style: text.bodyMedium!.copyWith(color: BoardColors.inkSoft),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
