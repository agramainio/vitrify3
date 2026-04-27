import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'design_system.dart';

enum AuthScreenMode { createAccount, login }

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    required this.onCreateAccount,
    required this.onLogin,
    required this.onForgotPassword,
    required this.onTemporaryTestUser,
    super.key,
  });

  final Future<void> Function(String email, String password) onCreateAccount;
  final Future<void> Function(String email, String password) onLogin;
  final Future<void> Function(String email) onForgotPassword;
  final Future<void> Function() onTemporaryTestUser;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  AuthScreenMode _mode = AuthScreenMode.createAccount;
  String? _message;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (!_validEmail(email)) {
      setState(() {
        _error = 'Enter a valid email address.';
        _message = null;
      });
      return;
    }
    if (password.length < 6) {
      setState(() {
        _error = 'Password must be at least 6 characters.';
        _message = null;
      });
      return;
    }

    await _run(() async {
      if (_mode == AuthScreenMode.createAccount) {
        await widget.onCreateAccount(email, password);
      } else {
        await widget.onLogin(email, password);
      }
    });
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (!_validEmail(email)) {
      setState(() {
        _error = 'Enter your email address first.';
        _message = null;
      });
      return;
    }

    await _run(
      () => widget.onForgotPassword(email),
      success:
          'If an account exists for this email, a reset email has been sent.',
    );
  }

  Future<void> _temporaryTestUser() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Temporary test user'),
          content: const Text(
            'Anonymous test data may become inaccessible after clearing browser or site data. Use Email/Password for durable atelier access.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }

    await _run(widget.onTemporaryTestUser);
  }

  Future<void> _run(Future<void> Function() action, {String? success}) async {
    setState(() {
      _loading = true;
      _error = null;
      _message = null;
    });

    try {
      await action();
      if (!mounted) {
        return;
      }
      if (success != null) {
        setState(() => _message = success);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = _readableError(error));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  bool _validEmail(String value) {
    return value.contains('@') && value.contains('.');
  }

  String _readableError(Object error) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'email-already-in-use':
          return 'An account already exists for this email. Try logging in.';
        case 'invalid-email':
          return 'Enter a valid email address.';
        case 'weak-password':
          return 'Choose a stronger password.';
        case 'wrong-password':
        case 'invalid-credential':
        case 'user-not-found':
          return 'Email or password is incorrect.';
        case 'operation-not-allowed':
          return 'Email/Password Auth is not enabled for this Firebase project.';
      }
      return error.message ?? 'Authentication failed.';
    }
    if (error is StateError) {
      return error.message;
    }
    return 'Authentication failed. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final isCreate = _mode == AuthScreenMode.createAccount;

    return Scaffold(
      body: SelectionArea(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.gutter),
              child: AppResponsiveContent(
                maxWidth: AppResponsive.narrowMaxWidth,
                child: AppCard(
                  margin: EdgeInsets.zero,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Vitrify',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: AppSpacing.related),
                      Text(
                        isCreate ? 'Create account' : 'Log in',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.gutter),
                      SegmentedButton<AuthScreenMode>(
                        segments: const [
                          ButtonSegment(
                            value: AuthScreenMode.createAccount,
                            label: Text('Create account'),
                          ),
                          ButtonSegment(
                            value: AuthScreenMode.login,
                            label: Text('Log in'),
                          ),
                        ],
                        selected: {_mode},
                        onSelectionChanged: _loading
                            ? null
                            : (selection) {
                                setState(() {
                                  _mode = selection.first;
                                  _error = null;
                                  _message = null;
                                });
                              },
                      ),
                      const SizedBox(height: AppSpacing.gutter),
                      TextField(
                        key: const Key('auth-email-input'),
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        textInputAction: TextInputAction.next,
                        enabled: !_loading,
                        decoration: const InputDecoration(labelText: 'Email'),
                      ),
                      const SizedBox(height: AppSpacing.related),
                      TextField(
                        key: const Key('auth-password-input'),
                        controller: _passwordController,
                        obscureText: true,
                        autofillHints: const [AutofillHints.password],
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _loading ? null : _submit(),
                        enabled: !_loading,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.related),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          key: const Key('forgot-password-button'),
                          onPressed: _loading ? null : _forgotPassword,
                          child: const Text('Forgot password?'),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: AppSpacing.related),
                        Text(
                          _error!,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                      if (_message != null) ...[
                        const SizedBox(height: AppSpacing.related),
                        Text(
                          _message!,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.gutter),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          key: const Key('auth-submit-button'),
                          onPressed: _loading ? null : _submit,
                          child: Text(
                            _loading
                                ? 'Working...'
                                : isCreate
                                ? 'Create account'
                                : 'Log in',
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.gutter),
                      const Divider(height: 1),
                      const SizedBox(height: AppSpacing.related),
                      Text(
                        'Temporary staging shortcut',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: AppSpacing.related),
                      Text(
                        'Anonymous test data may be lost after clearing browser or site data.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.related),
                      TextButton(
                        key: const Key('temporary-test-user-button'),
                        onPressed: _loading ? null : _temporaryTestUser,
                        child: const Text('Continue as temporary test user'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
