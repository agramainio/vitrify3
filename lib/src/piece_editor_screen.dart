import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'design_system.dart';
import 'global_piece_search.dart';
import 'mold_editor_screen.dart';
import 'models.dart';
import 'piece_detail_screen.dart';
import 'studio_repository.dart';
import 'user_page.dart';

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
  const PieceEditorScreen.create({
    required this.repository,
    required this.currentUser,
    this.initialMold,
    super.key,
  }) : piece = null,
       batchPieces = null;

  const PieceEditorScreen.edit({
    required this.repository,
    required this.piece,
    this.currentUser,
    this.batchPieces,
    super.key,
  }) : initialMold = null;

  final StudioRepository repository;
  final Piece? piece;
  final StudioUser? currentUser;
  final Mold? initialMold;
  final List<Piece>? batchPieces;

  bool get isEditing => piece != null;

  @override
  State<PieceEditorScreen> createState() => _PieceEditorScreenState();
}

class _PieceEditorScreenState extends State<PieceEditorScreen> {
  late final TextEditingController _headerSearchController;
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

  bool _editingMold = false;
  bool _editingColors = false;
  bool _editingCommerce = false;
  bool _editingState = false;
  bool _showMoldSuggestions = false;
  bool _showColorSuggestions = false;
  bool _showLinkSuggestions = false;
  bool _programmaticMoldText = false;
  bool _programmaticColorText = false;
  bool _programmaticLinkText = false;
  bool _allowExit = false;

  bool get _isIdentityChange {
    final pieces =
        widget.batchPieces ?? [if (widget.piece != null) widget.piece!];
    if (pieces.isEmpty) {
      return false;
    }

    final selectedMoldId = _selectedMold?.id;
    final typedMoldName = normalizeSearch(_moldController.text);
    return pieces.any((piece) {
      final moldChanged = selectedMoldId != null
          ? selectedMoldId != piece.mold.id
          : typedMoldName.isNotEmpty &&
                typedMoldName != piece.mold.normalizedName;
      return moldChanged || !_sameColorIds(_selectedColors, piece.colors);
    });
  }

  StudioUser get _activeUser {
    return widget.currentUser ??
        const StudioUser(id: 'local-user', name: 'Local');
  }

  bool get _hasUnsavedChanges {
    if (_allowExit) {
      return false;
    }

    final piece = widget.piece;
    if (piece == null) {
      return _moldController.text.trim().isNotEmpty ||
          _selectedMold != null ||
          _quantityController.text.trim() != '1' ||
          _selectedColors.isNotEmpty ||
          _colorController.text.trim().isNotEmpty ||
          _priceController.text.trim().isNotEmpty ||
          _destination != PieceDestination.stock ||
          _linkController.text.trim().isNotEmpty;
    }

    return _quantityController.text.trim() !=
            (widget.batchPieces?.length ?? 1).toString() ||
        _isIdentityChange ||
        _destination != piece.destination ||
        _stage != piece.stage ||
        _commercialState != piece.commercialState ||
        _price != piece.price ||
        (_selectedLinkedRecord?.id ?? _linkController.text.trim()) !=
            (piece.linkedRecord?.id ?? '') ||
        _failed != piece.failed ||
        _failureReasonController.text.trim() !=
            (piece.failureRecord?.reason ?? '') ||
        _failureNotesController.text.trim() !=
            (piece.failureRecord?.notes ?? '');
  }

  Future<bool> _confirmLeaveIfNeeded() async {
    if (!_hasUnsavedChanges) {
      return true;
    }

    return confirmDiscardUnsavedChanges(context);
  }

