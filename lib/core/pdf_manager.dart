import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart' hide PdfDocument;
import 'package:pdf/widgets.dart' as pw;
import 'package:image/image.dart' as img;
import 'package:flutter/services.dart';
import 'package:pdf_render/pdf_render.dart';
import 'pdf_processor.dart';

class PDFManager {
  /// Converts images to PDF — pure Dart, safe to run in the processor isolate.
  static Future<File> convertImagesToPDF(
    List<File> images, {
    String pageSize = 'A4',
    bool landscape = false,
    int quality = 85,
    double margin = 20.0,
    String? outputName,
  }) async {
    final List<List<int>> imageBytesList = [];
    for (final imageFile in images) {
      imageBytesList.add(await imageFile.readAsBytes());
    }

    final isolate = await PdfProcessorIsolate.spawn();
    final pdfBytes = await isolate.convertImagesToPDF(
      imageBytesList,
      pageSize: pageSize,
      landscape: landscape,
      quality: quality,
      margin: margin,
    );
    await isolate.kill();

    final Directory appDocDir = await getApplicationDocumentsDirectory();
    final String filename = (outputName?.isNotEmpty == true)
        ? '$outputName.pdf'
        : 'QuickPDF_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final File pdfFile = File('${appDocDir.path}/$filename');
    await pdfFile.writeAsBytes(pdfBytes);
    return pdfFile;
  }

  /// Merges PDFs on the main isolate so pdf_render's platform channels work.
  /// Accepts per-document page selections and reports progress via [onProgress].
  static Future<File> mergePDFFiles(
    List<File> pdfs, {
    List<List<int>?>? pageSelections,
    int quality = 85,
    String? outputName,
    void Function(int current, int total)? onProgress,
  }) async {
    final pw.Document target = pw.Document(compress: true);
    final double renderScale =
        quality >= 80 ? 2.0 : quality >= 60 ? 1.5 : 1.0;

    // Count total pages up front for progress reporting.
    int totalPages = 0;
    int donePages = 0;
    for (int d = 0; d < pdfs.length; d++) {
      final sel = pageSelections?[d];
      if (sel != null) {
        totalPages += sel.length;
      } else {
        // Open just to read page count, then dispose immediately.
        final tmp = await PdfDocument.openFile(pdfs[d].path);
        totalPages += tmp.pageCount;
        await tmp.dispose();
      }
    }

    for (int docIdx = 0; docIdx < pdfs.length; docIdx++) {
      final Uint8List pdfBytes = await pdfs[docIdx].readAsBytes();
      final source = await PdfDocument.openData(pdfBytes);
      final int total = source.pageCount;
      final List<int>? sel = pageSelections?[docIdx];

      final List<int> pages = sel != null
          ? (sel.where((p) => p >= 1 && p <= total).toList()..sort())
          : List.generate(total, (i) => i + 1);

      for (final pageNum in pages) {
        donePages++;
        onProgress?.call(donePages, totalPages);

        final page = await source.getPage(pageNum);
        final int rw = (page.width * renderScale).round();
        final int rh = (page.height * renderScale).round();
        final pageImage = await page.render(width: rw, height: rh);

        // Yield so Flutter can process redraws between pages.
        await Future.delayed(Duration.zero);

        final image = img.Image.fromBytes(
          width: pageImage.width,
          height: pageImage.height,
          bytes: pageImage.pixels.buffer,
          format: img.Format.uint8,
          numChannels: 4,
          order: img.ChannelOrder.rgba,
        );
        final encoded =
            Uint8List.fromList(img.encodeJpg(image, quality: quality));

        // Page size in PDF points (page.width/height), NOT pixel dimensions.
        target.addPage(pw.Page(
          pageFormat: PdfPageFormat(page.width, page.height),
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Image(pw.MemoryImage(encoded)),
        ));

        await Future.delayed(Duration.zero);
      }
      await source.dispose();
    }

    final Uint8List mergedBytes = await target.save();
    final Directory appDocDir = await getApplicationDocumentsDirectory();
    final String filename = (outputName?.isNotEmpty == true)
        ? '$outputName.pdf'
        : 'Merged_QuickPDF_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final File mergedFile = File('${appDocDir.path}/$filename');
    await mergedFile.writeAsBytes(mergedBytes);
    return mergedFile;
  }

