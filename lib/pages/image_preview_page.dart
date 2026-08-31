import 'dart:io';
import 'dart:ui' as ui;
import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../services/storage_service.dart';

class ImagePreviewPage extends StatefulWidget {
  const ImagePreviewPage({
    super.key,
    required this.paths,
    this.initialIndex = 0,
    this.caption,
    this.onDelete,
    this.liveVideos = const {},
  });
  final List<String> paths;
  final int initialIndex;
  final String? caption;
  final Future<bool> Function(String path)? onDelete;
  final Map<String, String> liveVideos;
  @override
  State<ImagePreviewPage> createState() => _ImagePreviewPageState();
}

class _ImagePreviewPageState extends State<ImagePreviewPage> {
  late final PageController controller = PageController(
    initialPage: widget.initialIndex,
  );
  late int index = widget.initialIndex;
  late final List<String> paths = [...widget.paths];
  VideoPlayerController? liveController;
  bool playingLive = false;
  bool loadingLive = false;
  int liveRequest = 0;
  String? loadedLivePath;

  String? get _livePath =>
      paths.isEmpty ? null : widget.liveVideos[paths[index]];

  void _liveUpdated() {
    final value = liveController?.value;
    if (mounted &&
        playingLive &&
        value != null &&
        (value.hasError ||
            (!value.isPlaying && value.position >= value.duration))) {
      setState(() => playingLive = false);
    }
  }

  void _resetLive() {
    liveRequest++;
    final previous = liveController;
    liveController = null;
    loadedLivePath = null;
    playingLive = false;
    loadingLive = false;
    previous?.removeListener(_liveUpdated);
    previous?.dispose();
  }

  Future<void> _toggleLive() async {
    final path = _livePath;
    if (path == null || loadingLive) return;
    final request = ++liveRequest;
    VideoPlayerController? pending;
    try {
      if (playingLive && liveController != null) {
        await liveController!.pause();
        if (mounted && request == liveRequest)
          setState(() => playingLive = false);
        return;
      }
      setState(() => loadingLive = true);
      if (loadedLivePath != path || liveController == null) {
        pending = VideoPlayerController.file(File(path));
        await pending.initialize();
        if (!mounted || request != liveRequest) {
          await pending.dispose();
          return;
        }
        final previous = liveController;
        previous?.removeListener(_liveUpdated);
        previous?.dispose();
        liveController = pending;
        pending = null;
        loadedLivePath = path;
        liveController!.addListener(_liveUpdated);
      }
      final video = liveController!;
      await video.seekTo(Duration.zero);
      if (!mounted || request != liveRequest) return;
      await video.play();
      if (mounted && request == liveRequest) setState(() => playingLive = true);
    } catch (_) {
      await pending?.dispose();
      if (mounted && request == liveRequest) {
        setState(_resetLive);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('实况视频暂时无法播放，原照片仍可查看。请保留原文件供排查。')),
        );
      }
    } finally {
      if (mounted && request == liveRequest)
        setState(() => loadingLive = false);
    }
  }

  void _changePage(int value) {
    setState(() {
      _resetLive();
      index = value;
    });
  }

  @override
  void dispose() {
    controller.dispose();
    _resetLive();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      title: Text('${index + 1} / ${paths.length}'),
      actions: [
        PopupMenuButton<String>(
          onSelected: (value) async {
            final path = paths[index];
            if (value == 'save') {
              final saved = await context
                  .read<StorageService>()
                  .saveMediaToGallery(path, isVideo: false);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(saved ? '图片已保存到相册' : '未能保存图片')),
                );
              }
            } else if (value == 'share') {
              await SharePlus.instance.share(ShareParams(files: [XFile(path)]));
            } else if (value == 'delete' && widget.onDelete != null) {
              final confirmed =
                  await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('删除这张照片？'),
                      content: const Text('照片会从这篇日记中移除。'),
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
              if (await widget.onDelete!(path) && mounted) {
                setState(() {
                  _resetLive();
                  paths.removeAt(index);
                  if (index >= paths.length && index > 0) index--;
                });
                if (paths.isEmpty && context.mounted) {
                  Navigator.pop(context);
                } else {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && controller.hasClients)
                      controller.jumpToPage(index);
                  });
                }
              }
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'save', child: Text('保存到相册')),
            const PopupMenuItem(value: 'share', child: Text('分享')),
            if (widget.onDelete != null)
              const PopupMenuItem(value: 'delete', child: Text('删除照片')),
          ],
        ),
      ],
    ),
    body: Stack(
      children: [
        PageView.builder(
          controller: controller,
          itemCount: paths.length,
          onPageChanged: _changePage,
          itemBuilder: (_, i) => StablePhotoViewport(
            key: ValueKey(paths[i]),
            path: paths[i],
            motion:
                playingLive &&
                    i == index &&
                    liveController?.value.isInitialized == true
                ? VideoPlayer(liveController!)
                : null,
            motionSize: liveController?.value.size,
          ),
        ),
        if (_livePath != null && File(_livePath!).existsSync())
          Positioned(
            left: 18,
            bottom: widget.caption == null ? 22 : 58,
            child: FilledButton.tonalIcon(
              onPressed: loadingLive ? null : _toggleLive,
              icon: loadingLive
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(playingLive ? Icons.pause : Icons.motion_photos_on),
              label: Text(
                loadingLive ? '加载实况…' : (playingLive ? '暂停实况' : '实况'),
              ),
            ),
          ),
        if (widget.caption != null)
          Positioned(
            left: 20,
            right: 20,
            bottom: 30,
            child: Text(
              widget.caption!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
      ],
    ),
  );
}

/// The still image determines the viewport for both still and motion. A video
/// encoded at 1920x1080 must not suddenly shrink a portrait photo's viewport.
class StablePhotoViewport extends StatefulWidget {
  const StablePhotoViewport({
    super.key,
    required this.path,
    this.motion,
    this.motionSize,
  });
  final String path;
  final Widget? motion;
  final Size? motionSize;
  @override
  State<StablePhotoViewport> createState() => _StablePhotoViewportState();
}

class _StablePhotoViewportState extends State<StablePhotoViewport> {
  Size? size;
  final transform = TransformationController();
  @override
  void initState() {
    super.initState();
    _readSize();
  }

  Future<void> _readSize() async {
    try {
      final buffer = await ui.ImmutableBuffer.fromFilePath(widget.path);
      try {
        final image = await ui.ImageDescriptor.encoded(buffer);
        final value = Size(image.width.toDouble(), image.height.toDouble());
        image.dispose();
        if (mounted) setState(() => size = value);
      } finally {
        buffer.dispose();
      }
    } catch (_) {
      /* The image below renders its own error state. */
    }
  }

  @override
  void dispose() {
    transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final available = constraints.biggest;
      final display = size == null
          ? available
          : applyBoxFit(BoxFit.contain, size!, available).destination;
      return InteractiveViewer(
        transformationController: transform,
        child: Center(
          child: SizedBox(
            key: const ValueKey('photo-viewport'),
            width: display.width,
            height: display.height,
            child: ClipRect(
              child: widget.motion == null
                  ? Image.file(File(widget.path), fit: BoxFit.contain)
                  : FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: widget.motionSize?.width ?? display.width,
                        height: widget.motionSize?.height ?? display.height,
                        child: widget.motion,
                      ),
                    ),
            ),
          ),
        ),
      );
    },
  );
}
