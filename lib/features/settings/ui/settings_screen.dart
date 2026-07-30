import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../models/settings_section.dart';
import 'sections/general_section.dart';
import 'sections/theme_section.dart';
import 'sections/window_section.dart';
import 'sections/shortcuts_section.dart';
import 'sections/backup_section.dart';
import 'sections/about_section.dart';
import 'sections/update_section.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SettingsBody();
  }
}

class _SettingsBody extends StatefulWidget {
  const _SettingsBody();

  @override
  State<_SettingsBody> createState() => _SettingsBodyState();
}

class _SettingsBodyState extends State<_SettingsBody> {
  SettingsSection _section = SettingsSection.general;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: cs.surface,
            border: Border(bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.3))),
          ),
          child: Row(
            children: [
              const SizedBox(width: 4),
              SizedBox(
                width: 40,
                height: 48,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                  visualDensity: VisualDensity.compact,
                  mouseCursor: SystemMouseCursors.click,
                ),
              ),
              Icon(Icons.tune, size: 20, color: cs.primary),
              const SizedBox(width: 8),
              Expanded(
                child: _DragBar(
                  child: SizedBox(
                    height: 48,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('设置',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: SettingsSection.values.indexOf(_section),
            onDestinationSelected: (i) => setState(() => _section = SettingsSection.values[i]),
            labelType: NavigationRailLabelType.all,
            groupAlignment: 0,
            minWidth: 80,
            destinations: SettingsSection.values.map((s) =>
              NavigationRailDestination(
                icon: Icon(s.icon),
                selectedIcon: Icon(s.icon, color: cs.primary),
                label: Text(s.label),
              ),
            ).toList(),
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: 520,
                child: _buildSection(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection() {
    switch (_section) {
      case SettingsSection.theme:
        return const ThemeSection();
      case SettingsSection.window:
        return const WindowSection();
      case SettingsSection.backup:
        return const BackupSection();
      case SettingsSection.about:
        return const AboutSection();
      case SettingsSection.update:
        return const UpdateSection();
      case SettingsSection.general:
        return const GeneralSection();
      case SettingsSection.shortcuts:
        return const ShortcutsSection();
    }
  }
}

class _DragBar extends StatelessWidget {
  final Widget child;
  const _DragBar({required this.child});

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => windowManager.startDragging(),
      behavior: HitTestBehavior.translucent,
      child: child,
    );
  }
}
