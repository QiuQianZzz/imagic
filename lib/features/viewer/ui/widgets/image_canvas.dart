import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:desktop_drop/desktop_drop.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/image_background_painter.dart';
import '../../../../features/settings/providers/settings_state.dart';
import '../../providers/viewer_state.dart';

/// 图片画布组件，支持空状态提示、图片渲染、缩放平移和拖拽打开。
class ImageCanvas extends StatelessWidget {
  final VoidCallback? onOpenFile;
  final ValueChanged<String>? onDropFile;
  final TransformationController? transformController;
  final VoidCallback? onReset;
  final bool hasPrev;
  final bool hasNext;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  const ImageCanvas({
    super.key,
    this.onOpenFile,
    this.onDropFile,
    this.transformController,
    this.onReset,
    this.hasPrev = false,
    this.hasNext = false,
    this.onPrev,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ViewerState>(
      builder: (context, state, _) {
        final child = !state.hasImage
            ? _buildEmptyState(context)
            : _buildViewer(context);
        return DropTarget(
          onDragDone: (details) {
            if (details.files.isEmpty) return;
            if (onDropFile != null) {
              onDropFile!(details.files.first.path);
            }
          },
          child: child,
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onOpenFile,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  Icons.image_outlined,
                  size: 48,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '点击打开图片',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              Text(
                '或拖拽文件到此处',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildViewer(BuildContext context) {
    final state = context.read<ViewerState>();
    final bgType = context.watch<SettingsState>().imageBackground;
    final ctrl = transformController;
    if (ctrl == null) return const SizedBox.shrink();

    final image = state.isSvg
        ? SvgPicture.memory(state.svgBytes!, fit: BoxFit.contain)
        : Image.memory(state.imageBytes!, fit: BoxFit.contain);

    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(painter: ImageBackgroundPainter(bgType)),
        InteractiveViewer(
          transformationController: ctrl,
          minScale: AppConstants.kMinZoom,
          maxScale: AppConstants.kMaxZoom,
          boundaryMargin: EdgeInsets.all(double.infinity),
          child: Center(child: image),
        ),
        _ResetOverlay(
          controller: ctrl,
          onReset: onReset ?? () => ctrl.value = Matrix4.identity(),
        ),
        if (hasPrev && context.watch<SettingsState>().showFloatingArrows)
          _NavButton(
            icon: Icons.chevron_left,
            onTap: onPrev,
            align: Alignment.centerLeft,
          ),
        if (hasNext && context.watch<SettingsState>().showFloatingArrows)
          _NavButton(
            icon: Icons.chevron_right,
            onTap: onNext,
            align: Alignment.centerRight,
          ),
      ],
    );
  }
}

class _ResetOverlay extends StatelessWidget {
  final TransformationController controller;
  final VoidCallback onReset;

  const _ResetOverlay({required this.controller, required this.onReset});

  bool _isDefault(Matrix4 m) {
    const e = 0.001;
    return (m.getMaxScaleOnAxis() - 1.0).abs() < e &&
        m.getTranslation().x.abs() < e &&
        m.getTranslation().y.abs() < e;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Matrix4>(
      valueListenable: controller,
      builder: (context, matrix, _) {
        final isDefault = _isDefault(matrix);
        final cs = Theme.of(context).colorScheme;
        return Positioned(
          bottom: 16,
          left: 0,
          right: 0,
          child: AnimatedSlide(
            offset: isDefault ? const Offset(0, 3) : Offset.zero,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            child: AnimatedOpacity(
              opacity: isDefault ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 250),
              child: Center(
                child: Material(
                  color: cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    mouseCursor: SystemMouseCursors.click,
                    onTap: onReset,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.restart_alt_rounded,
                            size: 18,
                            color: cs.onSurface,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '还原',
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(color: cs.onSurface),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 图片切换悬浮按钮，半透明背景，靠左或靠右对齐。
class _NavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Alignment align;

  const _NavButton({
    required this.icon,
    required this.onTap,
    required this.align,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Align(
      alignment: align,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: SizedBox(
          width: 40,
          height: 80,
          child: Material(
            color: cs.surfaceContainerHigh.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              mouseCursor: SystemMouseCursors.click,
              onTap: onTap,
              child: Icon(icon, size: 28, color: cs.onSurface),
            ),
          ),
        ),
      ),
    );
  }
}
