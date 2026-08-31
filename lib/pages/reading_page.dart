import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/reading_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:provider/provider.dart';
import '../models/reading_book.dart';
import '../services/app_state.dart';
import '../services/storage_service.dart';
import '../utils/rich_text_contrast.dart';
import '../widgets/loading_operation.dart';

class _EditorLifetime extends StatefulWidget {
  const _EditorLifetime({required this.child, required this.onDispose});
  final Widget child;
  final VoidCallback onDispose;
  @override
  State<_EditorLifetime> createState() => _EditorLifetimeState();
}

class _EditorLifetimeState extends State<_EditorLifetime> {
  @override
  Widget build(BuildContext context) => widget.child;
  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }
}

class ReadingPage extends StatefulWidget {
  const ReadingPage({super.key});
  @override
  State<ReadingPage> createState() => _ReadingPageState();
}

class _NoteContent extends StatefulWidget {
  const _NoteContent({super.key, required this.note});
  final OutlineNote note;

  @override
  State<_NoteContent> createState() => _NoteContentState();
}

class _NoteContentState extends State<_NoteContent> {
  QuillController? controller;

  @override
  void initState() {
    super.initState();
    if (widget.note.richContent.isNotEmpty) {
      try {
        controller = QuillController(
          document: Document.fromJson(
            jsonDecode(widget.note.richContent) as List,
          ),
          selection: const TextSelection.collapsed(offset: 0),
          readOnly: true,
        );
      } catch (_) {
        controller = null;
      }
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = controller;
    if (current == null) {
      return Text(
        _plainLegacy(widget.note.content),
        style: TextStyle(
          fontSize: context.watch<AppState>().readingFontSize,
          height: 1.55,
          fontWeight: FontWeight.w400,
          decoration: TextDecoration.none,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }
    return QuillEditor.basic(
      controller: current,
      config: QuillEditorConfig(
        scrollable: false,
        enableInteractiveSelection: false,
        customStyles: readingTextStyles(
          context,
          context.watch<AppState>().readingFontSize,
        ),
        textSpanBuilder: readableRichTextSpan,
      ),
    );
  }
}

String _plainLegacy(String source) => source
    .replaceAllMapped(
      RegExp(r'\{\{#[0-9A-Fa-f]{6}\|(.*?)\}\}'),
      (match) => match.group(1) ?? '',
    )
    .replaceAll('**', '')
    .replaceAll('__', '')
    .replaceAll(RegExp(r'(?<!\*)\*(?!\*)'), '');

class _ReadingPageState extends State<ReadingPage> {
  String query = '';
  String? selectedTag;
  bool showBooks = false;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final tagCounts = <String, int>{};
    for (final book in state.books) {
      for (final note in book.notes) {
        for (final tag in note.tags) {
          tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
        }
      }
    }
    final keyword = query.trim().toLowerCase();
    final results = <({ReadingBook book, OutlineNote note})>[];
    for (final book in state.books) {
      for (final note in book.notes) {
        final matchesTag =
            selectedTag == null || note.tags.contains(selectedTag);
        final matchesQuery =
            keyword.isEmpty ||
            note.title.toLowerCase().contains(keyword) ||
            note.content.toLowerCase().contains(keyword) ||
            note.tags.any((tag) => tag.toLowerCase().contains(keyword));
        if (matchesTag && matchesQuery) results.add((book: book, note: note));
      }
    }
    return Scaffold(
      appBar: AppBar(title: const Text('阅读感悟')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BookEditorPage()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('添加书籍'),
      ),
      body: state.books.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.menu_book_outlined, size: 54),
                  SizedBox(height: 14),
                  Text('把读过的书和感悟留在这里'),
                ],
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: TextField(
                    onChanged: (value) => setState(() => query = value),
                    decoration: InputDecoration(
                      hintText: showBooks ? '搜索书名或作者' : '搜索笔记标题、内容或标签',
                      prefixIcon: const Icon(Icons.search),
                    ),
                  ),
                ),
                SizedBox(
                  height: 48,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    scrollDirection: Axis.horizontal,
                    children: [
                      ChoiceChip(
                        label: Text(
                          '全部 ${state.books.fold<int>(0, (sum, book) => sum + book.notes.length)}',
                        ),
                        selected: selectedTag == null && !showBooks,
                        onSelected: (_) => setState(() {
                          selectedTag = null;
                          showBooks = false;
                        }),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: Text('书籍 ${state.books.length}'),
                        selected: showBooks,
                        onSelected: (_) => setState(() {
                          showBooks = true;
                          selectedTag = null;
                        }),
                      ),
                      const SizedBox(width: 8),
                      for (final entry in tagCounts.entries) ...[
                        ChoiceChip(
                          label: Text('${entry.key} ${entry.value}'),
                          selected: selectedTag == entry.key,
                          onSelected: (_) => setState(() {
                            selectedTag = entry.key;
                            showBooks = false;
                          }),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: showBooks
                      ? _bookGrid(context, state)
                      : results.isEmpty
                      ? const Center(child: Text('没有找到相关笔记'))
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(22, 14, 22, 100),
                          itemCount: results.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 6),
                          itemBuilder: (_, i) {
                            final result = results[i];
                            final book = result.book;
                            final note = result.note;
                            return Card(
                              child: InkWell(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => BookDetailPage(
                                      bookId: book.id!,
                                      initialNoteId: note.id,
                                    ),
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    14,
                                    11,
                                    14,
                                    10,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              note.title.isEmpty
                                                  ? '未命名笔记'
                                                  : note.title,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        note.content.isEmpty
                                            ? '暂无详细内容'
                                            : note.content,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 13.5,
                                          height: 1.38,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: Text(
                                          '${note.tags.map((tag) => '#$tag').join('  ')}  ·  来自《${book.title}》',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                            fontSize: 11.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _bookGrid(BuildContext context, AppState state) {
    final books = state.books
        .where(
          (book) => '${book.title} ${book.author}'.toLowerCase().contains(
            query.trim().toLowerCase(),
          ),
        )
        .toList();
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 100),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 260,
        childAspectRatio: .68,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
      ),
      itemCount: books.length,
      itemBuilder: (_, index) {
        final book = books[index];
        return Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BookDetailPage(bookId: book.id!),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: book.coverPath.isEmpty
                      ? Container(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          child: const Center(
                            child: Icon(Icons.auto_stories_rounded, size: 48),
                          ),
                        )
                      : Image.file(
                          File(book.coverPath),
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Center(
                            child: Icon(Icons.broken_image_outlined),
                          ),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        book.author.isEmpty
                            ? '${book.notes.length} 条笔记'
                            : '${book.author} · ${book.notes.length} 条笔记',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class BookEditorPage extends StatefulWidget {
  const BookEditorPage({super.key, this.book});
  final ReadingBook? book;
  @override
  State<BookEditorPage> createState() => _BookEditorPageState();
}

class _BookEditorPageState extends State<BookEditorPage> {
  late final title = TextEditingController(text: widget.book?.title ?? '');
  late final author = TextEditingController(text: widget.book?.author ?? '');
  late final review = TextEditingController(text: widget.book?.review ?? '');
  late String cover = widget.book?.coverPath ?? '';

  @override
  void dispose() {
    title.dispose();
    author.dispose();
    review.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.book == null ? '添加书籍' : '编辑书籍'),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: FilledButton(onPressed: _save, child: const Text('保存')),
        ),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: GestureDetector(
                onTap: _pickCover,
                child: Container(
                  width: 150,
                  height: 210,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: cover.isEmpty
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined, size: 36),
                            SizedBox(height: 8),
                            Text('上传封面'),
                          ],
                        )
                      : Image.file(File(cover), fit: BoxFit.cover),
                ),
              ),
            ),
            const SizedBox(height: 26),
            TextField(
              controller: title,
              decoration: const InputDecoration(labelText: '书名'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: author,
              decoration: const InputDecoration(labelText: '作者（可选）'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: review,
              minLines: 3,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: '整本书的观后感（可选）',
                hintText: '写下读完整本书后的整体感受…',
              ),
            ),
          ],
        ),
      ),
    ),
  );
  Future<void> _pickCover() async {
    final state = context.read<AppState>();
    final storage = context.read<StorageService>();
    try {
      final values = await runLoading(
        context,
        '正在选择并处理封面…',
        (_) => storage.pickImages(keepOriginal: state.keepOriginalMedia),
      );
      if (values.isNotEmpty && mounted) setState(() => cover = values.first);
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('添加封面失败：$error')));
    }
  }

  Future<void> _save() async {
    if (title.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请填写书名')));
      return;
    }
    final now = DateTime.now();
    await context.read<AppState>().saveBook(
      ReadingBook(
        id: widget.book?.id,
        title: title.text.trim(),
        author: author.text.trim(),
        coverPath: cover,
        notes: widget.book?.notes ?? const [],
        review: review.text.trim(),
        createdAt: widget.book?.createdAt ?? now,
        updatedAt: now,
      ),
    );
    if (mounted) Navigator.pop(context);
  }
}

