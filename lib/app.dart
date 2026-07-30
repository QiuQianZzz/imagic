import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/services/settings_service.dart';
import 'core/theme/app_theme.dart';
import 'features/browser/providers/browser_state.dart';
import 'features/settings/providers/settings_state.dart';
import 'features/viewer/providers/viewer_state.dart';
import 'features/viewer/ui/viewer_screen.dart';
import 'services/file_service.dart';
import 'services/image_codec_service.dart';

class ImagicApp extends StatelessWidget {
  final String? initialFile;
  final SettingsService settings;

  const ImagicApp({super.key, this.initialFile, required this.settings});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<FileService>(create: (_) => FileService()),
        Provider<ImageCodecService>(create: (_) => ImageCodecService()),
        ChangeNotifierProvider<SettingsState>(
          create: (_) => SettingsState(settings),
        ),
        ChangeNotifierProvider<BrowserState>(
          create: (_) => BrowserState(),
        ),
        ChangeNotifierProvider<ViewerState>(
          create: (_) => ViewerState(),
        ),
      ],
      child: Selector<SettingsState, ({ThemeMode themeMode, int seedColor})>(
        selector: (_, state) => (themeMode: state.themeMode, seedColor: state.seedColor),
        builder: (context, snapshot, _) {
          return ExcludeSemantics(
            child: MaterialApp(
              title: 'Imagic',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light(snapshot.seedColor),
              darkTheme: AppTheme.dark(snapshot.seedColor),
              themeMode: snapshot.themeMode,
              home: ViewerScreen(initialFile: initialFile),
            ),
          );
        },
      ),
    );
  }
}
