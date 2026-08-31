import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as image;
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/diary_entry.dart';
import '../models/profile.dart';
import '../models/reading_book.dart';
import 'storage_service.dart';
import 'backup_worker.dart';

typedef BackupProgressCallback =
    void Function(String phase, int completed, int total);

class BackupExportResult {
  const BackupExportResult(this.file, this.itemCount);
  final File file;
  final int itemCount;
}

class BackupPayload {
  const BackupPayload({
    required this.diaries,
    required this.tags,
    required this.categories,
    required this.books,
    required this.summaries,
    required this.profile,
    required this.settings,
    required this.mediaNames,
    this.sourceArchive,
  });
  final List<DiaryEntry> diaries;
  final List<String> tags;
  final List<String> categories;
  final List<ReadingBook> books;
  final Map<String, String> summaries;
  final UserProfile profile;
  final Map<String, dynamic> settings;

  /// ZIP entry names only. Keeping all media bytes here used several GB of
  /// RAM for a large backup and caused Android to terminate the app.
  final List<String> mediaNames;
  final File? sourceArchive;
}

class BackupService {
  BackupService(this.storage);
  final StorageService storage;
  static const _format = 'xiaoluo_diary_backup';
  static const _version = 1;

  Future<BackupExportResult> exportData({
    required List<DiaryEntry> diaries,
    required List<String> tags,
    required List<String> categories,
    required List<ReadingBook> books,
    required Map<String, String> summaries,
    required UserProfile profile,
    required Map<String, dynamic> settings,
    String? rangeLabel,
    BackupProgressCallback? onProgress,
  }) async {
    final exportFolder = await _exportFolder();
    final mediaFiles = <String, File>{};
    final pathMap = <String, String>{};

    Future<String> backupPath(String source, String type) async {
      if (source.isEmpty) return '';
      if (pathMap.containsKey(source)) return pathMap[source]!;
      final sourceFile = File(source);
      if (!await sourceFile.exists()) return '';
      final suffix = sha1
          .convert(utf8.encode(source))
          .toString()
          .substring(0, 12);
      final target = 'media/$type/$suffix-${p.basename(source)}';
      pathMap[source] = target;
      mediaFiles[target] = sourceFile;
      return target;
    }

    final diaryMaps = <Map<String, Object?>>[];
    final sourceItemTotal = diaries.length + books.length + 1;
    var sourceItemIndex = 0;
    onProgress?.call('正在整理日记和媒体…', 0, sourceItemTotal);
    for (final diary in diaries) {
      final savedImages = [
        for (final path in diary.images) await backupPath(path, 'images'),
      ];
      final savedVideos = [
        for (final path in diary.videos) await backupPath(path, 'videos'),
      ];
      final saved = diary.copyWith(
        images: savedImages,
        videos: savedVideos,
        attachments: [
          for (final path in diary.attachments)
            await backupPath(path, 'attachments'),
        ],
        richContent: _rewriteRichMedia(
          diary.richContent,
          (type, value) => pathMap[value] ?? value,
        ),
      );
      diaryMaps.add(saved.toMap());
      sourceItemIndex++;
      onProgress?.call('正在整理日记和媒体…', sourceItemIndex, sourceItemTotal);
    }
    final bookMaps = <Map<String, Object?>>[];
    for (final book in books) {
      bookMaps.add(
        book
            .copyWith(coverPath: await backupPath(book.coverPath, 'covers'))
            .toMap(),
      );
      sourceItemIndex++;
      onProgress?.call('正在整理日记和媒体…', sourceItemIndex, sourceItemTotal);
    }
    final profileMap = {
      'nickname': profile.nickname,
      'signature': profile.signature,
      'birthday': profile.birthday,
      'homeText': profile.homeText,
      'avatarPath': await backupPath(profile.avatarPath, 'avatar'),
    };
    onProgress?.call('正在整理日记和媒体…', sourceItemTotal, sourceItemTotal);
    final data = <String, dynamic>{
      'diaries': diaryMaps,
      'tags': tags,
      'categories': categories,
      'books': bookMaps,
      'summaries': summaries,
      'profile': profileMap,
      'settings': settings,
    };
    final dataBytes = utf8.encode(jsonEncode(data));
    final manifest = <String, dynamic>{
      'format': _format,
      'version': _version,
      'createdAt': DateTime.now().toIso8601String(),
      'dataSha256': sha256.convert(dataBytes).toString(),
      'diaryCount': diaries.length,
      'bookCount': books.length,
      'mediaCount': mediaFiles.length,
      if (rangeLabel != null) 'dateRange': rangeLabel,
    };
    final file = File(
      p.join(
        exportFolder.path,
        '${rangeLabel == null ? '小罗日记数据备份' : '小罗日记增量备份_$rangeLabel'}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.zip',
      ),
    );
    await runBackupWorker({
      'action': 'export',
      'path': file.path,
      'json': {
        'manifest.json': jsonEncode(manifest),
        'data.json': jsonEncode(data),
      },
      'media': {
        for (final entry in mediaFiles.entries) entry.key: entry.value.path,
      },
    }, onProgress);
    return BackupExportResult(file, diaries.length + books.length);
  }

