import 'package:flutter/services.dart';

/// 单实例通信处理。
///
/// C++ 端（main.cpp + flutter_window.cpp）通过命名管道接收第二实例传入的
/// 文件路径，再通过 MethodChannel "imagic/single_instance" 调用
/// `onExternalFileOpen` 方法推送到 Dart 端。
///
/// 本类作为全局单例，注册一个回调：
/// - [setHandler]：由 ViewerScreen 在 initState 时注册，dispose 时置 null
/// - 收到路径后调用回调，由 ViewerScreen 调用 ViewerState.openFile
///
/// 这种间接方式避免了 MethodChannel 与具体 State 的强耦合，也避免了
/// 在 main.dart 启动阶段就需要 ViewerState 的麻烦。
class SingleInstanceHandler {
  SingleInstanceHandler._();

  static final SingleInstanceHandler instance = SingleInstanceHandler._();

  static const MethodChannel _channel =
      MethodChannel('imagic/single_instance');

  /// 当前注册的"打开外部文件"回调。
  ///
  /// 通常由 home widget（ViewerScreen）持有，在 initState 注册、dispose 取消。
  /// 当应用处于尚未注册回调的状态时（如启动早期阶段），收到的路径会被缓存，
  /// 待回调注册后立即派发。
  void Function(String path)? _onOpenExternalFile;

  /// 缓存的待派发路径：当回调尚未注册时，先存起来。
  final List<String> _pendingPaths = [];

  bool _initialized = false;

  /// 初始化 MethodChannel 监听。应在 main() 中调用一次。
  void init() {
    if (_initialized) return;
    _initialized = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onExternalFileOpen') {
        final path = call.arguments;
        if (path is String && path.isNotEmpty) {
          _dispatch(path);
        }
      }
      return null;
    });
  }

  /// 注册"打开外部文件"回调。
  void setHandler(void Function(String path) onOpenExternalFile) {
    _onOpenExternalFile = onOpenExternalFile;
    // 派发之前缓存的路径
    if (_pendingPaths.isNotEmpty) {
      for (final p in _pendingPaths) {
        onOpenExternalFile(p);
      }
      _pendingPaths.clear();
    }
  }

  /// 取消注册。
  void clearHandler() {
    _onOpenExternalFile = null;
  }

  void _dispatch(String path) {
    final handler = _onOpenExternalFile;
    if (handler != null) {
      handler(path);
    } else {
      // 回调尚未注册（启动早期），缓存待派发
      _pendingPaths.add(path);
    }
  }
}
