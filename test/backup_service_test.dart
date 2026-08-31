import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:xiaoluo_diary/models/diary_entry.dart';
import 'package:xiaoluo_diary/models/profile.dart';
import 'package:xiaoluo_diary/services/backup_service.dart';
import 'package:xiaoluo_diary/services/storage_service.dart';

class _TestStorage extends StorageService {
  _TestStorage(this.root);
  final Directory root;

  @override
  Future<Directory> mediaRoot() async => root;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('exports a readable Chinese PDF', () async {
    final root = Directory('output/pdf');
    await root.create(recursive: true);
    final service = BackupService(_TestStorage(root));
    final now = DateTime(2026, 8, 29, 19, 20);
    final file = await service.exportPdf(
      profile: const UserProfile(nickname: '小罗'),
      diaries: [
        DiaryEntry(
          title: '炸酥肉',
          content: '今天自己尝试炸了一次酥肉，味道居然还不错。\n这是用于检查导出排版的测试内容。',
          diaryDate: now,
          createdAt: now,
          updatedAt: now,
          category: '',
          tags: const ['美食', '生活'],
          images: const [],
          attachments: const [],
        ),
      ],
    );
    expect(await file.exists(), isTrue);
    expect(await file.length(), greaterThan(1000));
  });

  test('round-trips a complete data backup', () async {
    final root = Directory('output/backup-test');
    await root.create(recursive: true);
    final imageFolder = Directory(
      '${root.path}${Platform.pathSeparator}images',
    );
    await imageFolder.create(recursive: true);
    final media = File('${imageFolder.path}${Platform.pathSeparator}photo.jpg');
    await media.writeAsBytes([1, 2, 3, 4]);
    final service = BackupService(_TestStorage(root));
    final now = DateTime(2026, 8, 29, 19, 20);
    final export = await service.exportData(
      diaries: [
        DiaryEntry(
          id: 1,
          title: '备份测试',
          content: '这是一条可恢复的数据。',
          richContent: jsonEncode([
            {'insert': '这是一条可恢复的数据。\n'},
            {
              'insert': {'image': media.path},
            },
            {'insert': '\n'},
          ]),
          diaryDate: now,
          createdAt: now,
          updatedAt: now,
          category: '',
          tags: const ['测试'],
          images: [media.path],
          attachments: const [],
        ),
      ],
      tags: const ['测试'],
      categories: const [],
      books: const [],
      summaries: const {'2026': '年总结'},
      profile: const UserProfile(nickname: '小罗'),
      settings: const {'showTimeline': true},
    );
    final parsed = await service.readBackup(export.file);
    final restored = await service.materializeMedia(parsed);
    expect(parsed.diaries, hasLength(1));
    expect(restored.diaries.single.title, '备份测试');
    expect(await File(restored.diaries.single.images.single).exists(), isTrue);
    final restoredDelta =
        jsonDecode(restored.diaries.single.richContent) as List;
    final restoredEmbed = (restoredDelta[1] as Map)['insert'] as Map;
    expect(restoredEmbed['image'], restored.diaries.single.images.single);
    expect(await File(restoredEmbed['image'] as String).exists(), isTrue);
  });

  test(
    'background streaming backup preserves a large media file and reports progress',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'xiaoluo_stream_test_',
      );
      try {
        final media = File('${root.path}/large.mp4');
        final sink = media.openWrite();
        final block = Uint8List.fromList(
          List<int>.generate(1024 * 1024, (i) => i % 251),
        );
        for (var i = 0; i < 16; i++) {
          sink.add(block);
        }
        await sink.close();
        final service = BackupService(_TestStorage(root));
        final phases = <String>[];
        final export = await service.exportData(
          diaries: [
            DiaryEntry(
              id: 1,
              title: '',
              content: '视频正文',
              diaryDate: DateTime(2026),
              createdAt: DateTime(2026),
              updatedAt: DateTime(2026),
              category: '',
              tags: [],
              images: [],
              videos: [media.path],
              attachments: [],
            ),
          ],
          tags: [],
          categories: [],
          books: [],
          summaries: {},
          profile: const UserProfile(),
          settings: {},
          onProgress: (phase, done, total) => phases.add(phase),
        );
        final preview = await service.readBackup(export.file);
        expect(preview.mediaNames, hasLength(1));
        final restored = await service.materializeMedia(
          preview,
          onProgress: (phase, done, total) => phases.add(phase),
        );
        final result = File(restored.diaries.single.videos.single);
        expect(await result.length(), 16 * 1024 * 1024);
        expect(
          await sha256.bind(result.openRead()).first,
          await sha256.bind(media.openRead()).first,
        );
        expect(phases.any((phase) => phase.contains('打包')), isTrue);
        expect(phases.any((phase) => phase.contains('恢复')), isTrue);
      } finally {
        await root.delete(recursive: true);
      }
    },
  );
}
