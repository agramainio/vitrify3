import 'package:flutter/material.dart';

import 'design_system.dart';
import 'models.dart';
import 'piece_editor_screen.dart';
import 'studio_repository.dart';

class AllPiecesScreen extends StatefulWidget {
  const AllPiecesScreen({
    required this.repository,
    required this.searchQuery,
    super.key,
  });

  final StudioRepository repository;
  final String searchQuery;

  @override
  State<AllPiecesScreen> createState() => _AllPiecesScreenState();
}

class _AllPiecesScreenState extends State<AllPiecesScreen> {
  late final TextEditingController _moldFilterController;
  late final TextEditingController _colorFilterController;

  PieceStage? _stageFilter;
  PieceDestination? _destinationFilter;
  bool _failedOnly = false;

  @override
  void initState() {
    super.initState();
    _moldFilterController = TextEditingController()
      ..addListener(_handleFilterChange);
    _colorFilterController = TextEditingController()
      ..addListener(_handleFilterChange);
  }

  @override
  void dispose() {
    _moldFilterController
      ..removeListener(_handleFilterChange)
      ..dispose();
    _colorFilterController
      ..removeListener(_handleFilterChange)
      ..dispose();
    super.dispose();
  }

  void _handleFilterChange() {
    setState(() {});
  }

  Future<void> _editPiece(Piece piece) async {
    await Navigator.of(context).push<PieceEditResult>(
      MaterialPageRoute(
        builder: (context) {
          return PieceEditorScreen.edit(
            repository: widget.repository,
            piece: piece,
          );
        },
      ),
    );
  }

  Future<void> _deletePiece(Piece piece) async {
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
  }

