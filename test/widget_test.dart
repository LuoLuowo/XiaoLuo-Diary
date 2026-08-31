import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiaoluo_diary/models/diary_entry.dart';
import 'package:xiaoluo_diary/widgets/diary_card.dart';

void main() {
  testWidgets('日记卡片展示标题、摘要和标签', (tester) async {
    final now = DateTime(2026, 8, 29, 19, 20);
    final diary = DiaryEntry(
      id: 1,
      title: '炸酥肉',
      content: '今天自己尝试炸了一次酥肉，味道居然还不错。',
      diaryDate: now,
      createdAt: now,
      updatedAt: now,
      category: '生活',
      tags: const ['美食', '生活'],
      images: const [],
      attachments: const [],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DiaryCard(diary: diary, showSummary: true, onTap: () {}),
        ),
      ),
    );
    expect(find.text('炸酥肉'), findsOneWidget);
    expect(find.textContaining('今天自己尝试'), findsOneWidget);
    expect(find.text('#美食'), findsOneWidget);
  });
}
