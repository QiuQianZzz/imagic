import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/window_style.dart';
import '../../../core/utils/window_controls.dart';
import '../../settings/providers/settings_state.dart';
import '../models/menu_action.dart';

class AppMenuBar extends StatelessWidget {
  final bool hasImage;
  final bool hasPrev;
  final bool hasNext;
  final String? fileName;
  final VoidCallback onOpenFile;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final ValueChanged<MenuAction> onAction;

  const AppMenuBar({
    super.key,
    required this.hasImage,
    required this.hasPrev,
    required this.hasNext,
    this.fileName,
    required this.onOpenFile,
    required this.onPrev,
    required this.onNext,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = context.watch<SettingsState>().windowStyle;
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3))),
      ),
      child: style == WindowStyle.macos
          ? _buildMacosLayout(context, theme)
          : _buildWindowsLayout(context, theme),
    );
  }

  Widget _buildWindowsLayout(BuildContext context, ThemeData theme) {
    final state = context.watch<SettingsState>();
    return Row(
      children: [
        _buildLogo(theme),
        _dragHandle(child: Container(width: 4, color: Colors.transparent)),
        _buildMenuBar(context, theme),
        _buildTitle(theme),
        ..._buildNavButtons(state),
        const _WindowControls(),
      ],
    );
  }

  Widget _buildMacosLayout(BuildContext context, ThemeData theme) {
    final state = context.watch<SettingsState>();
    return Row(
      children: [
        const _MacTrafficLights(),
        _buildLogo(theme),
        _dragHandle(child: Container(width: 4, color: Colors.transparent)),
        _buildMenuBar(context, theme),
        _buildTitle(theme),
        ..._buildNavButtons(state),
      ],
    );
  }

  Widget _buildLogo(ThemeData theme) {
    return _dragHandle(
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.only(left: 8, right: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text('Imagic', style: theme.textTheme.titleSmall),
          ],
        ),
      ),
    );
  }

  Widget _buildTitle(ThemeData theme) {
    return Expanded(
      child: _dragHandle(
        child: Container(
          color: Colors.transparent,
          alignment: Alignment.center,
          child: fileName != null
              ? Text(
                  fileName!,
                  style: theme.textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                )
              : null,
        ),
      ),
    );
  }

  List<Widget> _buildNavButtons(SettingsState state) {
    return [
      if (hasImage && state.showNavBarArrows) ...[
        _barButton(Icons.chevron_left, hasPrev ? onPrev : null, '上一张'),
        _barButton(Icons.chevron_right, hasNext ? onNext : null, '下一张'),
      ],
      if (state.showNavBarOpen)
        _barButton(Icons.folder_open, onOpenFile, '打开文件'),
    ];
  }

  Widget _buildMenuBar(BuildContext context, ThemeData theme) {
    return MenuTheme(
      data: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(theme.colorScheme.surface),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          )),
          elevation: WidgetStatePropertyAll(8),
          shadowColor: WidgetStatePropertyAll(Colors.black26),
          padding: WidgetStatePropertyAll(const EdgeInsets.symmetric(vertical: 4)),
        ),
      ),
      child: MenuBar(
        style: MenuStyle(
          padding: WidgetStatePropertyAll(EdgeInsets.zero),
          visualDensity: VisualDensity.compact,
          backgroundColor: WidgetStatePropertyAll(Colors.transparent),
          elevation: WidgetStatePropertyAll(0),
          shape: WidgetStatePropertyAll(const RoundedRectangleBorder()),
        ),
        children: [
          _buildMenu(context, '文件', [
            _item(context, MenuAction.openFile, '打开图片...', shortcut: 'Ctrl+O'),
            if (hasImage) ...[
              _sep(),
              _item(context, MenuAction.closeFile, '关闭当前图片', shortcut: 'Ctrl+W'),
            ],
          ]),
          _buildMenu(context, '查看', [
            if (hasImage) ...[
              _item(context, MenuAction.actualSize, '实际大小', shortcut: 'Ctrl+1'),
              _item(context, MenuAction.fitToWindow, '适应窗口', shortcut: 'Ctrl+0'),
              _sep(),
              _item(context, MenuAction.zoomIn, '放大', shortcut: 'Ctrl++'),
              _item(context, MenuAction.zoomOut, '缩小', shortcut: 'Ctrl+-'),
              _sep(),
              _item(context, MenuAction.fullscreen, '全屏', shortcut: 'F11'),
            ],
          ]),
          _buildMenu(context, '工具', [
            _item(context, MenuAction.openSettings, '设置...'),
          ]),
          _buildMenu(context, '帮助', [
            _item(context, MenuAction.about, '关于 Imagic'),
          ]),
        ],
      ),
    );
  }

  Widget _dragHandle({required Widget child}) => Listener(
    onPointerDown: (_) => windowStartDragging(),
    child: child,
  );

  Widget _barButton(IconData icon, VoidCallback? onTap, String tooltip) {
    return SizedBox(
      width: 40,
      height: 48,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          mouseCursor: SystemMouseCursors.click,
          child: Tooltip(message: tooltip, child: Icon(icon, size: 20)),
        ),
      ),
    );
  }

  Widget _buildMenu(BuildContext context, String label, List<Widget> children) {
    final cs = Theme.of(context).colorScheme;
    return SubmenuButton(
      style: ButtonStyle(
        padding: WidgetStatePropertyAll(const EdgeInsets.symmetric(horizontal: 10)),
        visualDensity: VisualDensity.compact,
        foregroundColor: WidgetStatePropertyAll(cs.onSurface),
        textStyle: WidgetStatePropertyAll(Theme.of(context).textTheme.labelLarge),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed) || states.contains(WidgetState.focused)) {
            return cs.primary.withValues(alpha: 0.12);
          }
          if (states.contains(WidgetState.hovered)) {
            return cs.primary.withValues(alpha: 0.06);
          }
          return Colors.transparent;
        }),
      ),
      menuChildren: children,
      child: Text(label),
    );
  }

  Widget _item(BuildContext context, MenuAction action, String label, {String? shortcut}) {
    return MenuItemButton(
      onPressed: () => onAction(action),
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        padding: WidgetStatePropertyAll(const EdgeInsets.symmetric(horizontal: 16, vertical: 6)),
      ),
      trailingIcon: shortcut != null
          ? Padding(
              padding: const EdgeInsets.only(left: 32),
              child: Text(
                shortcut,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          : null,
      child: Text(label),
    );
  }

  static Widget _sep() => const Divider(height: 1);
}

