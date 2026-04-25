import 'package:flutter/material.dart';

import 'design_system.dart';
import 'models.dart';
import 'piece_editor_screen.dart';
import 'studio_repository.dart';

class PieceDetailScreen extends StatefulWidget {
  const PieceDetailScreen({
    required this.repository,
    required this.piece,
    super.key,
  });

  final StudioRepository repository;
  final Piece piece;

  @override
  State<PieceDetailScreen> createState() => _PieceDetailScreenState();
}

class _PieceDetailScreenState extends State<PieceDetailScreen> {
  late final TextEditingController _headerSearchController;
  late Piece _piece;

  @override
  void initState() {
    super.initState();
    _headerSearchController = TextEditingController();
    _piece = widget.piece;
  }

  @override
  void dispose() {
    _headerSearchController.dispose();
    super.dispose();
  }

  Future<void> _editPiece() async {
    final result = await Navigator.of(context).push<PieceEditResult>(
      MaterialPageRoute(
        builder: (context) {
          return PieceEditorScreen.edit(
            repository: widget.repository,
            piece: _piece,
          );
        },
      ),
    );

    if (!mounted || result == null) {
      return;
    }

    if (result.deleted) {
      Navigator.of(context).pop();
      return;
    }

    if (result.piece != null) {
      setState(() {
        _piece = result.piece!;
      });
    }
  }

  Future<void> _deletePiece() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete piece'),
          content: Text('Delete ${_piece.id}? This cannot be undone.'),
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

    await widget.repository.deletePiece(_piece.id);
    if (!mounted) {
      return;
    }

    Navigator.of(context).pop();
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
              screenName: _piece.mold.name,
              dateLabel: dateLabel,
              searchController: _headerSearchController,
              onBack: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  AppSection(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _DetailLine(label: 'Colors', value: _colorsLabel),
                        _DetailLine(label: 'Status', value: _piece.stage.label),
                        _DetailLine(label: 'Owner', value: _ownerLabel),
                        _DetailLine(
                          label: 'Destination',
                          value: _piece.destination.label,
                        ),
                        _DetailLine(
                          label: 'Price',
                          value: formatPrice(_piece.price),
                        ),
                        _DetailLine(label: 'Piece ID', value: _piece.id),
                        _DetailLine(
                          label: 'Updated',
                          value: MaterialLocalizations.of(
                            context,
                          ).formatMediumDate(_piece.updatedAt),
                          style: AppTypography.dateText,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              color: AppColors.shellBackground,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      key: Key('piece-detail-delete-${_piece.id}'),
                      onPressed: _deletePiece,
                      child: const Text('Delete'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      key: Key('piece-detail-edit-${_piece.id}'),
                      onPressed: _editPiece,
                      child: const Text('Edit'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _colorsLabel {
    if (_piece.colors.isEmpty) {
      return '-';
    }
    return _piece.colors.map((color) => color.name).join(', ');
  }

  String get _ownerLabel {
    if (_piece.linkedRecord != null) {
      return _piece.linkedRecord!.label;
    }

    switch (_piece.destination) {
      case PieceDestination.stock:
        return 'Stock';
      case PieceDestination.order:
        return 'Client';
      case PieceDestination.workshop:
        return 'Student';
    }
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value, this.style});

  final String label;
  final String value;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(label, style: theme.textTheme.labelMedium),
          ),
          Expanded(
            child: Text(value, style: style ?? theme.textTheme.bodyLarge),
          ),
        ],
      ),
    );
  }
}
