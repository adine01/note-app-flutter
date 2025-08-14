import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/note.dart';
import '../models/category.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String databasePath = await getDatabasesPath();
    String path = join(databasePath, 'notes_app.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Create notes table
    await db.execute('''
      CREATE TABLE notes (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        category TEXT,
        tags TEXT,
        archived INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        user_id TEXT NOT NULL,
        sync_status INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Create categories table
    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        color TEXT NOT NULL,
        note_count INTEGER NOT NULL DEFAULT 0,
        user_id TEXT NOT NULL,
        sync_status INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Create sync metadata table
    await db.execute('''
      CREATE TABLE sync_metadata (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Create indexes for better performance
    await db.execute('CREATE INDEX idx_notes_user_id ON notes(user_id)');
    await db.execute('CREATE INDEX idx_notes_created_at ON notes(created_at)');
    await db.execute('CREATE INDEX idx_notes_updated_at ON notes(updated_at)');
    await db.execute('CREATE INDEX idx_notes_title ON notes(title)');
    await db.execute(
      'CREATE INDEX idx_categories_user_id ON categories(user_id)',
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle database upgrades here
    if (oldVersion < 2) {
      // Add any new columns or tables for version 2
    }
  }

  // Note operations
  Future<String> insertNote(Note note) async {
    final db = await database;
    final noteMap = note.toMap();
    noteMap['sync_status'] = 0; // 0 = needs sync

    await db.insert(
      'notes',
      noteMap,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return note.id;
  }

  Future<void> updateNote(Note note) async {
    final db = await database;
    final noteMap = note.toMap();
    noteMap['sync_status'] = 0; // 0 = needs sync

    final count = await db.update(
      'notes',
      noteMap,
      where: 'id = ?',
      whereArgs: [note.id],
    );
    if (count == 0) {
      await db.insert(
        'notes',
        noteMap,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<void> deleteNote(String id) async {
    final db = await database;
    await db.update(
      'notes',
      {
        'archived': 1,
        'sync_status': 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> permanentDeleteNote(String id) async {
    final db = await database;
    await db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }

  Future<Note?> getNote(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'notes',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Note.fromMap(maps.first);
    }
    return null;
  }

  Future<List<Note>> getAllNotes({
    String? userId,
    bool includeArchived = false,
    String? category,
    String? searchQuery,
    String sortBy = 'updated_at',
    bool ascending = false,
  }) async {
    final db = await database;

    String whereClause = '1=1';
    List<dynamic> whereArgs = [];

    if (userId != null) {
      whereClause += ' AND user_id = ?';
      whereArgs.add(userId);
    }

    if (!includeArchived) {
      whereClause += ' AND archived = 0';
    }

    if (category != null && category.isNotEmpty) {
      whereClause += ' AND category = ?';
      whereArgs.add(category);
    }

    if (searchQuery != null && searchQuery.isNotEmpty) {
      whereClause += ' AND (title LIKE ? OR content LIKE ?)';
      whereArgs.add('%$searchQuery%');
      whereArgs.add('%$searchQuery%');
    }

    String orderBy = '$sortBy ${ascending ? 'ASC' : 'DESC'}';

    final List<Map<String, dynamic>> maps = await db.query(
      'notes',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: orderBy,
    );

    return List.generate(maps.length, (i) => Note.fromMap(maps[i]));
  }

  // Category operations
  Future<String> insertCategory(Category category) async {
    final db = await database;
    final categoryMap = category.toMap();
    categoryMap['sync_status'] = 0;

    await db.insert(
      'categories',
      categoryMap,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return category.id;
  }

  Future<void> updateCategory(Category category) async {
    final db = await database;
    final categoryMap = category.toMap();
    categoryMap['sync_status'] = 0;

    final count = await db.update(
      'categories',
      categoryMap,
      where: 'id = ?',
      whereArgs: [category.id],
    );
    if (count == 0) {
      await db.insert(
        'categories',
        categoryMap,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<void> deleteCategory(String id) async {
    final db = await database;
    await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Category>> getAllCategories({String? userId}) async {
    final db = await database;

    String whereClause = '1=1';
    List<dynamic> whereArgs = [];

    if (userId != null) {
      whereClause += ' AND user_id = ?';
      whereArgs.add(userId);
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'categories',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'name ASC',
    );

    return List.generate(maps.length, (i) => Category.fromMap(maps[i]));
  }

  Future<void> updateCategoryNoteCounts() async {
    final db = await database;
    await db.execute('''
      UPDATE categories 
      SET note_count = (
        SELECT COUNT(*) 
        FROM notes 
        WHERE notes.category = categories.name 
        AND notes.archived = 0
      )
    ''');
  }

  // Sync operations
  Future<void> markAsSynced(String table, String id) async {
    final db = await database;
    await db.update(
      table,
      {'sync_status': 1}, // 1 = synced
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getUnsyncedItems(String table) async {
    final db = await database;
    return await db.query(
      table,
      where: 'sync_status = ?',
      whereArgs: [0], // 0 = needs sync
    );
  }

  Future<void> setSyncMetadata(String key, String value) async {
    final db = await database;
    await db.insert('sync_metadata', {
      'key': key,
      'value': value,
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getSyncMetadata(String key) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'sync_metadata',
      where: 'key = ?',
      whereArgs: [key],
    );

    if (maps.isNotEmpty) {
      return maps.first['value'] as String;
    }
    return null;
  }

  // Utility methods
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('notes');
    await db.delete('categories');
    await db.delete('sync_metadata');
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }

  Future<int> getNotesCount({
    String? userId,
    bool includeArchived = false,
  }) async {
    final db = await database;

    String whereClause = '1=1';
    List<dynamic> whereArgs = [];

    if (userId != null) {
      whereClause += ' AND user_id = ?';
      whereArgs.add(userId);
    }

    if (!includeArchived) {
      whereClause += ' AND archived = 0';
    }

    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM notes WHERE $whereClause',
      whereArgs,
    );

    return result.first['count'] as int;
  }

  bool _isLocalId(String id) => id.startsWith('local_');
}
