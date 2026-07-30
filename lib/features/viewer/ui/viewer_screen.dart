import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../providers/viewer_state.dart';
import '../../menu/models/menu_action.dart';
import '../../menu/ui/menu_bar.dart';
import '../../settings/ui/settings_screen.dart';
import 'widgets/image_canvas.dart';
import 'widgets/zoom_indicator.dart';
import '../../../services/file_service.dart';

/// 带动画的 TransformationController。
///
/// 拦截 value setter，对缩放操作自动插入 200ms easeOutCubic 动画，
/// 以视口中心为焦点平滑过渡；纯平移操作则直接透传。
class _AnimatedTransformationController extends TransformationController {
  final AnimationController animController;
  final GlobalKey canvasKey;
  bool _internal = false;
  VoidCallback? _animListener;

  _AnimatedTransformationController(this.animController, this.canvasKey);

  /// 计算以视口中心为焦点的缩放矩阵，使缩放后焦点位置保持不变。
  Matrix4 _withCenterFocal(Matrix4 begin, double newScale) {
    final renderBox =
        canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) {
      return Matrix4.diagonal3Values(newScale, newScale, newScale)
        ..setTranslationRaw(
          begin.getTranslation().x,
          begin.getTranslation().y,
          0,
        );
    }
    final center = Offset(renderBox.size.width / 2, renderBox.size.height / 2);
    final oldS = begin.getMaxScaleOnAxis();
    final focalInImage =
        (center - Offset(begin.getTranslation().x, begin.getTranslation().y)) /
        oldS;
    return Matrix4.diagonal3Values(newScale, newScale, newScale)
      ..setTranslationRaw(
        center.dx - focalInImage.dx * newScale,
        center.dy - focalInImage.dy * newScale,
        0,
      );
  }

  /// 启动 200ms easeOutCubic 动画，从 begin 过渡到 target。
  void _startAnim(Matrix4 begin, Matrix4 target) {
    if (_animListener != null) {
      animController.removeListener(_animListener!);
    }
    animController.duration = const Duration(milliseconds: 200);
    final anim = Matrix4Tween(begin: begin, end: target).animate(
      CurvedAnimation(parent: animController, curve: Curves.easeOutCubic),
    );
    _animListener = () {
      _internal = true;
      super.value = anim.value;
      _internal = false;
      if (animController.isCompleted) {
        animController.removeListener(_animListener!);
        _animListener = null;
      }
    };
    animController.addListener(_animListener!);
    animController.forward(from: 0);
  }

  void animateTo(Matrix4 target) {
    if (_internal) {
      super.value = target;
      return;
    }
    final begin = super.value;
    const e = 0.001;
    if ((begin.getMaxScaleOnAxis() - target.getMaxScaleOnAxis()).abs() < e &&
        (begin.getTranslation().x - target.getTranslation().x).abs() < e &&
        (begin.getTranslation().y - target.getTranslation().y).abs() < e) {
      return;
    }
    _startAnim(begin, target);
  }

  @override
  void dispose() {
    if (_animListener != null) {
      animController.removeListener(_animListener!);
      _animListener = null;
    }
    super.dispose();
  }

  @override
  set value(Matrix4 newValue) {
    if (_internal) {
      super.value = newValue;
      return;
    }

    final begin = super.value;
    const e = 0.001;
    final oldScale = begin.getMaxScaleOnAxis();
    final newScale = newValue.getMaxScaleOnAxis();

    if ((oldScale - newScale).abs() < e &&
        (begin.getTranslation().x - newValue.getTranslation().x).abs() < e &&
        (begin.getTranslation().y - newValue.getTranslation().y).abs() < e) {
      return;
    }

    // Translation only → pass through (pan)
    if ((oldScale - newScale).abs() < e) {
      if (_animListener != null) {
        animController.removeListener(_animListener!);
        _animListener = null;
      }
      super.value = newValue;
      return;
    }

    // Animate with viewport center as focal point
    final target = _withCenterFocal(begin, newScale);
    if ((oldScale - target.getMaxScaleOnAxis()).abs() < e &&
        (begin.getTranslation().x - target.getTranslation().x).abs() < e &&
        (begin.getTranslation().y - target.getTranslation().y).abs() < e) {
      return;
    }
    _startAnim(begin, target);
  }
}

