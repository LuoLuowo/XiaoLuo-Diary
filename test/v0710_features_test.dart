import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:xiaoluo_diary/database/app_database.dart';
import 'package:xiaoluo_diary/models/diary_entry.dart';
import 'package:xiaoluo_diary/models/reading_book.dart';
import 'package:xiaoluo_diary/pages/annual_summary_page.dart';
import 'package:xiaoluo_diary/pages/reading_page.dart';
import 'package:xiaoluo_diary/pages/search_page.dart';
import 'package:xiaoluo_diary/pages/summary_editor_page.dart';
import 'package:xiaoluo_diary/repositories/diary_repository.dart';
import 'package:xiaoluo_diary/services/app_state.dart';
import 'package:xiaoluo_diary/services/storage_service.dart';
import 'package:xiaoluo_diary/widgets/diary_card.dart';
import 'package:xiaoluo_diary/widgets/loading_operation.dart';

class _State extends AppState {
  _State() : super(DiaryRepository(AppDatabase()), StorageService());
  @override
  Future<String> loadSummary(String key) async => summaries[key] ?? '';
  @override
  Future<void> saveSummary(String key, String value) async {
    summaries[key] = value;
    notifyListeners();
  }
}

DiaryEntry entry(int id, String title, List<String> tags) => DiaryEntry(
  id: id,
  title: title,
  content: '只是正文$id',
  diaryDate: DateTime(2026),
  createdAt: DateTime(2026, 1, id),
  updatedAt: DateTime(2026),
  category: '',
  tags: tags,
  images: [],
  attachments: [],
);

void main() {
  late _State state;
  setUp(() {
    state = _State();
  });
  Widget app(Widget child) => ChangeNotifierProvider<AppState>.value(
    value: state,
    child: MaterialApp(
      localizationsDelegates: FlutterQuillLocalizations.localizationsDelegates,
      home: child,
    ),
  );

  testWidgets('无标题日记保留正文且不创建标题占位', (tester) async {
    await tester.pumpWidget(
      app(
        Scaffold(
          body: DiaryCard(
            diary: entry(1, '', []),
            showSummary: true,
            onTap: () {},
          ),
        ),
      ),
    );
    expect(find.text('无标题日记'), findsNothing);
    expect(find.text('只是正文1'), findsOneWidget);
    final text = tester.widget<Text>(find.text('只是正文1'));
    expect(text.style?.fontSize, 16);
  });

  testWidgets('多标签能组合和取消，全部清空筛选', (tester) async {
    state.tags = ['生活', '学习'];
    state.diaries = [
      entry(1, '生活记录', ['生活']),
      entry(2, '学习记录', ['学习']),
      entry(3, '两者都有', ['生活', '学习']),
    ];
    await tester.pumpWidget(app(const SearchPage()));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, '#生活'));
    await tester.pumpAndSettle();
    expect(find.text('生活记录'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilterChip, '#学习'));
    await tester.pumpAndSettle();
    expect(find.text('生活记录'), findsNothing);
    expect(find.text('两者都有'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilterChip, '#生活'));
    await tester.pumpAndSettle();
    expect(find.text('学习记录'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, '全部'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widgetList<FilterChip>(find.byType(FilterChip))
          .every((e) => !e.selected),
      isTrue,
    );
  });

  testWidgets('阅读全部显示无标签感想，书籍独立切换', (tester) async {
    state.books = [
      ReadingBook(
        id: 1,
        title: '一本书',
        author: '',
        coverPath: '',
        notes: [
          const OutlineNote(id: '1', title: '第一条感想', content: '内容1'),
          const OutlineNote(id: '2', title: '第二条感想', content: '内容2'),
        ],
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    ];
    await tester.pumpWidget(app(const ReadingPage()));
    await tester.pumpAndSettle();
    expect(find.text('第一条感想'), findsOneWidget);
    expect(find.text('第二条感想'), findsOneWidget);
    await tester.tap(find.text('书籍 1'));
    await tester.pumpAndSettle();
    expect(find.text('一本书'), findsOneWidget);
    expect(find.text('第一条感想'), findsNothing);
  });

  testWidgets('未写月总结隐藏，已写月总结预览两行且可以展开', (tester) async {
    final year = DateTime.now().year;
    state.summaries['$year-01'] = '第一行\n第二行\n第三行';
    state.summaries['title_$year-01'] = '一月小结';
    await tester.pumpWidget(app(const AnnualSummaryPage()));
    await tester.pumpAndSettle();
    expect(find.text('一月小结'), findsOneWidget);
    expect(find.text('2月'), findsNothing);
    expect(tester.widget<Text>(find.text('第一行\n第二行\n第三行')).maxLines, 2);
    await tester.ensureVisible(find.text('展开本月总结'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('展开本月总结'));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.text('第一行\n第二行\n第三行')).maxLines, isNull);
    expect(find.text('写月总结'), findsOneWidget);
  });

  testWidgets('总结保存富文本并能重新恢复格式', (tester) async {
    String? saved;
    await tester.pumpWidget(
      app(
        SummaryEditorPage(
          heading: '年总结',
          plain: '测试文字',
          rich: '',
          title: '',
          withTitle: false,
          onSave: (_, plain, rich) async {
            saved = rich;
            expect(plain, '测试文字');
          },
        ),
      ),
    );
    final editor = tester
        .widget<QuillEditor>(find.byType(QuillEditor))
        .controller;
    editor.updateSelection(
      const TextSelection(baseOffset: 0, extentOffset: 4),
      ChangeSource.local,
    );
    editor.formatSelection(Attribute.bold);
    editor.formatSelection(Attribute.underline);
    editor.formatSelection(LinkAttribute('https://example.com'));
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    final restored = summaryDocument('', saved!);
    final first = (jsonDecode(saved!) as List).first as Map;
    expect(first['attributes']['bold'], true);
    expect(first['attributes']['underline'], true);
    expect(first['attributes']['link'], 'https://example.com');
    expect(restored.toPlainText().trim(), '测试文字');
  });

  testWidgets('加载窗口先出现，失败后只关闭自己并保留页面', (tester) async {
    final task = Completer<void>();
    bool failed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              child: const Text('开始'),
              onPressed: () async {
                try {
                  await runLoading(context, '处理文件', (_) => task.future);
                } catch (_) {
                  failed = true;
                }
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('开始'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('加载中'), findsOneWidget);
    task.completeError(StateError('模拟文件错误'));
    await tester.pumpAndSettle();
    expect(failed, true);
    expect(find.text('加载中'), findsNothing);
    expect(find.text('开始'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