class _WindowControls extends StatelessWidget {
  const _WindowControls();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: windowMaximizedNotifier,
      builder: (context, maximized, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _WindowButton(
              icon: Icons.horizontal_rule,
              onTap: () => windowMinimize(),
            ),
            _WindowButton(
              icon: maximized ? Icons.filter_none : Icons.crop_square,
              onTap: () => windowToggleMaximize(),
            ),
            _WindowButton(
              icon: Icons.close,
              onTap: () => windowClose(),
              isClose: true,
            ),
          ],
        );
      },
    );
  }
}

class _WindowButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isClose;

  const _WindowButton({
    required this.icon,
    required this.onTap,
    this.isClose = false,
  });

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = widget.isClose && _hovered
        ? Colors.red.withValues(alpha: 0.85)
        : _hovered
            ? theme.colorScheme.surfaceContainerHighest
            : Colors.transparent;
    final iconColor = widget.isClose && _hovered
        ? Colors.white
        : theme.colorScheme.onSurface;

    return SizedBox(
      width: 46,
      height: 48,
      child: Material(
        color: bgColor,
        child: InkWell(
          onTap: widget.onTap,
          onHover: (v) => setState(() => _hovered = v),
          mouseCursor: SystemMouseCursors.click,
          child: Icon(widget.icon, size: 16, color: iconColor),
        ),
      ),
    );
  }
}

class _MacTrafficLights extends StatelessWidget {
  const _MacTrafficLights();

  static const _red = Color(0xFFFF5F57);
  static const _yellow = Color(0xFFFFBD2E);
  static const _green = Color(0xFF28C840);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: windowMaximizedNotifier,
      builder: (context, maximized, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 12),
            _MacDot(color: _red, hoverIcon: Icons.close, iconColor: const Color(0xFF4D1A1A), onTap: () => windowClose()),
            const SizedBox(width: 8),
            _MacDot(color: _yellow, hoverIcon: Icons.horizontal_rule, iconColor: const Color(0xFF4D3A00), onTap: () => windowMinimize()),
            const SizedBox(width: 8),
            _MacDot(
              color: _green,
              hoverIcon: maximized ? Icons.filter_none : Icons.crop_square,
              iconColor: const Color(0xFF003D1A),
              onTap: () => windowToggleMaximize(),
            ),
            const SizedBox(width: 8),
          ],
        );
      },
    );
  }
}

class _MacDot extends StatefulWidget {
  final Color color;
  final IconData hoverIcon;
  final Color iconColor;
  final VoidCallback onTap;

  const _MacDot({
    required this.color,
    required this.hoverIcon,
    required this.iconColor,
    required this.onTap,
  });

  @override
  State<_MacDot> createState() => _MacDotState();
}

class _MacDotState extends State<_MacDot> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: _hovered ? widget.color.withValues(alpha: 0.8) : widget.color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 1,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: _hovered
                ? Center(child: Icon(widget.hoverIcon, size: 8, color: widget.iconColor))
                : null,
          ),
        ),
      ),
    );
  }
}
