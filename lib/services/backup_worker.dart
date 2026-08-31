import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

typedef WorkerProgress = void Function(String phase, int completed, int total);

Future<dynamic> runBackupWorker(
  Map<String, dynamic> job,
  WorkerProgress? progress,
) async {
  final port = ReceivePort();
  final isolate = await Isolate.spawn(
    _worker,
    (job, port.sendPort),
    onError: port.sendPort,
    onExit: port.sendPort,
  );
  try {
    await for (final event in port) {
      if (event is Map) {
        if (event['event'] == 'progress') {
          progress?.call(
            event['phase'] as String,
            event['completed'] as int,
            event['total'] as int,
          );
        } else if (event['event'] == 'result') {
          return event['value'];
        } else {
          throw FileSystemException(event['message'] as String);
        }
      } else {
        throw FileSystemException('后台文件处理异常：$event');
      }
    }
  } finally {
    port.close();
    isolate.kill(priority: Isolate.immediate);
  }
}

void _validateMedia(String name) {
  if (!name.startsWith('media/') ||
      name.substring(6).isEmpty ||
      name.contains('..') ||
      name.contains(':') ||
      name.contains('\\') ||
      p.isAbsolute(name.substring(6))) {
    throw const FormatException('备份含有不安全路径');
  }
}

Future<void> _worker((Map<String, dynamic>, SendPort) args) async {
  final (job, port) = args;
  void progress(String phase, int done, int total) => port.send({
    'event': 'progress',
    'phase': phase,
    'completed': done,
    'total': total,
  });
  try {
    dynamic result;
    if (job['action'] == 'export') {
      final encoder = ZipFileEncoder()..create(job['path'] as String);
      try {
        for (final item in (job['json'] as Map).entries) {
          final bytes = utf8.encode(item.value as String);
          encoder.addArchiveFile(
            ArchiveFile(item.key as String, bytes.length, bytes),
          );
        }
        final media = job['media'] as Map;
        var count = 0;
        progress('正在打包照片、视频和附件…', count, media.length);
        for (final item in media.entries) {
          await encoder.addFile(File(item.value as String), item.key as String);
          progress('正在打包照片、视频和附件…', ++count, media.length);
        }
      } finally {
        await encoder.close();
      }
    } else {
      final input = InputFileStream(job['path'] as String);
      try {
        progress('正在读取备份目录…', 0, 0);
        final archive = ZipDecoder().decodeStream(input);
        if (job['action'] == 'inspect') {
          final manifestEntry = archive.find('manifest.json');
          final dataEntry = archive.find('data.json');
          if (manifestEntry == null || dataEntry == null)
            throw const FormatException('这不是小罗日记的数据备份文件');
          // Metadata should be small; reject an unreasonable allocation early.
          if (manifestEntry.size > 1024 * 1024 ||
              dataEntry.size > 128 * 1024 * 1024) {
            throw const FormatException('备份元数据过大，请分日期导出后再导入');
          }
          final manifest =
              jsonDecode(utf8.decode(manifestEntry.readBytes()!)) as Map;
          final bytes = dataEntry.readBytes()!;
          if (manifest['format'] != 'xiaoluo_diary_backup' ||
              manifest['version'] != 1)
            throw const FormatException('备份格式或版本不受支持');
          if (sha256.convert(bytes).toString() != manifest['dataSha256'])
            throw const FormatException('备份校验失败，文件可能不完整');
          final names = <String>[];
          for (final entry in archive.files) {
            if (!entry.isFile || !entry.name.startsWith('media/')) continue;
            _validateMedia(entry.name);
            if (entry.isSymbolicLink) throw const FormatException('备份不支持符号链接');
            names.add(entry.name);
          }
          result = {'data': jsonDecode(utf8.decode(bytes)), 'names': names};
        } else if (job['action'] == 'restore') {
          final names = List<String>.from(job['names'] as List);
          var count = 0;
          progress('正在恢复照片、视频和附件…', 0, names.length);
          for (final name in names) {
            _validateMedia(name);
            final entry = archive.find(name);
            if (entry == null || !entry.isFile || entry.isSymbolicLink)
              throw FormatException('备份媒体不可用：$name');
            final target = File(
              p.join(job['root'] as String, name.substring(6)),
            );
            if (!target.existsSync()) {
              target.parent.createSync(recursive: true);
              final temp = File(
                '${target.path}.${DateTime.now().microsecondsSinceEpoch}.partial',
              );
              try {
                final output = OutputFileStream(temp.path);
                try {
                  // Stream decompression to disk; even a multi-GB single video
                  // is never held in a byte array or retained by ArchiveFile.
                  entry.writeContent(output);
                } finally {
                  output.closeSync();
                }
                if (temp.lengthSync() != entry.size)
                  throw FormatException('媒体文件不完整：$name');
                if (!target.existsSync()) temp.renameSync(target.path);
              } finally {
                if (temp.existsSync()) temp.deleteSync();
              }
            }
            progress('正在恢复照片、视频和附件…', ++count, names.length);
          }
        }
      } finally {
        input.closeSync();
      }
    }
    port.send({'event': 'result', 'value': result});
  } catch (error) {
    port.send({'event': 'error', 'message': error.toString()});
  }
}
