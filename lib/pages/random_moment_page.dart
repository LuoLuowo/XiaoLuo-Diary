import 'dart:math';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/diary_entry.dart';
import '../models/reading_book.dart';
import '../services/app_state.dart';
import 'diary_detail_page.dart';
import 'reading_page.dart';
import '../widgets/video_thumbnail.dart';

class RandomMomentPage extends StatefulWidget {
  const RandomMomentPage({super.key});

  @override
  State<RandomMomentPage> createState() => _RandomMomentPageState();
}

class _RandomMomentPageState extends State<RandomMomentPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1250),
  );
  String? _type;
  String? _selectedTag;
  DiaryEntry? _diary;
  ({int bookId, String bookTitle, OutlineNote note})? _note;
  bool _rolling = false;

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  Future<void> _roll(String type) async {
    final state = context.read<AppState>();
    final diaries = _selectedTag == null
        ? state.diaries
        : state.diaries
              .where((diary) => diary.tags.contains(_selectedTag))
              .toList();
    if (type == 'diary' && diaries.isEmpty) {
      _empty('还没有日记，先记录一篇吧');
      return;
    }
    final notes = <({int bookId, String bookTitle, OutlineNote note})>[];
    for (final book in state.books) {
      for (final note in book.notes) {
        if (_selectedTag == null || note.tags.contains(_selectedTag)) {
          notes.add((bookId: book.id!, bookTitle: book.title, note: note));
        }
      }
    }
    if (type == 'note' && notes.isEmpty) {
      _empty('还没有阅读感悟，先写下一条吧');
      return;
    }
    setState(() {
      _type = type;
      _rolling = true;
      _diary = null;
      _note = null;
    });
    await _animation.forward(from: 0);
    if (!mounted) return;
    final random = Random();
    setState(() {
      if (type == 'diary') {
        _diary = diaries[random.nextInt(diaries.length)];
      } else {
        _note = notes[random.nextInt(notes.length)];
      }
      _rolling = false;
    });
  }

  void _empty(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  void _start(String type) {
    setState(() => _selectedTag = null);
    _roll(type);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final state = context.watch<AppState>();
    final availableTags =
        (_type == 'diary'
                ? state.diaries.expand((diary) => diary.tags)
                : state.books.expand(
                    (book) => book.notes.expand((note) => note.tags),
                  ))
            .toSet()
            .toList()
          ..sort();
    return Scaffold(
      appBar: AppBar(title: const Text('随机时刻')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 80),
            children: [
              Text(
                _type == null ? '今天想遇见哪一种过去？' : '时间正在轻轻转动',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _type == null ? '随机出现的那一页，也许正好想对你说些什么。' : '每一次再来，都是一次新的相遇。',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 30),
              if (_type == null) ...[
                _ChoiceCard(
                  icon: Icons.auto_stories_rounded,
                  title: '随机日记',
                  subtitle: '从所有人生记录中随机抽出一篇',
                  onTap: () => _start('diary'),
                ),
                const SizedBox(height: 14),
                _ChoiceCard(
                  icon: Icons.lightbulb_outline_rounded,
                  title: '随机感悟',
                  subtitle: '不分标签，随机遇见一条阅读笔记',
                  onTap: () => _start('note'),
                ),
              ] else ...[
                SizedBox(
                  height: 370,
                  child: AnimatedBuilder(
                    animation: _animation,
                    builder: (_, child) => Stack(
                      alignment: Alignment.center,
                      children: [
                        Transform.rotate(
                          angle: _animation.value * pi * 7,
                          child: CustomPaint(
                            size: const Size.square(330),
                            painter: _VortexPainter(
                              colors.primary,
                              _animation.value,
                            ),
                          ),
                        ),
                        AnimatedScale(
                          duration: const Duration(milliseconds: 420),
                          scale: _rolling ? .25 : 1,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 420),
                            opacity: _rolling ? 0 : 1,
                            child: _resultCard(context),
                          ),
                        ),
                        if (_rolling)
                          const Text('🌀', style: TextStyle(fontSize: 72)),
                      ],
                    ),
                  ),
                ),
                if (availableTags.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '按标签随机（不选择则从全部内容中抽取）',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 38,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        ChoiceChip(
                          label: const Text('全部'),
                          selected: _selectedTag == null,
                          onSelected: _rolling
                              ? null
                              : (_) {
                                  setState(() => _selectedTag = null);
                                  _roll(_type!);
                                },
                        ),
                        const SizedBox(width: 7),
                        for (final tag in availableTags) ...[
                          ChoiceChip(
                            label: Text('#$tag'),
                            selected: _selectedTag == tag,
                            onSelected: _rolling
                                ? null
                                : (_) {
                                    setState(() => _selectedTag = tag);
                                    _roll(_type!);
                                  },
                          ),
                          const SizedBox(width: 7),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _rolling ? null : () => _roll(_type!),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('再来一次'),
                ),
                TextButton(
                  onPressed: _rolling
                      ? null
                      : () => setState(() {
                          _type = null;
                          _diary = null;
                          _note = null;
                          _selectedTag = null;
                        }),
                  child: const Text('重新选择'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _resultCard(BuildContext context) {
    if (_diary != null) {
      final diary = _diary!;
      return _MomentResult(
        label: '随机日记',
        title: diary.displayTitle,
        content: diary.displayContent,
        media: diary.images.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.file(
                  File(diary.images.first),
                  height: 112,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              )
            : diary.videos.isNotEmpty
            ? VideoThumbnail(
                path: diary.videos.first,
                caption: diary.displayTitle,
                height: 112,
                borderRadius: 14,
              )
            : null,
        action: '查看这篇日记',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DiaryDetailPage(diaryId: diary.id!),
          ),
        ),
      );
    }
    if (_note != null) {
      final value = _note!;
      return _MomentResult(
        label: '来自《${value.bookTitle}》',
        title: value.note.title.isEmpty ? '未命名感悟' : value.note.title,
        content: value.note.content,
        action: '查看这条感悟',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BookDetailPage(
              bookId: value.bookId,
              initialNoteId: value.note.id,
            ),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Row(
          children: [
            CircleAvatar(radius: 27, child: Icon(icon)),
            const SizedBox(width: 17),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(subtitle),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    ),
  );
}

class _MomentResult extends StatelessWidget {
  const _MomentResult({
    required this.label,
    required this.title,
    required this.content,
    required this.action,
    required this.onTap,
    this.media,
  });
  final String label, title, content, action;
  final VoidCallback onTap;
  final Widget? media;
  @override
  Widget build(BuildContext context) => Card(
    elevation: 10,
    child: SizedBox(
      width: 270,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            if (title.isNotEmpty)
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            if (media != null) ...[const SizedBox(height: 10), media!],
            const SizedBox(height: 10),
            Text(
              content.trim().isEmpty ? '这一页暂时没有文字。' : content,
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 14),
            TextButton(onPressed: onTap, child: Text(action)),
          ],
        ),
      ),
    ),
  );
}

class _VortexPainter extends CustomPainter {
  const _VortexPainter(this.color, this.progress);
  final Color color;
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    for (var i = 0; i < 6; i++) {
      final radius = 35.0 + i * 22;
      final paint = Paint()
        ..color = color.withValues(alpha: .10 + (5 - i) * .025)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 8 - i * .7;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        i * .7,
        pi * (1.2 + progress * .5),
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _VortexPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
