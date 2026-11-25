import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/product.dart';

class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();
  Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    final root = await getDatabasesPath();
    _db = await openDatabase(
      p.join(root, 'shelf_life_scanner.db'),
      version: 1,
      onCreate: (database, version) async {
        await database.execute('''CREATE TABLE records (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          barcode TEXT NOT NULL,
          expiry_date TEXT NOT NULL,
          created_at TEXT NOT NULL
        )''');
      },
    );
    return _db!;
  }

  Future<void> save(ExpiryRecord record) async {
    final database = await db;
    await database.insert('records', record.toMap(), conflictAlgorithm: ConflictAlgorithm.abort);
  }

  Future<List<ExpiryRecord>> allRecords() async {
    final database = await db;
    final rows = await database.query('records', orderBy: 'id DESC');
    return rows.map(ExpiryRecord.fromMap).toList();
  }

  Future<void> delete(int id) async {
    final database = await db;
    await database.delete('records', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteAll() async {
    final database = await db;
    await database.delete('records');
  }
}
