import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/models/update_info.dart';
import '../../../../core/services/app_version_service.dart';
import '../../../../core/services/update_service.dart';

/// 弹出更新对话框：展示版本号、更新日志与安装进度。
Future<void> showUpdateDialog(BuildContext context, UpdateInfo update) {
  return showDialog<void>(
    context: context,
    // 更新安装期间不允许点击外部关闭，避免安装脚本与进程退出错位
    barrierDismissible: false,
    builder: (_) => UpdateDialog(update: update),
  );
}

class UpdateDialog extends StatelessWidget {
  final UpdateInfo update;

  const UpdateDialog({super.key, required this.update});

  bool _busy(UpdateService updater) =>
      updater.stage == UpdateStage.downloading ||
      updater.stage == UpdateStage.verifying ||
      updater.stage == UpdateStage.installing;

  Future<void> _download(BuildContext context, UpdateService updater) async {
    final result = await updater.downloadAndInstall(update);
    if (result.success) {
      if (update.assetType == AssetType.zip) {
        // 绿色版：安装脚本已启动（2 秒后替换文件），必须立即退出主进程，
        // 无论对话框是否还在。否则脚本会 taskkill 掉仍在使用的应用。
        exit(0);
      }
      // exe/msix：安装程序已启动，关闭对话框由用户接管剩余流程
      if (context.mounted) Navigator.of(context).pop();
    }
    // 失败：错误信息已通过 watch 驱动对话框内联显示
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final updater = context.watch<UpdateService>();
    return AlertDialog(
      title: Text('发现新版本 ${update.version}'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '当前版本 ${AppVersionService.instance.version} → 新版本 ${update.version}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            if (update.body.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('更新日志', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Container(
                constraints: const BoxConstraints(maxHeight: 240),
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    _plainText(update.body),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            ..._status(context, updater),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy(updater)
              ? null
              : () => Navigator.of(context).pop(),
          child: Text(updater.stage == UpdateStage.error ? '关闭' : '稍后'),
        ),
        FilledButton(
          onPressed: _busy(updater)
              ? null
              : () => _download(context, updater),
          child: Text(update.assetType == AssetType.zip
              ? '下载并更新'
              : '下载并安装'),
        ),
      ],
    );
  }

  /// 将 Markdown 正文转为更易读的纯文本：去除标题井号、加粗/斜体标记、
  /// 行内代码反引号等常见语法符号。不处理代码块与表格（更新日志极少含这些）。
  static String _plainText(String markdown) {
    var text = markdown;
    // 标题行：去掉行首 # 与空格
    text = text.replaceAllMapped(RegExp(r'^#{1,6}\s+'), (m) => '');
    // 加粗/斜体：**text** / *text* / __text__ / _text_
    text = text.replaceAllMapped(
      RegExp(r'(\*\*|__)(.+?)\1'),
      (m) => m.group(2)!,
    );
    text = text.replaceAllMapped(
      RegExp(r'(\*|_)(.+?)\1'),
      (m) => m.group(2)!,
    );
    // 行内代码：`text`
    text = text.replaceAllMapped(
      RegExp(r'`([^`]+)`'),
      (m) => m.group(1)!,
    );
    // 链接：[text](url) → text
    text = text.replaceAllMapped(
      RegExp(r'\[([^\]]+)\]\([^)]+\)'),
      (m) => m.group(1)!,
    );
    return text;
  }

  List<Widget> _status(BuildContext context, UpdateService updater) {
    final cs = Theme.of(context).colorScheme;
    switch (updater.stage) {
      case UpdateStage.downloading:
        final progress = updater.downloadProgress;
        return [
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(value: progress),
              ),
              const SizedBox(width: 8),
              Text(
                progress == null
                    ? '...'
                    : '${(progress * 100).round()}%',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
        ];
      case UpdateStage.verifying:
        return [
          Text('正在校验文件完整性（SHA-256）...',
              style: Theme.of(context).textTheme.bodySmall),
        ];
      case UpdateStage.installing:
        return [
          Text(
            update.assetType == AssetType.zip
                ? '正在准备更新，应用即将重启...'
                : '正在启动安装程序...',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ];
      case UpdateStage.error:
        return [
          Text(
            updater.installError ?? '更新失败',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: cs.error),
          ),
        ];
      case UpdateStage.idle:
      case UpdateStage.done:
        return const [];
    }
  }
}
