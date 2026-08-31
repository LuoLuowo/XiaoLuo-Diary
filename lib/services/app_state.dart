import 'dart:io';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/diary_entry.dart';
import '../models/profile.dart';
import '../models/reading_book.dart';
import '../repositories/diary_repository.dart';
import 'backup_service.dart';
import 'storage_service.dart';
import '../utils/diary_media.dart';

class AppState extends ChangeNotifier {
  AppState(this.repository, this.storage);
  final DiaryRepository repository;
  final StorageService storage;
  List<DiaryEntry> diaries = [];
  List<TrashedDiary> trash = [];
  List<String> tags = [];
  List<String> categories = [];
  List<ReadingBook> books = [];
  UserProfile profile = const UserProfile();
  bool showTimeline = true;
  bool showSummary = true;
  double diaryFontSize = 16;
  double readingFontSize = 14;
  bool keepOriginalMedia = false;
  bool calendarImageView = true;
  String photoRatioMode = 'dynamic';
  int storageBytes = 0;
  final Map<String, String> summaries = {};

  Future<void> initialize() async {
    await repository.seedIfNeeded();
    final expired = (await repository.trash())
        .where(
          (value) => value.deletedAt.isBefore(
            DateTime.now().subtract(const Duration(days: 30)),
          ),
        )
        .toList();
    await repository.purgeExpiredTrash();
    final prefs = await SharedPreferences.getInstance();
    profile = UserProfile(
      nickname: prefs.getString('nickname') ?? '小罗',
      signature: prefs.getString('signature') ?? '一点点记录自己的生活。',
      birthday: prefs.getString('birthday') ?? '',
      homeText: prefs.getString('homeText') ?? '记录属于自己的每一天。',
      avatarPath: prefs.getString('avatarPath') ?? '',
    );
    showTimeline = prefs.getBool('showTimeline') ?? true;
    showSummary = prefs.getBool('showSummary') ?? true;
    diaryFontSize = prefs.getDouble('diaryFontSize') ?? 16;
    readingFontSize = (prefs.getDouble('readingFontSize') ?? 14).clamp(12, 22);
    keepOriginalMedia = prefs.getBool('keepOriginalMedia') ?? false;
    calendarImageView = prefs.getBool('calendarImageView') ?? true;
    photoRatioMode = prefs.getString('photoRatioMode') ?? 'dynamic';
    await reload();
    if (expired.isNotEmpty) {
      await _releaseMedia(
        expired.expand((value) => diaryMediaPaths(value.diary)).toSet(),
      );
    }
  }

  Future<void> reload() async {
    diaries = await repository.all();
    trash = await repository.trash();
    tags = await repository.tags();
    categories = await repository.categories();
    books = await repository.books();
    storageBytes = await storage.totalBytes();
    notifyListeners();
  }

  Future<MediaRootMigration> changeMediaRoot() async {
    final result = await storage.chooseMediaRoot();
    if (!result.success || result.sourceRoots.isEmpty || result.newRoot == null)
      return result;
    for (final oldRoot in result.sourceRoots) {
      if (oldRoot != result.newRoot) {
        await repository.migrateMediaPaths(oldRoot, result.newRoot!);
      }
    }
    final prefs = await SharedPreferences.getInstance();
    for (final oldRoot in result.sourceRoots) {
      if (profile.avatarPath.startsWith(oldRoot)) {
        final suffix = profile.avatarPath.substring(oldRoot.length);
        profile = profile.copyWith(avatarPath: '${result.newRoot!}$suffix');
        await prefs.setString('avatarPath', profile.avatarPath);
        break;
      }
    }
    await reload();
    return result;
  }

  Future<void> saveDiary(DiaryEntry diary) async {
    final previous = diaries.where((value) => value.id == diary.id).firstOrNull;
    await repository.save(diary);
    await reload();
    if (previous != null) {
      await _releaseMedia(
        diaryMediaPaths(previous).difference(diaryMediaPaths(diary)),
      );
    }
  }

  Future<void> deleteDiary(DiaryEntry diary) async {
    if (diary.id != null) await repository.delete(diary.id!);
    await reload();
  }

  Future<void> restoreDiary(TrashedDiary value) async {
    if (value.diary.id != null) {
      await repository.restoreFromTrash(value.diary.id!);
      await reload();
    }
  }

  Future<void> deleteDiaryPermanently(TrashedDiary value) async {
    if (value.diary.id != null) {
      await repository.deletePermanently(value.diary.id!);
      await reload();
      await _releaseMedia(diaryMediaPaths(value.diary));
    }
  }

