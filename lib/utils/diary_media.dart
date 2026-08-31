import 'dart:convert';
import 'dart:io';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:path/path.dart' as p;
import '../models/diary_entry.dart';
import 'live_photo.dart';

List<String> documentMedia(Document document, String type) => [
  for (final op in document.toDelta().toJson())
    if (op['insert'] is Map && (op['insert'] as Map)[type] is String)
      (op['insert'] as Map)[type] as String,
].toSet().toList();

Set<String> diaryMediaPaths(DiaryEntry diary) {
  final paths = <String>{
    ...diary.images,
    ...diary.videos,
    ...diary.attachments,
  };
  try {
    final document = Document.fromJson(jsonDecode(diary.richContent) as List);
    paths.addAll(documentMedia(document, 'image'));
    paths.addAll(documentMedia(document, 'video'));
  } catch (_) {
    /* Legacy diaries need only their media lists. */
  }
  return paths;
}

Document editableDiaryDocument(DiaryEntry? diary) {
  Document document;
  try {
    final delta = jsonDecode(diary?.richContent ?? '') as List;
    delta.removeWhere((op) {
      if (op is! Map || op['insert'] is! Map) return false;
      final insert = op['insert'] as Map;
      for (final type in const ['image', 'video']) {
        final value = insert[type];
        if (value is! String) continue;
        final candidates = type == 'image' ? diary!.images : diary!.videos;
        var resolved = value;
        for (final candidate in candidates) {
          final name = p.basename(candidate);
          if (File(candidate).existsSync() &&
              (p.normalize(candidate) == p.normalize(value) ||
                  name == p.basename(value) ||
                  name.endsWith('-${p.basename(value)}'))) {
            resolved = candidate;
            break;
          }
        }
        insert[type] = resolved;
        if (!File(resolved).existsSync()) return true;
      }
      return false;
    });
    if (delta.isEmpty ||
        delta.last['insert'] is! String ||
        !(delta.last['insert'] as String).endsWith('\n'))
      delta.add({'insert': '\n'});
    document = Document.fromJson(delta);
  } catch (_) {
    document = Document()..insert(0, diary?.displayContent ?? '');
  }
  for (final type in const ['image', 'video']) {
    final embedded = documentMedia(document, type).map(p.normalize).toSet();
    final candidates = type == 'image'
        ? diary?.images
        : diary?.videos.where((path) => !isLivePhotoVideo(path));
    for (final path in candidates ?? <String>[]) {
      if (File(path).existsSync() && !embedded.contains(p.normalize(path))) {
        document.insert(document.length - 1, '\n');
        document.insert(
          document.length - 1,
          type == 'image' ? BlockEmbed.image(path) : BlockEmbed.video(path),
        );
        document.insert(document.length - 1, '\n');
      }
    }
  }
  return document;
}