  @override
  Widget build(BuildContext context) {
    final moldQuery = _moldFilterController.text.trim();
    final colorQuery = _colorFilterController.text.trim();
    final moldSuggestions = moldQuery.isEmpty
        ? const <Mold>[]
        : widget.repository.suggestMolds(moldQuery, limit: 6);
    final colorSuggestions = colorQuery.isEmpty
        ? const <StudioColor>[]
        : widget.repository.suggestColors(colorQuery, limit: 6);

    return AnimatedBuilder(
      animation: widget.repository,
      builder: (context, _) {
        final pieces = widget.repository
            .allPieces()
            .where(_matchesFilters)
            .toList();

        return ListView(
          padding: EdgeInsets.zero,
          children: [
            AppSection(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      key: const Key('stage-filter-all'),
                      label: 'All statuses',
                      selected: _stageFilter == null,
                      onTap: () => setState(() => _stageFilter = null),
                    ),
                    for (final stage in PieceStage.values)
                      _FilterChip(
                        key: Key('stage-filter-${stage.label}'),
                        label: stage.label,
                        selected: _stageFilter == stage,
                        onTap: () => setState(() => _stageFilter = stage),
                      ),
                    _FilterGap(),
                    _FilterChip(
                      key: const Key('destination-filter-all'),
                      label: 'All destinations',
                      selected: _destinationFilter == null,
                      onTap: () => setState(() => _destinationFilter = null),
                    ),
                    for (final destination in PieceDestination.values)
                      _FilterChip(
                        key: Key('destination-filter-${destination.label}'),
                        label: destination.label,
                        selected: _destinationFilter == destination,
                        onTap: () {
                          setState(() => _destinationFilter = destination);
                        },
                      ),
                    _FilterGap(),
                    _FilterChip(
                      key: const Key('failed-only-filter'),
                      label: 'Failed only',
                      selected: _failedOnly,
                      onTap: () {
                        setState(() => _failedOnly = !_failedOnly);
                      },
                    ),
                    _FilterGap(),
                    _FilterTextField(
                      key: const Key('mold-filter-input'),
                      controller: _moldFilterController,
                      label: 'Filter by mold',
                    ),
                    _FilterGap(),
                    _FilterTextField(
                      key: const Key('color-filter-input'),
                      controller: _colorFilterController,
                      label: 'Filter by color',
                    ),
                  ],
                ),
              ),
            ),
            if (moldSuggestions.isNotEmpty)
              AppSection(
                child: Column(
                  children: [
                    for (final mold in moldSuggestions)
                      _SuggestionRow(
                        key: Key('mold-filter-suggestion-${mold.name}'),
                        label: mold.name,
                        onTap: () {
                          _moldFilterController.text = mold.name;
                        },
                      ),
                  ],
                ),
              ),
            if (colorSuggestions.isNotEmpty)
              AppSection(
                child: Column(
                  children: [
                    for (final color in colorSuggestions)
                      _SuggestionRow(
                        key: Key('color-filter-suggestion-${color.name}'),
                        label: color.name,
                        onTap: () {
                          _colorFilterController.text = color.name;
                        },
                      ),
                  ],
                ),
              ),
            AppSection(
              child: pieces.isEmpty
                  ? Text(
                      'No pieces match.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    )
                  : Column(
                      children: [
                        for (final piece in pieces)
                          _PieceRow(
                            piece: piece,
                            onEdit: () => _editPiece(piece),
                            onDelete: () => _deletePiece(piece),
                          ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  bool _matchesFilters(Piece piece) {
    final searchQuery = widget.searchQuery.trim().toLowerCase();
    final moldQuery = _moldFilterController.text.trim().toLowerCase();
    final colorQuery = _colorFilterController.text.trim().toLowerCase();

    if (_stageFilter != null && piece.stage != _stageFilter) {
      return false;
    }

    if (_destinationFilter != null && piece.destination != _destinationFilter) {
      return false;
    }

    if (_failedOnly && !piece.failed) {
      return false;
    }

    if (moldQuery.isNotEmpty &&
        !piece.mold.name.toLowerCase().contains(moldQuery)) {
      return false;
    }

    if (colorQuery.isNotEmpty &&
        !piece.colors.any(
          (color) => color.name.toLowerCase().contains(colorQuery),
        )) {
      return false;
    }

    if (searchQuery.isEmpty) {
      return true;
    }

    final searchText = <String>[
      piece.id,
      piece.mold.name,
      piece.stage.label,
      piece.destination.label,
      piece.commercialState.label,
      if (piece.linkedRecord != null) piece.linkedRecord!.label,
      if (piece.failureRecord != null) piece.failureRecord!.reason,
      ...piece.colors.map((color) => color.name),
    ].join(' ').toLowerCase();

    return searchText.contains(searchQuery);
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
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(2),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryAccent : AppColors.appBackground,
            border: Border.all(color: AppColors.textPrimary),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ),
    );
  }
}

class _FilterGap extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const SizedBox(width: 8);
  }
}

class _FilterTextField extends StatelessWidget {
  const _FilterTextField({
    required this.controller,
    required this.label,
    super.key,
  });

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      height: 42,
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
        ),
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

class _PieceRow extends StatelessWidget {
  const _PieceRow({
    required this.piece,
    required this.onEdit,
    required this.onDelete,
  });

  final Piece piece;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorsLabel = piece.colors.map((color) => color.name).join(', ');
    final linkLabel = piece.linkedRecord == null
        ? null
        : '${piece.destination.label}: ${piece.linkedRecord!.label}';
    final dateLabel = MaterialLocalizations.of(
      context,
    ).formatMediumDate(piece.updatedAt);

    return InkWell(
      key: Key('piece-row-${piece.id}'),
      onTap: onEdit,
      borderRadius: BorderRadius.circular(2),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.textPrimary)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(piece.mold.name, style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(colorsLabel, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 4),
            Text(
              '${piece.stage.label} - ${piece.destination.label} - ${formatPrice(piece.price)}',
              style: theme.textTheme.bodyMedium,
            ),
            if (linkLabel != null) ...[
              const SizedBox(height: 4),
              Text(linkLabel, style: theme.textTheme.bodyMedium),
            ],
            const SizedBox(height: 4),
            Text(dateLabel, style: AppTypography.dateText),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton(
                  key: Key('edit-piece-${piece.id}'),
                  onPressed: onEdit,
                  child: const Text('Edit'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  key: Key('delete-piece-${piece.id}'),
                  onPressed: onDelete,
                  child: const Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