  Set<String> get _referencedMedia => {
    for (final diary in diaries) ...diaryMediaPaths(diary),
    for (final value in trash) ...diaryMediaPaths(value.diary),
    for (final book in books) book.coverPath,
    profile.avatarPath,
  }..remove('');

  Future<int> _releaseMedia(Set<String> candidates) async {
    if (candidates.isEmpty) return 0;
    final freed = await storage.deleteUnusedMedia(candidates, _referencedMedia);
    storageBytes = await storage.totalBytes();
    notifyListeners();
    return freed;
  }

  Future<int> cleanUnreferencedMedia() async => _releaseMedia({
    for (final file in await storage.managedMediaFiles()) file.path,
  });

  Future<void> setReadingFontSize(double value) async {
    readingFontSize = value.clamp(12, 22);
    await (await SharedPreferences.getInstance()).setDouble(
      'readingFontSize',
      readingFontSize,
    );
    notifyListeners();
  }

  Future<BackupExportResult> exportDataBackup({
    DateTime? from,
    DateTime? to,
    BackupProgressCallback? onProgress,
  }) async {
    final scoped = from == null || to == null
        ? diaries
        : diaries
              .where(
                (entry) =>
                    !entry.diaryDate.isBefore(from) &&
                    !entry.diaryDate.isAfter(to),
              )
              .toList();
    final scopedBooks = from == null || to == null
        ? books
        : books
              .where(
                (book) =>
                    !book.updatedAt.isBefore(from) &&
                    !book.updatedAt.isAfter(to),
              )
              .toList();
    final savedSummaries = await repository.summaries();
    String day(DateTime value) =>
        '${value.year.toString().padLeft(4, '0')}${value.month.toString().padLeft(2, '0')}${value.day.toString().padLeft(2, '0')}';
    final rangeLabel = from == null || to == null
        ? null
        : '${day(from)}-${day(to)}';
    return BackupService(storage).exportData(
      diaries: scoped,
      tags: {for (final entry in scoped) ...entry.tags}.toList(),
      categories: categories,
      books: scopedBooks,
      summaries: savedSummaries,
      profile: profile,
      settings: {
        'showTimeline': showTimeline,
        'showSummary': showSummary,
        'diaryFontSize': diaryFontSize,
        'readingFontSize': readingFontSize,
        'keepOriginalMedia': keepOriginalMedia,
        'calendarImageView': calendarImageView,
        'photoRatioMode': photoRatioMode,
      },
      rangeLabel: rangeLabel,
      onProgress: onProgress,
    );
  }

  Future<File> exportDiaryPdf() =>
      BackupService(storage).exportPdf(diaries: diaries, profile: profile);

  Future<BackupPayload> inspectDataBackup(
    File file, {
    BackupProgressCallback? onProgress,
  }) => BackupService(storage).readBackup(file, onProgress: onProgress);

  Future<BackupAppendResult> importDataBackup(
    File file, {
    BackupProgressCallback? onProgress,
  }) async {
    final backup = BackupService(storage);
    final checked = await backup.readBackup(file, onProgress: onProgress);
    String diaryKey(DiaryEntry entry) =>
        '${entry.createdAt.millisecondsSinceEpoch}';
    String bookKey(ReadingBook book) =>
        '${book.createdAt.millisecondsSinceEpoch}';
    final knownDiaries = diaries.map(diaryKey).toSet();
    final knownBooks = books.map(bookKey).toSet();
    final newDiaries = checked.diaries
        .where((entry) => knownDiaries.add(diaryKey(entry)))
        .toList();
    final newBooks = checked.books
        .where((book) => knownBooks.add(bookKey(book)))
        .toList();
    final requiredMedia = <String>{
      for (final entry in newDiaries) ...entry.images,
      for (final entry in newDiaries) ...entry.videos,
      for (final entry in newDiaries) ...entry.attachments,
      for (final book in newBooks) book.coverPath,
    };
    for (final entry in newDiaries) {
      try {
        for (final operation in jsonDecode(entry.richContent) as List) {
          if (operation is! Map || operation['insert'] is! Map) continue;
          final insert = operation['insert'] as Map;
          for (final type in const ['image', 'video']) {
            if (insert[type] is String)
              requiredMedia.add(insert[type] as String);
          }
        }
      } catch (_) {
        // Old plain-text diaries have no embedded media to collect.
      }
    }
    final selected = BackupPayload(
      diaries: newDiaries,
      tags: checked.tags,
      categories: checked.categories,
      books: newBooks,
      summaries: checked.summaries,
      profile: checked.profile,
      settings: checked.settings,
      mediaNames: [
        for (final name in checked.mediaNames)
          if (requiredMedia.contains(name)) name,
      ],
      sourceArchive: checked.sourceArchive,
    );
    // Write media first. Existing files are left intact; only new diary/book
    // records will be appended to SQLite below.
    final restored = await backup.materializeMedia(
      selected,
      onProgress: onProgress,
    );
    onProgress?.call('正在写入日记数据…', 0, 1);
    final result = await repository.appendUnique(
      diaries: restored.diaries,
      tags: restored.tags,
      categories: restored.categories,
      books: restored.books,
      summaries: restored.summaries,
    );
    await reload();
    onProgress?.call('导入完成', 1, 1);
    return result;
  }

