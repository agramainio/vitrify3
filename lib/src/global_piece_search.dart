import 'package:flutter/material.dart';

import 'design_system.dart';
import 'models.dart';
import 'studio_repository.dart';

class GlobalPieceSearchResults extends StatelessWidget {
  const GlobalPieceSearchResults({
    required this.repository,
    required this.searchController,
    required this.onOpenPiece,
    required this.onCreatePiece,
    super.key,
  });

  final StudioRepository repository;
  final TextEditingController searchController;
  final ValueChanged<Piece> onOpenPiece;
  final VoidCallback onCreatePiece;

  @override
  Widget build(BuildContext context) {
    final query = searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return const SizedBox.shrink();
    }

    final matches = repository
        .allPieces()
        .where((piece) {
          final searchText = <String>[
            piece.id,
            piece.mold.name,
            piece.stage.label,
            piece.destination.label,
            piece.commercialState.label,
            piece.createdByUserName ?? '',
            piece.linkedRecord?.label ?? '',
            ...piece.colors.map((color) => color.name),
            if (piece.colors.isEmpty) 'No color',
            if (piece.failed) 'Failed',
          ].join(' ').toLowerCase();
          return searchText.contains(query);
        })
        .take(6)
        .toList();

    return AppSection(
      child: matches.isEmpty
          ? Row(
              children: [
                Expanded(
                  child: Text(
                    'No results',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                TextButton(
                  key: const Key('search-create-piece-button'),
                  onPressed: onCreatePiece,
                  child: const Text('Create new piece'),
                ),
              ],
            )
          : Column(
              children: [
                for (final piece in matches)
                  _GlobalSearchPieceRow(
                    piece: piece,
                    onTap: () => onOpenPiece(piece),
                  ),
              ],
            ),
    );
  }
}

class _GlobalSearchPieceRow extends StatelessWidget {
  const _GlobalSearchPieceRow({required this.piece, required this.onTap});

  final Piece piece;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = piece.colors.isEmpty
        ? 'No color'
        : piece.colors.map((color) => color.name).join(', ');

    return InkWell(
      key: Key('search-result-${piece.id}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.button),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${piece.mold.name} - $colors',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            const SizedBox(width: AppSpacing.related),
            Text(
              piece.failed ? 'Failed' : piece.stage.label,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
        ),
      ),
    );
  }
}
