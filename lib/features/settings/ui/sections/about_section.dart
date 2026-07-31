import 'package:flutter/material.dart';

import '../../../../core/services/app_version_service.dart';
import '../widgets/section_card.dart';

class AboutSection extends StatelessWidget {
  const AboutSection({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Column(
            children: [
              const SizedBox(height: 32),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(Icons.image, size: 40, color: cs.onPrimaryContainer),
              ),
              const SizedBox(height: 16),
              Text('Imagic', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text('版本 ${AppVersionService.instance.version}', style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 32),
            ],
          ),
        ),
        SectionCard(
          icon: Icons.description,
          title: '说明',
          children: [
            Text(
              'Imagic 是一款基于 Flutter 的跨平台桌面图片查看与编辑工具。\n'
              '支持常见图片格式的浏览、缩放、编辑和导出。',
              style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ],
    );
  }
}
