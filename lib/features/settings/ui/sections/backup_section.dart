import 'package:flutter/material.dart';

import '../widgets/section_card.dart';

class BackupSection extends StatelessWidget {
  const BackupSection({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionCard(
          icon: Icons.backup,
          title: '配置备份',
          children: [
            Text(
              'TODO: 导出/导入设置\n将当前所有配置导出为 JSON 文件，'
              '也可从备份文件恢复配置。支持自动备份和版本管理。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ],
    );
  }
}
