import 'package:flutter/material.dart';

import 'design_system.dart';
import 'models.dart';

class MoldImagePanel extends StatelessWidget {
  const MoldImagePanel({
    required this.imageReference,
    required this.onUpload,
    this.compact = false,
    super.key,
  });

  final MoldImageReference? imageReference;
  final VoidCallback onUpload;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final bytes = imageReference?.bytes;
    final height = compact ? 180.0 : 260.0;

    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.shellBackground.withValues(alpha: 0.32),
        border: Border.all(color: AppColors.shellBackground),
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      clipBehavior: Clip.antiAlias,
      child: bytes == null
          ? _ImagePlaceholder(
              fileName: imageReference?.fileName,
              onUpload: onUpload,
            )
          : Stack(
              fit: StackFit.expand,
              children: [
                Image.memory(bytes, fit: BoxFit.cover),
                Positioned(
                  right: AppSpacing.related,
                  bottom: AppSpacing.related,
                  child: TextButton(
                    key: const Key('upload-mold-image-button'),
                    onPressed: onUpload,
                    child: const Text('Replace image'),
                  ),
                ),
              ],
            ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({required this.fileName, required this.onUpload});

  final String? fileName;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.image_outlined,
              color: AppColors.iconColor,
              size: 32,
            ),
            const SizedBox(height: AppSpacing.related),
            Text(
              fileName ?? 'No mold image',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.related),
            TextButton(
              key: const Key('upload-mold-image-button'),
              onPressed: onUpload,
              child: const Text('Upload image'),
            ),
          ],
        ),
      ),
    );
  }
}
