import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/bin_model.dart';
import 'database_service.dart';

/// Kutu detayları için SQLite veritabanı servisi.
/// Dosya adı: Kutu_detaylari.db
class BinDatabaseService {
  static final BinDatabaseService instance = BinDatabaseService._init();
  static Database? _database;

  BinDatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('Kutu_detaylari.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 7,
      onCreate: _createDB,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          try {
            await db.execute('ALTER TABLE bins ADD COLUMN qr_token TEXT');
          } catch (e) {
            print("Sütun zaten olabilir: $e");
          }
        }
        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE daily_tasks (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              material TEXT NOT NULL,
              count INTEGER NOT NULL DEFAULT 0,
              last_reset TEXT NOT NULL
            )
          ''');
        }
        if (oldVersion < 4) {
          await db.execute('''
            CREATE TABLE active_daily_task (
              id INTEGER PRIMARY KEY,
              material TEXT NOT NULL,
              target INTEGER NOT NULL
            )
          ''');
        }
        if (oldVersion < 5) {
          try {
            await db.execute('ALTER TABLE active_daily_task ADD COLUMN is_completed INTEGER NOT NULL DEFAULT 0');
            await db.execute('ALTER TABLE active_daily_task ADD COLUMN last_reset TEXT');
          } catch (e) {
            print("Sütun zaten olabilir: $e");
          }
        }
        if (oldVersion < 6) {
          await db.execute('''
            CREATE TABLE weekly_tasks (
              id INTEGER PRIMARY KEY,
              task_key TEXT NOT NULL,
              current_count INTEGER NOT NULL DEFAULT 0,
              target INTEGER NOT NULL,
              is_completed INTEGER NOT NULL DEFAULT 0,
              last_reset TEXT NOT NULL
            )
          ''');
        }
        if (oldVersion < 7) {
          try {
            await db.execute("ALTER TABLE bins ADD COLUMN status TEXT DEFAULT 'active'");
          } catch (e) {
            print("status sütunu zaten olabilir: $e");
          }
        }
      },
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE bins (
        bin_id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        status TEXT NOT NULL DEFAULT 'active',
        type TEXT NOT NULL,
        plastic REAL NOT NULL DEFAULT 0.0,
        paper REAL NOT NULL DEFAULT 0.0,
        glass REAL NOT NULL DEFAULT 0.0,
        metal REAL NOT NULL DEFAULT 0.0,
        general REAL NOT NULL DEFAULT 0.0,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        last_update TEXT NOT NULL,
        last_emptying TEXT NOT NULL,
        qr_token TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE daily_tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        material TEXT NOT NULL,
        count INTEGER NOT NULL DEFAULT 0,
        last_reset TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE active_daily_task (
        id INTEGER PRIMARY KEY,
        material TEXT NOT NULL,
        target INTEGER NOT NULL,
        is_completed INTEGER NOT NULL DEFAULT 0,
        last_reset TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE weekly_tasks (
        id INTEGER PRIMARY KEY,
        task_key TEXT NOT NULL,
        current_count INTEGER NOT NULL DEFAULT 0,
        target INTEGER NOT NULL,
        is_completed INTEGER NOT NULL DEFAULT 0,
        last_reset TEXT NOT NULL
      )
    ''');
  }

  // --- CRUD İşlemleri ---
  
  // --- Daily Tasks ---

  Future<int> getDailyCount(String material) async {
    final db = await instance.database;
    final now = DateTime.now();
    final today = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    final List<Map<String, dynamic>> maps = await db.query(
      'daily_tasks',
      where: 'material = ?',
      whereArgs: [material.toLowerCase()],
    );

    if (maps.isEmpty) {
      await db.insert('daily_tasks', {
        'material': material.toLowerCase(),
        'count': 0,
        'last_reset': today,
      });
      return 0;
    }

    final lastReset = maps.first['last_reset'] as String;
    if (lastReset != today) {
      await db.update(
        'daily_tasks',
        {'count': 0, 'last_reset': today},
        where: 'material = ?',
        whereArgs: [material.toLowerCase()],
      );
      return 0;
    }

    return maps.first['count'] as int;
  }

  Future<void> incrementDailyCount(String material) async {
    final db = await instance.database;
    final currentCount = await getDailyCount(material);
    await db.update(
      'daily_tasks',
      {'count': currentCount + 1},
      where: 'material = ?',
      whereArgs: [material.toLowerCase()],
    );
  }

  Future<void> resetDailyTask(String material) async {
    final db = await instance.database;
    final now = DateTime.now();
    final today = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    await db.update(
      'daily_tasks',
      {'count': 0, 'last_reset': today},
      where: 'material = ?',
      whereArgs: [material.toLowerCase()],
    );
  }

  Future<void> resetAllDailyTasks() async {
    final db = await instance.database;
    final now = DateTime.now();
    final today = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    await db.update(
      'daily_tasks',
      {'count': 0, 'last_reset': today},
    );
  }

  Future<Map<String, dynamic>?> getActiveTask() async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query('active_daily_task', where: 'id = 1');
    if (maps.isNotEmpty) {
      return maps.first;
    }
    return null;
  }

  Future<void> setActiveTask(String material, int target) async {
    final db = await instance.database;
    final now = DateTime.now();
    final today = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    
    await db.insert(
      'active_daily_task',
      {
        'id': 1, 
        'material': material, 
        'target': target, 
        'is_completed': 0,
        'last_reset': today
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> setTaskCompleted() async {
    final db = await instance.database;
    await db.update(
      'active_daily_task',
      {'is_completed': 1},
      where: 'id = 1',
    );
    // İstatistik tablosundaki tamamlanan görev sayısını artır
    await UserStaticsDatabase.instance.incrementStatic('daily_tasks');
  }

  // --- Weekly Tasks ---

  Future<List<Map<String, dynamic>>> getWeeklyTasks() async {
    final db = await instance.database;
    return await db.query('weekly_tasks');
  }

  Future<void> updateWeeklyTask(String key, int current, int target, int completed, String lastReset) async {
    final db = await instance.database;
    await db.insert(
      'weekly_tasks',
      {
        'id': key == 'view_public' ? 1 : 2,
        'task_key': key,
        'current_count': current,
        'target': target,
        'is_completed': completed,
        'last_reset': lastReset,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> incrementWeeklyTask(String key) async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'weekly_tasks',
      where: 'task_key = ?',
      whereArgs: [key],
    );

    if (maps.isNotEmpty) {
      final current = maps.first['current_count'] as int;
      final target = maps.first['target'] as int;
      final isCompleted = maps.first['is_completed'] as int;

      if (isCompleted == 0) {
        final newCount = current + 1;
        int newCompleted = newCount >= target ? 1 : 0;
        
        await db.update(
          'weekly_tasks',
          {'current_count': newCount, 'is_completed': newCompleted},
          where: 'task_key = ?',
          whereArgs: [key],
        );

        if (newCompleted == 1) {
          // İstatistikleri güncelle
          await UserStaticsDatabase.instance.incrementStatic('weekly_tasks');
        }
      }
    }
  }

  /// Yeni kutu ekle
  Future<void> insertBin(RebinBin bin) async {
    final db = await database;
    await db.insert(
      'bins',
      bin.toSQLiteMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Kutuyu varsa günceller (ismini korur), yoksa ekler
  Future<void> insertOrUpdateBin(RebinBin bin) async {
    final existing = await getBinById(bin.binId);
    if (existing != null) {
      // Mevcut kutu: İsmi koruyarak diğer verileri (doluluk, konum vb.) güncelle
      final updated = bin.copyWith(name: existing.name);
      await updateBin(updated);
    } else {
      // Yeni kutu
      await insertBin(bin);
    }
  }

  /// Kutu güncelle
  Future<void> updateBin(RebinBin bin) async {
    final db = await database;
    await db.update(
      'bins',
      bin.toSQLiteMap(),
      where: 'bin_id = ?',
      whereArgs: [bin.binId],
    );
  }

  /// Kutu adını güncelle (Özel kutular için yerel isim)
  Future<void> updateBinName(String binId, String newName) async {
    final db = await database;
    await db.update(
      'bins',
      {'name': newName},
      where: 'bin_id = ?',
      whereArgs: [binId],
    );
  }

  /// ID ile kutu getir
  Future<RebinBin?> getBinById(String binId) async {
    final db = await database;
    final result = await db.query(
      'bins',
      where: 'bin_id = ?',
      whereArgs: [binId],
    );
    if (result.isNotEmpty) {
      return RebinBin.fromSQLite(result.first);
    }
    return null;
  }

  /// Tüm kutuları getir
  Future<List<RebinBin>> getAllBins() async {
    final db = await database;
    final result = await db.query('bins');
    return result.map((map) => RebinBin.fromSQLite(map)).toList();
  }

  /// Sadece özel (private) kutuları getir
  Future<List<RebinBin>> getPrivateBins() async {
    final db = await database;
    final result = await db.query(
      'bins',
      where: 'type = ?',
      whereArgs: ['private'],
    );
    return result.map((map) => RebinBin.fromSQLite(map)).toList();
  }

  /// Sadece topluma açık (public) kutuları getir
  Future<List<RebinBin>> getPublicBins() async {
    final db = await database;
    final result = await db.query(
      'bins',
      where: 'type = ?',
      whereArgs: ['public'],
    );
    return result.map((map) => RebinBin.fromSQLite(map)).toList();
  }

  /// Kutu sil
  Future<void> deleteBin(String binId) async {
    final db = await database;
    await db.delete(
      'bins',
      where: 'bin_id = ?',
      whereArgs: [binId],
    );
  }

  /// Kutu var mı kontrol et
  Future<bool> binExists(String binId) async {
    final db = await database;
    final result = await db.query(
      'bins',
      where: 'bin_id = ?',
      whereArgs: [binId],
    );
    return result.isNotEmpty;
  }

  /// Varsayılan kutuları oluştur (uygulama ilk açılışında)
  Future<void> initDefaultBins() async {
    // Dummy verileri kaldırıldı. Artık varsayılan olarak veri yüklenmeyecek.
    // Kullanıcı kutularını QR taratarak ekleyecek ve veriler Supabase'den alınacak.
  }

  /// Veritabanını kapat
  Future<void> close() async {
    final db = await database;
    db.close();
    _database = null;
  }
}
