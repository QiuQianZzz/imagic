import 'package:flutter/material.dart';

enum SettingsSection {
  general(Icons.tune, '常规'),
  theme(Icons.palette, '主题'),
  window(Icons.check_box_outline_blank, '窗口'),
  backup(Icons.backup, '备份'),
  about(Icons.info_outline, '关于'),
  update(Icons.system_update, '更新');

  final IconData icon;
  final String label;
  const SettingsSection(this.icon, this.label);
}
