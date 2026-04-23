import 'package:flutter/material.dart';

import 'design_system.dart';
import 'models.dart';
import 'piece_detail_screen.dart';
import 'piece_editor_screen.dart';
import 'studio_repository.dart';

class AllPiecesScreen extends StatefulWidget {
  const AllPiecesScreen({required this.repository, super.key});

  final StudioRepository repository;

  @override
  State<AllPiecesScreen> createState() => _AllPiecesScreenState();
}

class _AllPiecesScreenState extends State<AllPiecesScreen> {
  late final TextEditingController _searchController;
  late final TextEditingController _moldFilterController;
  late final TextEditingController _colorFilterController;

  PieceStage? _stageFilter;
  PieceDestination? _destinationFilter;
  bool _failedOnly = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController()
      ..addListener(_handleFilterChange);
    _moldFilterController = TextEditingController()
      ..addListener(_handleFilterChange);
    _colorFilterController = TextEditingController()
      ..addListener(_handleFilterChange);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_handleFilterChange)
      ..dispose();
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

  Future<void> _openPiece(Piece piece) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) {
          return PieceDetailScreen(repository: widget.repository, piece: piece);
        },
      ),
    );
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
            Container(
              color: AppColors.shellBackground,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ALL PIECES', style: AppTypography.sectionLabel),
                  const SizedBox(height: 10),
                  Text(
                    'All pieces',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                ],
              ),
            ),
            _FlatSection(
              title: 'Search',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    key: const Key('all-pieces-search'),
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Search',
                      hintText: 'Search piece ID, mold, color, order, workshop',
                    ),
                  ),
                ],
              ),
            ),
            _FlatSection(
              title: 'Filters',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _NullableChoiceRow<PieceStage>(
                    groupKey: 'stage-filter',
                    value: _stageFilter,
                    allLabel: 'All statuses',
                    options: PieceStage.values,
                    labelOf: (item) => item.label,
                    onSelected: (value) {
                      setState(() {
                        _stageFilter = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  _NullableChoiceRow<PieceDestination>(
                    groupKey: 'destination-filter',
                    value: _destinationFilter,
                    allLabel: 'All destinations',
                    options: PieceDestination.values,
                    labelOf: (item) => item.label,
                    onSelected: (value) {
                      setState(() {
                        _destinationFilter = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    key: const Key('failed-only-toggle'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Failed only',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    activeThumbColor: AppColors.iconColor,
                    value: _failedOnly,
                    onChanged: (value) {
                      setState(() {
                        _failedOnly = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('mold-filter-input'),
                    controller: _moldFilterController,
                    decoration: const InputDecoration(
                      labelText: 'Mold filter',
                      hintText: 'Filter by mold',
                    ),
                  ),
                  if (moldSuggestions.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    for (final mold in moldSuggestions)
                      _SuggestionRow(
                        key: Key('mold-filter-suggestion-${mold.name}'),
                        label: mold.name,
                        onTap: () {
                          _moldFilterController.text = mold.name;
                        },
                      ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('color-filter-input'),
                    controller: _colorFilterController,
                    decoration: const InputDecoration(
                      labelText: 'Color filter',
                      hintText: 'Filter by color',
                    ),
                  ),
                  if (colorSuggestions.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    for (final color in colorSuggestions)
                      _SuggestionRow(
                        key: Key('color-filter-suggestion-${color.name}'),
                        label: color.name,
                        onTap: () {
                          _colorFilterController.text = color.name;
                        },
                      ),
                  ],
                ],
              ),
            ),
            _FlatSection(
              title: 'Results',
              child: pieces.isEmpty
                  ? Text(
                      'No pieces match the current filters.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    )
                  : Column(
                      children: [
                        for (final piece in pieces)
                          _PieceRow(
                            piece: piece,
                            onOpen: () => _openPiece(piece),
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
    final searchQuery = _searchController.text.trim().toLowerCase();
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

class _FlatSection extends StatelessWidget {
  const _FlatSection({required this.title, required this.child});

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

class _NullableChoiceRow<T> extends StatelessWidget {
  const _NullableChoiceRow({
    required this.groupKey,
    required this.value,
    required this.allLabel,
    required this.options,
    required this.labelOf,
    required this.onSelected,
  });

  final String groupKey;
  final T? value;
  final String allLabel;
  final List<T> options;
  final String Function(T value) labelOf;
  final ValueChanged<T?> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _FilterChoiceChip(
          key: Key('$groupKey-all'),
          label: allLabel,
          selected: value == null,
          onTap: () => onSelected(null),
          textStyle: theme.textTheme.bodyMedium,
        ),
        for (final option in options)
          _FilterChoiceChip(
            key: Key('$groupKey-${labelOf(option)}'),
            label: labelOf(option),
            selected: value == option,
            onTap: () => onSelected(option),
            textStyle: theme.textTheme.bodyMedium,
          ),
      ],
    );
  }
}

class _FilterChoiceChip extends StatelessWidget {
  const _FilterChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.textStyle,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(2),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryAccent : AppColors.appBackground,
          border: Border.all(color: AppColors.textPrimary),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Text(label, style: textStyle),
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
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  final Piece piece;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorsLabel = piece.colors.map((color) => color.name).join(', ');
    final linkLabel = piece.linkedRecord == null
        ? null
        : '${piece.destination.label}: ${piece.linkedRecord!.label}';

    return Container(
      key: Key('piece-row-${piece.id}'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.textPrimary)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(piece.id, style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            '${piece.mold.name} · $colorsLabel',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 4),
          Text(
            '${piece.stage.label} · ${piece.destination.label} · ${formatPrice(piece.price)}',
            style: theme.textTheme.bodyMedium,
          ),
          if (linkLabel != null) ...[
            const SizedBox(height: 4),
            Text(linkLabel, style: theme.textTheme.bodyMedium),
          ],
          if (piece.failureRecord != null) ...[
            const SizedBox(height: 4),
            Text(
              'Failed: ${piece.failureRecord!.reason}',
              style: theme.textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton(
                key: Key('open-piece-${piece.id}'),
                onPressed: onOpen,
                child: const Text('Open'),
              ),
              TextButton(
                key: Key('edit-piece-${piece.id}'),
                onPressed: onEdit,
                child: const Text('Edit'),
              ),
              TextButton(
                key: Key('delete-piece-${piece.id}'),
                onPressed: onDelete,
                child: const Text('Delete'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
