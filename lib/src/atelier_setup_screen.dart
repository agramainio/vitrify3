import 'package:flutter/material.dart';

import 'design_system.dart';
import 'models.dart';

class AtelierSetupScreen extends StatefulWidget {
  const AtelierSetupScreen({required this.onSubmit, super.key});

  final Future<void> Function(String name, String alias) onSubmit;

  @override
  State<AtelierSetupScreen> createState() => _AtelierSetupScreenState();
}

class _AtelierSetupScreenState extends State<AtelierSetupScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _aliasController;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _aliasController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _aliasController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final alias = normalizeAlias(_aliasController.text);
    if (name.isEmpty) {
      setState(() => _error = 'Atelier name is required.');
      return;
    }
    if (!_validAlias(alias)) {
      setState(() {
        _error =
            'Alias must be lowercase, URL-safe, and use letters, numbers, or hyphens.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await widget.onSubmit(name, alias);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = error is StateError
            ? error.message
            : 'Could not create atelier. Please try again.';
      });
    }
  }

  bool _validAlias(String value) {
    return RegExp(r'^[a-z0-9][a-z0-9-]{0,62}[a-z0-9]$').hasMatch(value);
  }

  @override
  Widget build(BuildContext context) {
    final previewAlias = normalizeAlias(_aliasController.text);

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
                        'Set up your atelier',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.related),
                      Text(
                        'Your account logs in. Your atelier owns the molds, pieces, orders, workshops, batches, and colors.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.gutter),
                      TextField(
                        key: const Key('atelier-name-input'),
                        controller: _nameController,
                        enabled: !_loading,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Atelier name',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.related),
                      TextField(
                        key: const Key('atelier-alias-input'),
                        controller: _aliasController,
                        enabled: !_loading,
                        textInputAction: TextInputAction.done,
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) => _loading ? null : _submit(),
                        decoration: const InputDecoration(
                          labelText: 'Atelier alias / slug',
                          hintText: 'eugene-griotte',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.related),
                      Text(
                        previewAlias.isEmpty
                            ? 'Future URL: alias.vitrify.app'
                            : 'Future URL: $previewAlias.vitrify.app',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: AppSpacing.related),
                        Text(
                          _error!,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.gutter),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          key: const Key('atelier-setup-submit-button'),
                          onPressed: _loading ? null : _submit,
                          child: Text(
                            _loading ? 'Creating...' : 'Create atelier',
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
      ),
    );
  }
}
