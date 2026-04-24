import 'package:flutter/material.dart';

import 'all_pieces_screen.dart';
import 'design_system.dart';
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
    });

    final result = await Navigator.of(context).push<List<Piece>>(
      MaterialPageRoute(
        builder: (context) =>
            PieceEditorScreen.create(repository: widget.repository),
      ),
    );

    if (!mounted || result == null || result.isEmpty) {
      return;
    }
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
                  onSearchChanged: (_) {
                    setState(() {});
                  },
                ),
                Expanded(child: _buildSectionBody()),
                if (_showCreateActions)
                  _CreateActionTray(onNewPiece: _openNewPiece),
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
          AppSection(child: _StateSummaryRow(repository: widget.repository)),
        ],
      );
    }

    if (_selectedSection == 1) {
      return AllPiecesScreen(
        repository: widget.repository,
        searchQuery: _globalSearchController.text,
      );
    }

    return _PlaceholderSection(index: _selectedSection);
  }
}

class _StateSummaryRow extends StatelessWidget {
  const _StateSummaryRow({required this.repository});

  final StudioRepository repository;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StateValue(
            label: PieceStage.toFire.label,
            count: repository.countPiecesByStage(PieceStage.toFire),
            valueKey: const Key('count-to-fire'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StateValue(
            label: PieceStage.toGlaze.label,
            count: repository.countPiecesByStage(PieceStage.toGlaze),
            valueKey: const Key('count-to-glaze'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StateValue(
            label: PieceStage.ready.label,
            count: repository.countPiecesByStage(PieceStage.ready),
            valueKey: const Key('count-ready'),
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
  });

  final String label;
  final int count;
  final Key valueKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.textPrimary),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelMedium),
          const SizedBox(height: 8),
          Text(
            '$count',
            key: valueKey,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: AppColors.primaryAccent,
            ),
          ),
        ],
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
      (icon: Icons.add, label: '+'),
      (icon: Icons.local_fire_department_outlined, label: 'Batches'),
      (icon: Icons.assignment_outlined, label: 'Jobs'),
    ];

    final theme = Theme.of(context);

    return Container(
      color: AppColors.shellBackground,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
      child: Row(
        children: [
          for (var index = 0; index < items.length; index++)
            Expanded(
              child: InkWell(
                key: Key(
                  index == 2
                      ? 'nav-create'
                      : 'nav-${items[index].label.toLowerCase().replaceAll(' ', '-')}',
                ),
                onTap: () => onSelected(index),
                borderRadius: BorderRadius.circular(2),
                child: Container(
                  padding: const EdgeInsets.only(top: 6, bottom: 8),
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
                        size: index == 2 ? 22 : 18,
                        color: currentIndex == index
                            ? AppColors.iconColor
                            : AppColors.textPrimary,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        items[index].label,
                        style: theme.textTheme.labelMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ),
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

class _CreateActionTray extends StatelessWidget {
  const _CreateActionTray({required this.onNewPiece});

  final VoidCallback onNewPiece;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.appBackground,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: FilledButton.icon(
        key: const Key('new-piece-button'),
        onPressed: onNewPiece,
        icon: const Icon(Icons.add, color: AppColors.iconColor),
        label: const Text('New piece'),
      ),
    );
  }
}
