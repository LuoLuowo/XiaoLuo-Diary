import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../widgets/diary_card.dart';
import 'diary_detail_page.dart';
import 'search_page.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});
  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  late DateTime selected = DateTime.now();
  bool yearView = false;
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final days = DateTime(month.year, month.month + 1, 0).day;
    final offset = DateTime(month.year, month.month, 1).weekday % 7;
    final selectedDiaries = state.diaries
        .where((d) => _sameDay(d.diaryDate, selected))
        .toList();
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surface,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SearchPage()),
            ),
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 13),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, size: 20, color: scheme.onSurface),
                  SizedBox(width: 8),
                  Text(
                    '搜索日记',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: scheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              MenuAnchor(
                builder: (_, controller, _) => TextButton.icon(
                  onPressed: controller.open,
                  iconAlignment: IconAlignment.end,
                  icon: const Icon(Icons.keyboard_arrow_down),
                  label: Text(
                    '${month.year}年',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                menuChildren: [
                  for (int y = month.year - 4; y <= month.year + 4; y++)
                    MenuItemButton(
                      onPressed: () =>
                          setState(() => month = DateTime(y, month.month)),
                      child: Text('$y年'),
                    ),
                ],
              ),
              const Spacer(),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('月')),
                  ButtonSegment(value: true, label: Text('年')),
                ],
                selected: {yearView},
                onSelectionChanged: (v) => setState(() => yearView = v.first),
              ),
            ],
          ),
          if (!yearView) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: true,
                    icon: Icon(Icons.image_outlined),
                    label: Text('图片'),
                  ),
                  ButtonSegment(
                    value: false,
                    icon: Icon(Icons.more_horiz),
                    label: Text('点点'),
                  ),
                ],
                selected: {state.calendarImageView},
                onSelectionChanged: (value) =>
                    state.setCalendarImageView(value.first),
              ),
            ),
          ],
          const SizedBox(height: 18),
          if (yearView)
            _yearGrid(state)
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => setState(
                            () => month = DateTime(month.year, month.month - 1),
                          ),
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Expanded(
                          child: Text(
                            '${month.month}月',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        IconButton(
                          onPressed: () => setState(
                            () => month = DateTime(month.year, month.month + 1),
                          ),
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        for (final w in ['日', '一', '二', '三', '四', '五', '六'])
                          Expanded(
                            child: Text(
                              w,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 7,
                            childAspectRatio: 1,
                          ),
                      itemCount: offset + days,
                      itemBuilder: (_, i) {
                        if (i < offset) return const SizedBox.shrink();
                        final day = i - offset + 1;
                        final date = DateTime(month.year, month.month, day);
                        final dayDiaries = state.diaries
                            .where((d) => _sameDay(d.diaryDate, date))
                            .toList();
                        final count = dayDiaries.length;
                        String? imagePath;
                        for (final diary in dayDiaries) {
                          if (diary.images.isNotEmpty) {
                            imagePath = diary.images.first;
                            break;
                          }
                        }
                        final active = _sameDay(date, selected);
                        return InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => setState(() => selected = date),
                          child: Container(
                            margin: const EdgeInsets.all(2),
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              color: active
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.primaryContainer
                                  : null,
                              borderRadius: BorderRadius.circular(12),
                              border: active
                                  ? Border.all(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      width: 2,
                                    )
                                  : null,
                            ),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                if (state.calendarImageView &&
                                    imagePath != null)
                                  Image.file(
                                    File(imagePath),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) =>
                                        const SizedBox.shrink(),
                                  ),
                                if (state.calendarImageView &&
                                    imagePath != null)
                                  Container(
                                    color: Colors.black.withValues(alpha: .18),
                                  ),
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '$day',
                                      style: TextStyle(
                                        color:
                                            state.calendarImageView &&
                                                imagePath != null
                                            ? Colors.white
                                            : null,
                                        fontWeight: active
                                            ? FontWeight.w900
                                            : FontWeight.w600,
                                        shadows:
                                            state.calendarImageView &&
                                                imagePath != null
                                            ? const [
                                                Shadow(
                                                  blurRadius: 5,
                                                  color: Colors.black87,
                                                ),
                                              ]
                                            : null,
                                      ),
                                    ),
                                    if (count > 0 &&
                                        (!state.calendarImageView ||
                                            imagePath == null))
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: List.generate(
                                            count.clamp(1, 3),
                                            (_) => Container(
                                              width: 4,
                                              height: 4,
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 1,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.primary,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          if (!yearView) ...[
            const SizedBox(height: 26),
            Text(
              DateFormat('yyyy年M月d日').format(selected),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            if (selectedDiaries.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 30),
                child: Text(
                  '这一天还没有记录',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              for (final diary in selectedDiaries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
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
        ],
      ),
    );
  }

  Widget _yearGrid(AppState state) => GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: 180,
      childAspectRatio: 1.35,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
    ),
    itemCount: 12,
    itemBuilder: (_, i) {
      final count = state.diaries
          .where(
            (d) => d.diaryDate.year == month.year && d.diaryDate.month == i + 1,
          )
          .length;
      return Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(26),
          onTap: () => setState(() {
            month = DateTime(month.year, i + 1);
            yearView = false;
            selected = month;
          }),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${i + 1}月',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(
                  count == 0 ? '静待记录' : '$count 篇日记',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
