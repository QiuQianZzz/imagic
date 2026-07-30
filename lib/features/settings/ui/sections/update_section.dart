import 'package:flutter/material.dart';

import '../widgets/section_card.dart';

class UpdateSection extends StatelessWidget {
  const UpdateSection({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionCard(
          icon: Icons.system_update,
          title: '检查更新',
          children: [
            Text(
              'TODO: 自动更新检查\n启动时自动检查新版本，支持手动检查更新。'
              '更新内容包括版本号、更新日志和下载链接。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ],
    );
  }
}
