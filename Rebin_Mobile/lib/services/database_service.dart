import 'dart:math';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Kullanıcı istatistikleri için SQLite veritabanı servisi.
/// Dosya adı: User_statics.db
/// Malzeme taratma, tarattığı malzemenin türleri vb. kullanıcı verileri burada tutulur.
class UserStaticsDatabase {
  static final UserStaticsDatabase instance = UserStaticsDatabase._init();
  static Database? _database;

  UserStaticsDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('User_statics.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 2, onCreate: _createDB, onUpgrade: _onUpgrade);
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const doubleType = 'REAL NOT NULL';
    const integerType = 'INTEGER NOT NULL';

    await db.execute('''
CREATE TABLE waste_scans (
  id $idType,
  label $textType,
  confidence $doubleType,
  timestamp $integerType
)
''');

    await db.execute('''
CREATE TABLE statics (
  key TEXT PRIMARY KEY,
  value INTEGER NOT NULL
)
''');
    
    // Varsayılan değerleri ekle
    await db.insert('statics', {'key': 'daily_tasks', 'value': 7});
    await db.insert('statics', {'key': 'weekly_tasks', 'value': 1});
    await db.insert('statics', {'key': 'info_cards', 'value': 8});
    await db.insert('statics', {'key': 'games_played', 'value': 0});
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
CREATE TABLE statics (
  key TEXT PRIMARY KEY,
  value INTEGER NOT NULL
)
''');
      await db.insert('statics', {'key': 'daily_tasks', 'value': 7});
      await db.insert('statics', {'key': 'weekly_tasks', 'value': 1});
      await db.insert('statics', {'key': 'info_cards', 'value': 8});
      await db.insert('statics', {'key': 'games_played', 'value': 0});
    }
  }

  Future<int> createWasteScan(String label, double confidence) async {
    final db = await instance.database;
    final data = {
      'label': label,
      'confidence': confidence,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    return await db.insert('waste_scans', data);
  }

  Future<List<Map<String, dynamic>>> getWasteScans() async {
    final db = await instance.database;
    return await db.query('waste_scans', orderBy: 'timestamp DESC');
  }

  Future<Map<String, int>> getWasteCountByType() async {
    final db = await instance.database;
    final result = await db.rawQuery('SELECT label, COUNT(*) as count FROM waste_scans GROUP BY label');
    
    Map<String, int> counts = {};
    for (var row in result) {
      counts[row['label'] as String] = row['count'] as int;
    }
    return counts;
  }

  // --- İstatistik Metotları ---

  Future<Map<String, int>> getGeneralStatics() async {
    final db = await instance.database;
    final result = await db.query('statics');
    
    Map<String, int> stats = {};
    for (var row in result) {
      stats[row['key'] as String] = row['value'] as int;
    }
    return stats;
  }

  Future<void> incrementStatic(String key) async {
    final db = await instance.database;
    await db.rawUpdate('UPDATE statics SET value = value + 1 WHERE key = ?', [key]);
  }

  Future<void> injectSyntheticDataIfNeeded() async {
    final db = await instance.database;
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM waste_scans')) ?? 0;
    if (count == 0) {
      final now = DateTime.now();
      final random = Random();
      final labels = ['Plastik', 'Kağıt', 'Cam', 'Metal'];
      
      // Inject ~60 random scans for the past month
      for (int i = 0; i < 60; i++) {
        final daysAgo = random.nextInt(30);
        final date = now.subtract(Duration(days: daysAgo));
        final label = labels[random.nextInt(labels.length)];
        final confidence = 0.65 + (random.nextDouble() * 0.34);
        
        await db.insert('waste_scans', {
          'label': label,
          'confidence': confidence,
          'timestamp': date.millisecondsSinceEpoch,
        });
      }
    }
  }

  Future close() async {
    final db = await instance.database;
    db.close();
    _database = null;
  }
}
