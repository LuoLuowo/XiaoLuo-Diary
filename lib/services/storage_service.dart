import 'dart:io';
import 'dart:isolate';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_compress/flutter_compress.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import '../utils/live_photo.dart';
import 'motion_photo_extractor.dart';

class PickedImageInfo {
  const PickedImageInfo({
    required this.path,
    required this.sourceName,
    this.capturedAt,
    this.liveVideoPath,
  });

  final String path;
  final String sourceName;
  final DateTime? capturedAt;

  /// Extracted motion clip from a vivo/Android Motion Photo, if present.
  final String? liveVideoPath;
}

class MediaRootMigration {
  const MediaRootMigration({
    required this.success,
    required this.message,
    this.sourceRoots = const [],
    this.newRoot,
  });
  final bool success;
  final String message;
  final List<String> sourceRoots;
  final String? newRoot;
}

class StorageService {
  Future<Directory> _folder(String name) async {
    var root = await mediaRoot();
    try {
      if (!await root.exists()) await root.create(recursive: true);
      final folder = Directory(p.join(root.path, name));
      if (!await folder.exists()) await folder.create(recursive: true);
      return folder;
    } on FileSystemException {
      await (await SharedPreferences.getInstance()).remove('mediaRoot');
      root = await _defaultRoot();
      final folder = Directory(p.join(root.path, name));
      await folder.create(recursive: true);
      return folder;
    }
  }

  Future<Directory> _defaultRoot() async {
    final documents = await getApplicationDocumentsDirectory();
    return Directory(p.join(documents.path, '小罗日记'));
  }

  Future<Directory> mediaRoot() async {
    final prefs = await SharedPreferences.getInstance();
    final custom = prefs.getString('mediaRoot');
    if (custom != null && custom.isNotEmpty) return Directory(custom);
    return _defaultRoot();
  }

