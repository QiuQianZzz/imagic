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
          '点击快捷键可重新绑定，按 Esc 取消。',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        for (final action in shortcutActions) ...[
          _ShortcutItem(action: action),
          const SizedBox(height: 4),
        ],
      ],
    );
  }
}

class _ShortcutItem extends StatelessWidget {
  final ShortcutAction action;

  const _ShortcutItem({required this.action});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SettingsState>();
    final key = state.getShortcutKey(action.id);
    final isCustom = state.isShortcutCustom(action.id);
    final conflicts = state.findConflicts(action.id, key);

    return Row(
      children: [
        Expanded(
          child: Text(
            action.label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        if (conflicts.isNotEmpty)
          Tooltip(
            message: '与「${conflicts.join('、')}」冲突',
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(
                Icons.warning_amber_rounded,
                size: 18,
                color: Colors.orange.shade700,
              ),
            ),
          ),
        if (isCustom)
          GestureDetector(
            onTap: () => state.resetShortcutBinding(action.id),
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Icon(
                  Icons.restart_alt,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        _KeyBadge(
          keyLabel: _toKeyLabel(key),
          onTap: () => _startRebind(context, action),
        ),
      ],
    );
  }

  void _startRebind(BuildContext context, ShortcutAction action) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _RebindDialog(action: action),
    );
  }

  String _toKeyLabel(LogicalKeyboardKey key) => keyToLabel(key);
}

class _KeyBadge extends StatelessWidget {
  final String keyLabel;
  final VoidCallback onTap;

  const _KeyBadge({required this.keyLabel, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Material(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(
              keyLabel,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
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
    return AlertDialog(
      title: Text('绑定快捷键：${widget.action.label}'),
      content: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.escape) {
              Navigator.of(context).pop();
              return KeyEventResult.handled;
            }
            if (event.logicalKey != LogicalKeyboardKey.shiftLeft &&
                event.logicalKey != LogicalKeyboardKey.shiftRight &&
                event.logicalKey != LogicalKeyboardKey.controlLeft &&
                event.logicalKey != LogicalKeyboardKey.controlRight &&
                event.logicalKey != LogicalKeyboardKey.altLeft &&
                event.logicalKey != LogicalKeyboardKey.altRight &&
                event.logicalKey != LogicalKeyboardKey.metaLeft &&
                event.logicalKey != LogicalKeyboardKey.metaRight) {
              _onKeySelected(context, event.logicalKey);
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: Container(
          width: 260,
          height: 120,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              '按下新快捷键...\n\n按 Esc 取消',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onKeySelected(BuildContext context, LogicalKeyboardKey key) {
    final state = context.read<SettingsState>();
    final conflicts = state.findConflicts(widget.action.id, key);
    if (conflicts.isEmpty) {
      state.setShortcutBinding(widget.action.id, key);
      Navigator.of(context).pop();
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('快捷键冲突'),
        content: Text('该快捷键已被「${conflicts.join('、')}」使用。是否仍然绑定？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              state.setShortcutBinding(widget.action.id, key);
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
