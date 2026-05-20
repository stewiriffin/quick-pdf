import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:quick_pdf/services/document_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// ---------------------------------------------------------------------------
// Fake PathProvider for tests
// ---------------------------------------------------------------------------
class _FakePathProvider extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  late final Directory _tmp;
  _FakePathProvider(this._tmp);

  @override
  Future<String?> getApplicationDocumentsPath() async => _tmp.path;
  @override
  Future<String?> getTemporaryPath() async => _tmp.path;
  @override
  Future<String?> getApplicationCachePath() async => _tmp.path;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
Future<File> _touchFile(Directory dir, String name) async {
  final f = File('${dir.path}/$name');
  await f.writeAsString('');
  return f;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------
void main() {
  late Directory tmpDir;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('qpdf_test_');
    PathProviderPlatform.instance = _FakePathProvider(tmpDir);
    // Reset the singleton DB so each test gets a fresh database.
    // We use the internal reset method exposed for tests.
  });

  tearDown(() async {
    await tmpDir.delete(recursive: true);
  });

  group('DocumentDatabase', () {
    test('insert and fetch a document', () async {
      final db = DocumentDatabase();
      final f = await _touchFile(tmpDir, 'test.pdf');
      await db.insertDocument(f.path);

      final doc = await db.getDocument(f.path);
      expect(doc, isNotNull);
      expect(doc!['name'], equals('test.pdf'));
    });

    test('getAllDocuments returns valid files only', () async {
      final db = DocumentDatabase();
      final real = await _touchFile(tmpDir, 'real.pdf');
      await db.insertDocument(real.path);

      // Insert a ghost path without creating the file
      final ghost = File('${tmpDir.path}/ghost.pdf');
      await db.insertDocument(ghost.path);
      await ghost.delete().catchError((_) => ghost);

      final docs = await db.getAllDocuments();
      expect(docs.map((d) => d['name']).toList(), contains('real.pdf'));
      expect(docs.map((d) => d['name']).toList(),
          isNot(contains('ghost.pdf')));
    });

    test('deleteDocument removes it from fetch', () async {
      final db = DocumentDatabase();
      final f = await _touchFile(tmpDir, 'del.pdf');
      await db.insertDocument(f.path);
      await db.deleteDocument(f.path);

      final doc = await db.getDocument(f.path);
      expect(doc, isNull);
    });

    test('toggleFavourite flips is_favourite', () async {
      final db = DocumentDatabase();
      final f = await _touchFile(tmpDir, 'fav.pdf');
      await db.insertDocument(f.path);

      await db.toggleFavourite(f.path);
      final after = await db.getDocument(f.path);
      expect(after!['is_favourite'], equals(1));

      await db.toggleFavourite(f.path);
      final reset = await db.getDocument(f.path);
      expect(reset!['is_favourite'], equals(0));
    });

    test('searchDocuments filters by name', () async {
      final db = DocumentDatabase();
      final a = await _touchFile(tmpDir, 'alpha.pdf');
      final b = await _touchFile(tmpDir, 'beta.pdf');
      await db.insertDocument(a.path);
      await db.insertDocument(b.path);

      final results = await db.searchDocuments('alpha');
      expect(results.length, equals(1));
      expect(results.first['name'], equals('alpha.pdf'));
    });
  });
}
