import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:quick_pdf/core/pdf_manager.dart';

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
// Tests
// ---------------------------------------------------------------------------
void main() {
  late Directory tmpDir;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('qpdf_manager_');
    PathProviderPlatform.instance = _FakePathProvider(tmpDir);
  });

  tearDown(() => tmpDir.delete(recursive: true));

  group('PDFManager.generateThumbnail', () {
    test('returns null for non-existent file', () async {
      final result = await PDFManager.generateThumbnail('/nonexistent/x.pdf');
      expect(result, isNull);
    });

    test('returns null for empty file', () async {
      final f = File('${tmpDir.path}/empty.pdf');
      await f.writeAsBytes([]);
      final result = await PDFManager.generateThumbnail(f.path);
      expect(result, isNull);
    });
  });

  group('PDFManager.getPageCount', () {
    test('returns 0 for non-existent file', () async {
      final count = await PDFManager.getPageCount('/nonexistent/x.pdf');
      expect(count, equals(0));
    });

    test('returns 0 for corrupted file', () async {
      final f = File('${tmpDir.path}/bad.pdf');
      await f.writeAsString('not a pdf');
      final count = await PDFManager.getPageCount(f.path);
      expect(count, equals(0));
    });
  });
}
