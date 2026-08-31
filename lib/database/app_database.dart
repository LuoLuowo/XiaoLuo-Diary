import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  late final Database db;

  Future<void> initialize({String? pathOverride}) async {
    final root = pathOverride == null
        ? await getApplicationSupportDirectory()
        : null;
    db = await openDatabase(
      pathOverride ?? p.join(root!.path, 'xiaoluo_diary.db'),
      version: 4,
      onCreate: (database, version) async {
        await database.execute('''CREATE TABLE diaries(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL, content TEXT NOT NULL, rich_content TEXT NOT NULL DEFAULT '',
          diary_date INTEGER NOT NULL, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
          category TEXT NOT NULL, tags TEXT NOT NULL, images TEXT NOT NULL, videos TEXT NOT NULL DEFAULT '[]',
          attachments TEXT NOT NULL
        )''');
        await database.execute(
          'CREATE TABLE tags(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT UNIQUE NOT NULL)',
        );
        await database.execute(
          'CREATE TABLE categories(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT UNIQUE NOT NULL)',
        );
        await database.execute(
          'CREATE TABLE metadata(key TEXT PRIMARY KEY, value TEXT NOT NULL)',
        );
        await _createBooks(database);
        await _createTrash(database);
        for (final name in ['生活', '学习', '工作', '旅行', '随笔', '重要', '其他']) {
          await database.insert('categories', {'name': name});
        }
        for (final name in ['生活', '美食']) {
          await database.insert('tags', {'name': name});
        }
      },
      onUpgrade: (database, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await database.execute(
            "ALTER TABLE diaries ADD COLUMN videos TEXT NOT NULL DEFAULT '[]'",
          );
          await _createBooks(database);
        }
        if (oldVersion < 3) {
          await database.execute(
            "ALTER TABLE diaries ADD COLUMN rich_content TEXT NOT NULL DEFAULT ''",
          );
        }
        if (oldVersion < 4) {
          final columns = await database.rawQuery('PRAGMA table_info(books)');
          if (!columns.any((column) => column['name'] == 'review')) {
            await database.execute(
              "ALTER TABLE books ADD COLUMN review TEXT NOT NULL DEFAULT ''",
            );
          }
          await _createTrash(database);
        }
      },
    );
  }

  static Future<void> _createBooks(Database database) =>
      database.execute('''CREATE TABLE IF NOT EXISTS books(
    id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, author TEXT NOT NULL,
    cover_path TEXT NOT NULL, notes TEXT NOT NULL, review TEXT NOT NULL DEFAULT '', created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL
  )''');

  static Future<void> _createTrash(Database database) =>
      database.execute('''CREATE TABLE IF NOT EXISTS diary_trash(
    id INTEGER PRIMARY KEY, title TEXT NOT NULL, content TEXT NOT NULL,
    rich_content TEXT NOT NULL DEFAULT '', diary_date INTEGER NOT NULL,
    created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
    category TEXT NOT NULL, tags TEXT NOT NULL, images TEXT NOT NULL,
    videos TEXT NOT NULL DEFAULT '[]', attachments TEXT NOT NULL,
    deleted_at INTEGER NOT NULL
  )''');
}
