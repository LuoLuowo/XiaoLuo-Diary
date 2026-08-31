import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/pomodoro_service.dart';

class PlanPage extends StatefulWidget {
  const PlanPage({super.key});
  @override
  State<PlanPage> createState() => _PlanPageState();
}

class _PlanPageState extends State<PlanPage> {
  int minutes = 25;
  String type = '学习';
  List<String> types = ['学习', '工作', '阅读'];
  @override
  void initState() {
    super.initState();
    _loadTypes();
  }

  Future<void> _loadTypes() async {
    final values = await PomodoroService.types();
    if (mounted)
      setState(() {
        types = values.isEmpty ? ['专注'] : values;
        if (!types.contains(type)) type = types.first;
      });
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(24, 30, 24, 120),
    children: [
      Text(
        '计划',
        style: Theme.of(
          context,
        ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 20),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              Text(
                '🍅 $type 专注',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Text(
                '$minutes:00',
                style: const TextStyle(
                  fontSize: 52,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  DropdownButton<String>(
                    value: type,
                    items: [
                      for (final value in types)
                        DropdownMenuItem(value: value, child: Text(value)),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => type = value);
                    },
                  ),
                  IconButton(
                    tooltip: '自定义专注类型',
                    onPressed: _addType,
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                  IconButton(
                    tooltip: '删除当前专注类型',
                    onPressed: _deleteType,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                ],
              ),
              Slider(
                min: 5,
                max: 120,
                divisions: 23,
                value: minutes.toDouble(),
                label: '$minutes 分钟',
                onChanged: (value) => setState(() => minutes = value.round()),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    fullscreenDialog: true,
                    builder: (_) =>
                        FocusSessionPage(type: type, minutes: minutes),
                  ),
                ),
                icon: const Icon(Icons.fullscreen),
                label: const Text('进入沉浸专注'),
              ),
            ],
          ),
        ),
      ),
    ],
  );

  Future<void> _deleteType() async {
    final removed = type;
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('删除专注类型？'),
            content: Text('是否删除“$removed”？已有专注记录不会被删除。'),
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
    if (!confirmed || !mounted) return;
    setState(() {
      types.remove(removed);
      if (types.isEmpty) types.add('专注');
      type = types.first;
    });
    await PomodoroService.saveTypes(types);
  }

  Future<void> _addType() async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('新建专注类型'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '例如：背单词'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('添加'),
          ),
        ],
      ),
    );
    if (value == null || value.isEmpty || types.contains(value)) return;
    setState(() {
      types.add(value);
      type = value;
    });
    await PomodoroService.saveTypes(types);
  }
}

class FocusSessionPage extends StatefulWidget {
  const FocusSessionPage({
    super.key,
    required this.type,
    required this.minutes,
  });
  final String type;
  final int minutes;
  @override
  State<FocusSessionPage> createState() => _FocusSessionPageState();
}

class _FocusSessionPageState extends State<FocusSessionPage>
    with SingleTickerProviderStateMixin {
  late int remaining = widget.minutes * 60;
  Timer? timer;
  bool finishing = false;
  late final AnimationController exitProgress =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1500),
      )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _finish(((widget.minutes * 60 - remaining) / 60).floor());
        }
      });
  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (remaining <= 1) {
      timer?.cancel();
      _finish(widget.minutes);
    } else if (mounted) {
      setState(() => remaining--);
    }
  }

  Future<void> _finish(int actualMinutes) async {
    if (finishing) return;
    finishing = true;
    if (actualMinutes > 0)
      await PomodoroService.addSession(
        FocusSession(
          type: widget.type,
          minutes: actualMinutes,
          completedAt: DateTime.now(),
        ),
      );
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    timer?.cancel();
    exitProgress.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.type,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 30),
              Text(
                '${(remaining ~/ 60).toString().padLeft(2, '0')}:${(remaining % 60).toString().padLeft(2, '0')}',
                style: const TextStyle(
                  fontSize: 72,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 24),
              const Text('保持专注，暂时离开其他事情。'),
              const SizedBox(height: 60),
              GestureDetector(
                onLongPressStart: (_) => exitProgress.forward(from: 0),
                onLongPressEnd: (_) {
                  if (!finishing &&
                      exitProgress.status != AnimationStatus.completed) {
                    exitProgress.reverse();
                  }
                },
                child: AnimatedBuilder(
                  animation: exitProgress,
                  builder: (_, child) => Container(
                    padding: const EdgeInsets.fromLTRB(4, 4, 16, 4),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(34),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 50,
                          height: 50,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CircularProgressIndicator(
                                value: exitProgress.value,
                                strokeWidth: 4,
                              ),
                              const Icon(Icons.lock_outline, size: 19),
                            ],
                          ),
                        ),
                        const SizedBox(width: 9),
                        const Text('长按结束专注'),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
