import 'package:flutter/material.dart';

import 'design_system.dart';
import 'models.dart';

class MoldImagePanel extends StatelessWidget {
  const MoldImagePanel({
    required this.imageReference,
    required this.onUpload,
    required this.onUrlSubmitted,
    this.compact = false,
    super.key,
  });

  final MoldImageReference? imageReference;
  final VoidCallback onUpload;
  final ValueChanged<String> onUrlSubmitted;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final bytes = imageReference?.bytes;
    final url = imageReference?.sourceUrl;
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
      child: bytes != null
          ? Stack(
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
            )
          : url != null && url.trim().isNotEmpty
          ? Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (context, _, _) {
                    return _ImagePlaceholder(
                      fileName: imageReference?.fileName,
                      onUpload: onUpload,
                      onUrlSubmitted: onUrlSubmitted,
                    );
                  },
                ),
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
            )
          : _ImagePlaceholder(
              fileName: imageReference?.fileName,
              onUpload: onUpload,
              onUrlSubmitted: onUrlSubmitted,
            ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({
    required this.fileName,
    required this.onUpload,
    required this.onUrlSubmitted,
  });

  final String? fileName;
  final VoidCallback onUpload;
  final ValueChanged<String> onUrlSubmitted;

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
            const SizedBox(height: AppSpacing.related),
            SizedBox(
              width: 260,
              child: TextField(
                key: const Key('mold-image-url-input'),
                textInputAction: TextInputAction.done,
                onSubmitted: onUrlSubmitted,
                decoration: const InputDecoration(
                  labelText: 'Paste image URL',
                  hintText: 'https://...',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
