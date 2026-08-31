import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import '../utils/diary_media.dart';
import '../utils/live_photo.dart';
import '../widgets/diary_media_embed.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import '../models/diary_entry.dart';
import '../services/app_state.dart';
import '../services/storage_service.dart';
import '../utils/rich_text_contrast.dart';
import '../widgets/loading_operation.dart';
import '../widgets/audio_attachment.dart';

class DiaryEditorPage extends StatefulWidget {
  const DiaryEditorPage({super.key, this.diary});
  final DiaryEntry? diary;
  @override
  State<DiaryEditorPage> createState() => _DiaryEditorPageState();
}

class _DiaryEditorPageState extends State<DiaryEditorPage> {
  late final TextEditingController title = TextEditingController(
    text: widget.diary?.title ?? '',
  );
  late final QuillController editor;
  final editorFocus = FocusNode();
  late DateTime date = widget.diary?.diaryDate ?? DateTime.now();
  late Set<String> selectedTags = {...?widget.diary?.tags};
  late List<String> images = [...?widget.diary?.images];
  late List<String> videos = [...?widget.diary?.videos];
  late List<String> attachments = [...?widget.diary?.attachments];
  bool saving = false;
  bool processingMedia = false;
  bool showStyleToolbar = false;

  @override
  void initState() {
    super.initState();
    final document = _initialDocument();
    editor = QuillController(
      document: document,
      selection: TextSelection.collapsed(
        offset: (document.length - 1).clamp(0, document.length),
      ),
    );
  }

  Document _initialDocument() => editableDiaryDocument(widget.diary);

