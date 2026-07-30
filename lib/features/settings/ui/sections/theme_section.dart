import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/settings_state.dart';
import '../widgets/section_card.dart';

const _kPresetColors = [
  0xFF5B8DEF,
  0xFF006D40,
  0xFF7C5800,
  0xFF9C27B0,
  0xFFD81B60,
  0xFFD32F2F,
  0xFFE64A19,
  0xFF5D4037,
  0xFF455A64,
  0xFF00897B,
  0xFF43A047,
  0xFF3949AB,
];

class ThemeSection extends StatelessWidget {
  const ThemeSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AppearanceCard(),
        SizedBox(height: 8),
        _SeedColorCard(),
        SizedBox(height: 8),
        _PalettePreviewCard(),
      ],
    );
  }
}

class _AppearanceCard extends StatelessWidget {
  const _AppearanceCard();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final state = context.watch<SettingsState>();
    return SectionCard(
      icon: Icons.brightness_6,
      title: '外观',
      children: [
        Row(
          children: [
            SizedBox(width: 160, child: Text('主题模式', style: Theme.of(context).textTheme.bodyMedium)),
            const Spacer(),
            SizedBox(
              width: 340,
              child: Align(
                alignment: Alignment.centerRight,
                child: SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(value: ThemeMode.system, label: Text('系统'), icon: Icon(Icons.brightness_auto)),
                    ButtonSegment(value: ThemeMode.light, label: Text('浅色'), icon: Icon(Icons.light_mode)),
                    ButtonSegment(value: ThemeMode.dark, label: Text('深色'), icon: Icon(Icons.dark_mode)),
                  ],
                  selected: {state.themeMode},
                  onSelectionChanged: (v) => state.setThemeMode(v.first),
                  showSelectedIcon: false,
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    mouseCursor: WidgetStatePropertyAll(SystemMouseCursors.click),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          '使用 Material Design 3 配色方案，自动基于种子颜色生成完整色调体系。',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _SeedColorCard extends StatelessWidget {
  const _SeedColorCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final state = context.watch<SettingsState>();
    return SectionCard(
      icon: Icons.color_lens,
      title: '种子颜色',
      children: [
        Text(
          '选择主题色，Imagic 将自动生成完整的 Material 3 调色板。',
          style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        Text('预设', style: theme.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final color in _kPresetColors)
              _ColorChip(
                color: color,
                selected: state.seedColor == color,
                onTap: () => state.setSeedColor(color),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text('自定义', style: theme.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final color in state.customSeedColors)
              _ColorChip(
                color: color,
                selected: state.seedColor == color,
                onTap: () => state.setSeedColor(color),
                onDelete: () => _deleteColor(context, state, color),
              ),
            _AddColorChip(onTap: () => _pickCustomColor(context, state)),
          ],
        ),
      ],
    );
  }

  Future<void> _pickCustomColor(BuildContext context, SettingsState state) async {
    final current = Color(state.seedColor);
    final picked = await showDialog<Color>(
      context: context,
      builder: (_) => _ColorPickerDialog(initial: current),
    );
    if (picked != null && context.mounted) {
      state.addCustomColor(picked.toARGB32());
    }
  }

  void _deleteColor(BuildContext context, SettingsState state, int color) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除颜色'),
        content: const Text('确定要移除此自定义颜色吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              state.removeCustomColor(color);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

class _ColorChip extends StatefulWidget {
  final int color;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _ColorChip({
    required this.color,
    required this.selected,
    required this.onTap,
    this.onDelete,
  });

  @override
  State<_ColorChip> createState() => _ColorChipState();
}

class _ColorChipState extends State<_ColorChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bright = _brightness(widget.color) > 0.5;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onSecondaryTap: widget.onDelete,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Stack(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Color(widget.color),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: widget.selected ? cs.primary : cs.outlineVariant,
                    width: widget.selected ? 2.5 : 1,
                  ),
                ),
                child: widget.selected
                    ? Icon(Icons.check, color: bright ? Colors.black87 : Colors.white, size: 22)
                    : null,
              ),
              if (widget.onDelete != null && _hovered)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Material(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: widget.onDelete,
                      mouseCursor: SystemMouseCursors.click,
                      child: Container(
                        width: 20,
                        height: 20,
                        alignment: Alignment.center,
                        child: Icon(Icons.close, size: 14, color: cs.onSurfaceVariant),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static double _brightness(int hex) {
    return (((hex >> 16) & 0xFF) * 0.299 +
            ((hex >> 8) & 0xFF) * 0.587 +
            (hex & 0xFF) * 0.114) / 255;
  }
}

class _AddColorChip extends StatelessWidget {
  final VoidCallback onTap;
  const _AddColorChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Icon(Icons.add, color: cs.onSurfaceVariant, size: 24),
        ),
      ),
    );
  }
}

class _ColorPickerDialog extends StatefulWidget {
  final Color initial;
  const _ColorPickerDialog({required this.initial});

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late double _hue;

  @override
  void initState() {
    super.initState();
    _hue = HSVColor.fromColor(widget.initial).hue;
  }

  Color get _currentColor => HSVColor.fromAHSV(1, _hue, 1, 0.8).toColor();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('选择自定义颜色'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 48,
              width: double.infinity,
              decoration: BoxDecoration(
                color: _currentColor,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Text('色相', style: Theme.of(context).textTheme.bodySmall),
                const Spacer(),
                Text('${_hue.round()}°',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            _hueSlider(),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('取消')),
        FilledButton(onPressed: () => Navigator.of(context).pop(_currentColor), child: const Text('确定')),
      ],
    );
  }

  Widget _hueSlider() {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 24,
        trackShape: const _HueTrackShape(),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
        activeTrackColor: Colors.transparent,
        inactiveTrackColor: Colors.transparent,
      ),
      child: Slider(value: _hue, min: 0, max: 360, onChanged: (v) => setState(() => _hue = v)),
    );
  }
}

