import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../utils/date_utils.dart';
import '../utils/rich_text_contrast.dart';
import '../utils/live_photo.dart';
import '../widgets/photo_grid.dart';
import '../widgets/video_thumbnail.dart';
import '../widgets/audio_attachment.dart';
import '../widgets/live_photo_badge.dart';
import 'diary_editor_page.dart';
import 'image_preview_page.dart';

class DiaryDetailPage extends StatefulWidget {
  const DiaryDetailPage({super.key, required this.diaryId});
  final int diaryId;
  @override
  State<DiaryDetailPage> createState() => _DiaryDetailPageState();
}

class _DiaryDetailPageState extends State<DiaryDetailPage> {
  List<int>? ids;
  PageController? pages;
  int index = 0;
  double pull = 0;
  bool turning = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (ids != null) return;
    ids = context.read<AppState>().diaries.map((diary) => diary.id!).toList();
    index = ids!.indexOf(widget.diaryId);
    if (index < 0) {
      ids = [widget.diaryId];
      index = 0;
    }
    pages = PageController(initialPage: index);
  }

  Future<void> _turn(int direction) async {
    final target = index + direction;
    if (turning || target < 0 || target >= ids!.length) return;
    turning = true;
    pull = 0;
    FocusManager.instance.primaryFocus?.unfocus();
    try {
      await pages!.animateToPage(
        target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    } finally {
      turning = false;
    }
  }

  bool _scroll(ScrollNotification event) {
    if (event.depth != 0 || turning) return false;
    if (event is ScrollStartNotification) pull = 0;
    if (event is OverscrollNotification && event.dragDetails != null) {
      if (pull.sign != event.overscroll.sign) pull = 0;
      pull += event.overscroll;
      if (pull.abs() > 75) _turn(pull > 0 ? 1 : -1);
    }
    if (event is ScrollEndNotification) pull = 0;
    return false;
  }

  @override
  void dispose() {
    pages?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PageView.builder(
    controller: pages,
    scrollDirection: Axis.vertical,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: ids!.length,
    onPageChanged: (value) => setState(() => index = value),
    itemBuilder: (context, page) => NotificationListener<ScrollNotification>(
      onNotification: _scroll,
      child: _DiaryDetailContent(
        key: ValueKey(ids![page]),
        diaryId: ids![page],
        position: '${page + 1} / ${ids!.length}',
        onPrevious: page > 0 ? () => _turn(-1) : null,
        onNext: page + 1 < ids!.length ? () => _turn(1) : null,
      ),
    ),
  );
}

class _DiaryDetailContent extends StatelessWidget {
  const _DiaryDetailContent({
    super.key,
    required this.diaryId,
    required this.position,
    this.onPrevious,
    this.onNext,
  });
  final int diaryId;
  final String position;
  final VoidCallback? onPrevious, onNext;
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final matches = state.diaries.where((e) => e.id == diaryId);
    if (matches.isEmpty)
      return const Scaffold(body: Center(child: Text('这篇日记已经不存在了')));
    final diary = matches.first;
    final embeddedMedia = _richMediaPaths(diary.richContent);
    final extraImages = diary.images
        .where((path) => !embeddedMedia.contains(p.normalize(path)))
        .toList();
    final extraVideos = diary.videos
        .where(
          (path) =>
              !isLivePhotoVideo(path) &&
              !embeddedMedia.contains(p.normalize(path)),
        )
        .toList();
    Future<bool> removeImage(String path) async {
      final current = state.diaries.where((value) => value.id == diaryId);
      if (current.isEmpty) return false;
      final latest = current.first;
      await state.saveDiary(
        latest.copyWith(
          images: latest.images
              .where((value) => p.normalize(value) != p.normalize(path))
              .toList(),
          videos: latest.videos
              .where(
                (video) => video != livePhotoVideoForImage(path, latest.videos),
              )
              .toList(),
          richContent: _removeRichMedia(latest.richContent, 'image', path),
          updatedAt: DateTime.now(),
        ),
      );
      return true;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(position, style: Theme.of(context).textTheme.labelLarge),
        actions: [
          IconButton(
            tooltip: '编辑',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => DiaryEditorPage(diary: diary)),
            ),
            icon: const Icon(Icons.edit_outlined),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'delete') await _delete(context, state, diary);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline),
                    SizedBox(width: 10),
                    Text('删除日记'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780),
          child: ListView(
            key: PageStorageKey('reading-$diaryId'),
            physics: const ClampingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(26, 12, 26, 70),
            children: [
              if (onPrevious != null)
                Align(
                  alignment: Alignment.center,
                  child: IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 28,
                      height: 22,
                    ),
                    tooltip: '上一篇',
                    onPressed: onPrevious,
                    icon: Icon(
                      Icons.keyboard_arrow_up_rounded,
                      size: 18,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withValues(alpha: .38),
                    ),
                  ),
                ),
              Text(
                diaryDate(diary.diaryDate),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              if (diary.displayTitle.isNotEmpty)
                Text(
                  diary.displayTitle,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              if (diary.content.isNotEmpty || diary.richContent.isNotEmpty) ...[
                if (diary.displayTitle.isNotEmpty) const SizedBox(height: 22),
                if (diary.richContent.isNotEmpty)
                  _DiaryRichContent(
                    key: ValueKey(diary.richContent),
                    json: diary.richContent,
                    fallback: diary.content,
                    fontSize: state.diaryFontSize,
                    photoRatioMode: state.photoRatioMode,
                    imagePaths: diary.images,
                    caption: diary.displayTitle,
                    onDeleteImage: removeImage,
                    liveVideos: diary.videos,
                  )
                else
                  Text(
                    diary.content,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontSize: state.diaryFontSize,
                      height: 1.9,
                    ),
                  ),
              ],
              if (extraVideos.isNotEmpty) ...[
                const SizedBox(height: 26),
                Text(
                  '视频',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                for (final file in extraVideos) ...[
                  VideoThumbnail(
                    path: file,
                    caption: diary.displayTitle,
                    borderRadius: 20,
                  ),
                  const SizedBox(height: 12),
                ],
              ],
              if (extraImages.isNotEmpty) ...[
                const SizedBox(height: 26),
                PhotoGrid(
                  paths: extraImages,
                  livePaths: {
                    for (final image in extraImages)
                      if (livePhotoVideoForImage(image, diary.videos) != null)
                        image,
                  },
                  height: 300,
                  mode: state.photoRatioMode,
                  onTap: (index) => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ImagePreviewPage(
                        paths: extraImages,
                        initialIndex: index,
                        caption: diary.displayTitle,
                        onDelete: removeImage,
                        liveVideos: {
                          for (final image in extraImages)
                            if (livePhotoVideoForImage(image, diary.videos)
                                case final video?)
                              image: video,
                        },
                      ),
                    ),
                  ),
                ),
              ],
              if (diary.attachments.isNotEmpty) ...[
                const SizedBox(height: 26),
                Text(
                  '附件',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                for (final file in diary.attachments)
                  if (isAudioAttachment(file))
                    AudioAttachment(key: ValueKey(file), path: file)
                  else
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        child: Icon(Icons.attach_file),
                      ),
                      title: Text(p.basename(file)),
                      subtitle: const Text('点击使用系统应用打开'),
                      onTap: () => OpenFilex.open(file),
                    ),
              ],
              const SizedBox(height: 24),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tag in diary.tags) Chip(label: Text('#$tag')),
                ],
              ),
              const SizedBox(height: 28),
              Center(
                child: onNext == null
                    ? const SizedBox(height: 22)
                    : IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 28,
                          height: 22,
                        ),
                        tooltip: '下一篇',
                        onPressed: onNext,
                        icon: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurfaceVariant.withValues(alpha: .38),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _delete(
    BuildContext context,
    AppState state,
    dynamic diary,
  ) async {
    final ok =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('删除这篇日记？'),
            content: const Text('删除后会移入回收站，30天内可以恢复。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('确认删除'),
              ),
            ],
          ),
        ) ??
        false;
    if (ok) {
      await state.deleteDiary(diary);
      if (context.mounted) Navigator.pop(context);
    }
  }
}

