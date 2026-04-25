import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'bench_screen.dart';
import 'design_system.dart';
import 'models.dart';
import 'studio_repository.dart';

class VitrifyApp extends StatefulWidget {
  const VitrifyApp({
    required this.repository,
    this.initialUser,
    this.persistUser = true,
    super.key,
  });

  final StudioRepository repository;
  final StudioUser? initialUser;
  final bool persistUser;

  @override
  State<VitrifyApp> createState() => _VitrifyAppState();
}

class _VitrifyAppState extends State<VitrifyApp> {
  static const _userIdKey = 'vitrify_user_id';
  static const _userNameKey = 'vitrify_user_name';

  StudioUser? _user;
  bool _loadingUser = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialUser != null) {
      _user = widget.initialUser;
      _loadingUser = false;
    } else {
      _loadUser();
    }
  }

  Future<void> _loadUser() async {
    if (!widget.persistUser) {
      setState(() => _loadingUser = false);
      return;
    }

    final preferences = await SharedPreferences.getInstance();
    final id = preferences.getString(_userIdKey);
    final name = preferences.getString(_userNameKey);

    if (!mounted) {
      return;
    }

    setState(() {
      if (id != null && name != null && name.trim().isNotEmpty) {
        _user = StudioUser(id: id, name: name);
      }
      _loadingUser = false;
    });
  }

  Future<void> _saveUser(String name) async {
    final user = StudioUser(
      id: 'user_${DateTime.now().microsecondsSinceEpoch}',
      name: name.trim(),
    );

    if (widget.persistUser) {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_userIdKey, user.id);
      await preferences.setString(_userNameKey, user.name);
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _user = user;
      _loadingUser = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vitrify',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      builder: (context, child) {
        return Overlay(
          key: ValueKey(_user?.id ?? (_loadingUser ? 'loading' : 'setup')),
          initialEntries: [
            OverlayEntry(
              builder: (context) {
                return SelectionArea(child: child ?? const SizedBox.shrink());
              },
            ),
          ],
        );
      },
      home: _loadingUser
          ? const _LoadingShell()
          : _user == null
          ? _UserSetupScreen(onSubmit: _saveUser)
          : BenchScreen(repository: widget.repository, currentUser: _user!),
    );
  }
}

class _LoadingShell extends StatelessWidget {
  const _LoadingShell();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: SizedBox.expand());
  }
}

class _UserSetupScreen extends StatefulWidget {
  const _UserSetupScreen({required this.onSubmit});

  final Future<void> Function(String name) onSubmit;

  @override
  State<_UserSetupScreen> createState() => _UserSetupScreenState();
}

class _UserSetupScreenState extends State<_UserSetupScreen> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController()..addListener(_handleChange);
  }

  @override
  void dispose() {
    _nameController
      ..removeListener(_handleChange)
      ..dispose();
    super.dispose();
  }

  void _handleChange() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _nameController.text.trim().isNotEmpty;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.gutter),
            child: AppCard(
              margin: EdgeInsets.zero,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What is your name?',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.related),
                  TextField(
                    key: const Key('user-name-input'),
                    controller: _nameController,
                    textInputAction: TextInputAction.done,
                    onSubmitted: canSubmit ? widget.onSubmit : null,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                  const SizedBox(height: AppSpacing.gutter),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      key: const Key('save-user-button'),
                      onPressed: canSubmit
                          ? () => widget.onSubmit(_nameController.text)
                          : null,
                      child: const Text('Continue'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
