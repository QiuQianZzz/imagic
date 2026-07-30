import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/image_background.dart';
import '../../../../core/constants/image_formats.dart';
import '../../../../core/utils/image_background_painter.dart';
import '../../providers/settings_state.dart';
import '../widgets/section_card.dart';

class GeneralSection extends StatelessWidget {
  const GeneralSection({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SettingsState>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionCard(
          icon: Icons.swap_horiz,
          title: '图片切换',
          children: [
            _SwitchTile(
              label: '顶部导航栏切换按钮',
              value: state.showNavBarArrows,
              onChanged: (v) => state.setShowNavBarArrows(v),
            ),
            const SizedBox(height: 8),
            _SwitchTile(
              label: '顶部导航栏打开按钮',
              value: state.showNavBarOpen,
              onChanged: (v) => state.setShowNavBarOpen(v),
            ),
            const SizedBox(height: 8),
            _SwitchTile(
              label: '查看区域悬浮按钮',
              value: state.showFloatingArrows,
              onChanged: (v) => state.setShowFloatingArrows(v),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SectionCard(
          icon: Icons.photo,
          title: '图片背景',
          children: [
            Text(
              '选择图片透明区域下方显示的背景样式。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final bg in ImageBackground.values)
                  _BackgroundChip(
                    type: bg,
                    selected: state.imageBackground == bg,
                    onTap: () => state.setImageBackground(bg),
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        SectionCard(
          icon: Icons.integration_instructions,
          title: '系统集成',
          children: [
            if (!Platform.isWindows)
              _PlaceholderText('仅在 Windows 上提供系统集成选项')
            else ...[
              _SwitchTile(
                label: '文件关联',
                subtitle: '双击 ${kSupportedExtensions.join('/')} 用 Imagic 打开',
                value: state.fileAssociation,
                // TODO(system-integration): setFileAssociation 返回 Future<bool>，
                // 失败时应用 SnackBar 提示用户。详见 docs/架构设计.md 4.6.3。
                onChanged: (v) => state.setFileAssociation(v),
              ),
              const SizedBox(height: 8),
              _SwitchTile(
                label: '开机自启动',
                subtitle: '系统启动时自动运行 Imagic',
                value: state.autoStart,
                // TODO(system-integration): 同上，setAutoStart 失败时需 SnackBar 提示。
                onChanged: (v) => state.setAutoStart(v),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        SectionCard(
          icon: Icons.file_download,
          title: '导出',
          children: [_PlaceholderText('导出功能尚未实现')],
        ),
        const SizedBox(height: 8),
        SectionCard(
          icon: Icons.slideshow,
          title: '幻灯片',
          children: [_PlaceholderText('幻灯片功能尚未实现')],
        ),
        const SizedBox(height: 8),
        SectionCard(
          icon: Icons.history,
          title: '最近文件',
          children: [_PlaceholderText('最近文件功能尚未实现')],
        ),
      ],
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodyMedium),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          mouseCursor: SystemMouseCursors.click,
        ),
      ],
    );
  }
}

class _PlaceholderText extends StatelessWidget {
  final String text;
  const _PlaceholderText(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _BackgroundChip extends StatefulWidget {
  final ImageBackground type;
  final bool selected;
  final VoidCallback onTap;

  const _BackgroundChip({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_BackgroundChip> createState() => _BackgroundChipState();
}

class _BackgroundChipState extends State<_BackgroundChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final borderColor = widget.selected
        ? cs.primary
        : _hovered
        ? cs.onSurfaceVariant.withValues(alpha: 0.7)
        : cs.outlineVariant;
    final borderWidth = widget.selected ? 2.5 : (_hovered ? 1.5 : 1.0);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 72,
            height: 56,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(painter: ImageBackgroundPainter(widget.type)),
                  Material(
                    color: Colors.transparent,
                    child: Ink(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: borderColor,
                          width: borderWidth,
                        ),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: widget.onTap,
                      ),
                    ),
                  ),
                  if (widget.selected)
                    Positioned(
                      right: 4,
                      top: 4,
                      child: Icon(
                        Icons.check_circle,
                        size: 18,
                        color: cs.primary,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 72,
            child: Text(
              widget.type.label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: widget.selected ? cs.primary : cs.onSurfaceVariant,
                fontWeight: widget.selected
                    ? FontWeight.w600
                    : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
