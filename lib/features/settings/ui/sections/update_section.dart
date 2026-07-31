import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/models/update_channel.dart';
import '../../../../core/services/app_version_service.dart';
import '../../../../core/services/update_service.dart';
import '../../../../core/utils/version.dart';
import '../../providers/settings_state.dart';
import '../widgets/section_card.dart';
import '../widgets/update_dialog.dart';

class UpdateSection extends StatelessWidget {
  const UpdateSection({super.key});

  Future<void> _check(BuildContext context) async {
    final settings = context.read<SettingsState>();
    final updater = context.read<UpdateService>();
    final result = await updater.checkForUpdates(
      channel: settings.updateChannel,
      current: Version.parse(AppVersionService.instance.version),
    );
    if (!context.mounted) return;
    if (result.status == UpdateCheckStatus.updateAvailable &&
        result.update != null) {
      showUpdateDialog(context, result.update!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final settings = context.watch<SettingsState>();
    final updater = context.watch<UpdateService>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionCard(
          icon: Icons.system_update,
          title: '更新',
          children: [
            _SwitchTile(
              label: '启动时检查更新',
              subtitle: '启动 Imagic 时自动检查新版本',
              value: settings.autoCheckUpdates,
              onChanged: (v) => settings.setAutoCheckUpdates(v),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text('更新渠道', style: Theme.of(context).textTheme.bodyMedium),
                const Spacer(),
                SegmentedButton<UpdateChannel>(
                  segments: UpdateChannel.values
                      .map((c) => ButtonSegment(value: c, label: Text(c.label)))
                      .toList(),
                  selected: {settings.updateChannel},
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) =>
                      settings.setUpdateChannel(selection.first),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '更新将下载绿色版安装包，校验 SHA-256 后自动替换文件并重启应用。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: updater.checking
                      ? null
                      : () => _check(context),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('检查更新'),
                ),
                const SizedBox(width: 16),
                Expanded(child: _status(context, updater)),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _status(BuildContext context, UpdateService updater) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    if (updater.checking) {
      return Row(
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text('正在检查更新...', style: theme.textTheme.bodySmall)),
        ],
      );
    }
    final result = updater.lastResult;
    if (result == null) {
      return Text(
        '尚未检查过更新',
        style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
      );
    }
    switch (result.status) {
      case UpdateCheckStatus.upToDate:
        return Text(
          '已是最新版本',
          style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        );
      case UpdateCheckStatus.error:
        return Text(
          result.error ?? '检查失败',
          style: theme.textTheme.bodySmall?.copyWith(color: cs.error),
        );
      case UpdateCheckStatus.updateAvailable:
        final update = result.update;
        return Row(
          children: [
            Expanded(
              child: Text(
                '发现新版本 v${update?.version}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.primary,
                ),
              ),
            ),
            TextButton(
              onPressed: update == null
                  ? null
                  : () => showUpdateDialog(context, update),
              child: const Text('查看'),
            ),
          ],
        );
    }
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
