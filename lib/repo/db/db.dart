import 'package:path/path.dart';
import 'package:simple_chat/repo/db/db_chat.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static const _databaseName = 'chat.db';
  static const _databaseVersion = 1;
  Database? _db;

  Future<void> initDatabase() async {
    if (_db != null) return;
    final path = join(await getDatabasesPath(), _databaseName);
    _db = await openDatabase(path, version: _databaseVersion,
        onCreate: (db, v) => db.execute(DbChat.getTableCreateString()));
  }

  Future<Database> get _database async {
    if (_db == null) await initDatabase();
    return _db!;
  }

  Future<DbChat> insert(DbChat chat) async {
    final db = await _database;
    chat.uuid = await db.insert(DbChat.TABLE, chat.toMap());
    return chat;
  }

  Future<List<Map<String, dynamic>>> getAllDbChatsForAccountId(String accountId) async {
    final db = await _database;
    return db.rawQuery(
        'SELECT * FROM ${DbChat.TABLE} WHERE ${DbChat.COLUMN_ACCOUNT_ID} = ?',
        [accountId]);
  }

  Future<int> delete(DbChat chat) async {
    final db = await _database;
    return db.delete(DbChat.TABLE,
        where: '${DbChat.COLUMN_UUID} = ?', whereArgs: [chat.uuid]);
  }
}
