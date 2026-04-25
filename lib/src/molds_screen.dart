import 'package:flutter/material.dart';

import 'design_system.dart';
import 'global_piece_search.dart';
import 'models.dart';
import 'mold_editor_screen.dart';
import 'piece_detail_screen.dart';
import 'piece_editor_screen.dart';
import 'studio_repository.dart';
import 'user_page.dart';

class MoldsScreen extends StatefulWidget {
  const MoldsScreen({
    required this.repository,
    required this.currentUser,
    super.key,
  });

  final StudioRepository repository;
  final StudioUser currentUser;

  @override
  State<MoldsScreen> createState() => _MoldsScreenState();
}

class _MoldsScreenState extends State<MoldsScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController()..addListener(_handleChange);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_handleChange)
      ..dispose();
    super.dispose();
  }

  void _handleChange() {
    setState(() {});
  }

  Future<void> _editMold(Mold mold) async {
    await Navigator.of(context).push<Mold>(
      MaterialPageRoute(
        builder: (context) => MoldEditorScreen.edit(
          repository: widget.repository,
          mold: mold,
          currentUser: widget.currentUser,
        ),
      ),
    );
  }

  Future<void> _createMold() async {
    _searchController.clear();
    setState(() {});
    await Navigator.of(context).push<Mold>(
      MaterialPageRoute(
        builder: (context) => MoldEditorScreen(
          repository: widget.repository,
          currentUser: widget.currentUser,
        ),
      ),
    );
  }

  Future<void> _openUserPage() async {
    _searchController.clear();
    setState(() {});
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) {
          return UserPage(
            repository: widget.repository,
            currentUser: widget.currentUser,
          );
        },
      ),
    );
  }

  Future<void> _openSearchPiece(Piece piece) async {
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

  Future<void> _deleteMold(Mold mold) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete mold'),
          content: Text('Delete ${mold.name}? Existing pieces keep history.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              key: const Key('confirm-delete-mold-button'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await widget.repository.deleteMold(mold.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              screenName: 'Molds',
              searchController: _searchController,
              onSearchChanged: (_) => setState(() {}),
              onBack: () => Navigator.of(context).maybePop(),
              onUserTap: _openUserPage,
            ),
            GlobalPieceSearchResults(
              repository: widget.repository,
              searchController: _searchController,
              onOpenPiece: _openSearchPiece,
              onCreatePiece: _openNewPiece,
            ),
            Expanded(
              child: MoldsSection(
                repository: widget.repository,
                searchQuery: _searchController.text,
                onCreateMold: _createMold,
                onEditMold: _editMold,
                onDeleteMold: _deleteMold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MoldsSection extends StatelessWidget {
  const MoldsSection({
    required this.repository,
    required this.searchQuery,
    required this.onCreateMold,
    required this.onEditMold,
    required this.onDeleteMold,
    super.key,
  });

  final StudioRepository repository;
  final String searchQuery;
  final VoidCallback onCreateMold;
  final ValueChanged<Mold> onEditMold;
  final ValueChanged<Mold> onDeleteMold;

  @override
  Widget build(BuildContext context) {
    final query = searchQuery.trim().toLowerCase();

    return AnimatedBuilder(
      animation: repository,
      builder: (context, _) {
        final molds = repository.allMolds().where((mold) {
          if (query.isEmpty) {
            return true;
          }
          final searchText = <String>[
            mold.name,
            mold.description ?? '',
            mold.size?.label ?? '',
          ].join(' ').toLowerCase();
          return searchText.contains(query);
        }).toList();

        return ListView(
          padding: EdgeInsets.zero,
          children: [
            AppSection(
              child: Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: AppResponsive.isDesktop(context)
                      ? 220
                      : double.infinity,
                  child: FilledButton(
                    key: const Key('create-mold-button'),
                    onPressed: onCreateMold,
                    child: const Text('Create mold'),
                  ),
                ),
              ),
            ),
            AppSection(
              child: molds.isEmpty
                  ? Text(
                      'No molds found',
                      style: Theme.of(context).textTheme.bodyLarge,
                    )
                  : AppResponsiveGrid(
                      minItemWidth: 320,
                      maxColumns: 3,
                      children: [
                        for (final mold in molds)
                          _MoldCard(
                            mold: mold,
                            onEdit: () => onEditMold(mold),
                            onDelete: () => onDeleteMold(mold),
                          ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _MoldCard extends StatelessWidget {
  const _MoldCard({
    required this.mold,
    required this.onEdit,
    required this.onDelete,
  });

  final Mold mold;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: Key('mold-card-${mold.id}'),
      margin: EdgeInsets.zero,
      onTap: onEdit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(mold.name, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.related),
          Text(
            [
              mold.size?.label,
              formatPriceEuro(mold.defaultPrice),
              mold.imageReference?.fileName,
            ].whereType<String>().join(' - '),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (mold.description != null) ...[
            const SizedBox(height: 4),
            Text(
              mold.description!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: AppSpacing.related),
          Row(
            children: [
              TextButton(
                key: Key('edit-mold-${mold.id}'),
                onPressed: onEdit,
                child: const Text('Edit'),
              ),
              const SizedBox(width: AppSpacing.related),
              TextButton(
                key: Key('delete-mold-${mold.id}'),
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