  Future<void> _leaveCurrentForm() async {
    setState(() => _allowExit = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) {
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _maybePop() async {
    if (await _confirmLeaveIfNeeded() && mounted) {
      await _leaveCurrentForm();
    }
  }

  Future<void> _handleBlockedPop() async {
    if (await _confirmLeaveIfNeeded() && mounted) {
      await _leaveCurrentForm();
    }
  }

  Future<void> _popEditor(Object? result) async {
    setState(() => _allowExit = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) {
      Navigator.of(context).pop(result);
    }
  }

  @override
  void initState() {
    super.initState();
    final piece = widget.piece;

    _headerSearchController = TextEditingController();
    _moldController = TextEditingController(text: piece?.mold.name ?? '');
    _quantityController = TextEditingController(
      text: widget.batchPieces == null
          ? '1'
          : widget.batchPieces!.length.toString(),
    );
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
    } else if (widget.initialMold != null) {
      _selectedMold = widget.initialMold;
      _moldController.text = widget.initialMold!.name;
      _priceController.text = formatPrice(widget.initialMold!.defaultPrice);
    }

    _moldController.addListener(_handleMoldTextChange);
    _quantityController.addListener(_handleFieldChange);
    _colorController.addListener(_handleColorTextChange);
    _priceController.addListener(_handleFieldChange);
    _linkController.addListener(_handleLinkTextChange);
    _failureReasonController.addListener(_handleFieldChange);
    _failureNotesController.addListener(_handleFieldChange);
  }

  @override
  void dispose() {
    _headerSearchController.dispose();
    _moldController
      ..removeListener(_handleMoldTextChange)
      ..dispose();
    _quantityController
      ..removeListener(_handleFieldChange)
      ..dispose();
    _colorController
      ..removeListener(_handleColorTextChange)
      ..dispose();
    _priceController
      ..removeListener(_handleFieldChange)
      ..dispose();
    _linkController
      ..removeListener(_handleLinkTextChange)
      ..dispose();
    _failureReasonController
      ..removeListener(_handleFieldChange)
      ..dispose();
    _failureNotesController
      ..removeListener(_handleFieldChange)
      ..dispose();
    super.dispose();
  }

  void _handleFieldChange() {
    setState(() {});
  }

  void _handleMoldTextChange() {
    if (_programmaticMoldText) {
      return;
    }

    final query = _moldController.text.trim();
    final exact = widget.repository.findExactMold(_moldController.text);
    setState(() {
      _showMoldSuggestions = query.isNotEmpty;
      _selectedMold = exact;
      if (exact != null) {
        _priceController.text = formatPrice(exact.defaultPrice);
      }
    });
  }

  void _handleColorTextChange() {
    if (_programmaticColorText) {
      return;
    }

    setState(() {
      _showColorSuggestions = _colorController.text.trim().isNotEmpty;
    });
  }

  void _handleLinkTextChange() {
    if (_programmaticLinkText) {
      return;
    }

    if (_destination == PieceDestination.stock) {
      if (_selectedLinkedRecord != null) {
        setState(() {
          _selectedLinkedRecord = null;
          _showLinkSuggestions = false;
        });
      }
      return;
    }

    final query = _linkController.text.trim();
    final exact = widget.repository.findExactLinkedRecord(
      _destination,
      _linkController.text,
    );

    setState(() {
      _showLinkSuggestions = query.isNotEmpty;
      _selectedLinkedRecord = exact;
    });
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

  String get _colorsLabel {
    if (_selectedColors.isEmpty) {
      return 'No color';
    }
    return _selectedColors.map((color) => color.name).join(', ');
  }

  Future<void> _pickMold(Mold mold) async {
    _programmaticMoldText = true;
    _moldController.text = mold.name;
    _programmaticMoldText = false;
    setState(() {
      _selectedMold = mold;
      _showMoldSuggestions = false;
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
      _programmaticColorText = true;
      _colorController.clear();
      _programmaticColorText = false;
      setState(() => _showColorSuggestions = false);
      return;
    }

    _programmaticColorText = true;
    _colorController.clear();
    _programmaticColorText = false;
    setState(() {
      _selectedColors = List<StudioColor>.from(_selectedColors)..add(color);
      _showColorSuggestions = false;
    });
  }

  void _selectNoColor() {
    _programmaticColorText = true;
    _colorController.clear();
    _programmaticColorText = false;
    setState(() {
      _selectedColors = <StudioColor>[];
      _showColorSuggestions = false;
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
    final hasFailureReason =
        !_failed || _failureReasonController.text.trim().isNotEmpty;

    return hasMold &&
        hasFailureReason &&
        _price != null &&
        _price! >= 0 &&
        _quantity > 0;
  }

  Future<void> _submit() async {
    if (!_canSubmit) {
      return;
    }

    if (!widget.isEditing &&
        _destination == PieceDestination.order &&
        _selectedLinkedRecord == null &&
        _linkController.text.trim().isEmpty) {
      final confirmed = await _confirmOrderlessPiece();
      if (confirmed != true) {
        return;
      }
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
      final batchPieces = widget.batchPieces;
      final identityChanged = _isIdentityChange;

      if (batchPieces != null) {
        if (_quantity != batchPieces.length) {
          final created = await _createPiecesFromEditedAttributes(
            mold: resolvedMold,
            quantity: _quantity,
            price: price,
            linkedRecord: linkedRecord,
            source: batchPieces.length == 1 ? batchPieces.first : null,
          );
          if (!mounted) {
            return;
          }
          await _popEditor(
            PieceEditResult(piece: created.first, identityChanged: true),
          );
          return;
        }

        final saved = await widget.repository.updatePieces([
          for (final item in batchPieces)
            item.copyWith(
              mold: resolvedMold,
              stage: _stage,
              colors: List<StudioColor>.unmodifiable(_selectedColors),
              price: price,
              destination: _destination,
              linkedRecord: linkedRecord,
              failureRecord: _failureRecordFor(item),
              commercialState: _commercialState,
            ),
        ]);
        if (!mounted) {
          return;
        }
        await _popEditor(
          PieceEditResult(piece: saved.first, identityChanged: identityChanged),
        );
        return;
      }

      if (_quantity != 1) {
        final created = await _createPiecesFromEditedAttributes(
          mold: resolvedMold,
          quantity: _quantity,
          price: price,
          linkedRecord: linkedRecord,
          source: piece,
        );
        if (!mounted) {
          return;
        }
        await _popEditor(
          PieceEditResult(piece: created.first, identityChanged: true),
        );
        return;
      }

      final updated = piece.copyWith(
        mold: resolvedMold,
        stage: _stage,
        colors: List<StudioColor>.unmodifiable(_selectedColors),
        price: price,
        destination: _destination,
        linkedRecord: linkedRecord,
        failureRecord: _failureRecordFor(piece),
        commercialState: _commercialState,
      );

      final saved = await widget.repository.updatePiece(updated);
      if (!mounted) {
        return;
      }
      await _popEditor(
        PieceEditResult(piece: saved, identityChanged: identityChanged),
      );
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
      createdBy: widget.currentUser,
    );
    if (!mounted) {
      return;
    }
    await _popEditor(created);
  }

  Future<List<Piece>> _createPiecesFromEditedAttributes({
    required Mold mold,
    required int quantity,
    required double price,
    required LinkedRecord? linkedRecord,
    required Piece? source,
  }) async {
    final created = await widget.repository.createPieces(
      mold: mold,
      quantity: quantity,
      colors: List<StudioColor>.unmodifiable(_selectedColors),
      price: price,
      destination: _destination,
      commercialState: _commercialState,
      linkedRecord: linkedRecord,
      createdBy: _createdByFor(source),
    );

    if (_stage == PieceStage.toFire && !_failed) {
      return created;
    }

    return widget.repository.updatePieces([
      for (final piece in created)
        piece.copyWith(
          stage: _stage,
          failureRecord: _failureRecordFor(null),
          commercialState: _commercialState,
        ),
    ]);
  }

  StudioUser? _createdByFor(Piece? source) {
    if (widget.currentUser != null) {
      return widget.currentUser;
    }

    if (source?.createdByUserId == null) {
      return null;
    }

    return StudioUser(
      id: source!.createdByUserId!,
      name: source.createdByUserName ?? 'Unknown',
    );
  }

  FailureRecord? _failureRecordFor(Piece? piece) {
    if (!_failed) {
      return null;
    }

    return FailureRecord(
      reason: _failureReasonController.text.trim(),
      notes: _failureNotesController.text.trim().isEmpty
          ? null
          : _failureNotesController.text.trim(),
      recordedAt: piece?.failureRecord?.recordedAt ?? DateTime.now(),
    );
  }

  Future<bool?> _confirmOrderlessPiece() {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('No order selected'),
          content: const Text('This piece is not linked to any order.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              key: const Key('confirm-orderless-piece-button'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Create anyway'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDelete() async {
    final piece = widget.piece;
    final batchPieces = widget.batchPieces;
    if (piece == null) {
      return;
    }

    final deleteCount = batchPieces?.length ?? 1;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(deleteCount == 1 ? 'Delete piece' : 'Delete pieces'),
          content: Text(
            deleteCount == 1
                ? 'Delete ${piece.id}? This cannot be undone.'
                : 'Delete $deleteCount pieces? This cannot be undone.',
          ),
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

    if (batchPieces == null) {
      await widget.repository.deletePiece(piece.id);
    } else {
      await widget.repository.deletePieces(
        batchPieces.map((item) => item.id).toList(growable: false),
      );
    }
    if (!mounted) {
      return;
    }

    await _popEditor(const PieceEditResult(deleted: true));
  }

  Future<void> _openSearchPiece(Piece piece) async {
    if (!await _confirmLeaveIfNeeded() || !mounted) {
      return;
    }

    _headerSearchController.clear();
    setState(() {});
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) {
          return PieceDetailScreen(
            repository: widget.repository,
            piece: piece,
            currentUser: _activeUser,
          );
        },
      ),
    );
  }

  Future<void> _openNewPiece() async {
    if (!await _confirmLeaveIfNeeded() || !mounted) {
      return;
    }

    _headerSearchController.clear();
    setState(() {});
    await Navigator.of(context).push<List<Piece>>(
      MaterialPageRoute(
        builder: (context) {
          return PieceEditorScreen.create(
            repository: widget.repository,
            currentUser: _activeUser,
          );
        },
      ),
    );
  }

  Future<void> _openUserPage() async {
    if (!await _confirmLeaveIfNeeded() || !mounted) {
      return;
    }

    _headerSearchController.clear();
    setState(() {});
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) {
          return UserPage(
            repository: widget.repository,
            currentUser: _activeUser,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final piece = widget.piece;
    final screenName = widget.batchPieces == null
        ? widget.isEditing
              ? '${_selectedMold?.name ?? piece!.mold.name} - $_colorsLabel'
              : 'New piece'
        : 'Edit ${widget.batchPieces!.length} pieces';

    return PopScope<Object?>(
      canPop: _allowExit || !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }
        _handleBlockedPop();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              AppHeader(
                screenName: screenName,
                searchController: _headerSearchController,
                onSearchChanged: (_) => setState(() {}),
                onBack: _maybePop,
                onUserTap: _openUserPage,
              ),
              GlobalPieceSearchResults(
                repository: widget.repository,
                searchController: _headerSearchController,
                onOpenPiece: _openSearchPiece,
                onCreatePiece: _openNewPiece,
              ),
              Expanded(
                child: widget.isEditing
                    ? _buildEditBody(context, piece!)
                    : _buildCreateBody(context),
              ),
              _EditorActionBar(
                isEditing: widget.isEditing,
                isIdentityChange: _isIdentityChange,
                canSubmit: _canSubmit,
                onDelete: widget.isEditing ? _confirmDelete : null,
                onSubmit: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreateBody(BuildContext context) {
    final moldQuery = _moldController.text.trim();
    final colorQuery = _colorController.text.trim();
    final moldSuggestions = !_showMoldSuggestions || moldQuery.isEmpty
        ? const <Mold>[]
        : widget.repository.suggestMolds(moldQuery);
    final colorSuggestions = !_showColorSuggestions || colorQuery.isEmpty
        ? const <StudioColor>[]
        : widget.repository.suggestColors(colorQuery);

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        AppSection(
          title: 'Mold',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MoldInput(
                controller: _moldController,
                suggestions: moldSuggestions,
                query: moldQuery,
                selectedMold: _selectedMold,
                onPick: _pickMold,
                onCreate: () => _createInlineMold(moldQuery),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('quantity-input'),
                controller: _quantityController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Quantity'),
              ),
              if (widget.isEditing) ...[
                const SizedBox(height: 12),
                Text(
                  'Changing quantity creates new piece IDs.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ],
          ),
        ),
        AppSection(
          title: 'Colors',
          child: _ColorEditor(
            selectedColors: _selectedColors,
            colorController: _colorController,
            suggestions: colorSuggestions,
            query: colorQuery,
            repository: widget.repository,
            onCommit: _commitColorQuery,
            onRemove: _removeColor,
            onNoColor: _selectNoColor,
          ),
        ),
        AppSection(
          title: 'Destination + price',
          child: _CommerceEditor(
            destination: _destination,
            linkedRecord: _selectedLinkedRecord,
            linkController: _linkController,
            showLinkSuggestions: _showLinkSuggestions,
            priceController: _priceController,
            repository: widget.repository,
            onDestinationSelected: _selectDestination,
            onLinkedRecordSelected: _selectLinkedRecord,
            onCreateLinkedRecord: _createInlineLinkedRecord,
            onClearLinkedRecord: _clearLinkedRecord,
          ),
        ),
      ],
    );
  }

  Widget _buildEditBody(BuildContext context, Piece piece) {
    final theme = Theme.of(context);

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        if (widget.batchPieces == null)
          AppSection(
            title: 'Identity',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Piece ID', style: theme.textTheme.labelMedium),
                const SizedBox(height: 4),
                Text(piece.id, style: theme.textTheme.bodyLarge),
                const SizedBox(height: 12),
                Text('Created', style: theme.textTheme.labelMedium),
                const SizedBox(height: 4),
                Text(
                  _formatTimestamp(context, piece.createdAt),
                  style: AppTypography.dateText,
                ),
                const SizedBox(height: 12),
                Text('Updated', style: theme.textTheme.labelMedium),
                const SizedBox(height: 4),
                Text(
                  _formatTimestamp(context, piece.updatedAt),
                  style: AppTypography.dateText,
                ),
              ],
            ),
          )
        else
          AppSection(
            title: 'Selection',
            child: Text(
              '${widget.batchPieces!.length} pieces selected',
              style: theme.textTheme.bodyLarge,
            ),
          ),
        AppSection(
          title: 'Quantity',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                key: const Key('edit-quantity-input'),
                controller: _quantityController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Quantity'),
              ),
              const SizedBox(height: 8),
              Text(
                'Changing quantity creates new piece IDs.',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        _EditableField(
          title: 'Mold',
          value: _selectedMold?.name ?? _moldController.text,
          isEditing: _editingMold,
          onEdit: () => setState(() => _editingMold = !_editingMold),
          editor: _buildMoldEditControls(),
        ),
        _EditableField(
          title: 'Color',
          value: _colorsLabel,
          isEditing: _editingColors,
          onEdit: () => setState(() => _editingColors = !_editingColors),
          editor: _buildColorEditControls(),
        ),
        _EditableField(
          title: 'Price / Destination',
          value: _commerceSummary,
          isEditing: _editingCommerce,
          onEdit: () => setState(() => _editingCommerce = !_editingCommerce),
          editor: _CommerceEditor(
            destination: _destination,
            linkedRecord: _selectedLinkedRecord,
            linkController: _linkController,
            showLinkSuggestions: _showLinkSuggestions,
            priceController: _priceController,
            repository: widget.repository,
            onDestinationSelected: _selectDestination,
            onLinkedRecordSelected: _selectLinkedRecord,
            onCreateLinkedRecord: _createInlineLinkedRecord,
            onClearLinkedRecord: _clearLinkedRecord,
          ),
        ),
        _EditableField(
          title: 'State',
          value: _stateSummary,
          isEditing: _editingState,
          onEdit: () => setState(() => _editingState = !_editingState),
          editor: _buildStateEditControls(context),
        ),
        if (_isIdentityChange)
          AppSection(
            child: Text(
              'Changing mold or colors creates a new piece ID.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
      ],
    );
  }

  Widget _buildMoldEditControls() {
    final moldQuery = _moldController.text.trim();
    final moldSuggestions = !_showMoldSuggestions || moldQuery.isEmpty
        ? const <Mold>[]
        : widget.repository.suggestMolds(moldQuery);

    return _MoldInput(
      controller: _moldController,
      suggestions: moldSuggestions,
      query: moldQuery,
      selectedMold: _selectedMold,
      onPick: _pickMold,
      onCreate: () => _createInlineMold(moldQuery),
    );
  }

  Widget _buildColorEditControls() {
    final colorQuery = _colorController.text.trim();
    final colorSuggestions = !_showColorSuggestions || colorQuery.isEmpty
        ? const <StudioColor>[]
        : widget.repository.suggestColors(colorQuery);

    return _ColorEditor(
      selectedColors: _selectedColors,
      colorController: _colorController,
      suggestions: colorSuggestions,
      query: colorQuery,
      repository: widget.repository,
      onCommit: _commitColorQuery,
      onRemove: _removeColor,
      onNoColor: _selectNoColor,
    );
  }

  Widget _buildStateEditControls(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ChoiceRow<PieceStage>(
          groupKey: 'stage',
          value: _stage,
          options: PieceStage.values,
          labelOf: (item) => item.label,
          onSelected: (stage) => setState(() => _stage = stage),
        ),
        const SizedBox(height: 12),
        _ChoiceRow<CommercialState>(
          groupKey: 'commercial',
          value: _commercialState,
          options: CommercialState.values,
          labelOf: (item) => item.label,
          onSelected: (value) => setState(() => _commercialState = value),
        ),
        const SizedBox(height: 12),
        _FilterChip(
          key: const Key('failed-piece-filter'),
          label: 'Failed',
          selected: _failed,
          onTap: () => setState(() => _failed = !_failed),
        ),
        if (_failed) ...[
          const SizedBox(height: 12),
          TextField(
            key: const Key('failure-reason-input'),
            controller: _failureReasonController,
            decoration: const InputDecoration(labelText: 'Failure reason'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _failureNotesController,
            minLines: 2,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Failure notes'),
          ),
        ],
        if (!_failed) ...[
          const SizedBox(height: 8),
          Text('No failure recorded.', style: theme.textTheme.bodyMedium),
        ],
      ],
    );
  }

  String get _commerceSummary {
    final linked = _selectedLinkedRecord == null
        ? ''
        : ' - ${_selectedLinkedRecord!.label}';
    return '${_destination.label}$linked - ${formatPriceEuro(_price ?? 0)}';
  }

  String get _stateSummary {
    final failed = _failed ? ' - Failed' : '';
    return '${_stage.label} - ${_commercialState.label}$failed';
  }

  Future<void> _createInlineMold(String query) async {
    if (query.isEmpty) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('You are being redirected to create a new mold.'),
      ),
    );

    final created = await Navigator.of(context).push<Mold>(
      MaterialPageRoute(
        builder: (context) => MoldEditorScreen(
          repository: widget.repository,
          currentUser: _activeUser,
          initialName: query,
          initialPrice: _price ?? 0,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    if (created == null) {
      return;
    }

    final returnToPiece = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Mold created successfully'),
          content: const Text('Return to create a piece from this mold?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No'),
            ),
            TextButton(
              key: const Key('return-with-created-mold-button'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );

    if (!mounted) {
      return;
    }

    if (returnToPiece == true) {
      await _pickMold(created);
    } else {
      await _popEditor(null);
    }
  }

  void _removeColor(StudioColor color) {
    setState(() {
      _selectedColors = _selectedColors
          .where((item) => item.id != color.id)
          .toList(growable: false);
    });
  }

  void _selectDestination(PieceDestination destination) {
    _programmaticLinkText = true;
    _linkController.clear();
    _programmaticLinkText = false;
    setState(() {
      final destinationChanged = _destination != destination;
      _destination = destination;
      if (destination == PieceDestination.stock || destinationChanged) {
        _selectedLinkedRecord = null;
        _showLinkSuggestions = false;
      }
      _commercialState = defaultCommercialStateForDestination(destination);
    });
  }

  void _clearLinkedRecord() {
    _programmaticLinkText = true;
    _linkController.clear();
    _programmaticLinkText = false;
    setState(() {
      _selectedLinkedRecord = null;
      _showLinkSuggestions = false;
    });
  }

  void _selectLinkedRecord(LinkedRecord record) {
    _programmaticLinkText = true;
    _linkController.text = record.label;
    _programmaticLinkText = false;
    setState(() {
      _selectedLinkedRecord = record;
      _showLinkSuggestions = false;
    });
  }

  Future<void> _createInlineLinkedRecord(String query) async {
    if (query.isEmpty) {
      return;
    }

    final created = await widget.repository.createLinkedRecord(
      destination: _destination,
      label: query,
    );
    if (!mounted) {
      return;
    }
    _selectLinkedRecord(created);
  }

  String _formatTimestamp(BuildContext context, DateTime value) {
    final localizations = MaterialLocalizations.of(context);
    return '${localizations.formatMediumDate(value)} ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(value))}';
  }
}

class _MoldInput extends StatelessWidget {
  const _MoldInput({
    required this.controller,
    required this.suggestions,
    required this.query,
    required this.selectedMold,
    required this.onPick,
    required this.onCreate,
  });

  final TextEditingController controller;
  final List<Mold> suggestions;
  final String query;
  final Mold? selectedMold;
  final ValueChanged<Mold> onPick;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const Key('mold-input'),
          controller: controller,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Mold',
            hintText: 'Type mold name',
          ),
        ),
        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: 10),
          for (final mold in suggestions)
            _SuggestionRow(
              key: Key('mold-suggestion-${mold.name}'),
              label: mold.name,
              onTap: () => onPick(mold),
            ),
        ],
        if (query.isNotEmpty && selectedMold == null)
          _SuggestionRow(
            key: const Key('create-inline-mold'),
            label: 'Create mold "$query"',
            onTap: onCreate,
          ),
      ],
    );
  }
}

