import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_spacing.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../../board/presentation/board_theme.dart';
import 'profile_widgets.dart';

/// Edits the user's photo, name and email. A new email needs the current
/// password; a new photo uploads on Save.
class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  // Seeded once; the user changing elsewhere shouldn't reset the form.
  late final _user = ref.read(authProvider).user;
  late final _name = TextEditingController(text: _user?.name ?? '');
  late final _email = TextEditingController(text: _user?.email ?? '');
  final _password = TextEditingController();
  File? _photo;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final c in [_name, _email, _password]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _emailChanged => _email.text.trim() != (_user?.email ?? '');

  bool get _dirty =>
      _photo != null ||
      _name.text.trim() != (_user?.name ?? '') ||
      _emailChanged;

  bool get _ready =>
      _dirty &&
      _name.text.trim().isNotEmpty &&
      _email.text.trim().isNotEmpty &&
      (!_emailChanged || _password.text.isNotEmpty);

  Future<void> _pickPhoto() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    final path = result?.files.single.path;
    if (path != null) setState(() => _photo = File(path));
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    final auth = ref.read(authProvider.notifier);
    final name = _name.text.trim();
    try {
      if (name != _user?.name || _emailChanged) {
        await auth.updateProfile(
          name: name,
          email: _emailChanged ? _email.text.trim() : null,
          currentPassword: _emailChanged ? _password.text : null,
        );
      }
      if (_photo != null) await auth.updatePhoto(_photo!.path);
      if (mounted) context.pop();
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

    return Scaffold(
      backgroundColor: BoardColors.bg,
      appBar: AppBar(
        backgroundColor: BoardColors.bg,
        title: const Text('Edit profile'),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.page),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: GestureDetector(
                  onTap: _saving ? null : _pickPhoto,
                  child: UserAvatar(
                    name: _name.text,
                    photoUrl: _user?.photoUrl,
                    file: _photo,
                    size: 96,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Center(
                child: TextButton(
                  onPressed: _saving ? null : _pickPhoto,
                  child: const Text('Change photo'),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _name,
                enabled: !_saving,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _email,
                enabled: !_saving,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.mail_outline_rounded),
                ),
              ),
              if (_emailChanged) ...[
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  controller: _password,
                  enabled: !_saving,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Current password',
                    helperText: 'Needed to change your email.',
                    prefixIcon: Icon(Icons.lock_outline_rounded),
                  ),
                ),
              ],
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
                    : const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
