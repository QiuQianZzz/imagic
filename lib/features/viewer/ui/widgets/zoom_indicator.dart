import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/viewer_state.dart';

/// 底栏，左侧显示图片信息（进度、尺寸、大小、格式），右侧显示缩放比例。
class ZoomIndicator extends StatelessWidget {
  final TransformationController transformController;

  const ZoomIndicator({super.key, required this.transformController});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ViewerState>();
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border(top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.3))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          if (state.hasImage) ...[
            Text(
              '${state.currentIndex + 1}/${state.totalCount}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            _sep(context),
            Text(
              _formatSize(state.fileSize),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            if (state.imageWidth > 0 && state.imageHeight > 0) ...[
              _sep(context),
              Text(
                '${state.imageWidth}x${state.imageHeight}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
            _sep(context),
            Text(
              _formatExt(state.currentPath),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
          const Spacer(),
          _ZoomValue(transformController: transformController),
        ],
      ),
    );
  }

  Widget _sep(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 1, height: 16,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: cs.outlineVariant.withValues(alpha: 0.3),
    );
  }

  String _formatExt(String? path) {
    if (path == null) return '';
    final ext = path.split('.').last.toUpperCase();
    return ext == 'JPG' ? 'JPEG' : ext;
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// 监听 TransformationController 的缩放值，显示缩放百分比。
class _ZoomValue extends StatelessWidget {
  final TransformationController transformController;
  const _ZoomValue({required this.transformController});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Matrix4>(
      valueListenable: transformController,
      builder: (context, matrix, _) {
        final scale = matrix.getMaxScaleOnAxis();
        final cs = Theme.of(context).colorScheme;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.zoom_in, size: 14, color: cs.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              '${(scale * 100).clamp(0, 999999).toStringAsFixed(0)}%',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        );
      },
    );
  }
}