  @override
  void dispose() {
    title.dispose();
    editor.dispose();
    editorFocus.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(1970),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted)
      setState(
        () => date = DateTime(
          picked.year,
          picked.month,
          picked.day,
          date.hour,
          date.minute,
        ),
      );
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(date),
    );
    if (picked != null && mounted)
      setState(
        () => date = DateTime(
          date.year,
          date.month,
          date.day,
          picked.hour,
          picked.minute,
        ),
      );
  }

  Future<void> _save() async {
    if (saving) return;
    // Do not leave a keyboard-anchored overlay alive while the route closes.
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => saving = true);
    final now = DateTime.now();
    final currentImages = documentMedia(editor.document, 'image');
    final diary = DiaryEntry(
      id: widget.diary?.id,
      title: title.text.trim(),
      content: editor.document.toPlainText().trim(),
      richContent: jsonEncode(editor.document.toDelta().toJson()),
      diaryDate: date,
      createdAt: widget.diary?.createdAt ?? now,
      updatedAt: now,
      category: '其他',
      tags: selectedTags.toList(),
      images: currentImages,
      videos: [
        ...documentMedia(editor.document, 'video'),
        for (final image in currentImages)
          if (livePhotoVideoForImage(image, videos) case final video?) video,
      ].toSet().toList(),
      attachments: attachments,
    );
    await context.read<AppState>().saveDiary(diary);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final toolbarReserve = showStyleToolbar ? 170.0 : 96.0;
    return Scaffold(
      // The toolbar is positioned explicitly above the soft keyboard below.
      // This is more reliable on vivo/Android than Scaffold.bottomNavigationBar.
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text(widget.diary == null ? '写一篇日记' : '编辑日记'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              onPressed: saving || processingMedia ? null : _save,
              child: Text(saving ? '保存中' : '保存'),
            ),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 780),
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  24,
                  12,
                  24,
                  toolbarReserve + keyboardInset,
                ),
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      ActionChip(
                        avatar: const Icon(
                          Icons.calendar_today_outlined,
                          size: 16,
                        ),
                        label: Text(DateFormat('yyyy年M月d日').format(date)),
                        onPressed: _pickDate,
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.schedule, size: 16),
                        label: Text(DateFormat('HH:mm').format(date)),
                        onPressed: _pickTime,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: InputDecoration(
                      hintText: '标题',
                      hintStyle: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurfaceVariant.withValues(alpha: .52),
                      ),
                      fillColor: Colors.transparent,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    constraints: const BoxConstraints(minHeight: 330),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: QuillEditor.basic(
                      controller: editor,
                      focusNode: editorFocus,
                      config: QuillEditorConfig(
                        scrollable: false,
                        minHeight: 300,
                        placeholder: '此刻，你想记下什么？',
                        embedBuilders: [
                          DiaryMediaEmbedBuilder(
                            type: 'image',
                            focusNode: editorFocus,
                            liveVideos: videos,
                          ),
                          DiaryMediaEmbedBuilder(
                            type: 'video',
                            focusNode: editorFocus,
                          ),
                        ],
                        customStyles: DefaultStyles(
                          placeHolder: DefaultTextBlockStyle(
                            TextStyle(
                              fontSize: state.diaryFontSize,
                              height: 1.8,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant
                                  .withValues(alpha: .48),
                            ),
                            const HorizontalSpacing(0, 0),
                            const VerticalSpacing(0, 0),
                            const VerticalSpacing(0, 0),
                            null,
                          ),
                          paragraph: DefaultTextBlockStyle(
                            TextStyle(
                              fontSize: state.diaryFontSize,
                              height: 1.8,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            const HorizontalSpacing(0, 0),
                            const VerticalSpacing(0, 0),
                            const VerticalSpacing(0, 0),
                            null,
                          ),
                        ),
                        textSpanBuilder: readableRichTextSpan,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    '标签',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 8,
                    runSpacing: 7,
                    children: [
                      for (final tag in state.tags)
                        FilterChip(
                          label: Text('#$tag'),
                          selected: selectedTags.contains(tag),
                          onSelected: (v) => setState(
                            () => v
                                ? selectedTags.add(tag)
                                : selectedTags.remove(tag),
                          ),
                        ),
                      ActionChip(
                        avatar: const Icon(Icons.add, size: 17),
                        label: const Text('新标签'),
                        onPressed: () => _newTag(state),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (attachments.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    for (var i = 0; i < attachments.length; i++) ...[
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.insert_drive_file_outlined),
                        title: Text(
                          p.basename(attachments[i]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          onPressed: () =>
                              setState(() => attachments.removeAt(i)),
                          icon: const Icon(Icons.close),
                        ),
                      ),
                      if (isAudioAttachment(attachments[i]))
                        AudioAttachment(
                          key: ValueKey(attachments[i]),
                          path: attachments[i],
                        ),
                    ],
                  ],
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: keyboardInset,
            child: _editorToolbar(state),
          ),
        ],
      ),
    );
  }

  Widget _editorToolbar(AppState state) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainer,
      elevation: 10,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showStyleToolbar)
              QuillSimpleToolbar(
                controller: editor,
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
                  showAlignmentButtons: true,
                  showHeaderStyle: false,
                  showListNumbers: true,
                  showListBullets: true,
                  showListCheck: true,
                  showCodeBlock: false,
                  showQuote: false,
                  showIndent: false,
                  showLink: false,
                  showUndo: false,
                  showRedo: false,
                  showDirection: false,
                  showSearchButton: false,
                  showSubscript: false,
                  showSuperscript: false,
                ),
              ),
            SizedBox(
              height: 58,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    tooltip: '文字样式',
                    onPressed: () =>
                        setState(() => showStyleToolbar = !showStyleToolbar),
                    icon: Icon(
                      Icons.format_size,
                      color: showStyleToolbar
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                  ),
                  IconButton(
                    tooltip: '添加图片',
                    onPressed: processingMedia
                        ? null
                        : () => _pickImages(state),
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                  ),
                  IconButton(
                    tooltip: '添加视频',
                    onPressed: processingMedia
                        ? null
                        : () => _pickVideos(state),
                    icon: const Icon(Icons.video_library_outlined),
                  ),
                  IconButton(
                    tooltip: '添加附件',
                    onPressed: processingMedia ? null : _pickAttachments,
                    icon: const Icon(Icons.attach_file),
                  ),
                  IconButton(
                    tooltip: '选择日期',
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today_outlined),
                  ),
                  IconButton(
                    tooltip: '选择时间',
                    onPressed: _pickTime,
                    icon: const Icon(Icons.schedule),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImages(AppState state) async {
    setState(() => processingMedia = true);
    try {
      final storage = context.read<StorageService>();
      final values = await runLoading(
        context,
        '正在选择并处理图片…',
        (_) => storage.pickImagesWithMetadata(
          keepOriginal: state.keepOriginalMedia,
        ),
      );
      if (!mounted) return;
      for (final value in values) {
        images.add(value.path);
        if (value.liveVideoPath != null) videos.add(value.liveVideoPath!);
        _insertEmbed(BlockEmbed.image(value.path));
      }
      if (values.isNotEmpty) {
        final liveCount = values
            .where((image) => image.liveVideoPath != null)
            .length;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已添加 ${values.length} 张照片，其中 $liveCount 张识别为实况'),
          ),
        );
      }
      final dated = values
          .where((value) => value.capturedAt != null)
          .firstOrNull;
      if (dated != null && mounted) {
        final capturedAt = dated.capturedAt!;
        final usePhotoDate = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('使用照片拍摄日期？'),
            content: Text(
              '检测到“${dated.sourceName}”拍摄于\n'
              '${DateFormat('yyyy年M月d日 HH:mm').format(capturedAt)}\n\n'
              '是否将这篇日记的日期和时间修改为照片拍摄时间？',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('保持当前日期'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('修改日期'),
              ),
            ],
          ),
        );
        if (usePhotoDate == true && mounted) {
          setState(() => date = capturedAt);
        }
      }
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('添加图片失败：$error')));
    } finally {
      if (mounted) setState(() => processingMedia = false);
    }
  }

  Future<void> _pickVideos(AppState state) async {
    setState(() => processingMedia = true);
    try {
      final storage = context.read<StorageService>();
      final values = await runLoading(
        context,
        '正在选择并处理视频，大视频需要一些时间…',
        (_) => storage.pickVideos(keepOriginal: state.keepOriginalMedia),
      );
      if (!mounted) return;
      for (final path in values) {
        videos.add(path);
        _insertEmbed(BlockEmbed.video(path));
      }
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('添加视频失败：$error')));
    } finally {
      if (mounted) setState(() => processingMedia = false);
    }
  }

  Future<void> _pickAttachments() async {
    setState(() => processingMedia = true);
    try {
      final storage = context.read<StorageService>();
      final values = await runLoading(
        context,
        '正在选择并保存附件…',
        (_) => storage.pickAttachments(),
      );
      if (mounted) setState(() => attachments.addAll(values));
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('添加附件失败：$error')));
    } finally {
      if (mounted) setState(() => processingMedia = false);
    }
  }

  void _insertEmbed(BlockEmbed embed) {
    final selection = editor.selection;
    final start = selection.isValid
        ? selection.start.clamp(0, editor.document.length - 1)
        : editor.document.length - 1;
    final length = selection.isValid ? selection.end - selection.start : 0;
    editor.replaceText(
      start,
      length,
      embed,
      TextSelection.collapsed(offset: start + 1),
    );
  }

  Future<void> _newTag(AppState state) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新建标签'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '例如：电影'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('创建'),
          ),
        ],
      ),
    );
    if (value != null && value.trim().isNotEmpty) {
      await state.addTag(value);
      if (mounted) setState(() => selectedTags.add(value.trim()));
    }
  }
}