class _ColorEditor extends StatelessWidget {
  const _ColorEditor({
    required this.selectedColors,
    required this.colorController,
    required this.suggestions,
    required this.query,
    required this.repository,
    required this.onCommit,
    required this.onRemove,
    required this.onNoColor,
  });

  final List<StudioColor> selectedColors;
  final TextEditingController colorController;
  final List<StudioColor> suggestions;
  final String query;
  final StudioRepository repository;
  final Future<void> Function([String? value]) onCommit;
  final ValueChanged<StudioColor> onRemove;
  final VoidCallback onNoColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (selectedColors.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final color in selectedColors)
                _TagChip(label: color.name, onRemove: () => onRemove(color)),
            ],
          ),
          const SizedBox(height: 12),
        ],
        InkWell(
          key: const Key('no-color-option'),
          onTap: onNoColor,
          borderRadius: BorderRadius.circular(AppRadii.button),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Checkbox(
                  value: selectedColors.isEmpty && query.isEmpty,
                  onChanged: (_) => onNoColor(),
                  activeColor: AppColors.primaryAccent,
                  checkColor: AppColors.textPrimary,
                ),
                const SizedBox(width: 2),
                Text('No color', style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('color-input'),
          controller: colorController,
          textInputAction: TextInputAction.done,
          onSubmitted: onCommit,
          decoration: const InputDecoration(
            labelText: 'Color',
            hintText: 'Type color',
          ),
        ),
        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: 10),
          for (final color in suggestions)
            _SuggestionRow(
              key: Key('color-suggestion-${color.name}'),
              label: color.name,
              onTap: () => onCommit(color.name),
            ),
        ],
        if (query.isNotEmpty && repository.findExactColor(query) == null)
          _SuggestionRow(
            key: const Key('create-inline-color'),
            label: 'Create color "$query"',
            onTap: onCommit,
          ),
      ],
    );
  }
}