class BookDetailPage extends StatefulWidget {
  const BookDetailPage({super.key, required this.bookId, this.initialNoteId});
  final int bookId;
  final String? initialNoteId;
  @override
  State<BookDetailPage> createState() => _BookDetailPageState();
}

class _BookDetailPageState extends State<BookDetailPage> {
  final Set<String> collapsed = {};
  bool initialCollapseApplied = false;
  final Map<String, GlobalKey> noteKeys = {};
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final values = state.books.where((e) => e.id == widget.bookId);
    if (values.isEmpty)
      return const Scaffold(body: Center(child: Text('这本书已被删除')));
    final book = values.first;
    if (!initialCollapseApplied) {
      collapsed.addAll(
        book.notes
            .where((note) => note.id != widget.initialNoteId)
            .map((note) => note.id),
      );
      initialCollapseApplied = true;
      if (widget.initialNoteId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final target = noteKeys[widget.initialNoteId]?.currentContext;
          if (mounted && target != null)
            Scrollable.ensureVisible(
              target,
              alignment: .08,
              duration: const Duration(milliseconds: 350),
            );
        });
      }
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(book.title),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => BookEditorPage(book: book)),
            ),
            icon: const Icon(Icons.edit_outlined),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'delete') _delete(context, state, book);
              if (v == 'font') _chooseFontSize(context, state);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'font', child: Text('所有书籍字体大小')),
              PopupMenuItem(value: 'delete', child: Text('删除书籍')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editNote(context, state, book),
        icon: const Icon(Icons.add),
        label: const Text('添加笔记'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: book.coverPath.isEmpty
                      ? Container(
                          width: 105,
                          height: 145,
                          color: Theme.of(context).colorScheme.primaryContainer,
                          child: const Icon(Icons.menu_book_rounded, size: 42),
                        )
                      : Image.file(
                          File(book.coverPath),
                          width: 105,
                          height: 145,
                          fit: BoxFit.cover,
                        ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book.title,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      if (book.author.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(book.author),
                      ],
                      const SizedBox(height: 14),
                      Text(
                        '${book.notes.length} 条笔记',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (book.review.isNotEmpty) ...[
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '整本书的观后感',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(book.review, style: const TextStyle(height: 1.6)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 22),
            if (book.notes.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 50),
                child: Center(child: Text('还没有笔记，记录第一条阅读感悟吧')),
              )
            else
              for (var i = 0; i < book.notes.length; i++)
                _noteCard(context, state, book, book.notes[i], i),
          ],
        ),
      ),
    );
  }

  Widget _noteCard(
    BuildContext context,
    AppState state,
    ReadingBook book,
    OutlineNote note,
    int index,
  ) {
    final hasDetails =
        note.content.trim().isNotEmpty ||
        note.richContent.isNotEmpty ||
        note.tags.isNotEmpty;
    final isCollapsed = collapsed.contains(note.id);
    return Padding(
      key: noteKeys.putIfAbsent(note.id, () => GlobalKey()),
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: hasDetails
                ? GestureDetector(
                    onTap: () => setState(() {
                      collapsed.contains(note.id)
                          ? collapsed.remove(note.id)
                          : collapsed.add(note.id);
                    }),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Icon(
                        isCollapsed ? Icons.chevron_right : Icons.expand_more,
                        size: 22,
                      ),
                    ),
                  )
                : const Padding(
                    padding: EdgeInsets.only(top: 7),
                    child: Icon(Icons.circle, size: 6),
                  ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () =>
                  _editNote(context, state, book, note: note, index: index),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(2, 3, 4, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      note.title.isEmpty ? '未命名节点' : note.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: state.readingFontSize + 1,
                        height: 1.35,
                        color: _noteTitleColor(context, note.titleColor),
                      ),
                    ),
                    if (!isCollapsed &&
                        (note.content.isNotEmpty ||
                            note.richContent.isNotEmpty)) ...[
                      const SizedBox(height: 3),
                      _NoteContent(
                        key: ValueKey('${note.id}-${note.richContent}'),
                        note: note,
                      ),
                    ],
                    if (!isCollapsed && note.tags.isNotEmpty) ...[
                      const SizedBox(height: 7),
                      Text(
                        note.tags.map((tag) => '#$tag').join('  '),
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editNote(
    BuildContext context,
    AppState state,
    ReadingBook book, {
    OutlineNote? note,
    int? index,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final draftKey = 'reading_draft_${book.id}_${note?.id ?? 'new'}';
    OutlineNote? draft;
    try {
      final raw = prefs.getString(draftKey);
      if (raw != null)
        draft = OutlineNote.fromMap(
          Map<String, Object?>.from(jsonDecode(raw) as Map),
        );
    } catch (_) {
      /* Ignore an invalid older draft. */
    }
    if (!context.mounted) return;
    final source = draft ?? note;
    final title = TextEditingController(text: source?.title ?? '');
    final tags = TextEditingController(text: source?.tags.join('、') ?? '');
    final titleColor = ValueNotifier<String>(source?.titleColor ?? '');
    late final Document initialDocument;
    if (source?.richContent.isNotEmpty == true) {
      initialDocument = Document.fromJson(
        jsonDecode(source!.richContent) as List,
      );
    } else {
      initialDocument = Document()
        ..insert(0, _legacyPlainText(source?.content ?? ''));
    }
    final richEditor = QuillController(
      document: initialDocument,
      selection: const TextSelection.collapsed(offset: 0),
    );
    Future<void> pendingDraft = Future<void>.value();
    void persistDraft() {
      final snapshot = jsonEncode(
        OutlineNote(
          id: note?.id ?? 'draft',
          title: title.text,
          content: richEditor.document.toPlainText(),
          richContent: jsonEncode(richEditor.document.toDelta().toJson()),
          tags: tags.text
              .split(RegExp(r'[,，、\s]+'))
              .where((value) => value.isNotEmpty)
              .toList(),
          titleColor: titleColor.value,
        ).toMap(),
      );
      pendingDraft = pendingDraft.then((_) async {
        await prefs.setString(draftKey, snapshot);
      });
    }

    title.addListener(persistDraft);
    tags.addListener(persistDraft);
    titleColor.addListener(persistDraft);
    richEditor.addListener(persistDraft);
    if (draft != null)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已恢复上次未保存的草稿')));
    final sheetGone = Completer<void>();
    final result = await showModalBottomSheet<OutlineNote>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        final screenHeight = MediaQuery.sizeOf(sheetContext).height;
        final keyboardInset = MediaQuery.viewInsetsOf(sheetContext).bottom;
        // Give the writing surface as much of the sheet as possible while
        // still fitting above the keyboard on smaller phones.
        final editorSheetHeight = math.min(
          screenHeight * .92,
          math.max(320.0, screenHeight - keyboardInset - 26),
        );
        return _EditorLifetime(
          onDispose: () => sheetGone.complete(),
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: EdgeInsets.fromLTRB(
              20,
              14,
              20,
              MediaQuery.viewInsetsOf(sheetContext).bottom + 20,
            ),
            child: SizedBox(
              height: editorSheetHeight,
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        note == null ? '添加笔记' : '编辑笔记',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      if (note != null)
                        IconButton(
                          onPressed: () => Navigator.pop(
                            sheetContext,
                            OutlineNote(
                              id: '__delete__',
                              title: '',
                              content: '',
                              level: 0,
                            ),
                          ),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      const SizedBox(width: 4),
                      FilledButton(
                        onPressed: () => Navigator.pop(
                          sheetContext,
                          OutlineNote(
                            id:
                                note?.id ??
                                DateTime.now().microsecondsSinceEpoch
                                    .toString(),
                            title: title.text.trim(),
                            content: richEditor.document.toPlainText().trim(),
                            richContent: jsonEncode(
                              richEditor.document.toDelta().toJson(),
                            ),
                            level: 0,
                            tags: tags.text
                                .split(RegExp(r'[,，、\s]+'))
                                .where((value) => value.trim().isNotEmpty)
                                .toSet()
                                .toList(),
                            titleColor: titleColor.value,
                          ),
                        ),
                        child: const Text('保存'),
                      ),
                    ],
                  ),
                  ValueListenableBuilder<String>(
                    valueListenable: titleColor,
                    builder: (_, value, _) => TextField(
                      controller: title,
                      style: const TextStyle(fontSize: 15),
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: '笔记标题',
                        suffixIconConstraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                        suffixIcon: IconButton(
                          tooltip: '标题颜色',
                          onPressed: () async {
                            final picked = await _pickTitleColor(
                              context,
                              value,
                            );
                            if (picked != null) titleColor.value = picked;
                          },
                          icon: Icon(
                            Icons.format_color_text_rounded,
                            color: _noteTitleColor(context, value),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  TextField(
                    controller: tags,
                    style: const TextStyle(fontSize: 14),
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: '标签',
                      hintText: '生活、成长、心理学',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(top: 10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      child: QuillEditor.basic(
                        controller: richEditor,
                        config: QuillEditorConfig(
                          placeholder: '写下摘录、想法或感悟…',
                          customStyles: readingTextStyles(
                            context,
                            context.watch<AppState>().readingFontSize,
                          ),
                          textSpanBuilder: readableRichTextSpan,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Row(
                      children: [
                        Icon(
                          Icons.account_tree_outlined,
                          size: 18,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '大纲层级',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () => richEditor.indentSelection(false),
                          icon: const Icon(
                            Icons.format_indent_decrease,
                            size: 18,
                          ),
                          label: const Text('上一级'),
                        ),
                        TextButton.icon(
                          onPressed: () => richEditor.indentSelection(true),
                          icon: const Icon(
                            Icons.format_indent_increase,
                            size: 18,
                          ),
                          label: const Text('下一级'),
                        ),
                      ],
                    ),
                  ),
                  QuillSimpleToolbar(
                    controller: richEditor,
                    config: const QuillSimpleToolbarConfig(
                      multiRowsDisplay: false,
                      showDividers: false,
                      showFontFamily: false,
                      showFontSize: false,
                      showBoldButton: true,
                      showItalicButton: false,
                      showSmallButton: false,
                      showUnderLineButton: true,
                      showLineHeightButton: false,
                      showStrikeThrough: false,
                      showInlineCode: false,
                      showColorButton: true,
                      showBackgroundColorButton: false,
                      showClearFormat: true,
                      showAlignmentButtons: false,
                      showHeaderStyle: false,
                      showListNumbers: true,
                      showListBullets: true,
                      showListCheck: false,
                      showCodeBlock: false,
                      showQuote: false,
                      showIndent: true,
                      showLink: false,
                      showUndo: true,
                      showRedo: true,
                      showDirection: false,
                      showSearchButton: false,
                      showSubscript: false,
                      showSuperscript: false,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    persistDraft();
    title.removeListener(persistDraft);
    tags.removeListener(persistDraft);
    titleColor.removeListener(persistDraft);
    richEditor.removeListener(persistDraft);
    await pendingDraft;
    await sheetGone.future;
    richEditor.dispose();
    title.dispose();
    tags.dispose();
    titleColor.dispose();
    if (result == null) return;
    final notes = [...book.notes];
    if (result.id == '__delete__') {
      if (index != null) notes.removeAt(index);
    } else if (index == null) {
      notes.add(result);
    } else {
      notes[index] = result;
    }
    await state.saveBook(
      book.copyWith(notes: notes, updatedAt: DateTime.now()),
    );
    await prefs.remove(draftKey);
  }

  Future<void> _chooseFontSize(BuildContext context, AppState state) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, refresh) => AlertDialog(
          title: const Text('所有书籍字体大小'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('当前 ${state.readingFontSize.round()} 号 · 对所有书籍生效'),
              Slider(
                min: 12,
                max: 22,
                divisions: 10,
                value: state.readingFontSize,
                onChanged: (value) {
                  state.setReadingFontSize(value);
                  refresh(() {});
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('关闭'),
            ),
          ],
        ),
      ),
    );
  }

  static Color _noteTitleColor(BuildContext context, String value) {
    if (value.isEmpty) return Theme.of(context).colorScheme.onSurface;
    final parsed = int.tryParse(value, radix: 16);
    return parsed == null
        ? Theme.of(context).colorScheme.onSurface
        : Color(parsed);
  }

  static Future<String?> _pickTitleColor(
    BuildContext context,
    String current,
  ) => showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('选择标题颜色'),
      content: Wrap(
        spacing: 14,
        runSpacing: 14,
        children: [
          for (final value in const [
            '',
            'FFE53935',
            'FFFB8C00',
            'FF43A047',
            'FF1E88E5',
            'FF8E24AA',
            'FF6D4C41',
          ])
            InkWell(
              borderRadius: BorderRadius.circular(30),
              onTap: () => Navigator.pop(dialogContext, value),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: _noteTitleColor(context, value),
                child: current == value
                    ? Icon(
                        Icons.check,
                        color:
                            ThemeData.estimateBrightnessForColor(
                                  _noteTitleColor(context, value),
                                ) ==
                                Brightness.dark
                            ? Colors.white
                            : Colors.black,
                      )
                    : null,
              ),
            ),
        ],
      ),
    ),
  );

  static String _legacyPlainText(String source) => source
      .replaceAllMapped(
        RegExp(r'\{\{#[0-9A-Fa-f]{6}\|(.*?)\}\}'),
        (match) => match.group(1) ?? '',
      )
      .replaceAll('**', '')
      .replaceAll('__', '')
      .replaceAll(RegExp(r'(?<!\*)\*(?!\*)'), '');

  Future<void> _delete(
    BuildContext context,
    AppState state,
    ReadingBook book,
  ) async {
    final ok =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('删除这本书？'),
            content: const Text('书籍和其中的大纲笔记都会删除。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('删除'),
              ),
            ],
          ),
        ) ??
        false;
    if (ok) {
      await state.deleteBook(book);
      if (context.mounted) Navigator.pop(context);
    }
  }
}
