import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../widgets/diary_card.dart';
import 'diary_detail_page.dart';
import '../services/pomodoro_service.dart';

class DataOverviewPage extends StatelessWidget {
  const DataOverviewPage({super.key});
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final photos = state.diaries.fold<int>(
      0,
      (sum, diary) => sum + diary.images.length,
    );
    final words = state.diaries.fold<int>(
      0,
      (sum, diary) => sum + diary.content.replaceAll(RegExp(r'\s'), '').length,
    );
    final today = DateTime.now();
    final lastYear = state.diaries
        .where(
          (diary) =>
              diary.diaryDate.year == today.year - 1 &&
              diary.diaryDate.month == today.month &&
              diary.diaryDate.day == today.day,
        )
        .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 30, 22, 120),
      children: [
        Text(
          '数据',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 18),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.55,
          children: [
            _stat(context, Icons.photo_library_outlined, '$photos', '照片'),
            _stat(context, Icons.text_fields, '$words', '文字'),
            _stat(
              context,
              Icons.auto_stories_outlined,
              '${state.diaries.length}',
              '日记篇数',
            ),
            _stat(
              context,
              Icons.menu_book_outlined,
              '${state.books.fold<int>(0, (sum, book) => sum + book.notes.length)}',
              '阅读笔记',
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          '专注统计',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        FutureBuilder<List<FocusSession>>(
          future: PomodoroService.sessions(),
          builder: (context, snapshot) {
            final sessions = snapshot.data ?? const <FocusSession>[];
            final total = sessions.fold<int>(
              0,
              (sum, item) => sum + item.minutes,
            );
            final groups = <String, int>{};
            for (final item in sessions) {
              groups[item.type] = (groups[item.type] ?? 0) + item.minutes;
            }
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '累计 $total 分钟 · ${sessions.length} 次',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (groups.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text('完成一次番茄钟后，这里会显示专注记录。'),
                      ),
                    for (final entry in groups.entries)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Row(
                          children: [
                            Expanded(child: Text(entry.key)),
                            Text(
                              '${entry.value} 分钟',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (sessions.isNotEmpty) ...[
                      const Divider(height: 28),
                      const Text(
                        '最近专注',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      for (final session in sessions.reversed.take(10))
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.timer_outlined, size: 20),
                          title: Text(session.type),
                          subtitle: Text(
                            '${session.completedAt.month}月${session.completedAt.day}日 '
                            '${session.completedAt.hour.toString().padLeft(2, '0')}:'
                            '${session.completedAt.minute.toString().padLeft(2, '0')}',
                          ),
                          trailing: Text('${session.minutes} 分钟'),
                        ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 28),
        Text(
          '去年今日',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        if (lastYear.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(22),
              child: Text('去年的今天没有留下日记。'),
            ),
          )
        else
          for (final diary in lastYear)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: DiaryCard(
                diary: diary,
                showSummary: true,
                fontSize: state.diaryFontSize,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DiaryDetailPage(diaryId: diary.id!),
                  ),
                ),
              ),
            ),
      ],
    );
  }

  Widget _stat(
    BuildContext context,
    IconData icon,
    String value,
    String label,
  ) => Card(
    child: Padding(
      padding: const EdgeInsets.all(15),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 11),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(label),
            ],
          ),
        ],
      ),
    ),
  );
}
