import 'package:flutter/material.dart';

import 'design_system.dart';
import 'global_piece_search.dart';
import 'models.dart';
import 'piece_detail_screen.dart';
import 'piece_editor_screen.dart';
import 'studio_repository.dart';

class UserHistoryScreen extends StatefulWidget {
  const UserHistoryScreen({
    required this.repository,
    required this.currentUser,
    super.key,
  });

  final StudioRepository repository;
  final StudioUser currentUser;

  @override
  State<UserHistoryScreen> createState() => _UserHistoryScreenState();
}

class _UserHistoryScreenState extends State<UserHistoryScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openPiece(Piece piece) async {
    _searchController.clear();
    setState(() {});
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

  Future<void> _openNewPiece() async {
    _searchController.clear();
    setState(() {});
    await Navigator.of(context).push<List<Piece>>(
      MaterialPageRoute(
        builder: (context) {
          return PieceEditorScreen.create(
            repository: widget.repository,
            currentUser: widget.currentUser,
          );
        },
      ),
    );
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
              screenName: widget.currentUser.name,
              dateLabel: dateLabel,
              searchController: _searchController,
              onSearchChanged: (_) => setState(() {}),
              onBack: () => Navigator.of(context).maybePop(),
              onUserTap: () {},
            ),
            GlobalPieceSearchResults(
              repository: widget.repository,
              searchController: _searchController,
              onOpenPiece: _openPiece,
              onCreatePiece: _openNewPiece,
            ),
            Expanded(
              child: AnimatedBuilder(
                animation: widget.repository,
                builder: (context, _) {
                  final pieces = widget.repository
                      .allPieces()
                      .where(
                        (piece) =>
                            piece.createdByUserId == widget.currentUser.id,
                      )
                      .toList();

                  return ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      AppSection(
                        title: 'History',
                        child: pieces.isEmpty
                            ? Text(
                                'No pieces yet.',
                                style: Theme.of(context).textTheme.bodyLarge,
                              )
                            : Column(
                                children: [
                                  for (final piece in pieces)
                                    _UserHistoryRow(
                                      key: Key('user-history-${piece.id}'),
                                      piece: piece,
                                      onTap: () => _openPiece(piece),
                                    ),
                                ],
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserHistoryRow extends StatelessWidget {
  const _UserHistoryRow({required this.piece, required this.onTap, super.key});

  final Piece piece;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = piece.colors.isEmpty
        ? 'No color'
        : piece.colors.map((color) => color.name).join(', ');
    final details = <String>[
      piece.stage.label,
      piece.destination.label,
      if (piece.failed) 'Failed',
    ].join(' - ');
    final dateLabel = MaterialLocalizations.of(
      context,
    ).formatMediumDate(piece.updatedAt);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.button),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.shellBackground)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    piece.mold.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    colors,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 3),
                  Text(details, style: Theme.of(context).textTheme.labelMedium),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.related),
            Text(dateLabel, style: AppTypography.dateText),
          ],
        ),
      ),
    );
  }
}
