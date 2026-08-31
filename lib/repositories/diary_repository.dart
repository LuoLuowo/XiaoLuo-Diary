import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';
import '../models/diary_entry.dart';
import '../models/reading_book.dart';

class BackupAppendResult {
  const BackupAppendResult({
    required this.addedDiaries,
    required this.skippedDiaries,
    required this.addedBooks,
    required this.skippedBooks,
  });
  final int addedDiaries;
  final int skippedDiaries;
  final int addedBooks;
  final int skippedBooks;
}

class DiaryRepository {
  DiaryRepository(this._database);
  final AppDatabase _database;
  Database get db => _database.db;

  Future<List<DiaryEntry>> all() async => (await db.query(
    'diaries',
    orderBy: 'diary_date DESC',
  )).map(DiaryEntry.fromMap).toList();
  Future<int> save(DiaryEntry entry) async {
    final map = entry.toMap()..remove('id');
    if (entry.id == null) return db.insert('diaries', map);
    await db.update('diaries', map, where: 'id = ?', whereArgs: [entry.id]);
    return entry.id!;
  }

  Future<void> delete(int id) async {
    await db.transaction((txn) async {
      final rows = await txn.query(
        'diaries',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) return;
      await txn.insert('diary_trash', {
        ...rows.first,
        'deleted_at': DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.delete('diaries', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<List<TrashedDiary>> trash() async =>
      (await db.query('diary_trash', orderBy: 'deleted_at DESC')).map((row) {
        final diaryMap = Map<String, Object?>.from(row)..remove('deleted_at');
        return TrashedDiary(
          diary: DiaryEntry.fromMap(diaryMap),
          deletedAt: DateTime.fromMillisecondsSinceEpoch(
            row['deleted_at'] as int,
          ),
        );
      }).toList();

  Future<void> restoreFromTrash(int id) async {
    await db.transaction((txn) async {
      final rows = await txn.query(
        'diary_trash',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) return;
      final map = Map<String, Object?>.from(rows.first)..remove('deleted_at');
      await txn.insert(
        'diaries',
        map,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.delete('diary_trash', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> deletePermanently(int id) =>
      db.delete('diary_trash', where: 'id = ?', whereArgs: [id]);

  Future<void> purgeExpiredTrash() => db.delete(
    'diary_trash',
    where: 'deleted_at < ?',
    whereArgs: [
      DateTime.now().subtract(const Duration(days: 30)).millisecondsSinceEpoch,
    ],
  );

  Future<void> migrateMediaPaths(String oldRoot, String newRoot) async {
    String replaceRoot(String value) {
      if (value == oldRoot) return newRoot;
      final oldPrefix = oldRoot.endsWith('/') || oldRoot.endsWith('\\')
          ? oldRoot
          : '$oldRoot${Platform.pathSeparator}';
      if (!value.startsWith(oldPrefix)) return value;
      return '$newRoot${Platform.pathSeparator}${value.substring(oldPrefix.length)}';
    }

    String replaceRichRoots(String source) {
      if (source.isEmpty) return source;
      try {
        final delta = jsonDecode(source) as List;
        for (final operation in delta) {
          if (operation is! Map || operation['insert'] is! Map) continue;
          final insert = operation['insert'] as Map;
          for (final type in const ['image', 'video']) {
            if (insert[type] is String) {
              insert[type] = replaceRoot(insert[type] as String);
            }
          }
        }
        return jsonEncode(delta);
      } catch (_) {
        return source;
      }
    }

    await db.transaction((txn) async {
      final diaryRows = await txn.query('diaries');
      for (final row in diaryRows) {
        final diary = DiaryEntry.fromMap(row);
        final updated = diary.copyWith(
          images: diary.images.map(replaceRoot).toList(),
          videos: diary.videos.map(replaceRoot).toList(),
          attachments: diary.attachments.map(replaceRoot).toList(),
          richContent: replaceRichRoots(diary.richContent),
        );
        await txn.update(
          'diaries',
          updated.toMap()..remove('id'),
          where: 'id = ?',
          whereArgs: [diary.id],
        );
      }
      final bookRows = await txn.query('books');
      for (final row in bookRows) {
        final book = ReadingBook.fromMap(row);
        if (book.coverPath.isEmpty) continue;
        await txn.update(
          'books',
          book.copyWith(coverPath: replaceRoot(book.coverPath)).toMap()
            ..remove('id'),
          where: 'id = ?',
          whereArgs: [book.id],
        );
      }
    });
  }

  Future<List<ReadingBook>> books() async => (await db.query(
    'books',
    orderBy: 'updated_at DESC',
  )).map(ReadingBook.fromMap).toList();

  Future<int> saveBook(ReadingBook book) async {
    final map = book.toMap()..remove('id');
    if (book.id == null) return db.insert('books', map);
    await db.update('books', map, where: 'id = ?', whereArgs: [book.id]);
    return book.id!;
  }

  Future<void> deleteBook(int id) =>
      db.delete('books', where: 'id = ?', whereArgs: [id]);

  Future<String> summary(String key) async {
    final rows = await db.query(
      'metadata',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['summary_$key'],
      limit: 1,
    );
    return rows.isEmpty ? '' : rows.first['value'] as String;
  }

  Future<void> saveSummary(String key, String value) => db.insert('metadata', {
    'key': 'summary_$key',
    'value': value,
  }, conflictAlgorithm: ConflictAlgorithm.replace);

  Future<Map<String, String>> summaries() async {
    final rows = await db.query(
      'metadata',
      where: 'key LIKE ?',
      whereArgs: ['summary_%'],
    );
    return {
      for (final row in rows)
        (row['key'] as String).substring('summary_'.length):
            row['value'] as String,
    };
  }

  Future<void> replaceAll({
    required List<DiaryEntry> diaries,
    required List<String> tags,
    required List<String> categories,
    required List<ReadingBook> books,
    required Map<String, String> summaries,
  }) async {
    await db.transaction((txn) async {
      await txn.delete('diaries');
      await txn.delete('diary_trash');
      await txn.delete('tags');
      await txn.delete('categories');
      await txn.delete('books');
      await txn.delete('metadata');
      for (final diary in diaries) {
        await txn.insert('diaries', diary.toMap()..remove('id'));
      }
      for (final tag in tags.toSet()) {
        await txn.insert('tags', {'name': tag});
      }
      for (final category in categories.toSet()) {
        await txn.insert('categories', {'name': category});
      }
      for (final book in books) {
        await txn.insert('books', book.toMap()..remove('id'));
      }
      await txn.insert('metadata', {'key': 'demo_seeded', 'value': '1'});
      for (final entry in summaries.entries) {
        await txn.insert('metadata', {
          'key': 'summary_${entry.key}',
          'value': entry.value,
        });
      }
    });
  }

  /// Adds only records that are not already present. Existing local records
  /// are never edited by a backup import.
  Future<BackupAppendResult> appendUnique({
    required List<DiaryEntry> diaries,
    required List<String> tags,
    required List<String> categories,
    required List<ReadingBook> books,
    required Map<String, String> summaries,
  }) async {
    var addedDiaries = 0;
    var skippedDiaries = 0;
    var addedBooks = 0;
    var skippedBooks = 0;
    await db.transaction((txn) async {
      // createdAt is immutable for a record, whereas a user may later change
      // its date/title/body. Using it avoids importing an older backup copy as
      // a second diary after a local edit.
      String diaryKey(DiaryEntry entry) =>
          '${entry.createdAt.millisecondsSinceEpoch}';
      String bookKey(ReadingBook book) =>
          '${book.createdAt.millisecondsSinceEpoch}';

      final diaryKeys = <String>{
        for (final row in await txn.query('diaries'))
          diaryKey(DiaryEntry.fromMap(row)),
      };
      for (final entry in diaries) {
        if (!diaryKeys.add(diaryKey(entry))) {
          skippedDiaries++;
          continue;
        }
        await txn.insert('diaries', entry.toMap()..remove('id'));
        addedDiaries++;
      }

      final bookKeys = <String>{
        for (final row in await txn.query('books'))
          bookKey(ReadingBook.fromMap(row)),
      };
      for (final book in books) {
        if (!bookKeys.add(bookKey(book))) {
          skippedBooks++;
          continue;
        }
        await txn.insert('books', book.toMap()..remove('id'));
        addedBooks++;
      }

      final tagNames = <String>{
        ...tags.map((value) => value.trim()).where((value) => value.isNotEmpty),
        for (final diary in diaries) ...diary.tags.map((value) => value.trim()),
      };
      for (final value in tagNames) {
        await txn.insert('tags', {
          'name': value,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      for (final value
          in categories
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)) {
        await txn.insert('categories', {
          'name': value,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }

      final existingSummaryKeys = <String>{
        for (final row in await txn.query(
          'metadata',
          where: 'key LIKE ?',
          whereArgs: ['summary_%'],
        ))
          row['key'] as String,
      };
      for (final entry in summaries.entries) {
        final key = 'summary_${entry.key}';
        if (existingSummaryKeys.add(key)) {
          await txn.insert('metadata', {'key': key, 'value': entry.value});
        }
      }
    });
    return BackupAppendResult(
      addedDiaries: addedDiaries,
      skippedDiaries: skippedDiaries,
      addedBooks: addedBooks,
      skippedBooks: skippedBooks,
    );
  }

  Future<List<String>> tags() async => (await db.query(
    'tags',
    orderBy: 'name',
  )).map((e) => e['name'] as String).toList();
  Future<List<String>> categories() async => (await db.query(
    'categories',
    orderBy: 'id',
  )).map((e) => e['name'] as String).toList();
  Future<void> addTag(String value) async => db.insert('tags', {
    'name': value.trim(),
  }, conflictAlgorithm: ConflictAlgorithm.ignore);
  Future<void> renameTag(String oldName, String newName) async {
    await db.transaction((txn) async {
      await txn.update(
        'tags',
        {'name': newName},
        where: 'name = ?',
        whereArgs: [oldName],
      );
      final rows = await txn.query('diaries');
      for (final row in rows) {
        final diary = DiaryEntry.fromMap(row);
        if (diary.tags.contains(oldName)) {
          final tags = diary.tags
              .map((e) => e == oldName ? newName : e)
              .toSet()
              .toList();
          await txn.update(
            'diaries',
            diary.copyWith(tags: tags).toMap()..remove('id'),
            where: 'id = ?',
            whereArgs: [diary.id],
          );
        }
      }
    });
  }

  Future<void> deleteTag(String name) async {
    await db.transaction((txn) async {
      await txn.delete('tags', where: 'name = ?', whereArgs: [name]);
      final rows = await txn.query('diaries');
      for (final row in rows) {
        final diary = DiaryEntry.fromMap(row);
        if (diary.tags.contains(name)) {
          await txn.update(
            'diaries',
            diary
                .copyWith(tags: diary.tags.where((e) => e != name).toList())
                .toMap()
              ..remove('id'),
            where: 'id = ?',
            whereArgs: [diary.id],
          );
        }
      }
    });
  }

  Future<void> addCategory(String value) async => db.insert('categories', {
    'name': value.trim(),
  }, conflictAlgorithm: ConflictAlgorithm.ignore);
  Future<void> renameCategory(String oldName, String newName) async {
    await db.transaction((txn) async {
      await txn.update(
        'categories',
        {'name': newName},
        where: 'name = ?',
        whereArgs: [oldName],
      );
      await txn.update(
        'diaries',
        {'category': newName},
        where: 'category = ?',
        whereArgs: [oldName],
      );
    });
  }

  Future<void> deleteCategory(String name) async {
    await db.transaction((txn) async {
      await txn.delete('categories', where: 'name = ?', whereArgs: [name]);
      await txn.update(
        'diaries',
        {'category': '其他'},
        where: 'category = ?',
        whereArgs: [name],
      );
    });
  }

  Future<void> seedIfNeeded() async {
    final seeded = await db.query(
      'metadata',
      where: 'key = ?',
      whereArgs: ['demo_seeded'],
      limit: 1,
    );
    if (seeded.isNotEmpty) return;
    final count =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM diaries'),
        ) ??
        0;
    if (count > 0) {
      await db.insert('metadata', {'key': 'demo_seeded', 'value': '1'});
      return;
    }
    final now = DateTime.now();
    final samples = [
      ('炸酥肉', '今天自己尝试炸了一次酥肉，味道居然还不错。外酥里嫩，厨房里都是香味。', '生活', ['美食', '生活'], 0),
      ('安静的周末', '午后给自己泡了一杯茶，把这周发生的小事慢慢写下来。', '生活', ['生活'], 3),
    ];
    for (final sample in samples) {
      final date = now.subtract(Duration(days: sample.$5));
      await save(
        DiaryEntry(
          title: sample.$1,
          content: sample.$2,
          diaryDate: date,
          createdAt: date,
          updatedAt: date,
          category: sample.$3,
          tags: sample.$4,
          images: const [],
          attachments: const [],
        ),
      );
    }
    await db.insert('metadata', {'key': 'demo_seeded', 'value': '1'});
  }

  DiaryEntry? random(List<DiaryEntry> values) =>
      values.isEmpty ? null : values[Random().nextInt(values.length)];
}
