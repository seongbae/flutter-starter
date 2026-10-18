import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/labeled_field.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    ref.listen(authProvider, (previous, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next.error!)));
      }
    });

    return Scaffold(
      appBar: AppBar(leading: BackButton(onPressed: () => context.go('/home'))),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.page),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context).welcomeBack,
                      style: Theme.of(context).textTheme.displayMedium,
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    LabeledField(
                      label: AppLocalizations.of(context).email,
                      child: TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(
                            Icons.mail_outline_rounded,
                            size: 20,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return AppLocalizations.of(
                              context,
                            ).pleaseEnterEmail;
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    LabeledField(
                      label: AppLocalizations.of(context).password,
                      child: TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(
                            Icons.lock_outline_rounded,
                            size: 20,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return AppLocalizations.of(
                              context,
                            ).pleaseEnterPassword;
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: authState.isLoading ? null : _onLogin,
                        child: authState.isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(AppLocalizations.of(context).login),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Center(
                      child: TextButton(
                        onPressed: () => context.go('/register'),
                        child: Text(
                          AppLocalizations.of(context).createAnAccount,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onLogin() {
    if (_formKey.currentState!.validate()) {
      ref
          .read(authProvider.notifier)
          .login(_emailController.text, _passwordController.text);
    }
  }
}
