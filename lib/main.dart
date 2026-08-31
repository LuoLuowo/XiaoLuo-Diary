import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'app.dart';
import 'database/app_database.dart';
import 'repositories/diary_repository.dart';
import 'services/app_state.dart';
import 'services/storage_service.dart';
import 'theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  final database = AppDatabase();
  await database.initialize();
  final repository = DiaryRepository(database);
  final storage = StorageService();
  final themeController = ThemeController();
  await themeController.load();
  final appState = AppState(repository, storage);
  await appState.initialize();
  runApp(
    MultiProvider(
      providers: [
        Provider.value(value: repository),
        Provider.value(value: storage),
        ChangeNotifierProvider.value(value: appState),
        ChangeNotifierProvider.value(value: themeController),
      ],
      child: const XiaoluoDiaryApp(),
    ),
  );
}