  /// Compresses a PDF on the main isolate so pdf_render's platform channels work.
  /// Reports progress via [onProgress].
  static Future<File> compressPDF(
    File pdfFile, {
    int imageQuality = 65,
    double renderScale = 1.0,
    String? outputName,
    void Function(int current, int total)? onProgress,
  }) async {
    final Uint8List pdfBytes = await pdfFile.readAsBytes();
    final source = await PdfDocument.openData(pdfBytes);
    final pw.Document target = pw.Document(compress: true);
    final int pageCount = source.pageCount;

    for (int i = 1; i <= pageCount; i++) {
      onProgress?.call(i, pageCount);

      final page = await source.getPage(i);
      final int rw = (page.width * renderScale).round();
      final int rh = (page.height * renderScale).round();
      final pageImage = await page.render(width: rw, height: rh);

      // Yield so Flutter can process redraws between pages.
      await Future.delayed(Duration.zero);

      final image = img.Image.fromBytes(
        width: pageImage.width,
        height: pageImage.height,
        bytes: pageImage.pixels.buffer,
        format: img.Format.uint8,
        numChannels: 4,
        order: img.ChannelOrder.rgba,
      );
      final encoded =
          Uint8List.fromList(img.encodeJpg(image, quality: imageQuality));

      // Page size in PDF points (page.width/height), NOT pixel dimensions.
      target.addPage(pw.Page(
        pageFormat: PdfPageFormat(page.width, page.height),
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.Image(pw.MemoryImage(encoded)),
      ));

      await Future.delayed(Duration.zero);
    }
    await source.dispose();

    final Uint8List compressedBytes = await target.save();
    final Directory appDocDir = await getApplicationDocumentsDirectory();
    final String filename = (outputName?.isNotEmpty == true)
        ? '$outputName.pdf'
        : 'Compressed_QuickPDF_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final File compressedFile = File('${appDocDir.path}/$filename');
    await compressedFile.writeAsBytes(compressedBytes);
    return compressedFile;
  }

  /// Saves a rasterised copy of the PDF (password protection unavailable
  /// in the pure-Dart pdf package).
  static Future<File> encryptPDF(File pdfFile, String password) async {
    final Uint8List pdfBytes = await pdfFile.readAsBytes();
    final sourceDoc = await PdfDocument.openData(pdfBytes);
    final pw.Document newDoc = pw.Document(compress: true);

    for (int i = 1; i <= sourceDoc.pageCount; i++) {
      final page = await sourceDoc.getPage(i);
      final pageImage = await page.render(
        width: page.width.toInt(),
        height: page.height.toInt(),
      );
      await Future.delayed(Duration.zero);

      final image = img.Image.fromBytes(
        width: pageImage.width,
        height: pageImage.height,
        bytes: pageImage.pixels.buffer,
        format: img.Format.uint8,
        numChannels: 4,
        order: img.ChannelOrder.rgba,
      );
      final pngBytes = img.encodePng(image);
      newDoc.addPage(pw.Page(
        pageFormat: PdfPageFormat(page.width, page.height),
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.Image(pw.MemoryImage(pngBytes)),
      ));
      await Future.delayed(Duration.zero);
    }
    await sourceDoc.dispose();

    final Uint8List newBytes = await newDoc.save();
    final Directory appDocDir = await getApplicationDocumentsDirectory();
    final File outFile = File(
        '${appDocDir.path}/Secured_QuickPDF_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await outFile.writeAsBytes(newBytes);
    return outFile;
  }

  /// Updates PDF metadata by rasterising pages into a new document.
  static Future<File> updatePDFMetadata(
    File pdfFile, {
    String? author,
    String? title,
    String? subject,
    String? keywords,
  }) async {
    final Uint8List pdfBytes = await pdfFile.readAsBytes();
    final sourceDoc = await PdfDocument.openData(pdfBytes);

    final pw.Document updatedPdf = pw.Document(
      compress: true,
      author: author,
      title: title,
      subject: subject,
      keywords: keywords,
      creator: 'QuickPDF',
    );

    for (int i = 1; i <= sourceDoc.pageCount; i++) {
      final page = await sourceDoc.getPage(i);
      final pageImage = await page.render(
        width: page.width.toInt(),
        height: page.height.toInt(),
      );
      await Future.delayed(Duration.zero);

      final image = img.Image.fromBytes(
        width: pageImage.width,
        height: pageImage.height,
        bytes: pageImage.pixels.buffer,
        format: img.Format.uint8,
        numChannels: 4,
        order: img.ChannelOrder.rgba,
      );
      final pngBytes = img.encodePng(image);
      updatedPdf.addPage(pw.Page(
        pageFormat: PdfPageFormat(page.width, page.height),
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.Image(pw.MemoryImage(pngBytes)),
      ));
      await Future.delayed(Duration.zero);
    }
    await sourceDoc.dispose();

    final Uint8List updatedBytes = await updatedPdf.save();
    final Directory appDocDir = await getApplicationDocumentsDirectory();
    final File updatedFile = File(
        '${appDocDir.path}/UpdatedMetadata_QuickPDF_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await updatedFile.writeAsBytes(updatedBytes);
    return updatedFile;
  }

  static void hapticFeedbackSuccess() => HapticFeedback.lightImpact();
  static void hapticFeedbackError() => HapticFeedback.heavyImpact();
}
