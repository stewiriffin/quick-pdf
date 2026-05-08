import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class FilePickerService {
  /// Pick multiple files from device storage
  static Future<List<File>?> pickMultipleFiles({
    List<String>? allowedExtensions,
    bool allowMultiple = true,
  }) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: allowMultiple,
        allowedExtensions: allowedExtensions,
        type: allowedExtensions != null ? FileType.custom : FileType.any,
      );

      if (result != null && result.files.isNotEmpty) {
        return result.files
            .map((file) => File(file.path!))
            .where((file) => file.existsSync())
            .toList();
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Pick a single image from gallery or camera
  static Future<File?> pickImage({
    required ImageSource source,
  }) async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: source);
      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Pick multiple images from gallery
  static Future<List<File>?> pickMultipleImages() async {
    try {
      final picker = ImagePicker();
      final List<XFile> images = await picker.pickMultiImage();
      if (images.isNotEmpty) {
        return images.map((image) => File(image.path)).toList();
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Check if device has enough storage space for estimated bytes
  static Future<bool> hasEnoughStorage(int estimatedBytes) async {
    try {
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      final FileStat stats = await appDocDir.stat();
      // A buffer is added to the estimated bytes to account for any other files
      // that may be created by the app.
      return (stats.size) > estimatedBytes + 1024;
    } catch (e) {
      return false;
    }
  }
}