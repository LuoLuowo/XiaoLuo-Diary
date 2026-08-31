import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lunar/lunar.dart';

class CountdownPage extends StatefulWidget {
  const CountdownPage({super.key});
  @override
  State<CountdownPage> createState() => _CountdownPageState();
}

class _CountdownPageState extends State<CountdownPage> {
  List<Map<String, String>> items = [];
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final raw = (await SharedPreferences.getInstance()).getString('countdowns');
    if (raw != null && mounted)
      setState(
        () => items = (jsonDecode(raw) as List)
            .map((e) => Map<String, String>.from(e))
            .toList(),
      );
  }

  Future<void> _save() async => (await SharedPreferences.getInstance())
      .setString('countdowns', jsonEncode(items));
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('倒数日')),
    floatingActionButton: FloatingActionButton(
      onPressed: () => _editCountdown(),
      child: const Icon(Icons.add),
    ),
    body: items.isEmpty
        ? const Center(child: Text('添加一个值得期待的日子'))
        : ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: items.length,
            itemBuilder: (_, i) {
              final start = DateTime.parse(items[i]['date']!);
              final target = _nextOccurrence(
                start,
                items[i]['repeat'] ?? '不重复',
                items[i]['calendar'] ?? '公历',
              );
              final lunar = Lunar.fromDate(start);
              final days = target
                  .difference(
                    DateTime(
                      DateTime.now().year,
                      DateTime.now().month,
                      DateTime.now().day,
                    ),
                  )
                  .inDays;
              return Dismissible(
                key: ValueKey('${items[i]['title']}${items[i]['date']}'),
                onDismissed: (_) {
                  setState(() => items.removeAt(i));
                  _save();
                },
                child: Card(
                  child: ListTile(
                    title: Text(
                      items[i]['title']!,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${items[i]['repeat'] ?? '不重复'} · 公历 ${target.year}年${target.month}月${target.day}日\n输入方式：${items[i]['calendar'] ?? '公历'} · 农历 ${lunar.getMonthInChinese()}月${lunar.getDayInChinese()}',
                    ),
                    trailing: Text(
                      days >= 0 ? '$days 天' : '已过 ${-days} 天',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    onLongPress: () => _deleteItem(i),
                    onTap: () => _editCountdown(i),
                  ),
                ),
              );
            },
          ),
  );
  Future<void> _editCountdown([int? index]) async {
    final existing = index == null ? null : items[index];
    final controller = TextEditingController(text: existing?['title'] ?? '');
    var date = existing == null
        ? DateTime.now().add(const Duration(days: 30))
        : DateTime.parse(existing['date']!);
    var repeat = existing?['repeat'] ?? '不重复';
    var calendar = existing?['calendar'] ?? '公历';
    if (calendar == '阳历') calendar = '公历';
    var pinned = existing?['pinned'] == 'true';
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: Text(index == null ? '新建倒数日' : '编辑倒数日'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: '公历', label: Text('公历')),
                  ButtonSegment(value: '农历', label: Text('农历')),
                ],
                selected: {calendar},
                onSelectionChanged: (value) =>
                    setDialogState(() => calendar = value.first),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.event_note_outlined),
                  hintText: '输入事件名称',
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.today_outlined),
                title: const Text('目标日'),
                subtitle: Text(
                  '公历 ${date.year}-${date.month}-${date.day} · 农历${Lunar.fromDate(date).getMonthInChinese()}月${Lunar.fromDate(date).getDayInChinese()}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final picked = calendar == '农历'
                      ? await _showLunarDatePicker(dialogContext, date)
                      : await showDatePicker(
                          context: dialogContext,
                          firstDate: DateTime(1900),
                          lastDate: DateTime(2100),
                          initialDate: date,
                        );
                  if (picked != null) setDialogState(() => date = picked);
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.push_pin_outlined),
                title: const Text('置顶'),
                value: pinned,
                onChanged: (value) => setDialogState(() => pinned = value),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.repeat_rounded),
                title: const Text('重复'),
                trailing: DropdownButton<String>(
                  value: repeat,
                  underline: const SizedBox.shrink(),
                  items: [
                    for (final value in ['不重复', '每天', '每周', '每月', '每年'])
                      DropdownMenuItem(value: value, child: Text(value)),
                  ],
                  onChanged: (value) {
                    if (value != null) setDialogState(() => repeat = value);
                  },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    if (result == true && controller.text.trim().isNotEmpty) {
      final value = {
        'title': controller.text.trim(),
        'date': date.toIso8601String(),
        'repeat': repeat,
        'calendar': calendar,
        'pinned': pinned.toString(),
      };
      setState(() {
        if (index == null) {
          items.add(value);
        } else {
          items[index] = value;
        }
      });
      await _save();
    }
    controller.dispose();
  }

  Future<DateTime?> _showLunarDatePicker(
    BuildContext context,
    DateTime initialDate,
  ) {
    final initial = Lunar.fromDate(initialDate);
    var year = initial.getYear();
    var month = initial.getMonth();
    var day = initial.getDay();

    List<LunarMonth> monthsForYear() =>
        LunarYear.fromYear(year).getMonthsInYear();

    return showDialog<DateTime>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setPickerState) {
          final months = monthsForYear();
          if (!months.any((value) => value.getMonth() == month)) {
            month = months.first.getMonth();
          }
          final selectedMonth = months.firstWhere(
            (value) => value.getMonth() == month,
          );
          day = day.clamp(1, selectedMonth.getDayCount()).toInt();
          return AlertDialog(
            title: const Text('选择农历日期'),
            content: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<int>(
                    value: year,
                    decoration: const InputDecoration(labelText: '农历年'),
                    items: [
                      for (var value = 1900; value <= 2100; value++)
                        DropdownMenuItem(value: value, child: Text('$value年')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setPickerState(() {
                        year = value;
                        final available = monthsForYear();
                        if (!available.any(
                          (item) => item.getMonth() == month,
                        )) {
                          month = available.first.getMonth();
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<int>(
                    value: month,
                    decoration: const InputDecoration(labelText: '月份'),
                    items: [
                      for (final value in months)
                        DropdownMenuItem(
                          value: value.getMonth(),
                          child: Text(
                            value.isLeap()
                                ? '闰${value.getMonth().abs()}月'
                                : '${value.getMonth()}月',
                          ),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setPickerState(() {
                          month = value;
                          day = 1;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<int>(
                    value: day,
                    decoration: const InputDecoration(labelText: '日期'),
                    items: [
                      for (
                        var value = 1;
                        value <= selectedMonth.getDayCount();
                        value++
                      )
                        DropdownMenuItem(value: value, child: Text('$value日')),
                    ],
                    onChanged: (value) {
                      if (value != null) setPickerState(() => day = value);
                    },
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () {
                  final solar = Lunar.fromYmd(year, month, day).getSolar();
                  Navigator.pop(
                    dialogContext,
                    DateTime(solar.getYear(), solar.getMonth(), solar.getDay()),
                  );
                },
                child: const Text('确定'),
              ),
            ],
          );
        },
      ),
    );
  }

  DateTime _nextOccurrence(DateTime start, String repeat, String calendar) {
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    if (repeat == '不重复' || !start.isBefore(today)) return start;
    if (repeat == '每天') return today.add(const Duration(days: 1));
    if (repeat == '每周') {
      var next = start;
      while (!next.isAfter(today)) {
        next = next.add(const Duration(days: 7));
      }
      return next;
    }
    if (repeat == '每月' && calendar == '农历') {
      final lunarDay = Lunar.fromDate(start).getDay();
      var next = today.add(const Duration(days: 1));
      while (Lunar.fromDate(next).getDay() != lunarDay) {
        next = next.add(const Duration(days: 1));
      }
      return next;
    }
    if (repeat == '每月') {
      var year = today.year;
      var month = today.month;
      var next = DateTime(
        year,
        month,
        start.day.clamp(1, DateTime(year, month + 1, 0).day).toInt(),
      );
      if (!next.isAfter(today)) {
        month++;
        next = DateTime(
          year,
          month,
          start.day.clamp(1, DateTime(year, month + 1, 0).day).toInt(),
        );
      }
      return next;
    }
    if (repeat == '每年' && calendar == '农历') {
      final original = Lunar.fromDate(start);
      var lunarYear = Lunar.fromDate(today).getYear();
      DateTime convert(int year) {
        final solar = Lunar.fromYmd(
          year,
          original.getMonth(),
          original.getDay(),
        ).getSolar();
        return DateTime(solar.getYear(), solar.getMonth(), solar.getDay());
      }

      var next = convert(lunarYear);
      if (!next.isAfter(today)) next = convert(++lunarYear);
      return next;
    }
    var next = DateTime(
      today.year,
      start.month,
      start.day.clamp(1, DateTime(today.year, start.month + 1, 0).day).toInt(),
    );
    if (!next.isAfter(today))
      next = DateTime(
        today.year + 1,
        start.month,
        start.day
            .clamp(1, DateTime(today.year + 1, start.month + 1, 0).day)
            .toInt(),
      );
    return next;
  }

  Future<void> _deleteItem(int index) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('删除倒数日？'),
            content: Text(items[index]['title'] ?? ''),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('删除'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    setState(() => items.removeAt(index));
    await _save();
  }
}
