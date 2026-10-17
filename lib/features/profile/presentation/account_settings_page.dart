import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_spacing.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../../board/presentation/board_theme.dart';
import '../../board/presentation/widgets/board_sheet.dart';
import 'profile_widgets.dart';

final _appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version} (${info.buildNumber})';
});

/// Settings under Me: change password, the app version, delete account.
class AccountSettingsPage extends ConsumerWidget {
  const AccountSettingsPage({super.key});

  Future<void> _changePassword(BuildContext context) async {
    final changed = await showBoardSheet<bool>(
      context,
      isScrollControlled: true,
      builder: (_) => const _ChangePasswordSheet(),
    );
    if (changed == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Password changed')));
    }
  }

  Future<void> _deleteAccount(BuildContext context) async {
    // On success the session ends and the router goes to the login page.
    await showDialog<void>(
      context: context,
      builder: (_) =>
          Theme(data: BoardTheme.data, child: const _DeleteAccountDialog()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final version = ref.watch(_appVersionProvider).valueOrNull;

    return Scaffold(
      backgroundColor: BoardColors.bg,
      appBar: AppBar(
        backgroundColor: BoardColors.bg,
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          MenuTile(
            icon: Icons.lock_outline_rounded,
            label: 'Change password',
            onTap: () => _changePassword(context),
          ),
          MenuTile(
            icon: Icons.info_outline_rounded,
            label: 'About',
            trailing: version == null ? null : 'Version $version',
            onTap: null,
          ),
          const SizedBox(height: AppSpacing.lg),
          MenuTile(
            icon: Icons.delete_forever_outlined,
            label: 'Delete account',
            danger: true,
            onTap: () => _deleteAccount(context),
          ),
        ],
      ),
    );
  }
}

class _ChangePasswordSheet extends ConsumerStatefulWidget {
  const _ChangePasswordSheet();

  @override
  ConsumerState<_ChangePasswordSheet> createState() =>
      _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends ConsumerState<_ChangePasswordSheet> {
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final c in [_current, _new, _confirm]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String? get _mismatch =>
      _confirm.text.isNotEmpty && _confirm.text != _new.text
      ? "Passwords don't match"
      : null;

  bool get _ready =>
      _current.text.isNotEmpty &&
      _new.text.length >= 8 &&
      _confirm.text == _new.text;

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(authProvider.notifier)
          .changePassword(
            currentPassword: _current.text,
            newPassword: _new.text,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = ApiException.from(e).message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          0,
          AppSpacing.page,
          AppSpacing.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Change password', style: text.headlineSmall),
            const SizedBox(height: AppSpacing.xs),
            Text(
              "You'll stay signed in here; other devices will be signed out.",
              style: text.bodyMedium!.copyWith(color: BoardColors.inkSoft),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _current,
              enabled: !_saving,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Current password'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _new,
              enabled: !_saving,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New password',
                helperText: 'At least 8 characters',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _confirm,
              enabled: !_saving,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Confirm new password',
                errorText: _mismatch,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(
                _error!,
                style: text.bodyMedium!.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton(
              onPressed: _ready && !_saving ? _save : null,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Change password'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeleteAccountDialog extends ConsumerStatefulWidget {
  const _DeleteAccountDialog();

  @override
  ConsumerState<_DeleteAccountDialog> createState() =>
      _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<_DeleteAccountDialog> {
  final _password = TextEditingController();
  bool _deleting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _password.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).deleteAccount(_password.text);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _error = ApiException.from(e).message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;

    return AlertDialog(
      title: const Text('Delete your account?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This signs you out everywhere and deletes your account. Teams '
            "and projects you own are deleted too, for everyone in them. "
            "This can't be undone.",
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _password,
            enabled: !_deleting,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'Current password',
              errorText: _error,
              errorMaxLines: 3,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _deleting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _password.text.isEmpty || _deleting ? null : _delete,
          style: TextButton.styleFrom(foregroundColor: error),
          child: _deleting
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Delete account'),
        ),
      ],
    );
  }
}
