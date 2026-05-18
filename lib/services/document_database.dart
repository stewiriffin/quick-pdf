import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class DocumentDatabase extends ChangeNotifier {
  static final DocumentDatabase _instance = DocumentDatabase._internal();
  factory DocumentDatabase() => _instance;
  DocumentDatabase._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, 'documents.db');
    return await openDatabase(
      path,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE documents(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        path TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL,
        size INTEGER,
        text_content TEXT,
        thumbnail_path TEXT,
        dateAdded TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        lastOpened TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE documents ADD COLUMN text_content TEXT');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE documents ADD COLUMN thumbnail_path TEXT');
    }
  }

  Future<void> insertDocument(String path, {String? textContent, String? thumbnailPath}) async {
    final db = await database;
    final File file = File(path);
    await db.insert(
      'documents',
      {
        'path': path,
        'name': file.path.split('/').last,
        'size': await file.length(),
        'text_content': textContent,
        'thumbnail_path': thumbnailPath,
        'dateAdded': DateTime.now().toIso8601String(),
        'lastOpened': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    notifyListeners();
  }

  /// Returns the most recently opened documents, automatically purging entries
  /// whose files have been deleted from disk.
  Future<List<Map<String, dynamic>>> getRecentDocuments({int limit = 10}) async {
    final db = await database;
    final all = await db.query(
      'documents',
      orderBy: 'lastOpened DESC',
      limit: limit * 3,
    );

    final List<Map<String, dynamic>> valid = [];
    final List<String> orphaned = [];

    for (final doc in all) {
      final path = doc['path'] as String?;
      if (path == null) {
        continue;
      }
      final exists = await File(path).exists();
      if (exists) {
        valid.add(doc);
        if (valid.length >= limit) break;
      } else {
        orphaned.add(path);
      }
    }

    if (orphaned.isNotEmpty) {
      final batch = db.batch();
      for (final path in orphaned) {
        batch.delete('documents', where: 'path = ?', whereArgs: [path]);
      }
      await batch.commit(noResult: true);
      notifyListeners();
    }

    return valid;
  }

  Future<Map<String, dynamic>?> getDocument(String path) async {
    final db = await database;
    final results = await db.query(
      'documents',
      where: 'path = ?',
      whereArgs: [path],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<List<Map<String, dynamic>>> searchDocuments(String query, {int limit = 50}) async {
    final db = await database;
    if (query.isEmpty) {
      return getRecentDocuments(limit: limit);
    }
    final String searchQuery = '%$query%';
    final results = await db.query(
      'documents',
      where: 'name LIKE ? OR text_content LIKE ?',
      whereArgs: [searchQuery, searchQuery],
      orderBy: 'lastOpened DESC',
      limit: limit * 2,
    );

    // Filter out orphaned entries (async)
    final valid = <Map<String, dynamic>>[];
    for (final doc in results) {
      final path = doc['path'] as String?;
      if (path == null) continue;
      if (await File(path).exists()) {
        valid.add(doc);
        if (valid.length >= limit) break;
      }
    }
    return valid;
  }

  Future<void> updateLastOpened(String path) async {
    final db = await database;
    await db.update(
      'documents',
      {'lastOpened': DateTime.now().toIso8601String()},
      where: 'path = ?',
      whereArgs: [path],
    );
    notifyListeners();
  }

  Future<void> updateTextContent(String path, String textContent) async {
    final db = await database;
    await db.update(
      'documents',
      {'text_content': textContent},
      where: 'path = ?',
      whereArgs: [path],
    );
    notifyListeners();
  }

  /// Renames a document in the database after the underlying file has been moved.
  Future<void> updatePath(String oldPath, String newPath) async {
    final db = await database;
    final File newFile = File(newPath);
    await db.update(
      'documents',
      {
        'path': newPath,
        'name': newPath.split('/').last,
        'size': await newFile.length(),
      },
      where: 'path = ?',
      whereArgs: [oldPath],
    );
    notifyListeners();
  }

  Future<void> deleteDocument(String path) async {
    final db = await database;
    await db.delete(
      'documents',
      where: 'path = ?',
      whereArgs: [path],
    );
    notifyListeners();
  }
}