class _HueTrackShape extends SliderTrackShape {
  const _HueTrackShape();

  @override
  Rect getPreferredRect({required RenderBox parentBox, Offset offset = Offset.zero, required SliderThemeData sliderTheme, bool isEnabled = false, bool isDiscrete = false}) {
    final thumbW = sliderTheme.thumbShape!.getPreferredSize(isEnabled, isDiscrete).width;
    return Rect.fromLTWH(
      offset.dx + thumbW / 2,
      offset.dy + (parentBox.size.height - sliderTheme.trackHeight!) / 2,
      parentBox.size.width - thumbW,
      sliderTheme.trackHeight!,
    );
  }

  @override
  void paint( PaintingContext context, Offset offset, {required RenderBox parentBox, required SliderThemeData sliderTheme, required Animation<double> enableAnimation, required TextDirection textDirection, required Offset thumbCenter, Offset? secondaryOffset, bool isEnabled = false, bool isDiscrete = false}) {
    final trackH = sliderTheme.trackHeight!;
    final fullRect = Rect.fromLTWH(
      offset.dx,
      offset.dy + (parentBox.size.height - trackH) / 2,
      parentBox.size.width,
      trackH,
    );
    final canvas = context.canvas;
    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFFCC0000), Color(0xFFCCCC00), Color(0xFF00CC00),
          Color(0xFF00CCCC), Color(0xFF0000CC), Color(0xFFCC00CC), Color(0xFFCC0000),
        ],
      ).createShader(fullRect);
    canvas.drawRRect(RRect.fromRectAndRadius(fullRect, const Radius.circular(12)), paint);
  }
}

class _PalettePreviewCard extends StatelessWidget {
  const _PalettePreviewCard();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SettingsState>();
    final cs = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final p = ColorScheme.fromSeed(seedColor: Color(state.seedColor), brightness: brightness);
    return SectionCard(
      icon: Icons.palette,
      title: '调色板预览',
      children: [
        Text(
          '基于当前种子颜色生成的 MD3 色调方案预览。',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 16,
          children: [
            _PaletteCard(label: 'Primary', items: [
              (p.primary, 'primary'),
              (p.onPrimary, 'onPrimary'),
              (p.primaryContainer, 'container'),
              (p.onPrimaryContainer, 'onContainer'),
            ]),
            _PaletteCard(label: 'Secondary', items: [
              (p.secondary, 'secondary'),
              (p.onSecondary, 'onSecondary'),
              (p.secondaryContainer, 'container'),
              (p.onSecondaryContainer, 'onContainer'),
            ]),
            _PaletteCard(label: 'Tertiary', items: [
              (p.tertiary, 'tertiary'),
              (p.onTertiary, 'onTertiary'),
              (p.tertiaryContainer, 'container'),
              (p.onTertiaryContainer, 'onContainer'),
            ]),
            _PaletteCard(label: 'Neutral', items: [
              (p.surface, 'surface'),
              (p.surfaceContainerLow, 'surfaceLow'),
              (p.surfaceContainerHigh, 'surfaceHigh'),
              (p.outline, 'outline'),
            ]),
            _PaletteCard(label: 'Error', items: [
              (p.error, 'error'),
              (p.onError, 'onError'),
              (p.errorContainer, 'container'),
              (p.onErrorContainer, 'onContainer'),
            ]),
          ],
        ),
      ],
    );
  }
}

class _PaletteCard extends StatelessWidget {
  final String label;
  final List<(Color, String)> items;

  const _PaletteCard({required this.label, required this.items});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 224,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: cs.onSurfaceVariant,
          )),
          const SizedBox(height: 8),
          _row(items[0], items[1], context, cs),
          const SizedBox(height: 6),
          _row(items[2], items[3], context, cs),
        ],
      ),
    );
  }

  Widget _row((Color, String) a, (Color, String) b, BuildContext context, ColorScheme cs) {
    return Row(
      children: [
        _swatch(a.$1, a.$2, context, cs),
        const SizedBox(width: 8),
        _swatch(b.$1, b.$2, context, cs),
      ],
    );
  }

  Widget _swatch(Color color, String name, BuildContext context, ColorScheme cs) {
    return Expanded(
      child: Row(
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3), width: 0.5),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(name, style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: 10,
              color: cs.onSurfaceVariant,
            ), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
