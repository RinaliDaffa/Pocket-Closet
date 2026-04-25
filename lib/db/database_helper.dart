import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/category_model.dart';
import '../models/clothing_model.dart';
import '../models/outfit_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('pocket_closet.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  // ================================================
  // BUAT TABEL — 3 tabel, 2 relasi (Foreign Key)
  // ================================================
  Future _createDB(Database db, int version) async {
    // TABEL 1: categories
    await db.execute('''
      CREATE TABLE categories (
        id    INTEGER PRIMARY KEY AUTOINCREMENT,
        name  TEXT    NOT NULL,
        icon  TEXT    NOT NULL
      )
    ''');

    // TABEL 2: clothing_items
    // Relasi 1: categoryId → categories.id
    await db.execute('''
      CREATE TABLE clothing_items (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        name        TEXT    NOT NULL,
        brand       TEXT    NOT NULL DEFAULT '',
        color       TEXT    NOT NULL DEFAULT '',
        imagePath   TEXT,
        categoryId  INTEGER NOT NULL,
        status      TEXT    NOT NULL DEFAULT 'clean',
        wearCount   INTEGER NOT NULL DEFAULT 0,
        firestoreId TEXT,
        userId      TEXT,
        createdAt   TEXT    NOT NULL,
        FOREIGN KEY (categoryId) REFERENCES categories(id) ON DELETE CASCADE
      )
    ''');

    // TABEL 3: outfits
    await db.execute('''
      CREATE TABLE outfits (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        name        TEXT    NOT NULL,
        occasion    TEXT    NOT NULL DEFAULT 'casual',
        isOotd      INTEGER NOT NULL DEFAULT 0,
        userId      TEXT,
        firestoreId TEXT,
        createdAt   TEXT    NOT NULL
      )
    ''');

    // TABEL 4: outfit_items (junction table — many to many)
    // Relasi 2: outfitId → outfits.id
    // Relasi 3: clothingId → clothing_items.id
    await db.execute('''
      CREATE TABLE outfit_items (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        outfitId   INTEGER NOT NULL,
        clothingId INTEGER NOT NULL,
        role       TEXT    NOT NULL DEFAULT 'top',
        FOREIGN KEY (outfitId)   REFERENCES outfits(id)        ON DELETE CASCADE,
        FOREIGN KEY (clothingId) REFERENCES clothing_items(id) ON DELETE CASCADE
      )
    ''');

    // Seed data kategori default
    final batch = db.batch();
    for (final cat in _defaultCategories) {
      batch.insert('categories', cat);
    }
    await batch.commit();
  }

  static const List<Map<String, dynamic>> _defaultCategories = [
    {'name': 'Atasan',     'icon': '👕'},
    {'name': 'Bawahan',    'icon': '👖'},
    {'name': 'Dress',      'icon': '👗'},
    {'name': 'Outerwear',  'icon': '🧥'},
    {'name': 'Sepatu',     'icon': '👟'},
    {'name': 'Aksesoris',  'icon': '⌚'},
  ];

  // ================================================
  // CRUD CATEGORIES
  // ================================================
  Future<List<CategoryModel>> getAllCategories() async {
    final db = await database;
    final result = await db.query('categories', orderBy: 'id ASC');
    return result.map((e) => CategoryModel.fromMap(e)).toList();
  }

  // ================================================
  // CRUD CLOTHING — CREATE
  // ================================================
  Future<int> insertClothing(ClothingModel item) async {
    final db = await database;
    final map = item.toMap()..remove('id');
    return await db.insert('clothing_items', map);
  }

  // ================================================
  // CRUD CLOTHING — READ (dengan JOIN ke categories)
  // ================================================
  Future<List<Map<String, dynamic>>> getAllClothing(String userId) async {
    final db = await database;
    // JOIN query: ambil pakaian beserta nama & icon kategorinya
    return await db.rawQuery('''
      SELECT 
        c.*,
        cat.name  AS categoryName,
        cat.icon  AS categoryIcon
      FROM clothing_items c
      INNER JOIN categories cat ON c.categoryId = cat.id
      WHERE c.userId = ?
      ORDER BY c.createdAt DESC
    ''', [userId]);
  }

  Future<List<Map<String, dynamic>>> getClothingByCategory(
      int categoryId, String userId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT 
        c.*,
        cat.name  AS categoryName,
        cat.icon  AS categoryIcon
      FROM clothing_items c
      INNER JOIN categories cat ON c.categoryId = cat.id
      WHERE c.categoryId = ? AND c.userId = ?
      ORDER BY c.createdAt DESC
    ''', [categoryId, userId]);
  }

  Future<List<Map<String, dynamic>>> getClothingByStatus(
      String status, String userId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT 
        c.*,
        cat.name  AS categoryName,
        cat.icon  AS categoryIcon
      FROM clothing_items c
      INNER JOIN categories cat ON c.categoryId = cat.id
      WHERE c.status = ? AND c.userId = ?
      ORDER BY c.createdAt DESC
    ''', [status, userId]);
  }

  Future<ClothingModel?> getClothingById(int id) async {
    final db = await database;
    final result = await db.query(
      'clothing_items',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (result.isEmpty) return null;
    return ClothingModel.fromMap(result.first);
  }

  // ================================================
  // CRUD CLOTHING — UPDATE
  // ================================================
  Future<int> updateClothing(ClothingModel item) async {
    final db = await database;
    return await db.update(
      'clothing_items',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<int> updateClothingStatus(int id, String status) async {
    final db = await database;
    return await db.update(
      'clothing_items',
      {'status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> incrementWearCount(int id) async {
    final db = await database;
    return await db.rawUpdate('''
      UPDATE clothing_items
      SET wearCount = wearCount + 1
      WHERE id = ?
    ''', [id]);
  }

  Future<int> updateFirestoreId(int localId, String firestoreId) async {
    final db = await database;
    return await db.update(
      'clothing_items',
      {'firestoreId': firestoreId},
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  // ================================================
  // CRUD CLOTHING — DELETE
  // ================================================
  Future<int> deleteClothing(int id) async {
    final db = await database;
    return await db.delete(
      'clothing_items',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ================================================
  // CRUD OUTFITS — CREATE
  // ================================================
  Future<int> insertOutfit(OutfitModel outfit, List<Map<String, dynamic>> items) async {
    final db = await database;
    return await db.transaction((txn) async {
      // Insert outfit dulu
      final map = outfit.toMap()..remove('id');
      final outfitId = await txn.insert('outfits', map);

      // Insert setiap item ke outfit_items
      for (final item in items) {
        await txn.insert('outfit_items', {
          'outfitId':   outfitId,
          'clothingId': item['clothingId'],
          'role':       item['role'],
        });
      }
      return outfitId;
    });
  }

  /// Simpan firestoreId ke SQLite setelah sync berhasil
  Future<int> updateOutfitFirestoreId(int localId, String firestoreId) async {
    final db = await database;
    return await db.update(
      'outfits',
      {'firestoreId': firestoreId},
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  // ================================================
  // CRUD OUTFITS — READ (dengan JOIN)
  // ================================================
  Future<List<OutfitModel>> getAllOutfits(String userId) async {
    final db = await database;
    final result = await db.query(
      'outfits',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'createdAt DESC',
    );
    return result.map((e) => OutfitModel.fromMap(e)).toList();
  }

  // Ambil detail pakaian dalam sebuah outfit (JOIN 3 tabel)
  Future<List<Map<String, dynamic>>> getOutfitItems(int outfitId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT 
        oi.role,
        c.*,
        cat.name AS categoryName,
        cat.icon AS categoryIcon
      FROM outfit_items oi
      INNER JOIN clothing_items c   ON oi.clothingId = c.id
      INNER JOIN categories     cat ON c.categoryId  = cat.id
      WHERE oi.outfitId = ?
    ''', [outfitId]);
  }

  // ================================================
  // CRUD OUTFITS — UPDATE (set OOTD)
  // ================================================
  Future<void> setOotd(int outfitId, String userId) async {
    final db = await database;
    await db.transaction((txn) async {
      // Reset semua OOTD user dulu
      await txn.update(
        'outfits',
        {'isOotd': 0},
        where: 'userId = ?',
        whereArgs: [userId],
      );
      // Set outfit ini jadi OOTD
      await txn.update(
        'outfits',
        {'isOotd': 1},
        where: 'id = ?',
        whereArgs: [outfitId],
      );
      // Increment wearCount semua pakaian dalam outfit ini
      await txn.rawUpdate('''
        UPDATE clothing_items
        SET wearCount = wearCount + 1
        WHERE id IN (
          SELECT clothingId FROM outfit_items WHERE outfitId = ?
        )
      ''', [outfitId]);
    });
  }

  // ================================================
  // CRUD OUTFITS — DELETE
  // ================================================
  Future<int> deleteOutfit(int id) async {
    final db = await database;
    // outfit_items otomatis terhapus karena ON DELETE CASCADE
    return await db.delete('outfits', where: 'id = ?', whereArgs: [id]);
  }

  // ================================================
  // STATS — untuk halaman dashboard
  // ================================================
  Future<Map<String, dynamic>> getStats(String userId) async {
    final db = await database;

    final totalClothing = Sqflite.firstIntValue(await db.rawQuery(
        'SELECT COUNT(*) FROM clothing_items WHERE userId = ?', [userId])) ?? 0;

    final totalOutfits = Sqflite.firstIntValue(await db.rawQuery(
        'SELECT COUNT(*) FROM outfits WHERE userId = ?', [userId])) ?? 0;

    final neverWorn = Sqflite.firstIntValue(await db.rawQuery(
        'SELECT COUNT(*) FROM clothing_items WHERE userId = ? AND wearCount = 0',
        [userId])) ?? 0;

    final dirtyCount = Sqflite.firstIntValue(await db.rawQuery(
        'SELECT COUNT(*) FROM clothing_items WHERE userId = ? AND status = "dirty"',
        [userId])) ?? 0;

    // Pakaian paling sering dipakai
    final mostWorn = await db.rawQuery('''
      SELECT name, wearCount FROM clothing_items
      WHERE userId = ? ORDER BY wearCount DESC LIMIT 1
    ''', [userId]);

    // Kategori terbanyak
    final topCategory = await db.rawQuery('''
      SELECT cat.name, cat.icon, COUNT(c.id) as total
      FROM clothing_items c
      INNER JOIN categories cat ON c.categoryId = cat.id
      WHERE c.userId = ?
      GROUP BY c.categoryId
      ORDER BY total DESC
      LIMIT 1
    ''', [userId]);

    return {
      'totalClothing': totalClothing,
      'totalOutfits':  totalOutfits,
      'neverWorn':     neverWorn,
      'dirtyCount':    dirtyCount,
      'mostWorn':      mostWorn.isNotEmpty ? mostWorn.first : null,
      'topCategory':   topCategory.isNotEmpty ? topCategory.first : null,
    };
  }

  Future close() async {
    final db = await database;
    db.close();
  }
}