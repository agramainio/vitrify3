import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'design_system.dart';
import 'studio_repository.dart';

class MoldEditorScreen extends StatefulWidget {
  const MoldEditorScreen({required this.repository, super.key});

  final StudioRepository repository;

  @override
  State<MoldEditorScreen> createState() => _MoldEditorScreenState();
}

class _MoldEditorScreenState extends State<MoldEditorScreen> {
  late final TextEditingController _headerSearchController;
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;

  @override
  void initState() {
    super.initState();
    _headerSearchController = TextEditingController();
    _nameController = TextEditingController()..addListener(_handleChange);
    _priceController = TextEditingController()..addListener(_handleChange);
  }

  @override
  void dispose() {
    _headerSearchController.dispose();
    _nameController
      ..removeListener(_handleChange)
      ..dispose();
    _priceController
      ..removeListener(_handleChange)
      ..dispose();
    super.dispose();
  }

  void _handleChange() {
    setState(() {});
  }

  bool get _canSubmit {
    final price = double.tryParse(_priceController.text.replaceAll(',', '.'));
    return _nameController.text.trim().isNotEmpty &&
        (_priceController.text.trim().isEmpty || price != null);
  }

  Future<void> _submit() async {
    if (!_canSubmit) {
      return;
    }

    final price =
        double.tryParse(_priceController.text.trim().replaceAll(',', '.')) ?? 0;
    final mold = await widget.repository.createMold(
      name: _nameController.text.trim(),
      defaultPrice: price,
    );

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop(mold);
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = MaterialLocalizations.of(
      context,
    ).formatMediumDate(DateUtils.dateOnly(DateTime.now()));

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              screenName: 'New mold',
              dateLabel: dateLabel,
              searchController: _headerSearchController,
              onBack: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  AppSection(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          key: const Key('mold-name-input'),
                          controller: _nameController,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Mold',
                            hintText: 'Type mold name',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          key: const Key('mold-price-input'),
                          controller: _priceController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9\.,]'),
                            ),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Default price',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              color: AppColors.shellBackground,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('save-mold-button'),
                  onPressed: _canSubmit ? _submit : null,
                  child: const Text('Create mold'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
