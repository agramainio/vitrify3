import 'package:flutter/material.dart';

import 'all_pieces_screen.dart';
import 'design_system.dart';
import 'molds_screen.dart';
import 'mold_editor_screen.dart';
import 'models.dart';
import 'piece_detail_screen.dart';
import 'piece_editor_screen.dart';
import 'studio_repository.dart';
import 'user_history_screen.dart';
import 'user_page.dart';

class BenchScreen extends StatefulWidget {
  const BenchScreen({
    required this.repository,
    required this.currentUser,
    super.key,
  });

  final StudioRepository repository;
  final StudioUser currentUser;

  @override
  State<BenchScreen> createState() => _BenchScreenState();
}

class _BenchScreenState extends State<BenchScreen> {
  int _selectedSection = 0;
  bool _showCreateActions = false;
  PieceStage? _piecesStageFilter;
  PieceDestination? _piecesDestinationFilter;
  late final TextEditingController _globalSearchController;

  @override
  void initState() {
    super.initState();
    _globalSearchController = TextEditingController();
  }

  @override
  void dispose() {
    _globalSearchController.dispose();
    super.dispose();
  }

  Future<void> _openNewPiece() async {
    setState(() {
      _showCreateActions = false;
      _globalSearchController.clear();
    });

    await Navigator.of(context).push<List<Piece>>(
      MaterialPageRoute(
        builder: (context) => PieceEditorScreen.create(
          repository: widget.repository,
          currentUser: widget.currentUser,
        ),
      ),
    );
  }