class _DiaryRichContent extends StatefulWidget {
  const _DiaryRichContent({
    super.key,
    required this.json,
    required this.fallback,
    required this.fontSize,
    required this.photoRatioMode,
    required this.imagePaths,
    required this.caption,
    required this.onDeleteImage,
    required this.liveVideos,
  });
  final String json;
  final String fallback;
  final double fontSize;
  final String photoRatioMode;
  final List<String> imagePaths;
  final String caption;
  final Future<bool> Function(String path) onDeleteImage;
  final List<String> liveVideos;

  @override
  State<_DiaryRichContent> createState() => _DiaryRichContentState();
}

class _DiaryRichContentState extends State<_DiaryRichContent> {
  late final QuillController controller;
  final focus = FocusNode(canRequestFocus: false);

  @override
  void initState() {
    super.initState();
    Document document;
    try {
      document = Document.fromJson(jsonDecode(widget.json) as List);
    } catch (_) {
      document = Document()..insert(0, widget.fallback);
    }
    controller = QuillController(
      document: document,
      selection: const TextSelection.collapsed(offset: 0),
      readOnly: true,
    );
  }

  @override
  void dispose() {
    controller.dispose();
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => QuillEditor.basic(
    controller: controller,
    focusNode: focus,
    config: QuillEditorConfig(
      scrollable: false,
      showCursor: false,
      enableInteractiveSelection: false,
      readOnlyMouseCursor: SystemMouseCursors.basic,
      checkBoxReadOnly: true,
      embedBuilders: [
        _RoundedImageEmbedBuilder(
          mode: widget.photoRatioMode,
          liveVideos: widget.liveVideos,
          onTap: (source) {
            final values = widget.imagePaths.contains(source)
                ? widget.imagePaths
                : [source];
            final index = values
                .indexOf(source)
                .clamp(0, values.length - 1)
                .toInt();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ImagePreviewPage(
                  paths: values,
                  initialIndex: index,
                  caption: widget.caption,
                  onDelete: widget.onDeleteImage,
                  liveVideos: {
                    for (final image in values)
                      if (livePhotoVideoForImage(image, widget.liveVideos)
                          case final video?)
                        image: video,
                  },
                ),
              ),
            );
          },
        ),
        ...FlutterQuillEmbeds.editorBuilders(
          imageEmbedConfig: null,
          videoEmbedConfig: QuillEditorVideoEmbedConfig(
            customVideoBuilder: (source, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: VideoThumbnail(
                path: source,
                caption: widget.caption,
                borderRadius: 20,
              ),
            ),
          ),
        ),
      ],
      customStyles: DefaultStyles(
        paragraph: DefaultTextBlockStyle(
          TextStyle(
            fontSize: widget.fontSize,
            height: 1.9,
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
  );
}

class _RoundedImageEmbedBuilder extends EmbedBuilder {
  const _RoundedImageEmbedBuilder({
    required this.onTap,
    required this.mode,
    required this.liveVideos,
  });

  final ValueChanged<String> onTap;
  final String mode;
  final List<String> liveVideos;

  @override
  String get key => BlockEmbed.imageType;

  @override
  bool get expanded => false;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final source = embedContext.node.value.data as String;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          child: InkWell(
            onTap: () => onTap(source),
            child: Stack(
              children: [
                _DetailInlineImage(path: source, mode: mode),
                if (livePhotoVideoForImage(source, liveVideos) != null)
                  const Positioned(left: 10, top: 10, child: LivePhotoBadge()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailInlineImage extends StatefulWidget {
  const _DetailInlineImage({required this.path, required this.mode});
  final String path;
  final String mode;
  @override
  State<_DetailInlineImage> createState() => _DetailInlineImageState();
}

class _DetailInlineImageState extends State<_DetailInlineImage> {
  double? actualRatio;
  @override
  void initState() {
    super.initState();
    _readRatio();
  }

  @override
  void didUpdateWidget(_DetailInlineImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) _readRatio();
  }

  Future<void> _readRatio() async {
    try {
      final buffer = await ui.ImmutableBuffer.fromFilePath(widget.path);
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      final value = descriptor.width / descriptor.height;
      descriptor.dispose();
      buffer.dispose();
      if (mounted) setState(() => actualRatio = value);
    } catch (_) {
      if (mounted) setState(() => actualRatio = 4 / 3);
    }
  }

  @override
  Widget build(BuildContext context) {
    final source = actualRatio ?? 4 / 3;
    final ratio = switch (widget.mode) {
      'landscape' => 16 / 9,
      'original' => source,
      _ => source >= 1 ? 4 / 3 : 3 / 4,
    };
    return AspectRatio(
      aspectRatio: ratio,
      child: Image.file(
        File(widget.path),
        fit: BoxFit.cover,
        cacheWidth: 1600,
        errorBuilder: (_, _, _) =>
            const Center(child: Icon(Icons.broken_image_outlined)),
      ),
    );
  }
}

Set<String> _richMediaPaths(String source) {
  if (source.isEmpty) return const {};
  try {
    final delta = jsonDecode(source) as List;
    final paths = <String>{};
    for (final operation in delta) {
      if (operation is! Map || operation['insert'] is! Map) continue;
      final insert = operation['insert'] as Map;
      for (final type in const ['image', 'video']) {
        final value = insert[type];
        if (value is String) paths.add(p.normalize(value));
      }
    }
    return paths;
  } catch (_) {
    return const {};
  }
}

String _removeRichMedia(String source, String type, String target) {
  if (source.isEmpty) return source;
  try {
    final delta = jsonDecode(source) as List;
    delta.removeWhere((operation) {
      if (operation is! Map || operation['insert'] is! Map) return false;
      final insert = operation['insert'] as Map;
      final value = insert[type];
      return value is String && p.normalize(value) == p.normalize(target);
    });
    return jsonEncode(delta);
  } catch (_) {
    return source;
  }
}
