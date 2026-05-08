import 'dart:typed_data';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf_render/pdf_render.dart';

class OcrPageResult {
  final int page;
  final String text;

  const OcrPageResult({required this.page, required this.text});

  int get wordCount =>
      text.trim().isEmpty ? 0 : text.trim().split(RegExp(r'\s+')).length;

  int get charCount => text.length;

  bool get isEmpty => text.trim().isEmpty;
}

class OcrService {
  final TextRecognizer _textRecognizer = TextRecognizer();

  /// Extracts text from a single image file.
  Future<OcrPageResult> extractTextFromImage(File imageFile) async {
    try {
      final InputImage input = InputImage.fromFilePath(imageFile.path);
      final RecognizedText recognized = await _textRecognizer.processImage(input);
      final String text = _structuredText(recognized);
      return OcrPageResult(page: 1, text: text);
    } catch (_) {
      return const OcrPageResult(page: 1, text: '');
    }
  }

  /// Extracts text from every page of a PDF, rendering at high resolution
  /// for better accuracy. Reports progress via [onProgress].
  Future<List<OcrPageResult>> extractTextFromPdf(
    File pdfFile, {
    void Function(int current, int total)? onProgress,
  }) async {
    final pdfDoc = await PdfDocument.openFile(pdfFile.path);
    final int total = pdfDoc.pageCount;
    final List<OcrPageResult> results = [];
    final Directory tmp = await getTemporaryDirectory();

    try {
      for (int i = 1; i <= total; i++) {
        onProgress?.call(i, total);

        final page = await pdfDoc.getPage(i);
        // Render at 1.5× the native size, capped to 1800px wide for OCR quality
        final int renderWidth =
            (page.width * 1.5).round().clamp(1200, 1800);
        final pageImage = await page.render(width: renderWidth);

        // Convert raw RGBA → PNG for ML Kit
        final rawImg = img.Image.fromBytes(
          width: pageImage.width,
          height: pageImage.height,
          bytes: pageImage.pixels.buffer,
          format: img.Format.uint8,
          numChannels: 4,
          order: img.ChannelOrder.rgba,
        );
        final pngBytes = Uint8List.fromList(img.encodePng(rawImg));
        final tmpFile = File('${tmp.path}/ocr_p$i.png');
        await tmpFile.writeAsBytes(pngBytes);

        final InputImage input = InputImage.fromFilePath(tmpFile.path);
        final RecognizedText recognized =
            await _textRecognizer.processImage(input);
        results.add(OcrPageResult(
          page: i,
          text: _structuredText(recognized),
        ));

        try { await tmpFile.delete(); } catch (_) {}
      }
    } finally {
      await pdfDoc.dispose();
    }

    return results;
  }

  /// Dispatches to the right method and always returns a list of per-page results.
  Future<List<OcrPageResult>> extractText(
    File file, {
    void Function(int current, int total)? onProgress,
  }) async {
    final ext = file.path.split('.').last.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'bmp', 'webp'].contains(ext)) {
      onProgress?.call(1, 1);
      return [await extractTextFromImage(file)];
    } else if (ext == 'pdf') {
      return extractTextFromPdf(file, onProgress: onProgress);
    }
    return [];
  }

  /// Rebuilds text from ML Kit blocks, preserving paragraph structure.
  String _structuredText(RecognizedText recognized) {
    if (recognized.blocks.isEmpty) return '';
    return recognized.blocks
        .map((b) => b.lines.map((l) => l.text).join('\n'))
        .join('\n\n');
  }

  void dispose() {
    _textRecognizer.close();
  }
}
