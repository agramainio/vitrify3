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
  String? _lastActionMessage;

  Future<void> _openNewPiece() async {
    final result = await Navigator.of(context).push<List<Piece>>(
      MaterialPageRoute(
        builder: (context) =>
            PieceEditorScreen.create(repository: widget.repository),
      ),
    );

    if (!mounted || result == null || result.isEmpty) {
      return;
    }

    setState(() {
      _lastActionMessage = result.length == 1
          ? '${result.first.id} created and sent to to_fire.'
          : '${result.length} pieces created and sent to to_fire.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateUtils.dateOnly(DateTime.now());
    final dateLabel = MaterialLocalizations.of(context).formatMediumDate(today);

    return AnimatedBuilder(
      animation: widget.repository,
      builder: (context, _) {
        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                Expanded(child: _buildSectionBody(theme, dateLabel)),
                const _BottomBenchNavDivider(),
                _BottomBenchNav(
                  currentIndex: _selectedSection,
                  onSelected: (index) {
                    setState(() {
                      _selectedSection = index;
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

  Widget _buildSectionBody(ThemeData theme, String dateLabel) {
    if (_selectedSection == 0) {
      return ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            color: AppColors.shellBackground,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('BENCH', style: AppTypography.sectionLabel),
                const SizedBox(height: 10),
                Text('Bench', style: theme.textTheme.headlineLarge),
                const SizedBox(height: 6),
                Text(dateLabel, style: AppTypography.dateText),
              ],
            ),
          ),
          _BenchSection(
            title: 'Piece intake',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const Key('new-piece-button'),
                    onPressed: _openNewPiece,
                    icon: const Icon(Icons.add, color: AppColors.iconColor),
                    label: const Text('New piece'),
                  ),
                ),
                if (_lastActionMessage != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.only(top: 14),
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: AppColors.textPrimary),
                      ),
                    ),
                    child: Text(
                      _lastActionMessage!,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ],
            ),
          ),
          _BenchSection(
            title: 'Current state',
            child: _StateSummaryRow(repository: widget.repository),
          ),
        ],
      );
    }

    if (_selectedSection == 1) {
      return AllPiecesScreen(repository: widget.repository);
    }

    return _PlaceholderSection(index: _selectedSection);
  }
}

class _BenchSection extends StatelessWidget {
  const _BenchSection({required this.title, required this.child});

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

class _StateSummaryRow extends StatelessWidget {
  const _StateSummaryRow({required this.repository});

  final StudioRepository repository;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StateValue(
            label: 'to_fire',
            count: repository.countPiecesByStage(PieceStage.toFire),
            valueKey: const Key('count-to-fire'),
          ),
        ),
        const _VerticalStateDivider(),
        Expanded(
          child: _StateValue(
            label: 'to_glaze',
            count: repository.countPiecesByStage(PieceStage.toGlaze),
            valueKey: const Key('count-to-glaze'),
          ),
        ),
        const _VerticalStateDivider(),
        Expanded(
          child: _StateValue(
            label: 'ready',
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
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

class _VerticalStateDivider extends StatelessWidget {
  const _VerticalStateDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 54, color: AppColors.textPrimary);
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
                  'nav-${items[index].label.toLowerCase().replaceAll(' ', '-')}',
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
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        items[index].icon,
                        size: 18,
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
    const labels = ['Bench', 'All pieces', 'Batches', 'Jobs'];

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Container(
          color: AppColors.shellBackground,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                labels[index].toUpperCase(),
                style: AppTypography.sectionLabel,
              ),
              const SizedBox(height: 10),
              Text(
                labels[index],
                style: Theme.of(context).textTheme.headlineLarge,
              ),
            ],
          ),
        ),
        _BenchSection(
          title: labels[index],
          child: Text(
            '${labels[index]} stays in the shell, but this area remains flat until its operational flow is implemented.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ],
    );
  }
}
