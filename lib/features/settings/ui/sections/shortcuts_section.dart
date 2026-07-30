import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/shortcuts/shortcut_definitions.dart';
import '../../../../core/utils/key_labels.dart';
import '../../providers/settings_state.dart';
import '../widgets/section_card.dart';

class ShortcutsSection extends StatelessWidget {
  const ShortcutsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      icon: Icons.keyboard,
      title: '快捷键',
      children: [
        Text(
          '点击按键可重新绑定（支持 Ctrl/Alt/Shift 组合键），按 Esc 取消。',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        for (final action in shortcutActions) ...[
          _ShortcutItem(action: action),
          if (action != shortcutActions.last) const SizedBox(height: 4),
        ],
      ],
    );
  }
}

class _ShortcutItem extends StatefulWidget {
  final ShortcutAction action;

  const _ShortcutItem({required this.action});

  @override
  State<_ShortcutItem> createState() => _ShortcutItemState();
}

class _ShortcutItemState extends State<_ShortcutItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final state = context.watch<SettingsState>();
    final binding = state.getShortcutBinding(widget.action.id);
    final isCustom = state.isShortcutCustom(widget.action.id);
    final conflicts = state.findConflicts(widget.action.id, binding);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: _hovered ? cs.surfaceContainerHighest : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(10),
          splashFactory: InkRipple.splashFactory,
          splashColor: cs.primary.withValues(alpha: 0.12),
          highlightColor: cs.primary.withValues(alpha: 0.04),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.action.label,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                if (conflicts.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Tooltip(
                      message: '与「${conflicts.join('、')}」冲突',
                      child: Icon(
                        Icons.warning_amber_rounded,
                        size: 18,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ),
                if (isCustom)
                  _ResetButton(
                    hovered: _hovered,
                    onTap: () => state.resetShortcutBinding(widget.action.id),
                  ),
                _KeyCap(
                  label: bindingToLabel(binding),
                  isCustom: isCustom,
                  hovered: _hovered,
                  onTap: () => _startRebind(context, widget.action),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _startRebind(BuildContext context, ShortcutAction action) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _RebindDialog(action: action),
    );
  }
}

class _ResetButton extends StatelessWidget {
  final bool hovered;
  final VoidCallback onTap;

