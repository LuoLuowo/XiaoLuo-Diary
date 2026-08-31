import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaoluo_diary/database/app_database.dart';
import 'package:xiaoluo_diary/models/diary_entry.dart';
import 'package:xiaoluo_diary/models/reading_book.dart';
import 'package:xiaoluo_diary/pages/home_shell.dart';
import 'package:xiaoluo_diary/pages/reading_page.dart';
import 'package:xiaoluo_diary/pages/plan_page.dart';
import 'package:xiaoluo_diary/repositories/diary_repository.dart';
import 'package:xiaoluo_diary/services/app_state.dart';
import 'package:xiaoluo_diary/services/storage_service.dart';
import 'package:xiaoluo_diary/utils/diary_media.dart';
import 'package:xiaoluo_diary/utils/reading_text_styles.dart';
import 'package:xiaoluo_diary/widgets/diary_media_embed.dart';
import 'package:xiaoluo_diary/widgets/photo_grid.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.root);
  final String root;
  @override
  Future<String?> getApplicationDocumentsPath() async => root;
}

DiaryEntry diary(int id, List<String> images, {String rich = ''}) => DiaryEntry(
  id: id,
  title: '日记$id',
  content: '正文$id',
  richContent: rich,
  diaryDate: DateTime(2026, 8, 30 - id),
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  category: '',
  tags: const [],
  images: images,
  attachments: const [],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  late PathProviderPlatform originalPaths;
  late AppState state;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    temp = await Directory.systemTemp.createTemp('xiaoluo_regression_');
    originalPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(temp.path);
    state = AppState(DiaryRepository(AppDatabase()), StorageService());
  });
  tearDown(() async {
    PathProviderPlatform.instance = originalPaths;
    for (var attempt = 0; attempt < 20; attempt++) {
      try {
        await temp.delete(recursive: true);
        break;
      } on FileSystemException catch (error) {
        // Flutter's Windows test engine retains decoded file mappings until
        // process exit, even after imageCache.clear. Only ignore that exact
        // teardown condition; media-deletion assertions above remain strict.
        if (attempt == 19) {
          if (Platform.isWindows && error.osError?.errorCode == 32) break;
          rethrow;
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
  });
  Widget app(Widget home) => ChangeNotifierProvider.value(
    value: state,
    child: MaterialApp(
      localizationsDelegates: FlutterQuillLocalizations.localizationsDelegates,
      home: home,
    ),
  );
  Future<String> photo(String name, int width, int height) async {
    final file = File(p.join(temp.path, name));
    await file.writeAsBytes(
      img.encodePng(img.Image(width: width, height: height)),
    );
    return file.path;
  }

  test('媒体移除后保存再打开不会复活；旧备份路径可恢复', () async {
    final path = await photo('photo.png', 20, 30);
    final legacy = diary(
      1,
      [path],
      rich: jsonEncode([
        {'insert': '正文\n'},
        {
          'insert': {'image': '/old/root/photo.png'},
        },
        {'insert': '\n'},
      ]),
    );
    final document = editableDiaryDocument(legacy);
    expect(documentMedia(document, 'image'), [path]);
    final offset = document.toPlainText().indexOf('\uFFFC');
    document.delete(offset, 1);
    final saved = legacy.copyWith(
      images: documentMedia(document, 'image'),
      richContent: jsonEncode(document.toDelta().toJson()),
    );
    expect(documentMedia(editableDiaryDocument(saved), 'image'), isEmpty);
    expect(
      File(path).existsSync(),
      isTrue,
    ); // Editing alone never deletes disk files.
  });

  test('永久清理释放实际字节，保护共享媒体、外部文件和备份', () async {
    final root = await state.storage.mediaRoot();
    final media = Directory(p.join(root.path, 'images'))
      ..createSync(recursive: true);
    final unused = File(p.join(media.path, 'unused.jpg'))
      ..writeAsBytesSync([1, 2, 3]);
    final shared = File(p.join(media.path, 'shared.jpg'))
      ..writeAsBytesSync([4, 5]);
    final backup = File(p.join(root.path, 'backup.zip'))..writeAsBytesSync([6]);
    final outside = File(p.join(temp.path, 'private.txt'))
      ..writeAsStringSync('keep');
    expect(await state.storage.totalBytes(), 5);
    expect(
      await state.storage.deleteUnusedMedia(
        {unused.path, shared.path, backup.path, outside.path},
        {shared.path},
      ),
      3,
    );
    expect(unused.existsSync(), isFalse);
    expect(
      shared.existsSync() && backup.existsSync() && outside.existsSync(),
      isTrue,
    );
    expect(await state.storage.totalBytes(), 2);
  });

  testWidgets('连续图片卡片按实际高度排列且键盘不抬升首页加号', (tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final paths = await tester.runAsync(
      () async => [
        await photo('portrait.png', 30, 40),
        await photo('landscape.png', 40, 30),
      ],
    );
    state.diaries = [diary(1, paths!), diary(2, paths), diary(3, paths)];
    await tester.pumpWidget(app(const HomeShell()));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    final first = tester.getRect(find.byKey(const ValueKey('timeline-1')));
    final second = tester.getRect(find.byKey(const ValueKey('timeline-2')));
    expect(second.top, greaterThanOrEqualTo(first.bottom));
    expect(first.height, greaterThan(150));
    final plus = find.byType(FloatingActionButton);
    final before = tester.getRect(plus);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    expect(tester.getRect(plus), before);
    tester.view.resetViewInsets();
    await tester.drag(
      find.byType(CustomScrollView).first,
      const Offset(0, -420),
    );
    await tester.pumpAndSettle();
    final third = tester.getRect(find.byKey(const ValueKey('timeline-3')));
    expect(
      third.top,
      greaterThanOrEqualTo(
        tester.getRect(find.byKey(const ValueKey('timeline-2'))).bottom,
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
  });

  testWidgets('时间轴拼图固定，详情网格才采用照片比例设置', (tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final paths = await tester.runAsync(
      () async => [
        await photo('one.png', 40, 30),
        await photo('two.png', 30, 40),
        await photo('three.png', 30, 40),
        await photo('four.png', 40, 30),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TimelinePhotoGrid(paths: paths!.take(2).toList())),
      ),
    );
    final two = tester.getRect(find.byType(Image).first);
    final twoSecond = tester.getRect(find.byType(Image).last);
    expect(two.width, closeTo(two.height, 1));
    expect(twoSecond.width, closeTo(twoSecond.height, 1));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TimelinePhotoGrid(paths: paths.take(3).toList())),
      ),
    );
    final three = find.byType(Image);
    expect(
      tester.getRect(three.at(0)).height,
      greaterThan(tester.getRect(three.at(1)).height),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TimelinePhotoGrid(paths: paths)),
      ),
    );
    final four = find.byType(Image);
    expect(tester.getRect(four.at(0)).size, tester.getRect(four.at(3)).size);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('点击图片上下留白可以换行输入，移除只改变正文', (tester) async {
    final path = (await tester.runAsync(() => photo('editor.png', 30, 40)))!;
    final document = Document.fromJson([
      {
        'insert': {'image': path},
      },
      {'insert': '\n'},
    ]);
    final controller = QuillController(
      document: document,
      selection: const TextSelection.collapsed(offset: 0),
    );
    final focus = FocusNode();
    await tester.pumpWidget(
      app(
        Scaffold(
          body: QuillEditor.basic(
            controller: controller,
            focusNode: focus,
            config: QuillEditorConfig(
              embedBuilders: [
                DiaryMediaEmbedBuilder(type: 'image', focusNode: focus),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('在媒体上方输入文字'));
    await tester.pumpAndSettle();
    controller.replaceText(controller.selection.baseOffset, 0, '图上文字', null);
    await tester.pumpAndSettle();
    expect(document.toPlainText(), startsWith('图上文字\n'));
    await tester.ensureVisible(find.bySemanticsLabel('在媒体下方输入文字'));
    await tester.tap(find.bySemanticsLabel('在媒体下方输入文字'));
    await tester.pumpAndSettle();
    controller.replaceText(controller.selection.baseOffset, 0, '图下文字', null);
    await tester.pumpAndSettle();
    expect(document.toPlainText(), contains('\uFFFC\n图下文字'));
    await tester.ensureVisible(find.byTooltip('移除媒体'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('移除媒体'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('移除'));
    await tester.pumpAndSettle();
    expect(documentMedia(document, 'image'), isEmpty);
    expect(File(path).existsSync(), isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    focus.dispose();
    controller.dispose();
  });

  ReadingBook book() => ReadingBook(
    id: 1,
    title: '测试书',
    author: '',
    coverPath: '',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    notes: List.generate(
      30,
      (i) => OutlineNote(id: '$i', title: '感悟$i', content: '详细内容$i'),
    ),
  );

  testWidgets('书籍默认收起，随机目标自动展开并滚动到视口', (tester) async {
    state.books = [book()];
    await tester.pumpWidget(app(const BookDetailPage(bookId: 1)));
    await tester.pumpAndSettle();
    expect(find.text('详细内容0'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      app(const BookDetailPage(bookId: 1, initialNoteId: '28')),
    );
    await tester.pumpAndSettle();
    expect(find.text('详细内容0'), findsNothing);
    expect(find.text('详细内容28'), findsOneWidget);
    final rect = tester.getRect(find.text('感悟28'));
    expect(rect.top, greaterThan(50));
    expect(rect.bottom, lessThan(600));
    expect(tester.takeException(), isNull);
  });

  testWidgets('阅读列表字号一致，退出后恢复草稿及富文本', (tester) async {
    state.books = [book().copyWith(notes: [])];
    await tester.pumpWidget(app(const BookDetailPage(bookId: 1)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('添加笔记'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '笔记标题'), '未写完的想法');
    final editor = tester.widget<QuillEditor>(find.byType(QuillEditor));
    editor.controller.document.insert(0, '草稿正文');
    editor.controller.formatText(0, 4, Attribute.bold);
    final context = tester.element(find.byType(QuillEditor));
    final styles = readingTextStyles(context, 14);
    expect(styles.lists!.style.fontSize, styles.paragraph!.style.fontSize);
    Navigator.of(context).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('添加笔记'));
    await tester.pumpAndSettle();
    expect(find.text('未写完的想法'), findsOneWidget);
    final restored = tester
        .widget<QuillEditor>(find.byType(QuillEditor))
        .controller;
    expect(restored.document.toPlainText(), contains('草稿正文'));
    expect(restored.document.toDelta().toJson().first['attributes'], {
      'bold': true,
    });
    Navigator.of(tester.element(find.byType(QuillEditor))).pop();
    await tester.pumpAndSettle();
    await state.setReadingFontSize(18);
    expect(
      (await SharedPreferences.getInstance()).getDouble('readingFontSize'),
      18,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('阅读编辑区更高，换行内容可升降大纲层级', (tester) async {
    state.books = [book().copyWith(notes: [])];
    await tester.pumpWidget(app(const BookDetailPage(bookId: 1)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('添加笔记'));
    await tester.pumpAndSettle();
    final editorFinder = find.byType(QuillEditor);
    expect(tester.getSize(editorFinder).height, greaterThan(240));
    final controller = tester.widget<QuillEditor>(editorFinder).controller;
    controller.replaceText(
      0,
      0,
      '根节点\n子节点',
      const TextSelection.collapsed(offset: 5),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('下一级'));
    await tester.pumpAndSettle();
    final indented = controller.document.toDelta().toJson();
    expect(
      indented.any((op) => (op['attributes'] as Map?)?['indent'] == 1),
      isTrue,
    );
    await tester.tap(find.text('上一级'));
    await tester.pumpAndSettle();
    final restored = controller.document.toDelta().toJson();
    expect(
      restored.any((op) => (op['attributes'] as Map?)?['indent'] == 1),
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('删除专注类型先确认，取消不删除', (tester) async {
    await tester.pumpWidget(app(const Scaffold(body: PlanPage())));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('删除当前专注类型'));
    await tester.pumpAndSettle();
    expect(find.text('删除专注类型？'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('删除专注类型？'), findsNothing);
    expect(find.textContaining('学习 专注'), findsOneWidget);
  });
}
