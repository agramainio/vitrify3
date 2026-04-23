import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'design_system.dart';
import 'models.dart';
import 'studio_repository.dart';

class PieceEditResult {
  const PieceEditResult({
    this.piece,
    this.deleted = false,
    this.identityChanged = false,
  });

  final Piece? piece;
  final bool deleted;
  final bool identityChanged;
}

class PieceEditorScreen extends StatefulWidget {
  const PieceEditorScreen.create({required this.repository, super.key})
    : piece = null;

  const PieceEditorScreen.edit({
    required this.repository,
    required this.piece,
    super.key,
  });

  final StudioRepository repository;
  final Piece? piece;

  bool get isEditing => piece != null;

  @override
  State<PieceEditorScreen> createState() => _PieceEditorScreenState();
}

class _PieceEditorScreenState extends State<PieceEditorScreen> {
  late final TextEditingController _moldController;
  late final TextEditingController _quantityController;
  late final TextEditingController _colorController;
  late final TextEditingController _priceController;
  late final TextEditingController _linkController;
  late final TextEditingController _failureReasonController;
  late final TextEditingController _failureNotesController;

  Mold? _selectedMold;
  List<StudioColor> _selectedColors = <StudioColor>[];
  PieceDestination _destination = PieceDestination.stock;
  LinkedRecord? _selectedLinkedRecord;
  PieceStage _stage = PieceStage.toFire;
  CommercialState _commercialState = CommercialState.available;
  bool _failed = false;

  bool get _isIdentityChange {
    final piece = widget.piece;
    if (piece == null) {
      return false;
    }

    final selectedMoldId = _selectedMold?.id;
    final typedMoldName = normalizeSearch(_moldController.text);
    final moldChanged = selectedMoldId != null
        ? selectedMoldId != piece.mold.id
        : typedMoldName.isNotEmpty &&
              typedMoldName != piece.mold.normalizedName;
    return moldChanged || !_sameColorIds(_selectedColors, piece.colors);
  }

  @override
  void initState() {
    super.initState();
    final piece = widget.piece;

    _moldController = TextEditingController(text: piece?.mold.name ?? '');
    _quantityController = TextEditingController(text: '1');
    _colorController = TextEditingController();
    _priceController = TextEditingController(
      text: piece == null ? '' : formatPrice(piece.price),
    );
    _linkController = TextEditingController(
      text: piece?.linkedRecord?.label ?? '',
    );
    _failureReasonController = TextEditingController(
      text: piece?.failureRecord?.reason ?? '',
    );
    _failureNotesController = TextEditingController(
      text: piece?.failureRecord?.notes ?? '',
    );

    if (piece != null) {
      _selectedMold = piece.mold;
      _selectedColors = List<StudioColor>.from(piece.colors);
      _destination = piece.destination;
      _selectedLinkedRecord = piece.linkedRecord;
      _stage = piece.stage;
      _commercialState = piece.commercialState;
      _failed = piece.failed;
    }

    _moldController.addListener(_handleMoldTextChange);
    _colorController.addListener(_handleColorTextChange);
    _linkController.addListener(_handleLinkTextChange);
  }

  @override
  void dispose() {
    _moldController
      ..removeListener(_handleMoldTextChange)
      ..dispose();
    _quantityController.dispose();
    _colorController
      ..removeListener(_handleColorTextChange)
      ..dispose();
    _priceController.dispose();
    _linkController
      ..removeListener(_handleLinkTextChange)
      ..dispose();
    _failureReasonController.dispose();
    _failureNotesController.dispose();
    super.dispose();
  }

  void _handleMoldTextChange() {
    final exact = widget.repository.findExactMold(_moldController.text);
    if (_selectedMold?.id == exact?.id) {
      setState(() {});
      return;
    }

    setState(() {
      _selectedMold = exact;
      if (exact != null) {
        _priceController.text = formatPrice(exact.defaultPrice);
      }
    });
  }

