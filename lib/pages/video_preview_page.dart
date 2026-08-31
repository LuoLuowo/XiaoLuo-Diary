import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../services/storage_service.dart';

class VideoPreviewPage extends StatefulWidget {
  const VideoPreviewPage({super.key, required this.path, this.caption});

  final String path;
  final String? caption;

  @override
  State<VideoPreviewPage> createState() => _VideoPreviewPageState();
}

class _VideoPreviewPageState extends State<VideoPreviewPage> {
  late final VideoPlayerController controller = VideoPlayerController.file(
    File(widget.path),
  );
  bool ready = false;

  @override
  void initState() {
    super.initState();
    controller.initialize().then((_) {
      if (!mounted) return;
      setState(() => ready = true);
      controller.play();
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      title: Text(widget.caption ?? '视频'),
      actions: [
        PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'save') {
              final saved = await context
                  .read<StorageService>()
                  .saveMediaToGallery(widget.path, isVideo: true);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(saved ? '视频已保存到相册' : '未能保存视频')),
                );
              }
            } else if (value == 'share') {
              await SharePlus.instance.share(
                ShareParams(files: [XFile(widget.path)]),
              );
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'save', child: Text('保存到相册')),
            PopupMenuItem(value: 'share', child: Text('分享')),
          ],
        ),
      ],
    ),
    body: Center(
      child: ready
          ? GestureDetector(
              onTap: () => setState(() {
                controller.value.isPlaying
                    ? controller.pause()
                    : controller.play();
              }),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AspectRatio(
                    aspectRatio: controller.value.aspectRatio == 0
                        ? 16 / 9
                        : controller.value.aspectRatio,
                    child: VideoPlayer(controller),
                  ),
                  if (!controller.value.isPlaying)
                    const CircleAvatar(
                      radius: 31,
                      backgroundColor: Colors.black54,
                      child: Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 43,
                      ),
                    ),
                ],
              ),
            )
          : const CircularProgressIndicator(color: Colors.white),
    ),
  );
}