class _CommerceEditor extends StatelessWidget {
  const _CommerceEditor({
    required this.destination,
    required this.linkedRecord,
    required this.linkController,
    required this.showLinkSuggestions,
    required this.priceController,
    required this.repository,
    required this.onDestinationSelected,
    required this.onLinkedRecordSelected,
    required this.onCreateLinkedRecord,
    required this.onClearLinkedRecord,
  });

  final PieceDestination destination;
  final LinkedRecord? linkedRecord;
  final TextEditingController linkController;
  final bool showLinkSuggestions;
  final TextEditingController priceController;
  final StudioRepository repository;
  final ValueChanged<PieceDestination> onDestinationSelected;
  final ValueChanged<LinkedRecord> onLinkedRecordSelected;
  final Future<void> Function(String query) onCreateLinkedRecord;
  final VoidCallback onClearLinkedRecord;

  @override
  Widget build(BuildContext context) {
    final linkQuery = linkController.text.trim();
    final linkSuggestions =
        !showLinkSuggestions || destination == PieceDestination.stock
        ? const <LinkedRecord>[]
        : linkQuery.isEmpty
        ? const <LinkedRecord>[]
        : repository.suggestLinkedRecords(destination, linkController.text);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ChoiceRow<PieceDestination>(
          groupKey: 'destination',
          value: destination,
          options: PieceDestination.values,
          labelOf: (item) => item.label,
          onSelected: onDestinationSelected,
        ),
        if (destination != PieceDestination.stock) ...[
          const SizedBox(height: 12),
          if (linkedRecord != null)
            _LinkedRecordSummary(
              key: const Key('selected-linked-record-summary'),
              title: destination == PieceDestination.order
                  ? 'Order'
                  : 'Workshop',
              label: linkedRecord!.label,
              onChange: onClearLinkedRecord,
            )
          else ...[
            TextField(
              key: const Key('linked-record-input'),
              controller: linkController,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: destination == PieceDestination.order
                    ? 'Order'
                    : 'Workshop',
                hintText: destination == PieceDestination.order
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
                  onTap: () => onLinkedRecordSelected(record),
                ),
            ],
            if (linkQuery.isNotEmpty && linkedRecord == null)
              _SuggestionRow(
                key: const Key('create-inline-link'),
                label: destination == PieceDestination.order
                    ? 'Create order "$linkQuery"'
                    : 'Create workshop "$linkQuery"',
                onTap: () => onCreateLinkedRecord(linkQuery),
              ),
          ],
        ],
        const SizedBox(height: 12),
        TextField(
          key: const Key('price-input'),
          controller: priceController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9\.,]')),
          ],
          decoration: const InputDecoration(labelText: 'Price'),
        ),
      ],
    );
  }
}

