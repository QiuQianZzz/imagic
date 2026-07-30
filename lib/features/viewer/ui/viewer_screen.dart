import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/fullscreen.dart';
import '../../../core/utils/key_labels.dart';
import '../providers/viewer_state.dart';
import '../../menu/models/menu_action.dart';
import '../../menu/ui/menu_bar.dart';
import '../../settings/providers/settings_state.dart';
import '../../settings/ui/settings_screen.dart';
import 'widgets/floating_fullscreen_hint.dart';
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
    with SingleTickerProviderStateMixin, WindowListener {
  final GlobalKey _canvasKey = GlobalKey();
  final FocusNode _focusNode = FocusNode();
  late final AnimationController _zoomAnimController;
  late final _AnimatedTransformationController _transformController;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _zoomAnimController = AnimationController(vsync: this);
    _transformController = _AnimatedTransformationController(
      _zoomAnimController,
      _canvasKey,
    );
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _focusNode.requestFocus(),
    );
    if (widget.initialFile != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<ViewerState>().openFile(widget.initialFile!);
      });
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    windowManager.removeListener(this);
    _zoomAnimController.dispose();
    _transformController.dispose();
    super.dispose();
  }

  @override
  void onWindowMaximize() {
    onWindowMaximized();
  }

  @override
  void onWindowUnmaximize() {
    onWindowUnmaximized();
  }

  Widget _buildCanvas(ViewerState state) {
    return ImageCanvas(
      key: _canvasKey,
      onOpenFile: _openFile,
      transformController: _transformController,
      onReset: () => _transformController.animateTo(Matrix4.identity()),
      hasPrev: state.currentIndex > 0,
      hasNext: state.currentIndex < state.totalCount - 1,
      onPrev: () => state.previousFile(),
      onNext: () => state.nextFile(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          final settings = context.read<SettingsState>();
          if (event.logicalKey ==
              settings.getShortcutKey('toggle_fullscreen')) {
            toggleFullscreen();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == settings.getShortcutKey('exit_fullscreen')) {
            if (fullscreenNotifier.value) toggleFullscreen();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == settings.getShortcutKey('prev_image')) {
            final state = context.read<ViewerState>();
            if (state.currentIndex > 0) state.previousFile();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == settings.getShortcutKey('next_image')) {
            final state = context.read<ViewerState>();
            if (state.currentIndex < state.totalCount - 1) state.nextFile();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: ValueListenableBuilder<bool>(
        valueListenable: fullscreenNotifier,
        builder: (context, fs, _) {
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
              final canvas = _buildCanvas(state);
              return Scaffold(
                body: Stack(
                  children: [
                    Column(
                      children: [
                        AnimatedSize(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutCubic,
                          alignment: Alignment.topCenter,
                          child: fs
                              ? const SizedBox.shrink()
                              : AppMenuBar(
                                  hasImage: state.hasImage,
                                  hasPrev: state.currentIndex > 0,
                                  hasNext:
                                      state.currentIndex < state.totalCount - 1,
                                  fileName: state.hasImage
                                      ? state.currentName
                                      : null,
                                  onOpenFile: _openFile,
                                  onPrev: () => state.previousFile(),
                                  onNext: () => state.nextFile(),
                                  onAction: (action) =>
                                      _handleMenuAction(action, state),
                                ),
                        ),
                        Expanded(child: canvas),
                      ],
                    ),
                    Align(
                      alignment: Alignment.topCenter,
                      child: FloatingFullscreenHint(
                        visible: fs,
                        hintText: _buildFullscreenHintText(context),
                      ),
                    ),
                  ],
                ),
                bottomNavigationBar: AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.bottomCenter,
                  child: fs
                      ? const SizedBox.shrink()
                      : ZoomIndicator(
                          transformController: _transformController,
                        ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _buildFullscreenHintText(BuildContext context) {
    final settings = context.read<SettingsState>();
    final toggleKey = keyToLabel(settings.getShortcutKey('toggle_fullscreen'));
    final exitKey = keyToLabel(settings.getShortcutKey('exit_fullscreen'));
    return '按 $toggleKey 或 $exitKey 退出全屏';
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
        toggleFullscreen();
        break;
      case MenuAction.togglePanel:
        // TODO: 文件面板（侧边栏文件浏览器）
        break;
      case MenuAction.editMode:
        // TODO: 编辑模式
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
    final target = _transformController._withCenterFocal(current, s);
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