  Future<File> exportPdf({
    required List<DiaryEntry> diaries,
    required UserProfile profile,
  }) async {
    final folder = await _exportFolder();
    final file = File(
      p.join(
        folder.path,
        '小罗日记_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf',
      ),
    );
    final fontData = await rootBundle.load('assets/fonts/SimHei.ttf');
    final path = file.path;
    await Isolate.run(() => _renderPdf(diaries, profile, fontData, path));
    return file;
  }

  static Future<void> _renderPdf(
    List<DiaryEntry> diaries,
    UserProfile profile,
    ByteData fontData,
    String path,
  ) async {
    final font = pw.Font.ttf(fontData);
    final document = pw.Document(
      title: '小罗日记',
      author: profile.nickname,
      creator: '小罗日记',
    );
    final heading = pw.TextStyle(
      font: font,
      fontSize: 19,
      fontWeight: pw.FontWeight.bold,
    );
    final title = pw.TextStyle(
      font: font,
      fontSize: 14,
      fontWeight: pw.FontWeight.bold,
    );
    final body = pw.TextStyle(font: font, fontSize: 10.5, lineSpacing: 4);
    final muted = pw.TextStyle(
      font: font,
      fontSize: 9,
      color: PdfColors.grey700,
    );
    final widgets = <pw.Widget>[
      pw.Text('小罗日记', style: heading),
      pw.SizedBox(height: 5),
      pw.Text(
        '导出于 ${DateFormat('yyyy年M月d日 HH:mm').format(DateTime.now())} · 共 ${diaries.length} 篇',
        style: muted,
      ),
      pw.SizedBox(height: 18),
    ];
    for (final diary in diaries) {
      widgets.add(
        pw.Text(
          DateFormat('yyyy年M月d日  HH:mm').format(diary.diaryDate),
          style: muted,
        ),
      );
      widgets.add(pw.SizedBox(height: 4));
      if (diary.displayTitle.isNotEmpty)
        widgets.add(pw.Text(diary.displayTitle, style: title));
      if (diary.tags.isNotEmpty) {
        widgets.add(pw.SizedBox(height: 4));
        widgets.add(
          pw.Text(diary.tags.map((tag) => '#$tag').join('  '), style: muted),
        );
      }
      if (diary.displayContent.isNotEmpty) {
        widgets.add(pw.SizedBox(height: 7));
        widgets.add(pw.Text(diary.displayContent, style: body));
      }
      final pictures = await _pdfImages(diary.images);
      if (pictures.isNotEmpty) {
        widgets.add(pw.SizedBox(height: 8));
        widgets.add(pw.Wrap(spacing: 7, runSpacing: 7, children: pictures));
      }
      if (diary.attachments.isNotEmpty || diary.videos.isNotEmpty) {
        widgets.add(pw.SizedBox(height: 7));
        widgets.add(
          pw.Text(
            '附件 ${diary.attachments.length} 个 · 视频 ${diary.videos.length} 个',
            style: muted,
          ),
        );
      }
      widgets.add(pw.SizedBox(height: 15));
      widgets.add(pw.Divider(color: PdfColors.grey300));
      widgets.add(pw.SizedBox(height: 15));
    }
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(42, 46, 42, 44),
        theme: pw.ThemeData.withFont(base: font, bold: font),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            '小罗日记 · ${context.pageNumber}/${context.pagesCount}',
            style: muted,
          ),
        ),
        build: (_) => widgets,
      ),
    );
    await File(path).writeAsBytes(await document.save(), flush: true);
  }

  Future<BackupPayload> readBackup(
    File file, {
    BackupProgressCallback? onProgress,
  }) async {
    if (!await file.exists()) throw const FormatException('找不到备份文件');
    final result =
        await runBackupWorker({
              'action': 'inspect',
              'path': file.path,
            }, onProgress)
            as Map;
    final data = Map<String, dynamic>.from(result['data'] as Map);
    final mediaNames = List<String>.from(result['names'] as List);
    final profileMap = Map<String, dynamic>.from(
      data['profile'] as Map? ?? const {},
    );
    return BackupPayload(
      diaries: (data['diaries'] as List? ?? const [])
          .map((e) => DiaryEntry.fromMap(Map<String, Object?>.from(e as Map)))
          .toList(),
      tags: List<String>.from(data['tags'] as List? ?? const []),
      categories: List<String>.from(data['categories'] as List? ?? const []),
      books: (data['books'] as List? ?? const [])
          .map((e) => ReadingBook.fromMap(Map<String, Object?>.from(e as Map)))
          .toList(),
      summaries: Map<String, String>.from(
        data['summaries'] as Map? ?? const {},
      ),
      profile: UserProfile(
        nickname: profileMap['nickname'] as String? ?? '小罗',
        signature: profileMap['signature'] as String? ?? '',
        birthday: profileMap['birthday'] as String? ?? '',
        homeText: profileMap['homeText'] as String? ?? '',
        avatarPath: profileMap['avatarPath'] as String? ?? '',
      ),
      settings: Map<String, dynamic>.from(data['settings'] as Map? ?? const {}),
      mediaNames: mediaNames,
      sourceArchive: file,
    );
  }

  Future<BackupPayload> materializeMedia(
    BackupPayload payload, {
    BackupProgressCallback? onProgress,
  }) async {
    final root = await storage.mediaRoot();
    await root.create(recursive: true);
    final archiveFile = payload.sourceArchive;
    if (archiveFile == null) {
      throw const FormatException('备份媒体来源不可用，请重新选择备份文件');
    }
    await runBackupWorker({
      'action': 'restore',
      'path': archiveFile.path,
      'root': root.path,
      'names': payload.mediaNames,
    }, onProgress);
    String resolve(String value) => value.startsWith('media/')
        ? p.join(root.path, value.substring('media/'.length))
        : value;
    return BackupPayload(
      diaries: payload.diaries.map((entry) {
        final images = entry.images.map(resolve).toList();
        final videos = entry.videos.map(resolve).toList();
        String restoreEmbed(String type, String value) {
          if (value.startsWith('media/')) return resolve(value);
          final candidates = type == 'image' ? images : videos;
          final originalName = p.basename(value);
          for (final candidate in candidates) {
            final name = p.basename(candidate);
            if (name == originalName || name.endsWith('-$originalName')) {
              return candidate;
            }
          }
          return value;
        }

        return entry.copyWith(
          images: images,
          videos: videos,
          attachments: entry.attachments.map(resolve).toList(),
          richContent: _rewriteRichMedia(entry.richContent, restoreEmbed),
        );
      }).toList(),
      tags: payload.tags,
      categories: payload.categories,
      books: payload.books
          .map((book) => book.copyWith(coverPath: resolve(book.coverPath)))
          .toList(),
      summaries: payload.summaries,
      profile: payload.profile.copyWith(
        avatarPath: resolve(payload.profile.avatarPath),
      ),
      settings: payload.settings,
      mediaNames: payload.mediaNames,
      sourceArchive: payload.sourceArchive,
    );
  }

  Future<Directory> _exportFolder() async {
    final folder = Directory(
      p.join((await storage.mediaRoot()).path, 'exports'),
    );
    await folder.create(recursive: true);
    return folder;
  }

  static String _rewriteRichMedia(
    String source,
    String Function(String type, String value) rewrite,
  ) {
    if (source.isEmpty) return source;
    try {
      final delta = jsonDecode(source) as List;
      for (final operation in delta) {
        if (operation is! Map) continue;
        final insert = operation['insert'];
        if (insert is! Map) continue;
        for (final type in const ['image', 'video']) {
          final value = insert[type];
          if (value is String && value.isNotEmpty) {
            insert[type] = rewrite(type, value);
          }
        }
      }
      return jsonEncode(delta);
    } catch (_) {
      return source;
    }
  }

  static Future<List<pw.Widget>> _pdfImages(List<String> paths) async {
    final widgets = <pw.Widget>[];
    for (final path in paths.take(4)) {
      try {
        final decoded = image.decodeImage(await File(path).readAsBytes());
        if (decoded == null) continue;
        final resized = decoded.width > 900
            ? image.copyResize(decoded, width: 900)
            : decoded;
        widgets.add(
          pw.Container(
            width: 150,
            height: 112,
            child: pw.Image(
              pw.MemoryImage(
                Uint8List.fromList(image.encodeJpg(resized, quality: 78)),
              ),
              fit: pw.BoxFit.cover,
            ),
          ),
        );
      } catch (_) {
        // A deleted or unsupported image should not prevent PDF export.
      }
    }
    return widgets;
  }
}