  Future<MediaRootMigration> chooseMediaRoot() async {
    final path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: '选择小罗日记媒体保存位置',
    );
    if (path == null)
      return const MediaRootMigration(success: false, message: '已取消修改');
    final directory = Directory(path);
    if (!await directory.exists()) {
      return const MediaRootMigration(
        success: false,
        message: '所选目录不存在或系统未授予访问权限',
      );
    }
    final oldRoot = await mediaRoot();
    final defaultRoot = await _defaultRoot();
    final target = Directory(p.join(path, '小罗日记媒体'));
    try {
      await target.create(recursive: true);
      final probe = File(p.join(target.path, '.write_test'));
      await probe.writeAsString('ok', flush: true);
      await probe.delete();
      final sources = <String>{oldRoot.path, defaultRoot.path};
      for (final sourcePath in sources) {
        final source = Directory(sourcePath);
        if (await source.exists() &&
            p.normalize(source.path) != p.normalize(target.path)) {
          await _copyDirectory(source, target);
        }
      }
      await (await SharedPreferences.getInstance()).setString(
        'mediaRoot',
        target.path,
      );
      return MediaRootMigration(
        success: true,
        message: '媒体和路径已迁移到新位置',
        sourceRoots: sources.toList(),
        newRoot: target.path,
      );
    } on FileSystemException catch (error) {
      return MediaRootMigration(
        success: false,
        message: Platform.isAndroid
            ? '该目录没有长期写入权限，请选择手机内部存储中允许应用访问的文件夹'
            : '该目录无法写入：${error.message}',
      );
    }
  }

  Future<void> _copyDirectory(Directory source, Directory target) async {
    await for (final entity in source.list(
      recursive: true,
      followLinks: false,
    )) {
      final relative = p.relative(entity.path, from: source.path);
      if (entity is Directory) {
        await Directory(p.join(target.path, relative)).create(recursive: true);
      } else if (entity is File) {
        final destination = File(p.join(target.path, relative));
        await destination.parent.create(recursive: true);
        if (!await destination.exists()) await entity.copy(destination.path);
      }
    }
  }

  Future<Map<String, int>> mediaCounts() async {
    final roots = <String>{
      (await _defaultRoot()).path,
      (await mediaRoot()).path,
    };
    final counts = {'images': 0, 'videos': 0, 'attachments': 0};
    for (final root in roots) {
      for (final name in counts.keys) {
        final folder = Directory(p.join(root, name));
        if (!await folder.exists()) continue;
        await for (final entity in folder.list()) {
          if (entity is File) counts[name] = counts[name]! + 1;
        }
      }
    }
    return counts;
  }

  Future<List<String>> pickImages({bool keepOriginal = false}) async {
    final picked = await pickImagesWithMetadata(keepOriginal: keepOriginal);
    return picked.map((value) => value.path).toList();
  }

  /// Appearance files are separate from diary media and its trash cleanup.
  /// Copy the selected image so removing the gallery original cannot break it.
  Future<String?> pickBackgroundImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      compressionQuality: 0,
    );
    final source = result?.files.firstOrNull?.path;
    if (source == null) return null;
    final support = await getApplicationSupportDirectory();
    final folder = Directory(p.join(support.path, 'appearance'));
    await folder.create(recursive: true);
    return _saveImage(source, folder, false);
  }

  Future<List<PickedImageInfo>> pickImagesWithMetadata({
    bool keepOriginal = false,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      // Keep the picker copy byte-for-byte. Compression happens only after
      // obtaining the original, otherwise an embedded motion clip is lost.
      compressionQuality: 0,
    );
    if (result == null) return [];
    final folder = await _folder('images');
    final output = <PickedImageInfo>[];
    for (final picked in result.files) {
      if (picked.path == null) continue;
      final capturedAt = await imageCaptureDate(picked.path!);
      final savedImage = await _saveImage(picked.path!, folder, keepOriginal);
      output.add(
        PickedImageInfo(
          path: savedImage,
          sourceName: picked.name,
          capturedAt: capturedAt,
          liveVideoPath: await _saveLivePhotoVideo(
            picked.path!,
            savedImage,
            keepOriginal,
          ),
        ),
      );
    }
    return output;
  }

  Future<DateTime?> imageCaptureDate(String source) =>
      Isolate.run(() => _imageCaptureDate(source));

  static Future<DateTime?> _imageCaptureDate(String source) async {
    try {
      final decoded = img.decodeImage(await File(source).readAsBytes());
      if (decoded == null) return null;
      final candidates = [
        decoded.exif.exifIfd[0x9003],
        decoded.exif.exifIfd[0x9004],
        decoded.exif.imageIfd[0x0132],
      ];
      for (final tagValue in candidates) {
        final raw = tagValue?.toString().trim();
        if (raw == null || raw.isEmpty) continue;
        final match = RegExp(
          r'(\d{4}):(\d{2}):(\d{2})\s+(\d{2}):(\d{2}):(\d{2})',
        ).firstMatch(raw);
        if (match == null) continue;
        final value = DateTime(
          int.parse(match.group(1)!),
          int.parse(match.group(2)!),
          int.parse(match.group(3)!),
          int.parse(match.group(4)!),
          int.parse(match.group(5)!),
          int.parse(match.group(6)!),
        );
        if (value.year >= 1970 && value.year <= 2100) return value;
      }
    } catch (_) {
      // Missing or malformed EXIF data simply means no date suggestion.
    }
    return null;
  }

  Future<String?> saveExportCopy(File source) async {
    if (Platform.isAndroid) {
      return const MethodChannel(
        'xiaoluo_diary/files',
      ).invokeMethod<String>('saveFile', {
        'sourcePath': source.path,
        'fileName': p.basename(source.path),
        'mimeType': p.extension(source.path).toLowerCase() == '.pdf'
            ? 'application/pdf'
            : 'application/zip',
      });
    }
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final destination = await FilePicker.platform.saveFile(
        dialogTitle: '保存小罗日记导出文件',
        fileName: p.basename(source.path),
        type: FileType.custom,
        allowedExtensions: [p.extension(source.path).replaceFirst('.', '')],
      );
      if (destination == null) return null;
      await source.copy(destination);
      return destination;
    }
    final bytes = await source.readAsBytes();
    return FilePicker.platform.saveFile(
      dialogTitle: '保存小罗日记导出文件',
      fileName: p.basename(source.path),
      bytes: bytes,
    );
  }

  Future<bool> saveMediaToGallery(
    String source, {
    required bool isVideo,
  }) async {
    if (!await File(source).exists()) return false;
    if (Platform.isAndroid) {
      return await const MethodChannel(
            'xiaoluo_diary/files',
          ).invokeMethod<bool>('saveMediaToGallery', {
            'sourcePath': source,
            'isVideo': isVideo,
          }) ??
          false;
    }
    return await saveExportCopy(File(source)) != null;
  }

  Future<List<String>> pickVideos({bool keepOriginal = false}) async {
    if (Platform.isAndroid || Platform.isIOS) {
      final picked = await ImagePicker().pickVideo(source: ImageSource.gallery);
      if (picked == null) return [];
      final folder = await _folder('videos');
      return [await _saveVideo(picked.path, folder, keepOriginal)];
    }
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: true,
    );
    if (result == null) return [];
    final folder = await _folder('videos');
    final output = <String>[];
    for (final picked in result.files) {
      if (picked.path == null) continue;
      output.add(await _saveVideo(picked.path!, folder, keepOriginal));
    }
    return output;
  }

  Future<String> _saveImage(
    String source,
    Directory folder,
    bool keepOriginal,
  ) async {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    if (keepOriginal)
      return (await File(
        source,
      ).copy(p.join(folder.path, '${stamp}_${p.basename(source)}'))).path;
    if (Platform.isAndroid || Platform.isIOS) {
      try {
        final result = await FlutterCompress.instance.compressImage(
          source,
          const ImageCompressConfig(
            quality: 82,
            maxWidth: 2048,
            maxHeight: 2048,
            keepExif: true,
          ),
          outputDirectory: folder.path,
          outputName: 'photo_$stamp',
        );
        if (!result.skipped) return result.outputPath;
      } on CompressException {
        // Fall through to the cross-platform encoder.
      }
    }
    final folderPath = folder.path;
    return Isolate.run(() => _saveImageFallback(source, folderPath, stamp));
  }

  static Future<String> _saveImageFallback(
    String source,
    String folderPath,
    int stamp,
  ) async {
    final bytes = await File(source).readAsBytes();
    var decoded = img.decodeImage(bytes);
    if (decoded == null)
      return (await File(
        source,
      ).copy(p.join(folderPath, '${stamp}_${p.basename(source)}'))).path;
    decoded = img.bakeOrientation(decoded);
    if (decoded.width > 2048 || decoded.height > 2048) {
      decoded = img.copyResize(
        decoded,
        width: decoded.width >= decoded.height ? 2048 : null,
        height: decoded.height > decoded.width ? 2048 : null,
      );
    }
    final target = p.join(folderPath, 'photo_$stamp.jpg');
    await File(
      target,
    ).writeAsBytes(img.encodeJpg(decoded, quality: 82), flush: true);
    return target;
  }

  Future<String> _saveVideo(
    String source,
    Directory folder,
    bool keepOriginal,
  ) async {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    if (keepOriginal)
      return (await File(
        source,
      ).copy(p.join(folder.path, '${stamp}_${p.basename(source)}'))).path;
    if (Platform.isAndroid || Platform.isIOS) {
      try {
        final result = await FlutterCompress.instance.compress(
          source,
          const VideoCompressConfig(
            qualityPercent: 65,
            maxWidth: 1920,
            maxHeight: 1080,
            container: VideoContainer.mp4,
            keepAliveInBackground: false,
          ),
          outputDirectory: folder.path,
          outputName: 'video_$stamp',
        );
        if (!result.skipped) return result.outputPath;
      } on CompressException {
        // Keep the original when the device has no compatible encoder.
      }
    }
    return (await File(
      source,
    ).copy(p.join(folder.path, '${stamp}_${p.basename(source)}'))).path;
  }

  /// Vivo and other Android galleries commonly keep a Motion Photo as a JPEG
  /// whose final bytes are an MP4.  The regular image compressor drops that
  /// tail, so extract it first and save it as an app-managed video sidecar.
  Future<String?> _saveLivePhotoVideo(
    String source,
    String savedImage,
    bool keepOriginal,
  ) async {
    final folder = await _folder('videos');
    final temporary = p.join(
      folder.path,
      '.motion_${DateTime.now().microsecondsSinceEpoch}.mp4',
    );
    final extracted = await Isolate.run(
      () => extractMotionPhoto(source, temporary),
    );
    if (extracted == null) return null;
    final target = p.join(folder.path, livePhotoVideoName(savedImage));
    try {
      if (keepOriginal || !(Platform.isAndroid || Platform.isIOS)) {
        await File(extracted).copy(target);
      } else {
        try {
          final result = await FlutterCompress.instance.compress(
            extracted,
            const VideoCompressConfig(
              qualityPercent: 65,
              maxWidth: 1920,
              maxHeight: 1080,
              container: VideoContainer.mp4,
              keepAliveInBackground: false,
            ),
            outputDirectory: folder.path,
            outputName: 'motion_${DateTime.now().microsecondsSinceEpoch}',
          );
          await File(
            result.skipped ? extracted : result.outputPath,
          ).copy(target);
          if (!result.skipped && result.outputPath != extracted) {
            await _removeTemporaryMedia(result.outputPath);
          }
        } catch (_) {
          // Some HDR/HEVC clips cannot be transcoded by a device. Keep their
          // motion data instead of rejecting the whole photo import.
          await File(extracted).copy(target);
        }
      }
      return target;
    } finally {
      await _removeTemporaryMedia(extracted);
    }
  }

  static Future<void> _removeTemporaryMedia(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // A device encoder can briefly retain a file handle. The app-managed
      // unused-media cleanup can remove it later; saved media stays intact.
    }
  }

  Future<List<String>> pickAttachments() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    return _copy(result, 'attachments');
  }

  Future<List<String>> _copy(FilePickerResult? result, String directory) async {
    if (result == null) return [];
    final folder = await _folder(directory);
    final output = <String>[];
    for (final picked in result.files) {
      if (picked.path == null) continue;
      final name =
          '${DateTime.now().microsecondsSinceEpoch}_${p.basename(picked.path!)}';
      output.add(
        (await File(picked.path!).copy(p.join(folder.path, name))).path,
      );
    }
    return output;
  }

  Future<int> totalBytes() async {
    var size = 0;
    for (final file in await managedMediaFiles()) {
      size += await file.length();
    }
    return size;
  }

  Future<List<File>> managedMediaFiles() async {
    final roots = {(await _defaultRoot()).path, (await mediaRoot()).path};
    final files = <String, File>{};
    for (final root in roots) {
      for (final name in const [
        'images',
        'videos',
        'attachments',
        'covers',
        'avatar',
      ]) {
        final directory = Directory(p.join(root, name));
        if (!await directory.exists()) continue;
        await for (final entry in directory.list(
          recursive: true,
          followLinks: false,
        )) {
          if (entry is File) files[p.normalize(entry.absolute.path)] = entry;
        }
      }
    }
    return files.values.toList();
  }

  /// Only app-managed files may be removed; shared diary/cover/avatar references
  /// and exported backup archives are never garbage-collected here.
  Future<int> deleteUnusedMedia(
    Set<String> candidates,
    Set<String> referenced,
  ) async {
    final protected = referenced
        .map((value) => p.normalize(File(value).absolute.path))
        .toSet();
    final targets = candidates
        .map((value) => p.normalize(File(value).absolute.path))
        .toSet();
    final roots = {(await _defaultRoot()).path, (await mediaRoot()).path};
    final realRoots = <String>[];
    for (final root in roots) {
      if (await Directory(root).exists())
        realRoots.add(await Directory(root).resolveSymbolicLinks());
    }
    var freed = 0;
    for (final file in await managedMediaFiles()) {
      final path = p.normalize(file.absolute.path);
      if (!targets.contains(path) || protected.contains(path)) continue;
      final resolved = await file.resolveSymbolicLinks();
      if (!realRoots.any((root) => p.isWithin(root, resolved))) continue;
      try {
        final bytes = await file.length();
        await file.delete();
        freed += bytes;
      } on FileSystemException {
        // A Windows image/video viewer can still hold a file open. Leave it for
        // the explicit unused-media cleanup; never fail an already saved diary.
      }
    }
    return freed;
  }
}
