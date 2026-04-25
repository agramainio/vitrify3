import 'package:flutter/material.dart';

import 'design_system.dart';
import 'models.dart';
import 'piece_detail_screen.dart';
import 'studio_repository.dart';

class AllPiecesScreen extends StatefulWidget {
  const AllPiecesScreen({
    required this.repository,
    required this.searchQuery,
    required this.stageFilter,
    required this.destinationFilter,
    required this.onFiltersChanged,
    required this.onClearFilters,
    super.key,
  });

  final StudioRepository repository;
  final String searchQuery;
  final PieceStage? stageFilter;
  final PieceDestination? destinationFilter;
  final void Function({PieceStage? stage, PieceDestination? destination})
  onFiltersChanged;
  final VoidCallback onClearFilters;

  @override
  State<AllPiecesScreen> createState() => _AllPiecesScreenState();
}

class _AllPiecesScreenState extends State<AllPiecesScreen> {
  Future<void> _openPiece(Piece piece) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) {
          return PieceDetailScreen(repository: widget.repository, piece: piece);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                      key: const Key('filter-all'),
                      label: 'All',
                      selected: _noChipFilters,
                      onTap: () {
                        widget.onClearFilters();
                      },
                    ),
                    _FilterChip(
                      key: const Key('stage-filter-To fire'),
                      label: 'To fire',
                      selected: widget.stageFilter == PieceStage.toFire,
                      onTap: () {
                        widget.onFiltersChanged(stage: PieceStage.toFire);
                      },
                    ),
                    _FilterChip(
                      key: const Key('stage-filter-To glaze'),
                      label: 'To glaze',
                      selected: widget.stageFilter == PieceStage.toGlaze,
                      onTap: () {
                        widget.onFiltersChanged(stage: PieceStage.toGlaze);
                      },
                    ),
                    _FilterChip(
                      key: const Key('stage-filter-Ready'),
                      label: 'Ready',
                      selected: widget.stageFilter == PieceStage.ready,
                      onTap: () {
                        widget.onFiltersChanged(stage: PieceStage.ready);
                      },
                    ),
                    _FilterChip(
                      key: const Key('destination-filter-Client'),
                      label: 'Client',
                      selected:
                          widget.destinationFilter == PieceDestination.order,
                      onTap: () {
                        widget.onFiltersChanged(
                          destination: PieceDestination.order,
                        );
                      },
                    ),
                    _FilterChip(
                      key: const Key('destination-filter-Student'),
                      label: 'Student',
                      selected:
                          widget.destinationFilter == PieceDestination.workshop,
                      onTap: () {
                        widget.onFiltersChanged(
                          destination: PieceDestination.workshop,
                        );
                      },
                    ),
                    _FilterChip(
                      key: const Key('destination-filter-Stock'),
                      label: 'Stock',
                      selected:
                          widget.destinationFilter == PieceDestination.stock,
                      onTap: () {
                        widget.onFiltersChanged(
                          destination: PieceDestination.stock,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            AppSection(
              child: pieces.isEmpty
                  ? Text(
                      'No pieces found',
                      style: Theme.of(context).textTheme.bodyLarge,
                    )
                  : Column(
                      children: [
                        for (final piece in pieces)
                          _PieceRow(
                            piece: piece,
                            onTap: () => _openPiece(piece),
                            onLongPress: () {},
                          ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  bool get _noChipFilters {
    return widget.stageFilter == null && widget.destinationFilter == null;
  }

  bool _matchesFilters(Piece piece) {
    final searchQuery = widget.searchQuery.trim().toLowerCase();

    if (widget.stageFilter != null && piece.stage != widget.stageFilter) {
      return false;
    }

    if (widget.destinationFilter != null &&
        piece.destination != widget.destinationFilter) {
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
      _ownerLabel(piece),
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
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(2),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryAccent : null,
            borderRadius: BorderRadius.circular(2),
          ),
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: selected ? AppColors.appBackground : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _PieceRow extends StatelessWidget {
  const _PieceRow({
    required this.piece,
    required this.onTap,
    required this.onLongPress,
  });

  final Piece piece;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateLabel = MaterialLocalizations.of(
      context,
    ).formatMediumDate(piece.updatedAt);

    return InkWell(
      key: Key('piece-row-${piece.id}'),
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(2),
      child: Container(
        height: 54,
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.textPrimary)),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: _RowText(
                piece.mold.name,
                style: theme.textTheme.bodyLarge,
              ),
            ),
            Expanded(flex: 4, child: _RowText(_ownerLabel(piece))),
            Expanded(flex: 3, child: _RowText(piece.stage.label)),
            Expanded(flex: 4, child: _RowText(_colorsLabel(piece))),
            Expanded(
              flex: 3,
              child: _RowText(dateLabel, style: AppTypography.dateText),
            ),
          ],
        ),
      ),
    );
  }
}

class _RowText extends StatelessWidget {
  const _RowText(this.value, {this.style});

  final String value;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style ?? Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

String _ownerLabel(Piece piece) {
  if (piece.linkedRecord != null) {
    return piece.linkedRecord!.label;
  }

  switch (piece.destination) {
    case PieceDestination.stock:
      return 'Stock';
    case PieceDestination.order:
      return 'Client';
    case PieceDestination.workshop:
      return 'Student';
  }
}

String _colorsLabel(Piece piece) {
  if (piece.colors.isEmpty) {
    return '-';
  }
  return piece.colors.map((color) => color.name).join(', ');
}
