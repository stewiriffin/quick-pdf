import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class ScannerService {
  /// Returns a back-facing CameraDescription, or the first available camera.
  static Future<CameraDescription?> getBackCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return null;
      return cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
    } catch (_) {
      return null;
    }
  }

  /// Creates and initialises a CameraController at high resolution.
  static Future<CameraController?> createController(
      CameraDescription camera) async {
    final controller = CameraController(
      camera,
      ResolutionPreset.high,
      imageFormatGroup: ImageFormatGroup.jpeg,
      enableAudio: false,
    );
    try {
      await controller.initialize();
      await controller.setFocusMode(FocusMode.auto);
      await controller.setExposureMode(ExposureMode.auto);
      return controller;
    } catch (_) {
      await controller.dispose();
      return null;
    }
  }

  /// Runs the document-enhancement pipeline in a Dart isolate so the UI
  /// stays fully responsive while processing a high-resolution photo.
  static Future<File> enhanceDocument(
    File imageFile, {
    bool blackAndWhite = false,
  }) async {
    final Directory appDocDir = await getApplicationDocumentsDirectory();
    final String outputPath =
        '${appDocDir.path}/scan_${DateTime.now().millisecondsSinceEpoch}.jpg';

    final String resultPath = await compute(
      _enhancePipeline,
      {
        'inputPath': imageFile.path,
        'outputPath': outputPath,
        'bw': blackAndWhite,
      },
    );

    return File(resultPath);
  }

  /// Isolate entry point — pure Dart, no Flutter plugins.
  static String _enhancePipeline(Map<String, dynamic> params) {
    final String inputPath = params['inputPath'] as String;
    final String outputPath = params['outputPath'] as String;
    final bool blackAndWhite = params['bw'] as bool;

    final Uint8List bytes = File(inputPath).readAsBytesSync();
    img.Image? image = img.decodeImage(bytes);
    if (image == null) return inputPath;

    if (blackAndWhite) {
      image = img.grayscale(image);
      // Normalise levels so the whitest point becomes 255 and darkest 0
      image = img.normalize(image, min: 0, max: 255);
      // Strong contrast boost for clean B&W text
      image = img.contrast(image, contrast: 1.9);
    } else {
      // Colour mode: normalise + mild contrast boost
      image = img.normalize(image, min: 10, max: 245);
      image = img.contrast(image, contrast: 1.25);
    }

    // Laplacian sharpening — improves text/edge clarity in both modes
    image = img.convolution(
      image,
      filter: [0, -1, 0, -1, 5, -1, 0, -1, 0],
      div: 1,
      offset: 0,
    );

    File(outputPath)
        .writeAsBytesSync(img.encodeJpg(image, quality: 92));
    return outputPath;
  }
}
