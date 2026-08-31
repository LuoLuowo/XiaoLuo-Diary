import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:xiaoluo_diary/models/diary_entry.dart';
import 'package:xiaoluo_diary/models/profile.dart';
import 'package:xiaoluo_diary/services/backup_service.dart';
import 'package:xiaoluo_diary/services/motion_photo_extractor.dart';
import 'package:xiaoluo_diary/services/storage_service.dart';
import 'package:xiaoluo_diary/utils/diary_media.dart';
import 'package:xiaoluo_diary/utils/live_photo.dart';

List<int> box(String type, List<int> payload) => [
  ...(ByteData(4)..setUint32(0, payload.length + 8)).buffer.asUint8List(),
  ...ascii.encode(type),
  ...payload,
];

List<int> video({String handler = 'vide'}) => [
  ...box('ftyp', [
    ...ascii.encode('mp42'),
    0,
    0,
    0,
    0,
    ...ascii.encode('isom'),
  ]),
  ...box(
    'moov',
    box(
      'trak',
      box(
        'mdia',
        box('hdlr', [...List<int>.filled(8, 0), ...ascii.encode(handler)]),
      ),
    ),
  ),
  ...box('mdat', [1, 2, 3, 4, 5]),
];

class TestStorage extends StorageService {
  TestStorage(this.root);
  final Directory root;
  @override
  Future<Directory> mediaRoot() async => root;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  setUp(
    () async =>
        root = await Directory.systemTemp.createTemp('motion_photo_test_'),
  );
  tearDown(() async => root.delete(recursive: true));

  Future<String?> extract(List<int> input) async {
    final source = File('${root.path}/original.jpg');
    await source.writeAsBytes(input);
    return extractMotionPhoto(source.path, '${root.path}/motion.mp4');
  }

  test(
    'extracts legacy JPEG and new Container XMP without MicroVideoOffset',
    () async {
      final motion = video();
      for (final xmp in [
        '<rdf:Description GCamera:MicroVideoOffset="${motion.length}"/>',
        '<Container:Item Item:Mime="video/mp4" Item:Length="${motion.length}"/>',
        '<vivo:LivePhoto>1</vivo:LivePhoto>',
      ]) {
        final result = await extract([
          0xff,
          0xd8,
          ...ascii.encode(xmp),
          0xff,
          0xd9,
          ...motion,
        ]);
        expect(result, isNotNull);
        expect(await File(result!).readAsBytes(), motion);
      }
    },
  );

  test(
    'HEIC mpvd yields the embedded video, not the primary image container',
    () async {
      final motion = video();
      final result = await extract([
        ...box('ftyp', [
          ...ascii.encode('heic'),
          0,
          0,
          0,
          0,
          ...ascii.encode('mif1'),
        ]),
        ...box('mdat', [10, 11]),
        ...box('mpvd', motion),
      ]);
      expect(await File(result!).readAsBytes(), motion);
    },
  );

  test(
    'finds motion headers across scan chunks and excludes vendor trailers',
    () async {
      final motion = video();
      final result = await extract([
        0xff,
        0xd8,
        ...List<int>.filled(256 * 1024 - 8, 0),
        0xff,
        0xd9,
        ...motion,
        ...ascii.encode('VIVO_TRAILER'),
      ]);
      expect(await File(result!).readAsBytes(), motion);
    },
  );

  test(
    'ordinary still, stale XMP, audio-only and truncated MP4 are not live photos',
    () async {
      for (final input in [
        [0xff, 0xd8, 0xff, 0xd9],
        [
          0xff,
          0xd8,
          ...ascii.encode('MicroVideoOffset="999999" ftyp isom'),
          0xff,
          0xd9,
        ],
        [0xff, 0xd8, 0xff, 0xd9, ...video(handler: 'soun')],
        [0xff, 0xd8, 0xff, 0xd9, ...video().take(video().length - 2)],
        video(),
      ]) {
        expect(await extract(input), isNull);
      }
    },
  );

  test(
    'two backup/restore cycles keep the photo-motion link; editing never inserts a second video',
    () async {
      final photo = File('${root.path}/photo_123.jpg');
      final clip = File('${root.path}/${livePhotoVideoName(photo.path)}');
      await photo.writeAsBytes([0xff, 0xd8, 0xff, 0xd9]);
      await clip.writeAsBytes(video());
      var entry = DiaryEntry(
        id: 1,
        title: '实况测试',
        content: '',
        diaryDate: DateTime(2026, 8, 31),
        createdAt: DateTime(2026, 8, 31),
        updatedAt: DateTime(2026, 8, 31),
        category: '',
        tags: [],
        images: [photo.path],
        videos: [clip.path],
        attachments: [],
      );
      final service = BackupService(TestStorage(root));
      for (var cycle = 0; cycle < 2; cycle++) {
        final backup = await service.exportData(
          diaries: [entry],
          tags: [],
          categories: [],
          books: [],
          summaries: {},
          profile: const UserProfile(),
          settings: {},
        );
        final restored = await service.materializeMedia(
          await service.readBackup(backup.file),
        );
        entry = restored.diaries.single;
        final linked = livePhotoVideoForImage(
          entry.images.single,
          entry.videos,
        );
        expect(linked, isNotNull);
        expect(isLivePhotoVideo(linked!), isTrue);
        expect(await File(linked).readAsBytes(), video());
        expect(documentMedia(editableDiaryDocument(entry), 'video'), isEmpty);
        expect(
          documentMedia(editableDiaryDocument(entry), 'image'),
          hasLength(1),
        );
      }
    },
  );
}
