import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/diary_entry.dart';
import '../services/app_state.dart';
import 'summary_editor_page.dart';

class AnnualSummaryPage extends StatefulWidget {
  const AnnualSummaryPage({super.key});
  @override
  State<AnnualSummaryPage> createState() => _AnnualSummaryPageState();
}

class _AnnualSummaryPageState extends State<AnnualSummaryPage> {
  late int year = DateTime.now().year;
  final Set<int> expandedMonths = {};
  bool expandedYear = false;
  bool loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!loaded) {
      loaded = true;
      _loadSummaries();
    }
  }

  Future<void> _loadSummaries() => Future.wait([
    context.read<AppState>().loadSummary('$year'),
    context.read<AppState>().loadSummary('rich_$year'),
    for (var month = 1; month <= 12; month++) ...[
      context.read<AppState>().loadSummary(
        'rich_$year-${month.toString().padLeft(2, '0')}',
      ),
      context.read<AppState>().loadSummary(
        '$year-${month.toString().padLeft(2, '0')}',
      ),
      context.read<AppState>().loadSummary(
        'title_$year-${month.toString().padLeft(2, '0')}',
      ),
    ],
  ]);

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final all = state.diaries;
    final years = {
      ...all.map((e) => e.diaryDate.year),
      DateTime.now().year,
    }.toList()..sort((a, b) => b.compareTo(a));
    if (!years.contains(year)) year = years.first;
    final diaries = all.where((e) => e.diaryDate.year == year).toList();
    final words = diaries.fold<int>(
      0,
      (sum, e) => sum + e.content.replaceAll(RegExp(r'\\s'), '').length,
    );
    final photos = diaries.fold<int>(0, (sum, e) => sum + e.images.length);
    return Scaffold(
      appBar: AppBar(title: const Text('年度总结')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 50),
        children: [
          Row(
            children: [
              Text(
                '$year 年',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              DropdownButton<int>(
                value: year,
                underline: const SizedBox.shrink(),
                items: [
                  for (final y in years)
                    DropdownMenuItem(value: y, child: Text('$y年')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      year = value;
                      expandedMonths.clear();
                    });
                    _loadSummaries();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primaryContainer,
                  Theme.of(context).colorScheme.tertiaryContainer,
                ],
              ),
              borderRadius: BorderRadius.circular(26),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _stat(context, '${diaries.length}', '篇日记'),
                _stat(context, '$words', '字'),
                _stat(context, '$photos', '张照片'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _yearSummary(context, state),
          const SizedBox(height: 28),
          Text(
            '月总结',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          TextButton.icon(
            onPressed: () => _chooseMonth(context, state),
            icon: const Icon(Icons.add),
            label: const Text('写月总结'),
          ),
          const SizedBox(height: 12),
          for (var month = 1; month <= 12; month++)
            _monthCard(context, state, diaries, month),
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String value, String label) => Column(
    children: [
      Text(
        value,
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
      ),
      Text(
        label,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    ],
  );

  Widget _yearSummary(BuildContext context, AppState state) {
    final content = state.summaryFor('$year');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '$year 年总结',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => _editSummary(
                    context,
                    state,
                    '$year',
                    '$year 年总结',
                    '这一年，有哪些想留给自己的话？',
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (expandedYear && state.summaryFor('rich_$year').isNotEmpty)
              SummaryContent(
                key: ValueKey(state.summaryFor('rich_$year')),
                plain: content,
                rich: state.summaryFor('rich_$year'),
              )
            else
              Text(
                content.isEmpty ? '这一年，有哪些想留给自己的话？' : content,
                maxLines: expandedYear ? null : 5,
                overflow: expandedYear ? null : TextOverflow.ellipsis,
                style: TextStyle(
                  height: 1.65,
                  color: content.isEmpty
                      ? Theme.of(context).colorScheme.onSurfaceVariant
                      : null,
                ),
              ),
            if (content.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => expandedYear = !expandedYear),
                  icon: Icon(
                    expandedYear
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                  ),
                  label: Text(expandedYear ? '收起年总结' : '展开年总结'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _monthCard(
    BuildContext context,
    AppState state,
    List<DiaryEntry> diaries,
    int month,
  ) {
    final values = diaries.where((e) => e.diaryDate.month == month).toList();
    final words = values.fold<int>(
      0,
      (sum, e) => sum + e.content.replaceAll(RegExp(r'\\s'), '').length,
    );
    final key = '$year-${month.toString().padLeft(2, '0')}';
    final content = state.summaryFor(key);
    final title = state.summaryFor('title_$key');
    final expanded = expandedMonths.contains(month);
    if (content.trim().isEmpty && title.trim().isEmpty)
      return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(child: Text('$month')),
            title: Text(
              title.isEmpty ? '$month月' : title,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              values.isEmpty ? '写下这个月的总结' : '${values.length} 篇日记 · $words 字',
            ),
            trailing: IconButton(
              onPressed: () => _editSummary(
                context,
                state,
                key,
                '$year 年 $month 月总结',
                '这个月，留下些什么心情和收获？',
                withTitle: true,
              ),
              icon: const Icon(Icons.edit_outlined, size: 20),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: expanded && state.summaryFor('rich_$key').isNotEmpty
                  ? SummaryContent(
                      key: ValueKey(state.summaryFor('rich_$key')),
                      plain: content,
                      rich: state.summaryFor('rich_$key'),
                    )
                  : Text(
                      content,
                      maxLines: expanded ? null : 2,
                      overflow: expanded ? null : TextOverflow.ellipsis,
                      style: const TextStyle(height: 1.65),
                    ),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(
                () => expanded
                    ? expandedMonths.remove(month)
                    : expandedMonths.add(month),
              ),
              icon: Icon(
                expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              ),
              label: Text(expanded ? '收起本月总结' : '展开本月总结'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _chooseMonth(BuildContext context, AppState state) async {
    final month = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * .6,
          child: ListView(
            children: [
              const ListTile(title: Text('选择要写总结的月份')),
              for (var month = 1; month <= 12; month++)
                ListTile(
                  title: Text('$year年$month月'),
                  onTap: () => Navigator.pop(sheetContext, month),
                ),
            ],
          ),
        ),
      ),
    );
    if (month == null || !context.mounted) return;
    await _editSummary(
      context,
      state,
      '$year-${month.toString().padLeft(2, '0')}',
      '$year 年 $month 月总结',
      '',
      withTitle: true,
    );
  }

  Future<void> _editSummary(
    BuildContext context,
    AppState state,
    String key,
    String heading,
    String hint, {
    bool withTitle = false,
  }) async {
    final plain = await state.loadSummary(key);
    final rich = await state.loadSummary('rich_$key');
    final title = await state.loadSummary('title_$key');
    if (!context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SummaryEditorPage(
          heading: heading,
          plain: plain,
          rich: rich,
          title: title,
          withTitle: withTitle,
          onSave: (title, plain, rich) async {
            await state.saveSummary(key, plain);
            await state.saveSummary('rich_$key', rich);
            if (withTitle) await state.saveSummary('title_$key', title);
          },
        ),
      ),
    );
  }
}