  void _handleLinkTextChange() {
    if (_destination == PieceDestination.stock) {
      if (_selectedLinkedRecord != null) {
        setState(() {
          _selectedLinkedRecord = null;
        });
      }
      return;
    }

    final exact = widget.repository.findExactLinkedRecord(
      _destination,
      _linkController.text,
    );
    if (_selectedLinkedRecord?.id == exact?.id) {
      setState(() {});
      return;
    }

    setState(() {
      _selectedLinkedRecord = exact;
    });
  }

  void _handleColorTextChange() {
    setState(() {});
  }

  int get _quantity {
    final parsed = int.tryParse(_quantityController.text.trim());
    if (parsed == null || parsed < 1) {
      return 0;
    }
    return parsed;
  }

  double? get _price {
    return double.tryParse(_priceController.text.trim().replaceAll(',', '.'));
  }

  Future<void> _pickMold(Mold mold) async {
    setState(() {
      _selectedMold = mold;
      _moldController.text = mold.name;
      _priceController.text = formatPrice(mold.defaultPrice);
    });
  }

  Future<void> _commitColorQuery([String? value]) async {
    final query = (value ?? _colorController.text).trim();
    if (query.isEmpty) {
      return;
    }

    final existing = widget.repository.findExactColor(query);
    final color = existing ?? await widget.repository.createColor(name: query);
    if (!mounted) {
      return;
    }

    if (_selectedColors.any((item) => item.id == color.id)) {
      setState(() {
        _colorController.clear();
      });
      return;
    }

    setState(() {
      _selectedColors = List<StudioColor>.from(_selectedColors)..add(color);
      _colorController.clear();
    });
  }

  Future<LinkedRecord?> _resolveLinkedRecord() async {
    if (_destination == PieceDestination.stock) {
      return null;
    }

    final query = _linkController.text.trim();
    if (query.isEmpty) {
      return null;
    }

    return _selectedLinkedRecord ??
        widget.repository.createLinkedRecord(
          destination: _destination,
          label: query,
        );
  }

  bool get _canSubmit {
    final hasMold = _moldController.text.trim().isNotEmpty;
    final hasColors =
        _selectedColors.isNotEmpty || _colorController.text.trim().isNotEmpty;
    final hasLink =
        _destination == PieceDestination.stock ||
        _linkController.text.trim().isNotEmpty;
    final hasFailureReason =
        !_failed || _failureReasonController.text.trim().isNotEmpty;

    return hasMold &&
        hasColors &&
        hasLink &&
        hasFailureReason &&
        _price != null &&
        _price! >= 0 &&
        (widget.isEditing || _quantity > 0);
  }

