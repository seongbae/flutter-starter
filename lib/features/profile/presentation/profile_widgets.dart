import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_spacing.dart';
import '../../board/presentation/board_theme.dart';

/// The user's photo in a circle: a just-picked [file], else [photoUrl], else
/// the first letter of [name].
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.file,
    this.size = 56,
  });

  final String name;
  final String? photoUrl;
  final File? file;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initial = Center(
      child: Text(
        name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase(),
        style: TextStyle(
          fontSize: size * 0.42,
          fontWeight: FontWeight.w700,
          color: BoardColors.navy,
        ),
      ),
    );

    return ClipOval(
      child: Container(
        width: size,
        height: size,
        color: BoardColors.chip,
        child: file != null
            ? Image.file(file!, fit: BoxFit.cover)
            : photoUrl != null && photoUrl!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: photoUrl!,
                fit: BoxFit.cover,
                placeholder: (_, __) => initial,
                errorWidget: (_, __, ___) => initial,
              )
            : initial,
      ),
    );
  }
}

/// A white card with a hairline border, as the Me and Settings rows use.
class ProfileCard extends StatelessWidget {
  const ProfileCard({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // A Material (not a decorated Container) so ink splashes paint on it.
    return Material(
      color: BoardColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: BoardColors.line),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: InkWell(onTap: onTap, child: child),
    );
  }
}

/// One row of the Me and Settings menus.
class MenuTile extends StatelessWidget {
  const MenuTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  /// Shown before the chevron, e.g. the app version.
  final String? trailing;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final color = danger
        ? Theme.of(context).colorScheme.error
        : BoardColors.ink;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: ProfileCard(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Text(
                  label,
                  style: text.titleSmall!.copyWith(color: color),
                ),
              ),
              if (trailing != null)
                Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.sm),
                  child: Text(
                    trailing!,
                    style: text.bodySmall!.copyWith(color: BoardColors.inkSoft),
                  ),
                ),
              if (onTap != null)
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: BoardColors.inkSoft,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
