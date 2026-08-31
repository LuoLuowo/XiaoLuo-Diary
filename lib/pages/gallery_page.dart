import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/diary_entry.dart';
import '../services/app_state.dart';
import 'diary_detail_page.dart';
import 'image_preview_page.dart';
import '../utils/live_photo.dart';

class GalleryPage extends StatelessWidget {
  const GalleryPage({super.key});
  @override
  Widget build(BuildContext context) {
    final diaries = context
        .watch<AppState>()
        .diaries
        .where((d) => d.images.isNotEmpty)
        .toList();
    final groups = <String, List<DiaryEntry>>{};
    for (final diary in diaries) {
      groups
          .putIfAbsent(DateFormat('yyyy年M月').format(diary.diaryDate), () => [])
          .add(diary);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('我的画廊')),
      body: groups.isEmpty
          ? const Center(child: Text('日记里还没有照片'))
          : ListView(
              padding: const EdgeInsets.fromLTRB(22, 10, 22, 50),
              children: [
                for (final group in groups.entries) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 16, bottom: 12),
                    child: Text(
                      group.key,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 190,
                          mainAxisSpacing: 6,
                          crossAxisSpacing: 6,
                        ),
                    itemCount: group.value.fold<int>(
                      0,
                      (sum, e) => sum + e.images.length,
                    ),
                    itemBuilder: (_, index) {
                      var cursor = index;
                      late DiaryEntry diary;
                      late int imageIndex;
                      for (final item in group.value) {
                        if (cursor < item.images.length) {
                          diary = item;
                          imageIndex = cursor;
                          break;
                        }
                        cursor -= item.images.length;
                      }
                      return GestureDetector(
                        onTap: () => showModalBottomSheet(
                          context: context,
                          showDragHandle: true,
                          builder: (context) => Padding(
                            padding: const EdgeInsets.fromLTRB(22, 4, 22, 28),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    diary.displayTitle,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  subtitle: Text(
                                    DateFormat(
                                      'yyyy年M月d日',
                                    ).format(diary.diaryDate),
                                  ),
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () {
                                          Navigator.pop(context);
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => ImagePreviewPage(
                                                paths: diary.images,
                                                initialIndex: imageIndex,
                                                caption: diary.displayTitle,
                                                liveVideos: {
                                                  for (final image
                                                      in diary.images)
                                                    if (livePhotoVideoForImage(
                                                          image,
                                                          diary.videos,
                                                        )
                                                        case final video?)
                                                      image: video,
                                                },
                                              ),
                                            ),
                                          );
                                        },
                                        child: const Text('全屏查看'),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: FilledButton(
                                        onPressed: () {
                                          Navigator.pop(context);
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => DiaryDetailPage(
                                                diaryId: diary.id!,
                                              ),
                                            ),
                                          );
                                        },
                                        child: const Text('查看日记'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.file(
                            File(diary.images[imageIndex]),
                            fit: BoxFit.cover,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
    );
  }
}
