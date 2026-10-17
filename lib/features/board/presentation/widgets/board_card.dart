import 'package:flutter/material.dart';
import '../../domain/board_models.dart';
import '../board_theme.dart';

/// A card on the board: white sheet with a colored rule along the top.
class BoardCard extends StatelessWidget {
  const BoardCard({
    super.key,
    required this.card,
    required this.accent,
    required this.assignee,
    required this.now,
    this.onTap,
  });

  final TaskCard card;
  final Color accent;
  final Member? assignee;
  final DateTime now;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final age = now.difference(card.createdAt).inDays;

    return Material(
      color: BoardColors.surface,
      borderRadius: BorderRadius.circular(3),
      elevation: 1.5,
      shadowColor: Colors.black26,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(3),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: accent, width: 2.5)),
          ),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                card.title,
                style: text.titleMedium!.copyWith(
                  fontSize: 15,
                  color: BoardColors.ink,
                ),
              ),
              if (card.note != null && card.note!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  card.note!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall!.copyWith(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w400,
                    color: BoardColors.inkSoft,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  if (card.size != null) ...[
                    SizeBadge(size: card.size!),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      assignee?.name ?? 'Nobody yet',
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall!.copyWith(
                        fontSize: 13,
                        color: assignee == null
                            ? BoardColors.inkSoft
                            : BoardColors.ink,
                      ),
                    ),
                  ),
                  Text(
                    age <= 0 ? 'today' : '${age}d',
                    style: text.labelMedium!.copyWith(
                      fontWeight: FontWeight.w700,
                      color: BoardColors.inkSoft,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SizeBadge extends StatelessWidget {
  const SizeBadge({super.key, required this.size});

  final CardSize size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: BoardColors.line, width: 1.5),
      ),
      child: Text(
        size.label,
        style: Theme.of(context).textTheme.labelSmall!.copyWith(
          color: BoardColors.inkSoft,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
