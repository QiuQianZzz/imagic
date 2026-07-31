import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
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
    final tt = Theme.of(context).textTheme;
    final updater = context.watch<UpdateService>();
    final busy = _busy(updater);
    final currentVer = AppVersionService.instance.version.toString();
    final newVer = update.version.toString();
    final isZip = update.assetType == AssetType.zip;

    return AlertDialog(
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.system_update_alt,
            color: cs.primary,
            size: 28,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '发现新版本',
                  style: tt.titleLarge,
                ),
                const SizedBox(height: 2),
                Text(
                  newVer,
                  style: tt.headlineSmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 版本对比：当前 → 新版本
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '当前版本',
                          style: tt.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          currentVer,
                          style: tt.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.trending_flat_rounded,
                    color: cs.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '新版本',
                          style: tt.labelSmall?.copyWith(
                            color: cs.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          newVer,
                          style: tt.titleMedium?.copyWith(
                            color: cs.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (update.body.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    Icons.article_outlined,
                    size: 18,
                    color: cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '更新日志',
                    style: tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 260),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: SingleChildScrollView(
                  child: MarkdownBody(
                    data: _stripVersionHeader(update.body),
                    selectable: true,
                    styleSheet: MarkdownStyleSheet.fromTheme(
                      Theme.of(context),
                    ).copyWith(
                      p: tt.bodyMedium,
                      // 更新日志层级浅，h1~h3 加粗加大，h4~h6 加粗但字号小
                      h1: tt.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      h2: tt.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      h3: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      h4: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      h5: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      h6: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      listBullet: tt.bodyMedium,
                      blockquoteDecoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(color: cs.primary, width: 3),
                        ),
                        color: cs.surfaceContainerHighest,
                      ),
                      codeblockDecoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: cs.outlineVariant),
                      ),
                      code: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        color: cs.primary,
                      ),
                      a: TextStyle(color: cs.primary),
                    ),
                    onTapLink: (text, href, title) {
                      if (href == null) return;
                      if (Platform.isWindows) {
                        Process.start('cmd', ['/c', 'start', '', href]);
                      }
                    },
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            ..._status(context, updater),
          ],
        ),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton.icon(
          onPressed: busy
              ? null
              : () => Navigator.of(context).pop(),
          icon: Icon(updater.stage == UpdateStage.error ? Icons.close : Icons.schedule),
          label: Text(updater.stage == UpdateStage.error ? '关闭' : '稍后'),
        ),
        FilledButton.icon(
          onPressed: busy
              ? null
              : () => _download(context, updater),
          icon: busy
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: cs.onPrimary,
                  ),
                )
              : Icon(isZip ? Icons.download_for_offline : Icons.install_desktop),
          label: Text(busy
              ? (updater.stage == UpdateStage.downloading
                  ? '下载中'
                  : updater.stage == UpdateStage.verifying
                  ? '校验中'
                  : '准备中')
              : (isZip ? '下载并更新' : '下载并安装')),
        ),
      ],
    );
  }

  /// 剥离版本号标题行（仅 ## [version] 形式）+ 紧跟的所有空行。
  /// 保留其他 Markdown 语法（标题、列表、加粗、链接、代码等），由 MarkdownBody 渲染。
  ///
  /// - 弹窗顶部已显示版本号，CHANGELOG 里的 ## [version] 标题属于重复信息
  /// - release.yml 生成的正式版 body 已无标题，此处兜底处理手动创建 / 预发布的情况
  /// - 仅匹配 ## [ 开头的标题，保留其他级别标题（### 新特性 等）的 Markdown 结构
  /// - \n+ 与 release.yml L124 的行为对齐：删除标题后所有连续空行
  static String _stripVersionHeader(String markdown) {
    return markdown.replaceAllMapped(
      RegExp(r'^#{1,6}\s*\[[^\n]*\]\s*[^\n]*\n+', multiLine: true),
      (m) => '',
    );
  }

  List<Widget> _status(BuildContext context, UpdateService updater) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    switch (updater.stage) {
      case UpdateStage.downloading:
        final progress = updater.downloadProgress;
        final pct = progress == null ? null : (progress * 100).round();
        return [
          Row(
            children: [
              Icon(
                Icons.downloading_rounded,
                size: 16,
                color: cs.primary,
              ),
              const SizedBox(width: 6),
              Text(
                '正在下载${pct == null ? '' : ' $pct%'}',
                style: tt.labelLarge?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: progress == null
                ? const LinearProgressIndicator(minHeight: 8)
                : LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                  ),
          ),
        ];
      case UpdateStage.verifying:
        return [
          Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: cs.tertiary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '正在校验文件完整性（SHA-256）...',
                  style: tt.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ];
      case UpdateStage.installing:
        return [
          Row(
            children: [
              Icon(
                Icons.task_alt_rounded,
                size: 18,
                color: cs.tertiary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  update.assetType == AssetType.zip
                      ? '正在准备更新，应用即将重启...'
                      : '正在启动安装程序...',
                  style: tt.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ];
      case UpdateStage.error:
        return [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: cs.errorContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: cs.error.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 18,
                  color: cs.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    updater.installError ?? '更新失败',
                    style: tt.bodyMedium?.copyWith(
                      color: cs.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ];
      case UpdateStage.idle:
      case UpdateStage.done:
        return const [];
    }
  }
}