  Future<void> _openNewMold() async {
    setState(() {
      _showCreateActions = false;
      _globalSearchController.clear();
    });

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
    setState(() {
      _showCreateActions = false;
      _globalSearchController.clear();
    });

    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => UserPage(
          repository: widget.repository,
          currentUser: widget.currentUser,
        ),
      ),
    );
  }

  Future<void> _openSearchPiece(Piece piece) async {
    setState(() {
      _showCreateActions = false;
    });

    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => PieceDetailScreen(
          repository: widget.repository,
          piece: piece,
          currentUser: widget.currentUser,
        ),
      ),
    );
  }

  void _openPiecesWithStage(PieceStage stage) {
    setState(() {
      _selectedSection = 1;
      _showCreateActions = false;
      _globalSearchController.clear();
      _piecesStageFilter = stage;
      _piecesDestinationFilter = null;
    });
  }

  void _handlePiecesFiltersChanged({
    PieceStage? stage,
    PieceDestination? destination,
  }) {
    setState(() {
      if (stage != null) {
        _piecesStageFilter = stage;
      }

      if (destination != null) {
        _piecesDestinationFilter = destination;
      }
    });
  }

  void _clearPiecesFilters() {
    setState(() {
      _piecesStageFilter = null;
      _piecesDestinationFilter = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.repository,
      builder: (context, _) {
        return Scaffold(
          floatingActionButton: _CreateFabCluster(
            expanded: _showCreateActions,
            onToggle: () {
              setState(() => _showCreateActions = !_showCreateActions);
            },
            onNewPiece: _openNewPiece,
            onNewMold: _openNewMold,
          ),
          body: SelectionArea(
            child: SafeArea(
              child: Column(
                children: [
                  AppHeader(
                    screenName: _screenName,
                    searchController: _globalSearchController,
                    onSearchChanged: (_) => setState(() {}),
                    onUserTap: _openUserPage,
                  ),
                  _buildSearchSuggestions(),
                  Expanded(child: _buildSectionBody()),
                  const _BottomBenchNavDivider(),
                  _BottomBenchNav(
                    currentIndex: _selectedSection,
                    onSelected: (index) {
                      setState(() {
                        _selectedSection = index;
                        _showCreateActions = false;
                        _globalSearchController.clear();
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String get _screenName {
    switch (_selectedSection) {
      case 0:
        return 'Bench';
      case 1:
        return 'All pieces';
      case 2:
        return 'Molds';
      case 3:
        return 'History';
      case 4:
        return 'Batches';
      case 5:
        return 'Jobs';
      default:
        return 'Bench';
    }
  }

  Widget _buildSectionBody() {
    if (_selectedSection == 0) {
      return ListView(
        padding: EdgeInsets.zero,
        children: [
          AppSection(
            child: _StateSummaryRow(
              repository: widget.repository,
              onStageSelected: _openPiecesWithStage,
            ),
          ),
        ],
      );
    }

    if (_selectedSection == 1) {
      return AllPiecesScreen(
        repository: widget.repository,
        searchQuery: _globalSearchController.text,
        stageFilter: _piecesStageFilter,
        destinationFilter: _piecesDestinationFilter,
        currentUser: widget.currentUser,
        onFiltersChanged: _handlePiecesFiltersChanged,
        onClearFilters: _clearPiecesFilters,
      );
    }

    if (_selectedSection == 2) {
      return MoldsSection(
        repository: widget.repository,
        searchQuery: _globalSearchController.text,
        onCreateMold: _openNewMold,
        onEditMold: _editMold,
        onDeleteMold: _deleteMold,
      );
    }

    if (_selectedSection == 3) {
      return UserHistorySection(
        repository: widget.repository,
        currentUser: widget.currentUser,
        searchQuery: _globalSearchController.text,
        onOpenPiece: _openSearchPiece,
      );
    }

    return _PlaceholderSection(index: _selectedSection);
  }

  Widget _buildSearchSuggestions() {
    final query = _globalSearchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return const SizedBox.shrink();
    }

    final matches = widget.repository
        .allPieces()
        .where((piece) {
          final searchText = <String>[
            piece.id,
            piece.mold.name,
            piece.stage.label,
            piece.destination.label,
            piece.createdByUserName ?? '',
            piece.linkedRecord?.label ?? '',
            ...piece.colors.map((color) => color.name),
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
                  onPressed: _openNewPiece,
                  child: const Text('Create new piece'),
                ),
              ],
            )
          : Column(
              children: [
                for (final piece in matches)
                  _SearchSuggestionRow(
                    piece: piece,
                    onTap: () => _openSearchPiece(piece),
                  ),
              ],
            ),
    );
  }

  Future<void> _editMold(Mold mold) async {
    setState(() => _showCreateActions = false);
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

  Future<void> _deleteMold(Mold mold) async {
    setState(() => _showCreateActions = false);
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
}

class _SearchSuggestionRow extends StatelessWidget {
  const _SearchSuggestionRow({required this.piece, required this.onTap});

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

class _StateSummaryRow extends StatelessWidget {
  const _StateSummaryRow({
    required this.repository,
    required this.onStageSelected,
  });

  final StudioRepository repository;
  final ValueChanged<PieceStage> onStageSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StateValue(
            label: 'To fire',
            count: repository.countPiecesByStage(PieceStage.toFire),
            valueKey: const Key('count-to-fire'),
            onTap: () => onStageSelected(PieceStage.toFire),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StateValue(
            label: 'To glaze',
            count: repository.countPiecesByStage(PieceStage.toGlaze),
            valueKey: const Key('count-to-glaze'),
            onTap: () => onStageSelected(PieceStage.toGlaze),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StateValue(
            label: 'Ready',
            count: repository.countPiecesByStage(PieceStage.ready),
            valueKey: const Key('count-ready'),
            onTap: () => onStageSelected(PieceStage.ready),
          ),
        ),
      ],
    );
  }
}

class _StateValue extends StatelessWidget {
  const _StateValue({
    required this.label,
    required this.count,
    required this.valueKey,
    required this.onTap,
  });

  final String label;
  final int count;
  final Key valueKey;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: AppCard(
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        child: Row(
          children: [
            Expanded(child: Text(label, style: theme.textTheme.labelMedium)),
            Text('$count', key: valueKey, style: AppTypography.homeNumberText),
          ],
        ),
      ),
    );
  }
}

class _BottomBenchNavDivider extends StatelessWidget {
  const _BottomBenchNavDivider();

  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: AppColors.textPrimary);
  }
}

class _BottomBenchNav extends StatelessWidget {
  const _BottomBenchNav({required this.currentIndex, required this.onSelected});

  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    const items = <({IconData icon, String label})>[
      (icon: Icons.home_outlined, label: 'Bench'),
      (icon: Icons.dehaze, label: 'Pieces'),
      (icon: Icons.category_outlined, label: 'Molds'),
      (icon: Icons.history, label: 'History'),
      (icon: Icons.local_fire_department_outlined, label: 'Batches'),
      (icon: Icons.assignment_outlined, label: 'Jobs'),
    ];

    final theme = Theme.of(context);

    return Container(
      color: AppColors.shellBackground,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
      child: AppResponsiveContent(
        maxWidth: 960,
        child: Row(
          children: [
            for (var index = 0; index < items.length; index++) ...[
              Expanded(
                child: InkWell(
                  key: Key(
                    'nav-${items[index].label.toLowerCase().replaceAll(' ', '-')}',
                  ),
                  onTap: () => onSelected(index),
                  borderRadius: BorderRadius.circular(AppRadii.button),
                  child: Container(
                    padding: const EdgeInsets.only(top: 6, bottom: 7),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: currentIndex == index
                              ? AppColors.iconColor
                              : AppColors.shellBackground,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          items[index].icon,
                          size: 23,
                          color: currentIndex == index
                              ? AppColors.iconColor
                              : AppColors.textPrimary,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          items[index].label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PlaceholderSection extends StatelessWidget {
  const _PlaceholderSection({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final label = index == 4 ? 'Batches' : 'Jobs';

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        AppSection(
          child: Text(
            'No ${label.toLowerCase()} yet.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ],
    );
  }
}

class _CreateFabCluster extends StatelessWidget {
  const _CreateFabCluster({
    required this.expanded,
    required this.onToggle,
    required this.onNewPiece,
    required this.onNewMold,
  });

  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onNewPiece;
  final VoidCallback onNewMold;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 120),
          child: expanded
              ? _CreateActionMenu(
                  key: const Key('create-action-menu'),
                  onNewPiece: onNewPiece,
                  onNewMold: onNewMold,
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(height: AppSpacing.related),
        FloatingActionButton(
          key: const Key('fab-create'),
          onPressed: onToggle,
          backgroundColor: AppColors.primaryAccent,
          foregroundColor: AppColors.textPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.button),
          ),
          child: const Icon(Icons.add, color: AppColors.iconColor),
        ),
      ],
    );
  }
}

class _CreateActionMenu extends StatelessWidget {
  const _CreateActionMenu({
    required this.onNewPiece,
    required this.onNewMold,
    super.key,
  });

  final VoidCallback onNewPiece;
  final VoidCallback onNewMold;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.appBackground,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppColors.textPrimary),
        borderRadius: BorderRadius.circular(AppRadii.modal),
      ),
      child: SizedBox(
        width: 260,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _CreateMenuRow(
              key: const Key('new-piece-button'),
              label: 'New piece',
              icon: Icons.add,
              onTap: onNewPiece,
            ),
            _CreateMenuRow(
              key: const Key('new-person-button'),
              label: 'New person',
              icon: Icons.person_add_alt_1_outlined,
              onTap: () {},
            ),
            _CreateMenuRow(
              key: const Key('new-firing-batch-button'),
              label: 'New firing batch',
              icon: Icons.local_fire_department_outlined,
              onTap: () {},
            ),
            _CreateMenuRow(
              key: const Key('new-mold-button'),
              label: 'New mold',
              icon: Icons.category_outlined,
              onTap: onNewMold,
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateMenuRow extends StatelessWidget {
  const _CreateMenuRow({
    required this.label,
    required this.icon,
    required this.onTap,
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.button),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(
          children: [
            Icon(icon, color: AppColors.iconColor, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
