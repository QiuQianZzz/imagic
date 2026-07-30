import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/window_style.dart';
import '../../providers/settings_state.dart';
import '../widgets/section_card.dart';

class WindowSection extends StatelessWidget {
  const WindowSection({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SettingsState>();
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionCard(
          icon: Icons.straighten,
          title: '窗口大小',
          children: [
            Text(
              'TODO: 窗口尺寸设置\n可分别设置默认宽度和高度，'
              '支持选择"记住窗口位置"和"启动时最大化"。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SectionCard(
          icon: Icons.radio_button_checked,
          title: '窗口控件样式',
          children: [
            SegmentedButton<WindowStyle>(
              segments: const [
                ButtonSegment(value: WindowStyle.windows, label: Text('Windows'), icon: Icon(Icons.window)),
                ButtonSegment(value: WindowStyle.macos, label: Text('macOS'), icon: Icon(Icons.circle) ),
              ],
              selected: {state.windowStyle},
              onSelectionChanged: (v) => state.setWindowStyle(v.first),
              showSelectedIcon: false,
            ),
          ],
        ),
      ],
    );
  }
}
