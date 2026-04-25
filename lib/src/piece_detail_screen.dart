import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import 'design_system.dart';
import 'global_piece_search.dart';
import 'models.dart';
import 'mold_image_panel.dart';
import 'piece_editor_screen.dart';
import 'studio_repository.dart';
import 'user_history_screen.dart';

class PieceDetailScreen extends StatefulWidget {
  const PieceDetailScreen({
    required this.repository,
    required this.piece,
    required this.currentUser,
    super.key,
  });

  final StudioRepository repository;
  final Piece piece;
  final StudioUser currentUser;

  @override
  State<PieceDetailScreen> createState() => _PieceDetailScreenState();
}

class _PieceDetailScreenState extends State<PieceDetailScreen> {
  late final TextEditingController _headerSearchController;
  late Piece _piece;
  bool _showMore = false;

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
            currentUser: widget.currentUser,
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

  Future<void> _pickMoldImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final file = result?.files.single;
    if (file == null) {
      return;
    }

    final updatedMold = await widget.repository.updateMold(
      _piece.mold.copyWith(
        imageReference: MoldImageReference(
          fileName: file.name,
          mimeType: file.extension == null ? null : 'image/${file.extension}',
          sizeBytes: file.size,
          bytes: file.bytes,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _piece = _piece.copyWith(mold: updatedMold);
    });
  }

  Future<void> _openUserHistory() async {
    _headerSearchController.clear();
    setState(() {});
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) {
          return UserHistoryScreen(
            repository: widget.repository,
            currentUser: widget.currentUser,
          );
        },
      ),
    );
  }

  Future<void> _openSearchPiece(Piece piece) async {
    _headerSearchController.clear();
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
    _headerSearchController.clear();
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
              screenName: _piece.mold.name,
              dateLabel: dateLabel,
              searchController: _headerSearchController,
              onSearchChanged: (_) => setState(() {}),
              onBack: () => Navigator.of(context).maybePop(),
              onUserTap: _openUserHistory,
            ),
            GlobalPieceSearchResults(
              repository: widget.repository,
              searchController: _headerSearchController,
              onOpenPiece: _openSearchPiece,
              onCreatePiece: _openNewPiece,
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
                        if (_piece.failed)
                          const _DetailLine(label: 'Failure', value: 'Failed'),
                        _DetailLine(label: 'Owner', value: _ownerLabel),
                        _DetailLine(
                          label: 'Destination',
                          value: _piece.destination.label,
                        ),
                        _DetailLine(
                          label: 'Price',
                          value: formatPriceEuro(_piece.price),
                        ),
                        TextButton(
                          key: const Key('piece-see-more-button'),
                          onPressed: () {
                            setState(() => _showMore = !_showMore);
                          },
                          child: Text(_showMore ? 'See less' : 'See more'),
                        ),
                        if (_showMore) ...[
                          _DetailLine(label: 'Piece ID', value: _piece.id),
                          _DetailLine(
                            label: 'Created',
                            value: MaterialLocalizations.of(
                              context,
                            ).formatMediumDate(_piece.createdAt),
                            style: AppTypography.dateText,
                          ),
                          _DetailLine(
                            label: 'Updated',
                            value: MaterialLocalizations.of(
                              context,
                            ).formatMediumDate(_piece.updatedAt),
                            style: AppTypography.dateText,
                          ),
                        ],
                      ],
                    ),
                  ),
                  AppSection(
                    title: 'Mold image',
                    child: MoldImagePanel(
                      imageReference: _piece.mold.imageReference,
                      onUpload: _pickMoldImage,
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
      return 'No color';
    }
    return _piece.colors.map((color) => color.name).join(', ');
  }

  String get _ownerLabel {
    if (_piece.linkedRecord != null) {
      return _piece.linkedRecord!.label;
    }

    switch (_piece.destination) {
      case PieceDestination.stock:
        return _piece.createdByUserName == null
            ? '${widget.currentUser.name}\'s stock'
            : '${_piece.createdByUserName}\'s stock';
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
