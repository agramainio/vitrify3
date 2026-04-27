import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'app_environment.dart';
import 'design_system.dart';
import 'firebase_atelier_bootstrap.dart';

class FirebaseBootstrapApp extends StatefulWidget {
  const FirebaseBootstrapApp({required this.environment, super.key});

  final VitrifyEnvironment environment;

  @override
  State<FirebaseBootstrapApp> createState() => _FirebaseBootstrapAppState();
}

class _FirebaseBootstrapAppState extends State<FirebaseBootstrapApp> {
  FirebaseAtelierSession? _session;
  Object? _error;
  StackTrace? _stackTrace;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    setState(() {
      _loading = true;
      _error = null;
      _stackTrace = null;
    });

    try {
      final session = await FirebaseAtelierBootstrap.start(widget.environment);
      if (!mounted) {
        return;
      }

      setState(() {
        _session = session;
        _loading = false;
      });
    } catch (error, stackTrace) {
      if (!mounted) {
        return;
      }

      setState(() {
        _session = null;
        _error = error;
        _stackTrace = stackTrace;
        _loading = false;
      });
    }
  }

  Future<void> _resetAndRetry() async {
    setState(() {
      _loading = true;
      _error = null;
      _stackTrace = null;
    });

    await FirebaseAtelierBootstrap.clearLocalBootstrapStateForCurrentUser(
      widget.environment,
    );

    if (!mounted) {
      return;
    }

    await _start();
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    if (session != null) {
      return VitrifyApp(
        repository: session.repository,
        initialUser: session.currentUser,
        persistUser: false,
      );
    }

    return MaterialApp(
      title: 'Vitrify',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      home: _loading
          ? _BootstrapLoadingScreen(environment: widget.environment)
          : _BootstrapErrorScreen(
              environment: widget.environment,
              error: _error,
              stackTrace: _stackTrace,
              onRetry: _start,
              onResetLocalState: _resetAndRetry,
            ),
    );
  }
}

class _BootstrapLoadingScreen extends StatelessWidget {
  const _BootstrapLoadingScreen({required this.environment});

  final VitrifyEnvironment environment;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SelectionArea(
        child: SafeArea(
          child: Center(
            child: Padding(
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
                        'Starting Vitrify',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.related),
                      Text(
                        'VITRIFY_ENV: ${environment.name}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.gutter),
                      const LinearProgressIndicator(),
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

class _BootstrapErrorScreen extends StatelessWidget {
  const _BootstrapErrorScreen({
    required this.environment,
    required this.error,
    required this.stackTrace,
    required this.onRetry,
    required this.onResetLocalState,
  });

  final VitrifyEnvironment environment;
  final Object? error;
  final StackTrace? stackTrace;
  final VoidCallback onRetry;
  final VoidCallback onResetLocalState;

  @override
  Widget build(BuildContext context) {
    final details = _technicalDetails(error, stackTrace);

    return Scaffold(
      body: SelectionArea(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.gutter),
            child: AppResponsiveContent(
              maxWidth: AppResponsive.readingMaxWidth,
              child: AppCard(
                margin: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vitrify could not start',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.related),
                    Text(
                      'VITRIFY_ENV: ${environment.name}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.gutter),
                    Text(
                      _readableMessage(error),
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: AppSpacing.gutter),
                    Text(
                      'Likely causes',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.related),
                    const _CauseList(),
                    const SizedBox(height: AppSpacing.gutter),
                    Text(
                      'Technical details',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.related),
                    TextField(
                      controller: TextEditingController(text: details),
                      readOnly: true,
                      maxLines: 10,
                      minLines: 6,
                      decoration: const InputDecoration(
                        labelText: 'Copyable error details',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.gutter),
                    Wrap(
                      spacing: AppSpacing.related,
                      runSpacing: AppSpacing.related,
                      children: [
                        FilledButton(
                          key: const Key('bootstrap-retry-button'),
                          onPressed: onRetry,
                          child: const Text('Retry'),
                        ),
                        TextButton(
                          key: const Key('bootstrap-reset-local-state-button'),
                          onPressed: onResetLocalState,
                          child: Text(
                            environment == VitrifyEnvironment.staging
                                ? 'Reset local staging state'
                                : 'Reset local bootstrap state',
                          ),
                        ),
                      ],
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

  String _readableMessage(Object? error) {
    if (error is FirebaseException) {
      final message = error.message?.trim();
      if (message != null && message.isNotEmpty) {
        return '${error.plugin}/${error.code}: $message';
      }
      return '${error.plugin}/${error.code}: Firebase startup failed.';
    }

    final text = error?.toString().trim();
    if (text != null && text.isNotEmpty) {
      return text;
    }
    return 'Firebase startup failed before the app could open.';
  }

  String _technicalDetails(Object? error, StackTrace? stackTrace) {
    final buffer = StringBuffer()
      ..writeln('VITRIFY_ENV=${environment.name}')
      ..writeln('errorType=${error.runtimeType}')
      ..writeln('error=$error');

    if (error is FirebaseException) {
      buffer
        ..writeln('firebasePlugin=${error.plugin}')
        ..writeln('firebaseCode=${error.code}')
        ..writeln('firebaseMessage=${error.message}');
    }

    if (stackTrace != null) {
      buffer
        ..writeln()
        ..writeln(stackTrace);
    }

    return buffer.toString();
  }
}

class _CauseList extends StatelessWidget {
  const _CauseList();

  @override
  Widget build(BuildContext context) {
    const causes = [
      'Firestore rules are not deployed or deny anonymous atelier bootstrap.',
      'Firebase Auth provider or authorized domain is not enabled for this host.',
      'Saved activeAtelierId in local storage is stale for this preview.',
      'The deployed build is pointing at a different Firebase project.',
      'Firestore web persistence contains stale local state.',
      'Storage bucket is unavailable only when an image upload is attempted.',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final cause in causes)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text('- $cause'),
          ),
      ],
    );
  }
}
