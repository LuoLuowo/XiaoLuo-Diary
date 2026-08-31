import 'dart:io';
import 'package:flutter/material.dart';
import '../models/diary_entry.dart';
import '../pages/image_preview_page.dart';
import '../utils/live_photo.dart';
import 'photo_grid.dart';

class DiaryCard extends StatelessWidget {
  const DiaryCard({
    super.key,
    required this.diary,
    required this.showSummary,
    required this.onTap,
    this.fontSize = 16,
  });
  final DiaryEntry diary;
  final bool showSummary;
  final VoidCallback onTap;
  final double fontSize;
  @override
  Widget build(BuildContext context) {
    final images = diary.images
        .where((path) => File(path).existsSync())
        .toList();
    return SizedBox(
      width: double.infinity,
      child: Card(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (diary.displayTitle.isNotEmpty)
                  Text(
                    diary.displayTitle,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: fontSize + 4,
                    ),
                  ),
                if (showSummary && diary.displayContent.isNotEmpty) ...[
                  if (diary.displayTitle.isNotEmpty) const SizedBox(height: 10),
                  Text(
                    diary.displayContent,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      height: 1.65,
                      fontSize: fontSize,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (images.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  TimelinePhotoGrid(
                    paths: images,
                    livePaths: {
                      for (final image in images)
                        if (livePhotoVideoForImage(image, diary.videos) != null)
                          image,
                    },
                    onTap: (index) => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ImagePreviewPage(
                          paths: images,
                          initialIndex: index,
                          caption: diary.displayTitle,
                          liveVideos: {
                            for (final image in images)
                              if (livePhotoVideoForImage(image, diary.videos)
                                  case final video?)
                                image: video,
                          },
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 15),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    for (final tag in diary.tags)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .secondaryContainer
                              .withValues(alpha: .65),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Text(
                          '#$tag',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ),
                    if (diary.attachments.isNotEmpty)
                      Chip(
                        visualDensity: VisualDensity.compact,
                        avatar: const Icon(Icons.attach_file, size: 15),
                        label: Text('${diary.attachments.length} 个附件'),
                      ),
                    if (diary.videos
                        .where((path) => !isLivePhotoVideo(path))
                        .isNotEmpty)
                      Chip(
                        visualDensity: VisualDensity.compact,
                        avatar: const Icon(Icons.play_circle_outline, size: 15),
                        label: Text(
                          '${diary.videos.where((path) => !isLivePhotoVideo(path)).length} 个视频',
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