  Future<void> _submit() async {
    if (!_canSubmit) {
      return;
    }

    if (_colorController.text.trim().isNotEmpty) {
      await _commitColorQuery();
    }

    if (!mounted) {
      return;
    }

    final moldQuery = _moldController.text.trim();
    final resolvedMold =
        _selectedMold ??
        await widget.repository.createMold(
          name: moldQuery,
          defaultPrice: _price ?? 0,
        );
    final linkedRecord = await _resolveLinkedRecord();
    final price = _price ?? 0;

    if (!mounted) {
      return;
    }

    if (widget.isEditing) {
      final piece = widget.piece!;
      final identityChanged = _isIdentityChange;
      final updated = piece.copyWith(
        mold: resolvedMold,
        stage: _stage,
        colors: List<StudioColor>.unmodifiable(_selectedColors),
        price: price,
        destination: _destination,
        linkedRecord: linkedRecord,
        failureRecord: _failed
            ? FailureRecord(
                reason: _failureReasonController.text.trim(),
                notes: _failureNotesController.text.trim().isEmpty
                    ? null
                    : _failureNotesController.text.trim(),
                recordedAt: piece.failureRecord?.recordedAt ?? DateTime.now(),
              )
            : null,
        commercialState: _commercialState,
      );

      final saved = await widget.repository.updatePiece(updated);
      if (!mounted) {
        return;
      }
      Navigator.of(
        context,
      ).pop(PieceEditResult(piece: saved, identityChanged: identityChanged));
      return;
    }

    final created = await widget.repository.createPieces(
      mold: resolvedMold,
      quantity: _quantity,
      colors: List<StudioColor>.unmodifiable(_selectedColors),
      price: price,
      destination: _destination,
      commercialState: defaultCommercialStateForDestination(_destination),
      linkedRecord: linkedRecord,
    );
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(created);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final moldQuery = _moldController.text.trim();
    final colorQuery = _colorController.text.trim();
    final linkQuery = _linkController.text.trim();
    final moldSuggestions = moldQuery.isEmpty
        ? const <Mold>[]
        : widget.repository.suggestMolds(moldQuery);
    final colorSuggestions = colorQuery.isEmpty
        ? const <StudioColor>[]
        : widget.repository.suggestColors(colorQuery);
    final linkSuggestions = _destination == PieceDestination.stock
        ? const <LinkedRecord>[]
        : linkQuery.isEmpty
        ? const <LinkedRecord>[]
        : widget.repository.suggestLinkedRecords(
            _destination,
            _linkController.text,
          );
    final piece = widget.piece;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: AppColors.shellBackground,
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(
                      Icons.arrow_back,
                      color: AppColors.iconColor,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.isEditing ? 'EDIT PIECE' : 'NEW PIECE',
                          style: AppTypography.sectionLabel,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.isEditing ? piece!.id : 'Create piece',
                          style: theme.textTheme.headlineSmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _EditorSection(
                    title: 'Mold + quantity',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          key: const Key('mold-input'),
                          controller: _moldController,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Mold',
                            hintText: 'Type mold name',
                          ),
                        ),
                        if (moldSuggestions.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          for (final mold in moldSuggestions)
                            _SuggestionRow(
                              key: Key('mold-suggestion-${mold.name}'),
                              label: mold.name,
                              onTap: () => _pickMold(mold),
                            ),
                        ],
                        if (moldQuery.isNotEmpty && _selectedMold == null)
                          _SuggestionRow(
                            key: const Key('create-inline-mold'),
                            label: 'Create mold "$moldQuery"',
                            onTap: () async {
                              final created = await widget.repository
                                  .createMold(
                                    name: moldQuery,
                                    defaultPrice: _price ?? 0,
                                  );
                              if (!mounted) {
                                return;
                              }
                              await _pickMold(created);
                            },
                          ),
                        if (!widget.isEditing) ...[
                          const SizedBox(height: 12),
                          TextField(
                            key: const Key('quantity-input'),
                            controller: _quantityController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Quantity',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  _EditorSection(
                    title: 'Colors',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_selectedColors.isNotEmpty) ...[
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final color in _selectedColors)
                                _TagChip(
                                  label: color.name,
                                  onRemove: () {
                                    setState(() {
                                      _selectedColors = _selectedColors
                                          .where((item) => item.id != color.id)
                                          .toList(growable: false);
                                    });
                                  },
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],
                        TextField(
                          key: const Key('color-input'),
                          controller: _colorController,
                          textInputAction: TextInputAction.done,
                          onSubmitted: _commitColorQuery,
                          decoration: const InputDecoration(
                            labelText: 'Color',
                            hintText: 'Type color and add it',
                          ),
                        ),
                        if (colorSuggestions.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          for (final color in colorSuggestions)
                            _SuggestionRow(
                              key: Key('color-suggestion-${color.name}'),
                              label: color.name,
                              onTap: () => _commitColorQuery(color.name),
                            ),
                        ],
                        if (colorQuery.isNotEmpty &&
                            widget.repository.findExactColor(colorQuery) ==
                                null)
                          _SuggestionRow(
                            key: const Key('create-inline-color'),
                            label: 'Create color "$colorQuery"',
                            onTap: _commitColorQuery,
                          ),
                      ],
                    ),
                  ),
                  _EditorSection(
                    title: 'Destination + price',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ChoiceRow<PieceDestination>(
                          groupKey: 'destination',
                          value: _destination,
                          options: PieceDestination.values,
                          labelOf: (item) => item.label,
                          onSelected: (destination) {
                            setState(() {
                              final destinationChanged =
                                  _destination != destination;
                              _destination = destination;
                              if (destination == PieceDestination.stock ||
                                  destinationChanged) {
                                _linkController.clear();
                                _selectedLinkedRecord = null;
                              }
                              _commercialState =
                                  defaultCommercialStateForDestination(
                                    destination,
                                  );
                            });
                          },
                        ),
                        if (_destination != PieceDestination.stock) ...[
                          const SizedBox(height: 12),
                          if (_selectedLinkedRecord != null)
                            _LinkedRecordSummary(
                              key: const Key('selected-linked-record-summary'),
                              title: _destination == PieceDestination.order
                                  ? 'Order'
                                  : 'Workshop',
                              label: _selectedLinkedRecord!.label,
                              onChange: () {
                                setState(() {
                                  _selectedLinkedRecord = null;
                                  _linkController.clear();
                                });
                              },
                            )
                          else ...[
                            TextField(
                              key: const Key('linked-record-input'),
                              controller: _linkController,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText:
                                    _destination == PieceDestination.order
                                    ? 'Order'
                                    : 'Workshop',
                                hintText: _destination == PieceDestination.order
                                    ? 'Type order name or ref'
                                    : 'Type workshop name',
                              ),
                            ),
                            if (linkSuggestions.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              for (final record in linkSuggestions)
                                _SuggestionRow(
                                  key: Key('link-suggestion-${record.label}'),
                                  label: record.label,
                                  onTap: () {
                                    setState(() {
                                      _selectedLinkedRecord = record;
                                      _linkController.text = record.label;
                                    });
                                  },
                                ),
                            ],
                            if (linkQuery.isNotEmpty &&
                                _selectedLinkedRecord == null)
                              _SuggestionRow(
                                key: const Key('create-inline-link'),
                                label: _destination == PieceDestination.order
                                    ? 'Create order "$linkQuery"'
                                    : 'Create workshop "$linkQuery"',
                                onTap: () async {
                                  final created = await widget.repository
                                      .createLinkedRecord(
                                        destination: _destination,
                                        label: linkQuery,
                                      );
                                  if (!mounted) {
                                    return;
                                  }
                                  setState(() {
                                    _selectedLinkedRecord = created;
                                    _linkController.text = created.label;
                                  });
                                },
                              ),
                          ],
                        ],
                        const SizedBox(height: 12),
                        TextField(
                          key: const Key('price-input'),
                          controller: _priceController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9\.,]'),
                            ),
                          ],
                          decoration: const InputDecoration(labelText: 'Price'),
                        ),
                      ],
                    ),
                  ),
                  if (widget.isEditing)
                    _EditorSection(
                      title: 'State',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ChoiceRow<PieceStage>(
                            groupKey: 'stage',
                            value: _stage,
                            options: PieceStage.values,
                            labelOf: (item) => item.label,
                            onSelected: (stage) {
                              setState(() {
                                _stage = stage;
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          _ChoiceRow<CommercialState>(
                            groupKey: 'commercial',
                            value: _commercialState,
                            options: CommercialState.values,
                            labelOf: (item) => item.label,
                            onSelected: (value) {
                              setState(() {
                                _commercialState = value;
                              });
                            },
                          ),
                          if (_isIdentityChange) ...[
                            const SizedBox(height: 12),
                            Text(
                              'Changing mold or colors creates a new piece ID.',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ],
                      ),
                    ),
                  if (widget.isEditing)
                    _EditorSection(
                      title: 'Failure + timestamps',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              'Failed piece',
                              style: theme.textTheme.bodyLarge,
                            ),
                            activeThumbColor: AppColors.iconColor,
                            value: _failed,
                            onChanged: (value) {
                              setState(() {
                                _failed = value;
                              });
                            },
                          ),
                          if (_failed) ...[
                            const SizedBox(height: 10),
                            TextField(
                              key: const Key('failure-reason-input'),
                              controller: _failureReasonController,
                              decoration: const InputDecoration(
                                labelText: 'Failure reason',
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _failureNotesController,
                              minLines: 2,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                labelText: 'Failure notes',
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Text('Created', style: theme.textTheme.labelMedium),
                          const SizedBox(height: 4),
                          Text(
                            _formatTimestamp(context, piece!.createdAt),
                            style: AppTypography.dateText,
                          ),
                          const SizedBox(height: 12),
                          Text('Updated', style: theme.textTheme.labelMedium),
                          const SizedBox(height: 4),
                          Text(
                            _formatTimestamp(context, piece.updatedAt),
                            style: AppTypography.dateText,
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            child: TextButton(
                              key: const Key('delete-piece-button'),
                              onPressed: _confirmDelete,
                              child: const Text('Delete'),
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
                  key: const Key('save-piece-button'),
                  onPressed: _canSubmit ? _submit : null,
                  child: Text(
                    widget.isEditing && _isIdentityChange
                        ? 'Save as new piece'
                        : widget.isEditing
                        ? 'Save piece'
                        : 'Create',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final piece = widget.piece;
    if (piece == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete piece'),
          content: Text('Delete ${piece.id}? This cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await widget.repository.deletePiece(piece.id);
    if (!mounted) {
      return;
    }

    Navigator.of(context).pop(const PieceEditResult(deleted: true));
  }

  String _formatTimestamp(BuildContext context, DateTime value) {
    final localizations = MaterialLocalizations.of(context);
    return '${localizations.formatMediumDate(value)} ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(value))}';
  }
}

class _EditorSection extends StatelessWidget {
  const _EditorSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.textPrimary)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: AppTypography.sectionLabel),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({required this.label, required this.onTap, super.key});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(2),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.textPrimary)),
        ),
        child: Text(label, style: Theme.of(context).textTheme.bodyLarge),
      ),
    );
  }
}

class _LinkedRecordSummary extends StatelessWidget {
  const _LinkedRecordSummary({
    required this.title,
    required this.label,
    required this.onChange,
    super.key,
  });

  final String title;
  final String label;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.textPrimary),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 4),
                Text(label, style: Theme.of(context).textTheme.bodyLarge),
              ],
            ),
          ),
          TextButton(
            key: const Key('change-linked-record-button'),
            onPressed: onChange,
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }
}

bool _sameColorIds(List<StudioColor> left, List<StudioColor> right) {
  if (left.length != right.length) {
    return false;
  }

  for (var index = 0; index < left.length; index++) {
    if (left[index].id != right[index].id) {
      return false;
    }
  }

  return true;
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.textPrimary),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(width: 8),
          InkWell(
            onTap: onRemove,
            child: const Icon(
              Icons.close,
              size: 16,
              color: AppColors.iconColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoiceRow<T> extends StatelessWidget {
  const _ChoiceRow({
    required this.groupKey,
    required this.value,
    required this.options,
    required this.labelOf,
    required this.onSelected,
  });

  final String groupKey;
  final T value;
  final List<T> options;
  final String Function(T value) labelOf;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options)
          InkWell(
            key: Key('$groupKey-${labelOf(option)}'),
            onTap: () => onSelected(option),
            borderRadius: BorderRadius.circular(2),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: option == value
                    ? AppColors.primaryAccent
                    : AppColors.appBackground,
                border: Border.all(color: AppColors.textPrimary),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Text(labelOf(option), style: theme.textTheme.bodyMedium),
            ),
          ),
      ],
    );
  }
}
