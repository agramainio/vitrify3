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
  late Piece _piece;

  @override
  void initState() {
    super.initState();
    _piece = widget.piece;
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
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: AppColors.shellBackground,
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(
                      Icons.arrow_back,
                      color: AppColors.iconColor,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('PIECE', style: AppTypography.sectionLabel),
                        const SizedBox(height: 6),
                        Text(_piece.id, style: theme.textTheme.headlineSmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _DetailSection(
                    title: 'Production',
                    children: [
                      _DetailRow(label: 'Mold', value: _piece.mold.name),
                      _DetailRow(
                        label: 'Colors',
                        value: _piece.colors
                            .map((color) => color.name)
                            .join(', '),
                      ),
                      _DetailRow(label: 'Stage', value: _piece.stage.label),
                    ],
                  ),
                  _DetailSection(
                    title: 'Commercial',
                    children: [
                      _DetailRow(
                        label: 'Destination',
                        value: _piece.destination.label,
                      ),
                      if (_piece.linkedRecord != null)
                        _DetailRow(
                          label: _piece.destination == PieceDestination.order
                              ? 'Order'
                              : 'Workshop',
                          value: _piece.linkedRecord!.label,
                        ),
                      _DetailRow(
                        label: 'Commercial state',
                        value: _piece.commercialState.label,
                      ),
                      _DetailRow(
                        label: 'Price',
                        value: formatPrice(_piece.price),
                      ),
                    ],
                  ),
                  _DetailSection(
                    title: 'History',
                    children: [
                      if (_piece.failureRecord != null)
                        _DetailRow(
                          label: 'Failure',
                          value: _piece.failureRecord!.notes?.isNotEmpty == true
                              ? '${_piece.failureRecord!.reason} - ${_piece.failureRecord!.notes}'
                              : _piece.failureRecord!.reason,
                        ),
                      _DetailRow(
                        label: 'Created',
                        value: _formatTimestamp(context, _piece.createdAt),
                        valueStyle: AppTypography.dateText,
                      ),
                      _DetailRow(
                        label: 'Updated',
                        value: _formatTimestamp(context, _piece.updatedAt),
                        valueStyle: AppTypography.dateText,
                      ),
                    ],
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

  String _formatTimestamp(BuildContext context, DateTime value) {
    final localizations = MaterialLocalizations.of(context);
    return '${localizations.formatMediumDate(value)} ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(value))}';
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

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
          ...children,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value, this.valueStyle});

  final String label;
  final String value;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(
            value,
            style: valueStyle ?? Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}
