import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../pages/video_preview_page.dart';

class VideoThumbnail extends StatefulWidget {
  const VideoThumbnail({
    super.key,
    required this.path,
    this.caption,
    this.height = 210,
    this.borderRadius = 18,
  });

  final String path;
  final String? caption;
  final double height;
  final double borderRadius;

  @override
  State<VideoThumbnail> createState() => _VideoThumbnailState();
}

class _VideoThumbnailState extends State<VideoThumbnail> {
  late final VideoPlayerController controller = VideoPlayerController.file(
    File(widget.path),
  );
  bool ready = false;

  @override
  void initState() {
    super.initState();
    controller.initialize().then((_) {
      if (mounted) setState(() => ready = true);
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(widget.borderRadius),
    child: Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                VideoPreviewPage(path: widget.path, caption: widget.caption),
          ),
        ),
        child: SizedBox(
          width: double.infinity,
          height: widget.height,
          child: Stack(
            fit: StackFit.expand,
            alignment: Alignment.center,
            children: [
              if (ready)
                FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: controller.value.size.width,
                    height: controller.value.size.height,
                    child: VideoPlayer(controller),
                  ),
                )
              else
                const Center(child: CircularProgressIndicator()),
              const Center(
                child: CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.black54,
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 39,
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
