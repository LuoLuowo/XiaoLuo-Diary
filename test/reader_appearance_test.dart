import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaoluo_diary/database/app_database.dart';
import 'package:xiaoluo_diary/models/diary_entry.dart';
import 'package:xiaoluo_diary/pages/diary_detail_page.dart';
import 'package:xiaoluo_diary/pages/image_preview_page.dart';
import 'package:xiaoluo_diary/pages/theme_page.dart';
import 'package:xiaoluo_diary/repositories/diary_repository.dart';
import 'package:xiaoluo_diary/services/app_state.dart';
import 'package:xiaoluo_diary/services/storage_service.dart';
import 'package:xiaoluo_diary/theme/app_backdrop.dart';
import 'package:xiaoluo_diary/theme/app_theme.dart';
import 'package:xiaoluo_diary/theme/theme_controller.dart';
import 'package:xiaoluo_diary/widgets/diary_card.dart';
import 'package:xiaoluo_diary/widgets/live_photo_badge.dart';

DiaryEntry entry(
  int id, {
  String content = '阅读文字',
  String rich = '',
  List<String> images = const [],
  List<String> videos = const [],
}) => DiaryEntry(
  id: id,
  title: '日记$id',
  content: content,
  richContent: rich,
  diaryDate: DateTime(2026, 8, 31 - id),
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  category: '',
  tags: [],
  images: images,
  videos: videos,
  attachments: [],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppState state;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    state = AppState(DiaryRepository(AppDatabase()), StorageService());
  });

  Widget reader(int id) => ChangeNotifierProvider.value(
    value: state,
    child: MaterialApp(
      localizationsDelegates: FlutterQuillLocalizations.localizationsDelegates,
      home: DiaryDetailPage(diaryId: id),
    ),
  );

  testWidgets(
    'reading text never focuses the editor; swipe changes diary only at content boundary',
    (tester) async {
      state.diaries = [
        entry(
          1,
          rich: jsonEncode([
            {'insert': '阅读文字\n'},
          ]),
        ),
        entry(2, content: List.filled(90, '长篇内容需要先正常滚动阅读。').join('\n')),
        entry(3),
      ];
      await tester.pumpWidget(reader(1));
      await tester.pumpAndSettle();
      final editor = tester.widget<QuillEditor>(find.byType(QuillEditor));
      final before = editor.controller.document.toDelta().toJson();
      await tester.tap(find.byType(QuillEditor));
      await tester.pump();
      expect(editor.focusNode.hasFocus, isFalse);
      expect(tester.testTextInput.hasAnyClients, isFalse);
      expect(editor.controller.document.toDelta().toJson(), before);
      await tester.drag(find.byType(ListView).first, const Offset(0, -350));
      await tester.pumpAndSettle();
      expect(find.text('2 / 3'), findsOneWidget);
      await tester.drag(
        find.byType(ListView).hitTestable().first,
        const Offset(0, -150),
      );
      await tester.pumpAndSettle();
      expect(find.text('2 / 3'), findsOneWidget);
      final scroll = tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byType(ListView).hitTestable().first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      scroll.position.jumpTo(scroll.position.maxScrollExtent);
      await tester.pump();
      await tester.drag(
        find.byType(ListView).hitTestable().first,
        const Offset(0, -250),
      );
      await tester.pumpAndSettle();
      expect(find.text('3 / 3'), findsOneWidget);
      await tester.drag(
        find.byType(ListView).hitTestable().first,
        const Offset(0, 300),
      );
      await tester.pumpAndSettle();
      expect(find.text('2 / 3'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('timeline and non-editing reader mark live images', (
    tester,
  ) async {
    final root = Directory.systemTemp.createTempSync('live_badge_test_');
    final file = File('${root.path}/photo.jpg');
    file.writeAsBytesSync(img.encodeJpg(img.Image(width: 20, height: 30)));
    final diary = entry(
      1,
      images: [file.path],
      videos: ['${root.path}/live_photo.jpg.mp4'],
      rich: jsonEncode([
        {
          'insert': {'image': file.path},
        },
        {'insert': '\n'},
      ]),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DiaryCard(diary: diary, showSummary: true, onTap: () {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(LivePhotoBadge), findsOneWidget);
    state.diaries = [diary];
    await tester.pumpWidget(reader(1));
    await tester.pumpAndSettle();
    expect(find.byType(LivePhotoBadge), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'portrait photo and landscape motion keep exactly the same viewport',
    (tester) async {
      final root = Directory.systemTemp.createTempSync('live_viewport_test_');
      final file = File('${root.path}/portrait.png');
      file.writeAsBytesSync(img.encodePng(img.Image(width: 300, height: 400)));
      Widget preview(bool playing) => MaterialApp(
        home: Scaffold(
          body: StablePhotoViewport(
            path: file.path,
            motion: playing ? const ColoredBox(color: Colors.blue) : null,
            motionSize: const Size(1920, 1080),
          ),
        ),
      );
      await tester.pumpWidget(preview(false));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      final before = tester.getRect(
        find.byKey(const ValueKey('photo-viewport')),
      );
      await tester.pumpWidget(preview(true));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byKey(const ValueKey('photo-viewport'))),
        before,
      );
      await tester.pumpWidget(preview(false));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byKey(const ValueKey('photo-viewport'))),
        before,
      );
    },
  );

  test(
    'wallpaper, readability strength and decoration persist across restart',
    () async {
      final theme = ThemeController();
      await theme.setWallpaper('/app/appearance/saved.jpg');
      await theme.setWallpaperStrength(.24);
      await theme.setDecoration('leaves');
      final reloaded = ThemeController();
      await reloaded.load();
      expect(reloaded.wallpaperPath, '/app/appearance/saved.jpg');
      expect(reloaded.wallpaperStrength, .24);
      expect(reloaded.decoration, 'leaves');
      await reloaded.setWallpaper('');
      final cleared = ThemeController();
      await cleared.load();
      expect(cleared.wallpaperPath, isEmpty);
    },
  );

  testWidgets(
    'custom photo backgrounds render safely and tolerate missing files',
    (tester) async {
      final root = Directory.systemTemp.createTempSync('wallpaper_test_');
      final file = File('${root.path}/background.png');
      file.writeAsBytesSync(img.encodePng(img.Image(width: 40, height: 60)));
      for (final dark in [false, true]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? AppTheme.dark('night') : AppTheme.light('warm'),
            home: AppBackdrop(imagePath: file.path, strength: .9),
          ),
        );
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pumpAndSettle();
        expect(find.byType(Image), findsOneWidget);
        expect(tester.widget<Opacity>(find.byType(Opacity).first).opacity, .28);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(
        MaterialApp(home: AppBackdrop(imagePath: '${root.path}/missing.png')),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('theme previews fit a phone in light and dark mode', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final font = FontLoader('PreviewChinese')
      ..addFont(rootBundle.load('assets/fonts/SimHei.ttf'));
    await tester.runAsync(font.load);
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await tester.runAsync(icons.load);
    final theme = ThemeController();
    for (final dark in [false, true]) {
      final boundary = GlobalKey();
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: theme,
          child: MaterialApp(
            theme: (dark ? AppTheme.dark('night') : AppTheme.light('green'))
                .copyWith(
                  textTheme:
                      (dark ? AppTheme.dark('night') : AppTheme.light('green'))
                          .textTheme
                          .apply(fontFamily: 'PreviewChinese'),
                ),
            builder: (context, child) => RepaintBoundary(
              key: boundary,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AppBackdrop(decoration: dark ? 'stars' : 'leaves'),
                  if (child != null) child,
                ],
              ),
            ),
            home: const ThemePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final output = File(
          'output/appearance-v0713-${dark ? 'dark' : 'light'}.png',
        );
        await output.parent.create(recursive: true);
        await output.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
  });
}