class _EditableField extends StatelessWidget {
  const _EditableField({
    required this.title,
    required this.value,
    required this.isEditing,
    required this.onEdit,
    required this.editor,
  });

  final String title;
  final String value;
  final bool isEditing;
  final VoidCallback onEdit;
  final Widget editor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppSection(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(value, style: theme.textTheme.bodyLarge)),
              IconButton(
                key: Key('edit-${title.toLowerCase().replaceAll(' ', '-')}'),
                onPressed: onEdit,
                icon: const Icon(
                  Icons.edit,
                  color: AppColors.iconColor,
                  size: 18,
                ),
              ),
            ],
          ),
          if (isEditing) ...[const SizedBox(height: 12), editor],
        ],
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
        borderRadius: BorderRadius.circular(AppRadii.card),
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

class _EditorActionBar extends StatelessWidget {
  const _EditorActionBar({
    required this.isEditing,
    required this.isIdentityChange,
    required this.canSubmit,
    required this.onSubmit,
    this.onDelete,
  });

  final bool isEditing;
  final bool isIdentityChange;
  final bool canSubmit;
  final VoidCallback onSubmit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.shellBackground,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Row(
        children: [
          if (onDelete != null) ...[
            Expanded(
              child: TextButton(
                key: const Key('delete-piece-button'),
                onPressed: onDelete,
                child: const Text('Delete'),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            flex: onDelete == null ? 1 : 2,
            child: FilledButton(
              key: const Key('save-piece-button'),
              onPressed: canSubmit ? onSubmit : null,
              child: Text(
                isEditing && isIdentityChange
                    ? 'Save as new piece'
                    : isEditing
                    ? 'Save piece'
                    : 'Create',
              ),
            ),
          ),
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
      borderRadius: BorderRadius.circular(AppRadii.button),
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
        borderRadius: BorderRadius.circular(AppRadii.button),
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
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options)
          _FilterChip(
            key: Key('$groupKey-${labelOf(option)}'),
            label: labelOf(option),
            selected: option == value,
            onTap: () => onSelected(option),
          ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.button),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryAccent : AppColors.appBackground,
          border: Border.all(color: AppColors.textPrimary),
          borderRadius: BorderRadius.circular(AppRadii.button),
        ),
        child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
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