class ViewerScreen extends StatefulWidget {
  final String? initialFile;

  const ViewerScreen({super.key, this.initialFile});

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey _canvasKey = GlobalKey();
  late final AnimationController _zoomAnimController;
  late final _AnimatedTransformationController _transformController;

  @override
  void initState() {
    super.initState();
    _zoomAnimController = AnimationController(vsync: this);
    _transformController = _AnimatedTransformationController(
      _zoomAnimController,
      _canvasKey,
    );
    if (widget.initialFile != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<ViewerState>().openFile(widget.initialFile!);
      });
    }
  }

  @override
  void dispose() {
    _zoomAnimController.dispose();
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ViewerState>(
      builder: (context, state, _) {
        if (state.errorMessage != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.errorMessage!),
                  duration: const Duration(seconds: 3),
                ),
              );
              state.clearError();
            }
          });
        }
        return Scaffold(
          body: Column(
            children: [
              AppMenuBar(
                hasImage: state.hasImage,
                hasPrev: state.currentIndex > 0,
                hasNext: state.currentIndex < state.totalCount - 1,
                fileName: state.hasImage ? state.currentName : null,
                onOpenFile: _openFile,
                onPrev: () => state.previousFile(),
                onNext: () => state.nextFile(),
                onAction: (action) => _handleMenuAction(action, state),
              ),
              Expanded(
                child: ImageCanvas(
                  key: _canvasKey,
                  onOpenFile: _openFile,
                  transformController: _transformController,
                  onReset: () =>
                      _transformController.animateTo(Matrix4.identity()),
                  hasPrev: state.currentIndex > 0,
                  hasNext: state.currentIndex < state.totalCount - 1,
                  onPrev: () => state.previousFile(),
                  onNext: () => state.nextFile(),
                ),
              ),
            ],
          ),
          bottomNavigationBar: ZoomIndicator(
            transformController: _transformController,
          ),
        );
      },
    );
  }

  void _handleMenuAction(MenuAction action, ViewerState state) {
    switch (action) {
      case MenuAction.openFile:
        _openFile();
        break;
      case MenuAction.save:
      case MenuAction.saveAs:
        break;
      case MenuAction.closeFile:
        state.closeImage();
        break;
      case MenuAction.exit:
        break;
      case MenuAction.undo:
      case MenuAction.redo:
        break;
      case MenuAction.copy:
        break;
      case MenuAction.actualSize:
      case MenuAction.fitToWindow:
        _transformController.animateTo(Matrix4.identity());
        break;
      case MenuAction.zoomIn:
        _zoom(1.25);
        break;
      case MenuAction.zoomOut:
        _zoom(1 / 1.25);
        break;
      case MenuAction.fullscreen:
        break;
      case MenuAction.togglePanel:
        break;
      case MenuAction.editMode:
        break;
      case MenuAction.openSettings:
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
        break;
      case MenuAction.about:
        _showAbout();
        break;
    }
  }

  Future<void> _openFile() async {
    final fileService = context.read<FileService>();
    final path = await fileService.openFileDialog();
    if (path != null && mounted) {
      context.read<ViewerState>().openFile(path);
    }
  }

  /// 以当前缩放值为基准乘以 factor，播放缩放到 target 的动画。
  void _zoom(double factor) {
    final current = _transformController.value;
    final s = (current.getMaxScaleOnAxis() * factor).clamp(
      AppConstants.kMinZoom,
      AppConstants.kMaxZoom,
    );
    if ((s - current.getMaxScaleOnAxis()).abs() < 0.001) return;
    final target = Matrix4.diagonal3Values(s, s, s)
      ..setTranslationRaw(
        current.getTranslation().x,
        current.getTranslation().y,
        0,
      );
    _transformController.animateTo(target);
  }

  void _showAbout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('关于 Imagic'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Imagic 图片查看工具'),
            SizedBox(height: 8),
            Text('版本 1.0.0'),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}
