import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';

import 'design_system.dart';
import 'global_piece_search.dart';
import 'models.dart';
import 'piece_detail_screen.dart';
import 'piece_editor_screen.dart';
import 'studio_repository.dart';

class MoldEditorScreen extends StatefulWidget {
  const MoldEditorScreen({
    required this.repository,
    required this.currentUser,
    this.initialName,
    this.initialPrice,
    super.key,
  }) : mold = null;

  const MoldEditorScreen.edit({
    required this.repository,
    required this.mold,
    required this.currentUser,
    super.key,
  }) : initialName = null,
       initialPrice = null;

  final StudioRepository repository;
  final Mold? mold;
  final StudioUser currentUser;
  final String? initialName;
  final double? initialPrice;

  bool get isEditing => mold != null;

  @override
  State<MoldEditorScreen> createState() => _MoldEditorScreenState();
}

class _MoldEditorScreenState extends State<MoldEditorScreen> {
  late final TextEditingController _headerSearchController;
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _priceController;

  MoldSize? _selectedSize;
  MoldImageReference? _selectedImage;
  bool _showSummary = false;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _headerSearchController = TextEditingController();
    _nameController = TextEditingController(
      text: widget.mold?.name ?? widget.initialName ?? '',
    )..addListener(_handleChange);
    _descriptionController = TextEditingController(
      text: widget.mold?.description ?? '',
    );
    _priceController = TextEditingController(
      text: widget.mold == null
          ? widget.initialPrice == null
                ? ''
                : formatPrice(widget.initialPrice!)
          : formatPrice(widget.mold!.defaultPrice),
    )..addListener(_handleChange);
    _selectedSize = widget.mold?.size;
    _selectedImage = widget.mold?.imageReference;
  }

  @override
  void dispose() {
    _headerSearchController.dispose();
    _nameController
      ..removeListener(_handleChange)
      ..dispose();
    _descriptionController.dispose();
    _priceController
      ..removeListener(_handleChange)
      ..dispose();
    super.dispose();
  }

  void _handleChange() {
    setState(() {
      _submitError = null;
    });
  }

  bool get _nameIsDuplicate {
    final existing = widget.repository.findExactMold(_nameController.text);
    return existing != null && existing.id != widget.mold?.id;
  }

  double? get _price {
    final value = _priceController.text.trim();
    if (value.isEmpty) {
      return 0;
    }
    return double.tryParse(value.replaceAll(',', '.'));
  }

  bool get _canReview {
    return _nameController.text.trim().isNotEmpty &&
        !_nameIsDuplicate &&
        _price != null &&
        _price! >= 0;
  }

  void _review() {
    if (!_canReview) {
      return;
    }

    setState(() {
      _showSummary = true;
      _submitError = null;
    });
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final file = result?.files.single;
    if (file == null) {
      return;
    }

    setState(() {
      _selectedImage = MoldImageReference(
        fileName: file.name,
        mimeType: file.extension == null ? null : 'image/${file.extension}',
        sizeBytes: file.size,
        bytes: file.bytes,
      );
    });
  }

  Future<void> _confirm() async {
    if (!_canReview) {
      setState(() => _showSummary = false);
      return;
    }

    try {
      final mold = widget.isEditing
          ? await widget.repository.updateMold(
              widget.mold!.copyWith(
                name: _nameController.text.trim(),
                normalizedName: normalizeSearch(_nameController.text),
                description: _emptyToNull(_descriptionController.text),
                size: _selectedSize,
                imageReference: _selectedImage,
                defaultPrice: _price ?? 0,
              ),
            )
          : await widget.repository.createMold(
              name: _nameController.text.trim(),
              description: _emptyToNull(_descriptionController.text),
              size: _selectedSize,
              imageReference: _selectedImage,
              defaultPrice: _price ?? 0,
            );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(mold);
    } on StateError catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _showSummary = false;
        _submitError = error.message;
      });
    }
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
              screenName: widget.isEditing ? 'Edit mold' : 'New mold',
              dateLabel: dateLabel,
              searchController: _headerSearchController,
              onSearchChanged: (_) => setState(() {}),
              onBack: () => Navigator.of(context).maybePop(),
            ),
            GlobalPieceSearchResults(
              repository: widget.repository,
              searchController: _headerSearchController,
              onOpenPiece: _openSearchPiece,
              onCreatePiece: _openNewPiece,
            ),
            Expanded(
              child: _showSummary ? _buildSummary(context) : _buildForm(),
            ),
            _showSummary
                ? _MoldSummaryActions(
                    onEdit: () => setState(() => _showSummary = false),
                    onConfirm: _confirm,
                  )
                : _MoldFormActions(canSubmit: _canReview, onSubmit: _review),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        AppSection(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                key: const Key('mold-name-input'),
                controller: _nameController,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Name',
                  hintText: 'New mold name',
                  errorText: _nameIsDuplicate
                      ? 'Mold name already exists'
                      : _submitError,
                ),
              ),
              const SizedBox(height: AppSpacing.related),
              TextField(
                key: const Key('mold-description-input'),
                controller: _descriptionController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: AppSpacing.related),
              DropdownButtonFormField<MoldSize>(
                key: const Key('mold-size-dropdown'),
                initialValue: _selectedSize,
                decoration: const InputDecoration(labelText: 'Size'),
                items: [
                  for (final size in MoldSize.values)
                    DropdownMenuItem(value: size, child: Text(size.label)),
                ],
                onChanged: (value) => setState(() => _selectedSize = value),
              ),
              const SizedBox(height: AppSpacing.related),
              AppCard(
                margin: EdgeInsets.zero,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _selectedImage?.fileName ?? 'No image selected',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    TextButton(
                      key: const Key('pick-mold-image-button'),
                      onPressed: _pickImage,
                      child: const Text('Upload image'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.related),
              TextField(
                key: const Key('mold-price-input'),
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9\.,]')),
                ],
                decoration: InputDecoration(
                  labelText: 'Price',
                  errorText: _price == null ? 'Enter a valid price' : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummary(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        AppSection(
          child: AppCard(
            margin: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Confirm mold',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.related),
                _SummaryLine(label: 'Name', value: _nameController.text.trim()),
                _SummaryLine(
                  label: 'Description',
                  value: _emptyToNull(_descriptionController.text) ?? '-',
                ),
                _SummaryLine(label: 'Size', value: _selectedSize?.label ?? '-'),
                _SummaryLine(
                  label: 'Image',
                  value: _selectedImage?.fileName ?? '-',
                ),
                _SummaryLine(
                  label: 'Price',
                  value: formatPriceEuro(_price ?? 0),
                ),
                _SummaryLine(
                  label: 'Internal ID',
                  value: widget.isEditing
                      ? widget.mold!.id
                      : 'Generated on confirm',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.related),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(label, style: Theme.of(context).textTheme.labelMedium),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyLarge),
          ),
        ],
      ),
    );
  }
}

class _MoldFormActions extends StatelessWidget {
  const _MoldFormActions({required this.canSubmit, required this.onSubmit});

  final bool canSubmit;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.shellBackground,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          key: const Key('save-mold-button'),
          onPressed: canSubmit ? onSubmit : null,
          child: const Text('Create'),
        ),
      ),
    );
  }
}

class _MoldSummaryActions extends StatelessWidget {
  const _MoldSummaryActions({required this.onEdit, required this.onConfirm});

  final VoidCallback onEdit;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.shellBackground,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: TextButton(
              key: const Key('edit-mold-summary-button'),
              onPressed: onEdit,
              child: const Text('Back to edit'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              key: const Key('confirm-mold-button'),
              onPressed: onConfirm,
              child: const Text('Confirm'),
            ),
          ),
        ],
      ),
    );
  }
}
