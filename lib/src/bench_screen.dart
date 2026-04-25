import 'package:flutter/material.dart';

import 'all_pieces_screen.dart';
import 'design_system.dart';
import 'mold_editor_screen.dart';
import 'models.dart';
import 'piece_editor_screen.dart';
import 'studio_repository.dart';

class BenchScreen extends StatefulWidget {
  const BenchScreen({required this.repository, super.key});

  final StudioRepository repository;

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
    setState(() => _showCreateActions = false);

    await Navigator.of(context).push<List<Piece>>(
      MaterialPageRoute(
        builder: (context) =>
            PieceEditorScreen.create(repository: widget.repository),
      ),
    );
  }

  Future<void> _openNewMold() async {
    setState(() => _showCreateActions = false);

    await Navigator.of(context).push<Mold>(
      MaterialPageRoute(
        builder: (context) => MoldEditorScreen(repository: widget.repository),
      ),
    );
  }

  void _openPiecesWithStage(PieceStage stage) {
    setState(() {
      _selectedSection = 1;
      _showCreateActions = false;
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
    final today = DateUtils.dateOnly(DateTime.now());
    final dateLabel = MaterialLocalizations.of(context).formatMediumDate(today);

    return AnimatedBuilder(
      animation: widget.repository,
      builder: (context, _) {
        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                AppHeader(
                  screenName: _screenName,
                  dateLabel: dateLabel,
                  searchController: _globalSearchController,
                  onSearchChanged: (_) => setState(() {}),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(child: _buildSectionBody()),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 12,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 120),
                          child: _showCreateActions
                              ? _CreateActionMenu(
                                  key: const Key('create-action-menu'),
                                  onNewPiece: _openNewPiece,
                                  onNewMold: _openNewMold,
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
                    ],
                  ),
                ),
                const _BottomBenchNavDivider(),
                _BottomBenchNav(
                  currentIndex: _selectedSection,
                  onSelected: (index) {
                    setState(() {
                      if (index == 2) {
                        _showCreateActions = !_showCreateActions;
                      } else {
                        _selectedSection = index;
                        _showCreateActions = false;
                      }
                    });
                  },
                ),
              ],
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
      case 3:
        return 'Batches';
      case 4:
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
        onFiltersChanged: _handlePiecesFiltersChanged,
        onClearFilters: _clearPiecesFilters,
      );
    }

    return _PlaceholderSection(index: _selectedSection);
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
      borderRadius: BorderRadius.circular(2),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.textPrimary),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Row(
          children: [
            Expanded(child: Text(label, style: theme.textTheme.labelMedium)),
            Text(
              '$count',
              key: valueKey,
              style: theme.textTheme.titleLarge?.copyWith(
                color: AppColors.primaryAccent,
              ),
            ),
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
      (icon: Icons.dehaze, label: 'All pieces'),
      (icon: Icons.add, label: ''),
      (icon: Icons.local_fire_department_outlined, label: 'Batches'),
      (icon: Icons.assignment_outlined, label: 'Jobs'),
    ];

    final theme = Theme.of(context);

    return Container(
      color: AppColors.shellBackground,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
      child: Row(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            if (index == 2)
              SizedBox(
                width: 58,
                child: IconButton(
                  key: const Key('nav-create'),
                  onPressed: () => onSelected(index),
                  icon: const Icon(
                    Icons.add,
                    color: AppColors.iconColor,
                    size: 30,
                  ),
                ),
              )
            else
              Expanded(
                child: InkWell(
                  key: Key(
                    'nav-${items[index].label.toLowerCase().replaceAll(' ', '-')}',
                  ),
                  onTap: () => onSelected(index),
                  borderRadius: BorderRadius.circular(2),
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
                          size: 25,
                          color: currentIndex == index
                              ? AppColors.iconColor
                              : AppColors.textPrimary,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          items[index].label,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontSize: 13,
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
    );
  }
}

class _PlaceholderSection extends StatelessWidget {
  const _PlaceholderSection({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final label = index == 3 ? 'Batches' : 'Jobs';

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
    return Align(
      alignment: Alignment.bottomCenter,
      child: Material(
        color: AppColors.appBackground,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: AppColors.textPrimary),
          borderRadius: BorderRadius.circular(2),
        ),
        child: SizedBox(
          width: 280,
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
