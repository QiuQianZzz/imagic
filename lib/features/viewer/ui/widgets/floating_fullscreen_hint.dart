import 'dart:async';

import 'package:flutter/material.dart';

/// 全屏模式下的悬浮提示，告知用户如何退出全屏。
///
/// 具有流畅的进入（从顶部滑入 + 淡入）和退出（向上滑出 + 淡出）动画，
/// 显示 3 秒后自动消失。组件宽度根据内容自适应，水平居中显示。
class FloatingFullscreenHint extends StatefulWidget {
  final bool visible;
  final String hintText;

  const FloatingFullscreenHint({
    super.key,
    required this.visible,
    required this.hintText,
  });

  @override
  State<FloatingFullscreenHint> createState() => _FloatingFullscreenHintState();
}

class _FloatingFullscreenHintState extends State<FloatingFullscreenHint>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;
  Timer? _autoDismissTimer;

  static const Duration _enterDuration = Duration(milliseconds: 350);
  static const Duration _exitDuration = Duration(milliseconds: 300);
  static const Duration _displayDuration = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    if (widget.visible) {
      _playEnter();
    }
  }

  @override
  void didUpdateWidget(covariant FloatingFullscreenHint oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible && !oldWidget.visible) {
      _playEnter();
    } else if (!widget.visible && oldWidget.visible) {
      _playExit();
    }
  }

  void _playEnter() {
    _autoDismissTimer?.cancel();
    _controller.duration = _enterDuration;
    _controller.forward();
    _autoDismissTimer = Timer(_displayDuration + _enterDuration, () {
      if (mounted) _playExit();
    });
  }

  void _playExit() {
    _autoDismissTimer?.cancel();
    _controller.duration = _exitDuration;
    _controller.reverse();
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: child,
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.only(top: 48),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.fullscreen_exit, size: 20, color: cs.primary),
                const SizedBox(width: 12),
                Text(
                  widget.hintText,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