  List<DiaryEntry> search(String query, {String? tag}) {
    final q = query.trim().toLowerCase();
    final source = tag == null
        ? diaries
        : diaries.where((d) => d.tags.contains(tag)).toList();
    if (q.isEmpty) return source;
    return source
        .where(
          (d) => '${d.title} ${d.displayContent} ${d.tags.join(' ')}'
              .toLowerCase()
              .contains(q),
        )
        .toList();
  }

  Future<void> setDiaryFontSize(double value) async {
    diaryFontSize = value;
    await (await SharedPreferences.getInstance()).setDouble(
      'diaryFontSize',
      value,
    );
    notifyListeners();
  }

  Future<void> setKeepOriginalMedia(bool value) async {
    keepOriginalMedia = value;
    await (await SharedPreferences.getInstance()).setBool(
      'keepOriginalMedia',
      value,
    );
    notifyListeners();
  }

  Future<void> setCalendarImageView(bool value) async {
    calendarImageView = value;
    await (await SharedPreferences.getInstance()).setBool(
      'calendarImageView',
      value,
    );
    notifyListeners();
  }

  Future<void> setPhotoRatioMode(String value) async {
    if (!const ['dynamic', 'landscape', 'original'].contains(value)) return;
    photoRatioMode = value;
    await (await SharedPreferences.getInstance()).setString(
      'photoRatioMode',
      value,
    );
    notifyListeners();
  }

  Future<void> saveBook(ReadingBook book) async {
    await repository.saveBook(book);
    await reload();
  }

  Future<void> deleteBook(ReadingBook book) async {
    if (book.id != null) await repository.deleteBook(book.id!);
    await reload();
  }

  String summaryFor(String key) => summaries[key] ?? '';

  Future<String> loadSummary(String key) async {
    if (summaries.containsKey(key)) return summaries[key]!;
    final value = await repository.summary(key);
    summaries[key] = value;
    notifyListeners();
    return value;
  }

  Future<void> saveSummary(String key, String value) async {
    await repository.saveSummary(key, value.trim());
    summaries[key] = value.trim();
    notifyListeners();
  }

  Future<void> saveProfile(UserProfile value) async {
    profile = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('nickname', value.nickname);
    await prefs.setString('signature', value.signature);
    await prefs.setString('birthday', value.birthday);
    await prefs.setString('homeText', value.homeText);
    await prefs.setString('avatarPath', value.avatarPath);
    notifyListeners();
  }

  Future<void> setDisplay({bool? timeline, bool? summary}) async {
    final prefs = await SharedPreferences.getInstance();
    if (timeline != null) {
      showTimeline = timeline;
      await prefs.setBool('showTimeline', timeline);
    }
    if (summary != null) {
      showSummary = summary;
      await prefs.setBool('showSummary', summary);
    }
    notifyListeners();
  }

  Future<void> addTag(String value) async {
    if (value.trim().isEmpty) return;
    await repository.addTag(value);
    await reload();
  }

  Future<void> renameTag(String oldName, String newName) async {
    if (newName.trim().isEmpty) return;
    await repository.renameTag(oldName, newName.trim());
    await reload();
  }

  Future<void> deleteTag(String value) async {
    await repository.deleteTag(value);
    await reload();
  }

  Future<void> addCategory(String value) async {
    if (value.trim().isEmpty) return;
    await repository.addCategory(value);
    await reload();
  }

  Future<void> renameCategory(String oldName, String newName) async {
    if (newName.trim().isEmpty) return;
    await repository.renameCategory(oldName, newName.trim());
    await reload();
  }

  Future<void> deleteCategory(String value) async {
    await repository.deleteCategory(value);
    await reload();
  }
}