  const _ResetButton({required this.hovered, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          splashFactory: InkRipple.splashFactory,
          splashColor: cs.primary.withValues(alpha: 0.2),
          highlightColor: cs.primary.withValues(alpha: 0.06),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(
              Icons.restart_alt,
              size: 16,
              color: hovered ? cs.primary : cs.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _KeyCap extends StatefulWidget {
  final String label;
  final bool isCustom;
  final bool hovered;
  final VoidCallback onTap;

  const _KeyCap({
    required this.label,
    required this.onTap,
    required this.hovered,
    this.isCustom = false,
  });

  @override
  State<_KeyCap> createState() => _KeyCapState();
}

class _KeyCapState extends State<_KeyCap> {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final foreground = cs.surfaceContainerLow;
    final border = widget.hovered
        ? cs.primary
        : widget.isCustom
        ? cs.tertiary.withValues(alpha: 0.6)
        : cs.outlineVariant;

    final shadow = [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.15),
        blurRadius: widget.hovered ? 6 : 3,
        offset: Offset(0, widget.hovered ? 3 : 2),
      ),
    ];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: foreground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border, width: 1.0),
        boxShadow: shadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(8),
          splashFactory: InkRipple.splashFactory,
          splashColor: cs.primary.withValues(alpha: 0.25),
          highlightColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            child: Text(
              widget.label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
                color: widget.hovered
                    ? cs.primary
                    : widget.isCustom
                    ? cs.tertiary
                    : cs.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RebindDialog extends StatefulWidget {
  final ShortcutAction action;

  const _RebindDialog({required this.action});

  @override
  State<_RebindDialog> createState() => _RebindDialogState();
}

class _RebindDialogState extends State<_RebindDialog> {
  final FocusNode _focusNode = FocusNode();
  LogicalKeyboardKey? _capturedKey;
  int _capturedMods = 0;
  int _pressedMods = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _focusNode.requestFocus(),
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text('绑定快捷键：${widget.action.label}'),
      content: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
            Navigator.of(context).pop();
            return KeyEventResult.handled;
          }
          if (_isModifierKey(event.logicalKey)) {
            final kb = HardwareKeyboard.instance;
            var mods = 0;
            if (kb.isControlPressed) mods |= 1 << ShortcutModifier.ctrl.index;
            if (kb.isAltPressed) mods |= 1 << ShortcutModifier.alt.index;
            if (kb.isShiftPressed) mods |= 1 << ShortcutModifier.shift.index;
            if (kb.isMetaPressed) mods |= 1 << ShortcutModifier.meta.index;
            if (mods != _pressedMods) {
              setState(() => _pressedMods = mods);
            }
            return KeyEventResult.ignored;
          }
          if (event is KeyUpEvent) return KeyEventResult.ignored;
          final key = event.logicalKey;
          final kb = HardwareKeyboard.instance;
          var mods = 0;
          if (kb.isControlPressed) mods |= 1 << ShortcutModifier.ctrl.index;
          if (kb.isAltPressed) mods |= 1 << ShortcutModifier.alt.index;
          if (kb.isShiftPressed) mods |= 1 << ShortcutModifier.shift.index;
          if (kb.isMetaPressed) mods |= 1 << ShortcutModifier.meta.index;
          final binding = ShortcutBinding(keyId: key.keyId, modifiers: mods);
          setState(() {
            _capturedKey ??= key;
            _capturedMods = mods;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _onBindingSelected(context, binding);
          });
          return KeyEventResult.handled;
        },
        child: Container(
          width: 300,
          height: 150,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Center(
            child: _capturedKey != null
                ? _CapturedDisplay(
                    capturedKey: _capturedKey!,
                    modifiers: _capturedMods,
                  )
                : _pressedMods != 0
                    ? _ModifierHintDisplay(mods: _pressedMods)
                    : _WaitingDisplay(cs: cs),
          ),
        ),
      ),
    );
  }

  bool _isModifierKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.shiftLeft ||
        key == LogicalKeyboardKey.shiftRight ||
        key == LogicalKeyboardKey.controlLeft ||
        key == LogicalKeyboardKey.controlRight ||
        key == LogicalKeyboardKey.altLeft ||
        key == LogicalKeyboardKey.altRight ||
        key == LogicalKeyboardKey.metaLeft ||
        key == LogicalKeyboardKey.metaRight;
  }

  void _onBindingSelected(BuildContext context, ShortcutBinding binding) {
    final state = context.read<SettingsState>();
    final conflicts = state.findConflicts(widget.action.id, binding);
    if (conflicts.isEmpty) {
      state.setShortcutBinding(widget.action.id, binding);
      Navigator.of(context).pop();
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange.shade700,
              size: 22,
            ),
            const SizedBox(width: 8),
            const Text('快捷键冲突'),
          ],
        ),
        content: Text('该快捷键已被「${conflicts.join('、')}」使用。是否仍然绑定？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              state.setShortcutBinding(widget.action.id, binding);
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: const Text('仍然绑定'),
          ),
        ],
      ),
    );
  }
}

class _WaitingDisplay extends StatelessWidget {
  final ColorScheme cs;

  const _WaitingDisplay({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.keyboard, size: 32, color: cs.primary),
        const SizedBox(height: 8),
        Text(
          '按下快捷键（支持组合键）',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '按 Esc 或点击外部取消',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _CapturedDisplay extends StatelessWidget {
  final LogicalKeyboardKey capturedKey;
  final int modifiers;

  const _CapturedDisplay({required this.capturedKey, required this.modifiers});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _KeyCap(
          label: bindingToLabel(ShortcutBinding(keyId: capturedKey.keyId, modifiers: modifiers)),
          hovered: false,
          onTap: () {},
        ),
        const SizedBox(height: 14),
        Text(
          '按 Esc 或点击外部取消',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ModifierHintDisplay extends StatelessWidget {
  final int mods;

  const _ModifierHintDisplay({required this.mods});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final combo = modifiersFromBitmask(mods);
    final labels = <String>[];
    if (combo.contains(ShortcutModifier.ctrl)) labels.add('Ctrl');
    if (combo.contains(ShortcutModifier.alt)) labels.add('Alt');
    if (combo.contains(ShortcutModifier.shift)) labels.add('Shift');
    if (combo.contains(ShortcutModifier.meta)) labels.add('Meta');
    final hint = labels.isEmpty ? '?' : '${labels.join('+')}+...';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _KeyCap(
          label: hint,
          hovered: false,
          onTap: () {},
        ),
        const SizedBox(height: 14),
        Text(
          '再按一个非修饰键完成绑定',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
