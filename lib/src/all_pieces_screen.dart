import 'package:flutter/material.dart';

import 'design_system.dart';
import 'models.dart';
import 'piece_detail_screen.dart';
import 'piece_editor_screen.dart';
import 'studio_repository.dart';

class AllPiecesScreen extends StatefulWidget {
  const AllPiecesScreen({
    required this.repository,
    required this.searchQuery,
    required this.stageFilter,
    required this.destinationFilter,
    required this.currentUser,
    required this.onFiltersChanged,
    required this.onClearFilters,
    super.key,
  });

  final StudioRepository repository;
  final String searchQuery;
  final PieceStage? stageFilter;
  final PieceDestination? destinationFilter;
  final StudioUser currentUser;
  final void Function({PieceStage? stage, PieceDestination? destination})
  onFiltersChanged;
  final VoidCallback onClearFilters;

  @override
  State<AllPiecesScreen> createState() => _AllPiecesScreenState();
}

class _AllPiecesScreenState extends State<AllPiecesScreen> {
  final Set<String> _expandedGroupKeys = <String>{};
  bool _failedOnly = false;

  Future<void> _openPiece(Piece piece) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) {
          return PieceDetailScreen(
            repository: widget.repository,
            piece: piece,
            currentUser: widget.currentUser,
          );
        },
      ),
    );
  }

  void _toggleGroup(_PieceGroup group) {
    setState(() {
      if (_expandedGroupKeys.contains(group.key)) {
        _expandedGroupKeys.remove(group.key);
      } else {
        _expandedGroupKeys.add(group.key);
      }
    });
  }

  Future<void> _editPiece(Piece piece) async {
    await Navigator.of(context).push<PieceEditResult>(
      MaterialPageRoute(
        builder: (context) => PieceEditorScreen.edit(
          repository: widget.repository,
          piece: piece,
          currentUser: widget.currentUser,
        ),
      ),
    );
  }

  Future<void> _editGroup(_PieceGroup group) async {
    await Navigator.of(context).push<PieceEditResult>(
      MaterialPageRoute(
        builder: (context) => PieceEditorScreen.edit(
          repository: widget.repository,
          piece: group.pieces.first,
          currentUser: widget.currentUser,
          batchPieces: group.pieces,
        ),
      ),
    );
  }

  Future<void> _deletePieces(List<Piece> pieces) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(pieces.length == 1 ? 'Delete piece' : 'Delete pieces'),
          content: Text(
            'Delete ${pieces.length} piece(s)? This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              key: const Key('confirm-delete-pieces-button'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await widget.repository.deletePieces(
        pieces.map((piece) => piece.id).toList(growable: false),
      );
    }
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
        final groups = _buildPieceGroups(pieces);

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
                      onTap: widget.onClearFilters,
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
                    _FilterChip(
                      key: const Key('failed-only-filter'),
                      label: 'Failed',
                      selected: _failedOnly,
                      onTap: () => setState(() => _failedOnly = !_failedOnly),
                    ),
                  ],
                ),
              ),
            ),
            AppSection(
              child: groups.isEmpty
                  ? Text(
                      'No pieces found',
                      style: Theme.of(context).textTheme.bodyLarge,
                    )
                  : Column(
                      children: [
                        for (final group in groups)
                          _PieceGroupCard(
                            group: group,
                            expanded: _expandedGroupKeys.contains(group.key),
                            onTap: group.isGrouped
                                ? () => _toggleGroup(group)
                                : () => _openPiece(group.pieces.single),
                            onPieceTap: _openPiece,
                            onPieceEdit: _editPiece,
                            onPieceDelete: (piece) => _deletePieces([piece]),
                            onEditAll: () => _editGroup(group),
                            onDeleteAll: () => _deletePieces(group.pieces),
                            currentUser: widget.currentUser,
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

    if (_failedOnly && !piece.failed) {
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
      _ownerLabel(piece, widget.currentUser),
      if (piece.linkedRecord != null) piece.linkedRecord!.label,
      if (piece.failureRecord != null) piece.failureRecord!.reason,
      ...piece.colors.map((color) => color.name),
      if (piece.colors.isEmpty) 'No color',
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
      padding: const EdgeInsets.only(right: AppSpacing.related),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.button),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryAccent : null,
            borderRadius: BorderRadius.circular(AppRadii.button),
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

class _PieceGroupCard extends StatelessWidget {
  const _PieceGroupCard({
    required this.group,
    required this.expanded,
    required this.onTap,
    required this.onPieceTap,
    required this.onPieceEdit,
    required this.onPieceDelete,
    required this.onEditAll,
    required this.onDeleteAll,
    required this.currentUser,
  });

  final _PieceGroup group;
  final bool expanded;
  final VoidCallback onTap;
  final ValueChanged<Piece> onPieceTap;
  final ValueChanged<Piece> onPieceEdit;
  final ValueChanged<Piece> onPieceDelete;
  final VoidCallback onEditAll;
  final VoidCallback onDeleteAll;
  final StudioUser currentUser;

  @override
  Widget build(BuildContext context) {
    final representative = group.pieces.first;
    final theme = Theme.of(context);
    final dateLabel = MaterialLocalizations.of(
      context,
    ).formatMediumDate(group.updatedAt);

    return AppCard(
      key: group.isGrouped
          ? Key('piece-group-${group.key}')
          : Key('piece-row-${representative.id}'),
      onTap: onTap,
      semanticLabel: group.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(group.title, style: theme.textTheme.titleMedium),
              ),
              if (group.isGrouped)
                Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  color: AppColors.iconColor,
                  size: 22,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.related),
          Wrap(
            spacing: AppSpacing.related,
            runSpacing: 6,
            children: [
              _MetaPill(label: group.statusSummary, tone: _PillTone.status),
              _MetaPill(
                label: group.ownerSummary(currentUser),
                tone: _PillTone.destination,
              ),
              _MetaPill(label: group.priceSummary),
              if (group.failedCount > 0)
                _MetaPill(
                  label: 'Failed ×${group.failedCount}',
                  tone: _PillTone.failed,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.related),
          Row(
            children: [
              Expanded(
                child: Text(
                  _colorsLabel(representative),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              Text(dateLabel, style: AppTypography.dateText),
            ],
          ),
          if (!group.isGrouped) ...[
            const SizedBox(height: AppSpacing.related),
            Row(
              children: [
                TextButton(
                  key: Key('edit-piece-${representative.id}'),
                  onPressed: () => onPieceEdit(representative),
                  child: const Text('Edit'),
                ),
                const SizedBox(width: AppSpacing.related),
                TextButton(
                  key: Key('delete-piece-${representative.id}'),
                  onPressed: () => onPieceDelete(representative),
                  child: const Text('Delete'),
                ),
              ],
            ),
          ],
          if (group.isGrouped && expanded) ...[
            const SizedBox(height: AppSpacing.related),
            Row(
              children: [
                TextButton(
                  key: Key('edit-all-${group.key}'),
                  onPressed: onEditAll,
                  child: const Text('Edit all'),
                ),
                const SizedBox(width: AppSpacing.related),
                TextButton(
                  key: Key('delete-all-${group.key}'),
                  onPressed: onDeleteAll,
                  child: const Text('Delete all'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.related),
            const Divider(height: 1, color: AppColors.shellBackground),
            const SizedBox(height: AppSpacing.related),
            for (final piece in group.pieces)
              _ExpandedPieceRow(
                piece: piece,
                onTap: () => onPieceTap(piece),
                onEdit: () => onPieceEdit(piece),
                onDelete: () => onPieceDelete(piece),
              ),
          ],
        ],
      ),
    );
  }
}

class _ExpandedPieceRow extends StatelessWidget {
  const _ExpandedPieceRow({
    required this.piece,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final Piece piece;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final dateLabel = MaterialLocalizations.of(
      context,
    ).formatMediumDate(piece.updatedAt);

    return InkWell(
      key: Key('piece-row-${piece.id}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.button),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Expanded(
              child: Text(
                piece.id,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(width: AppSpacing.related),
            Text(dateLabel, style: AppTypography.dateText),
            const SizedBox(width: AppSpacing.related),
            IconButton(
              key: Key('edit-piece-${piece.id}'),
              onPressed: onEdit,
              icon: const Icon(
                Icons.edit,
                color: AppColors.iconColor,
                size: 16,
              ),
            ),
            IconButton(
              key: Key('delete-piece-${piece.id}'),
              onPressed: onDelete,
              icon: const Icon(
                Icons.delete_outline,
                color: AppColors.iconColor,
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _PillTone { neutral, status, destination, failed }

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.label, this.tone = _PillTone.neutral});

  final String label;
  final _PillTone tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: switch (tone) {
          _PillTone.status => AppColors.primaryAccent.withValues(alpha: 0.22),
          _PillTone.destination => AppColors.shellBackground.withValues(
            alpha: 0.72,
          ),
          _PillTone.failed => AppColors.iconColor.withValues(alpha: 0.18),
          _PillTone.neutral => AppColors.shellBackground.withValues(
            alpha: 0.48,
          ),
        },
        borderRadius: BorderRadius.circular(AppRadii.button),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelMedium),
    );
  }
}

class _PieceGroup {
  const _PieceGroup({required this.key, required this.pieces});

  final String key;
  final List<Piece> pieces;

  bool get isGrouped => pieces.length > 1;

  DateTime get updatedAt {
    return pieces
        .map((piece) => piece.updatedAt)
        .reduce((left, right) => left.isAfter(right) ? left : right);
  }

  String get title {
    final piece = pieces.first;
    final base = '${piece.mold.name} — ${_colorsLabel(piece)}';
    if (!isGrouped) {
      return base;
    }
    return '$base (×${pieces.length})';
  }

  int get failedCount => pieces.where((piece) => piece.failed).length;

  String get statusSummary {
    final labels = pieces.map((piece) {
      return piece.failed ? 'Failed' : piece.stage.label;
    }).toSet();
    if (labels.length == 1) {
      return labels.single;
    }
    return '${labels.length} statuses';
  }

  String ownerSummary(StudioUser currentUser) {
    final labels = pieces
        .map((piece) => _ownerLabel(piece, currentUser))
        .toSet();
    if (labels.length == 1) {
      return labels.single;
    }
    return '${labels.length} owners';
  }

  String get priceSummary {
    final prices = pieces
        .map((piece) => piece.price.toStringAsFixed(2))
        .toSet();
    if (prices.length == 1) {
      return formatPriceEuro(pieces.first.price);
    }
    return 'Mixed prices';
  }
}

List<_PieceGroup> _buildPieceGroups(List<Piece> pieces) {
  final buckets = <String, List<Piece>>{};

  for (final piece in pieces) {
    final key = _groupKey(piece);
    buckets.putIfAbsent(key, () => <Piece>[]).add(piece);
  }

  final groups = buckets.entries.map((entry) {
    final sortedPieces = entry.value.toList()
      ..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
    return _PieceGroup(key: entry.key, pieces: sortedPieces);
  }).toList();

  groups.sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
  return groups;
}

String _groupKey(Piece piece) {
  final colors = piece.colors.map((color) => color.id).join(',');
  return '${piece.mold.id}|$colors';
}

String _ownerLabel(Piece piece, StudioUser? currentUser) {
  if (piece.linkedRecord != null) {
    return piece.linkedRecord!.label;
  }

  switch (piece.destination) {
    case PieceDestination.stock:
      return piece.createdByUserName == null
          ? currentUser == null
                ? 'Stock'
                : '${currentUser.name}\'s stock'
          : '${piece.createdByUserName}\'s stock';
    case PieceDestination.order:
      return 'Client';
    case PieceDestination.workshop:
      return 'Student';
  }
}

String _colorsLabel(Piece piece) {
  if (piece.colors.isEmpty) {
    return 'No color';
  }
  return piece.colors.map((color) => color.name).join(', ');
}
