import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:xiaoluo_diary/database/app_database.dart';
import 'package:xiaoluo_diary/repositories/diary_repository.dart';
import 'package:xiaoluo_diary/models/reading_book.dart';
import 'package:xiaoluo_diary/models/diary_entry.dart';

void main() {
  test('SQLite 数据可持久化，演示数据只生成一次', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final temp = await Directory.systemTemp.createTemp('xiaoluo_diary_test_');
    final path = p.join(temp.path, 'diary.db');

    final firstDatabase = AppDatabase();
    await firstDatabase.initialize(pathOverride: path);
    final firstRepository = DiaryRepository(firstDatabase);
    await firstRepository.seedIfNeeded();
    expect((await firstRepository.all()).length, 2);
    expect(await firstRepository.tags(), ['生活', '美食']);
    final now = DateTime.now();
    await firstRepository.saveBook(
      ReadingBook(
        title: '测试书籍',
        author: '作者',
        review: '整本书的观后感',
        coverPath: '',
        notes: [
          OutlineNote(id: '1', title: '第一章', content: '**重点**', level: 0),
        ],
        createdAt: now,
        updatedAt: now,
      ),
    );
    await firstDatabase.db.close();

    final reopenedDatabase = AppDatabase();
    await reopenedDatabase.initialize(pathOverride: path);
    final reopenedRepository = DiaryRepository(reopenedDatabase);
    expect((await reopenedRepository.all()).length, 2);
    expect((await reopenedRepository.books()).single.notes.single.title, '第一章');
    expect((await reopenedRepository.books()).single.review, '整本书的观后感');
    for (final diary in await reopenedRepository.all()) {
      await reopenedRepository.delete(diary.id!);
    }
    expect(await reopenedRepository.trash(), hasLength(2));
    final recoverable = (await reopenedRepository.trash()).first;
    await reopenedRepository.restoreFromTrash(recoverable.diary.id!);
    expect(await reopenedRepository.all(), hasLength(1));
    await reopenedRepository.delete(recoverable.diary.id!);
    await reopenedRepository.seedIfNeeded();
    expect(await reopenedRepository.all(), isEmpty);
    await reopenedDatabase.db.close();
    await temp.delete(recursive: true);
  });

  test('备份追加只插入新记录，不覆盖本地已有日记或书籍', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final temp = await Directory.systemTemp.createTemp('xiaoluo_append_test_');
    final database = AppDatabase();
    await database.initialize(pathOverride: p.join(temp.path, 'diary.db'));
    final repository = DiaryRepository(database);
    final now = DateTime(2026, 8, 30, 10);
    final local = DiaryEntry(
      title: '本地日记',
      content: '本地最新版',
      diaryDate: now,
      createdAt: now,
      updatedAt: now,
      category: '',
      tags: const ['本地'],
      images: const [],
      attachments: const [],
    );
    await repository.save(local);
    final localBook = ReadingBook(
      title: '本地书',
      author: '作者',
      coverPath: '',
      notes: const [],
      createdAt: now,
      updatedAt: now,
    );
    await repository.saveBook(localBook);
    final newDiary = DiaryEntry(
      title: '备份新增日记',
      content: '只应新增这一篇',
      diaryDate: now.add(const Duration(days: 1)),
      createdAt: now.add(const Duration(days: 1)),
      updatedAt: now,
      category: '',
      tags: const ['备份'],
      images: const [],
      attachments: const [],
    );
    final newBook = ReadingBook(
      title: '备份新增书',
      author: '作者',
      coverPath: '',
      notes: const [],
      createdAt: now.add(const Duration(days: 1)),
      updatedAt: now,
    );
    final result = await repository.appendUnique(
      diaries: [
        local.copyWith(content: '备份中的旧版本'),
        newDiary,
      ],
      tags: const ['备份'],
      categories: const [],
      books: [localBook, newBook],
      summaries: const {'2026': '从备份添加的年总结'},
    );
    expect(result.addedDiaries, 1);
    expect(result.skippedDiaries, 1);
    expect(result.addedBooks, 1);
    expect(result.skippedBooks, 1);
    expect(
      (await repository.all())
          .where((entry) => entry.title == '本地日记')
          .single
          .content,
      '本地最新版',
    );
    expect(await repository.tags(), contains('备份'));
    expect(await repository.summary('2026'), '从备份添加的年总结');
    await database.db.close();
    await temp.delete(recursive: true);
  });
}
