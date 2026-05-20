import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Simple local error logger. Writes a rotating log to the app's documents
/// directory so crash/error details are accessible for debugging without
/// any internet dependency.
class ErrorLogger {
  static const String _logFilename = 'quickpdf_errors.log';
  static const int _maxBytes = 512 * 1024; // 512 KB cap

  static File? _logFile;

  static Future<File> _getFile() async {
    if (_logFile != null) return _logFile!;
    final dir = await getApplicationDocumentsDirectory();
    _logFile = File('${dir.path}/$_logFilename');
    return _logFile!;
  }

  /// Appends an error entry. Rotates (clears) the log when it exceeds the cap.
  static Future<void> log(String operation, Object error,
      [StackTrace? stack]) async {
    try {
      final file = await _getFile();
      if (await file.exists() &&
          (await file.length()) > _maxBytes) {
        await file.writeAsString(''); // rotate
      }
      final entry = '${DateTime.now().toIso8601String()} [$operation] '
          '${error.toString()}'
          '${stack != null ? '\n$stack' : ''}\n\n';
      await file.writeAsString(entry,
          mode: FileMode.append, flush: true);
    } catch (_) {
      // Never let the logger throw
    }
  }

  /// Returns the full log as a string (for display in Settings or share).
  static Future<String> read() async {
    try {
      final file = await _getFile();
      if (await file.exists()) return await file.readAsString();
    } catch (_) {}
    return '';
  }

  static Future<void> clear() async {
    try {
      final file = await _getFile();
      if (await file.exists()) await file.writeAsString('');
    } catch (_) {}
  }
}
