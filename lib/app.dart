import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:provider/provider.dart';
import 'pages/home_shell.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

class XiaoluoDiaryApp extends StatelessWidget {
  const XiaoluoDiaryApp({super.key});
  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>();
    return MaterialApp(
      title: '小罗日记',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [FlutterQuillLocalizations.delegate],
      themeMode: theme.mode,
      theme: AppTheme.light(theme.lightPalette),
      darkTheme: AppTheme.dark(theme.darkPalette),
      home: const HomeShell(),
    );
  }
}
