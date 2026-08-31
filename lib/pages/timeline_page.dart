import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../utils/date_utils.dart';
import '../widgets/diary_card.dart';
import 'diary_detail_page.dart';
import 'calendar_page.dart';

class TimelinePage extends StatelessWidget {
  const TimelinePage({super.key});
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 18, 26),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        greeting(),
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '今天也值得被好好收藏',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: '日期查看',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CalendarPage()),
                  ),
                  icon: const Icon(Icons.calendar_month_rounded),
                ),
              ],
            ),
          ),
        ),
        if (state.diaries.isEmpty)
          const SliverFillRemaining(
            child: Center(child: Text('还没有日记，点击下方 ＋ 写下第一篇吧。')),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(8, 4, 18, 75),
            sliver: SliverList.builder(
              itemCount: state.diaries.length,
              itemBuilder: (context, index) {
                final diary = state.diaries[index];
                // Natural child height drives the stack; no intrinsic measurement
                // of asynchronous image widgets inside the sliver.
                return Padding(
                  key: ValueKey('timeline-${diary.id}'),
                  padding: const EdgeInsets.only(bottom: 22),
                  child: Stack(
                    children: [
                      if (state.showTimeline)
                        Positioned(
                          left: 14,
                          top: 2,
                          bottom: 0,
                          width: 14,
                          child: Column(
                            children: [
                              Container(
                                width: 13,
                                height: 13,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    width: 3,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 7),
                              Expanded(
                                child: Container(
                                  width: 2,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: .35),
                                ),
                              ),
                            ],
                          ),
                        ),
                      Padding(
                        padding: EdgeInsets.only(
                          left: state.showTimeline ? 42 : 8,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: 9,
                                left: 3,
                              ),
                              child: Text(
                                diaryDate(diary.diaryDate),
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                            DiaryCard(
                              diary: diary,
                              showSummary: state.showSummary,
                              fontSize: state.diaryFontSize,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      DiaryDetailPage(diaryId: diary.id!),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
