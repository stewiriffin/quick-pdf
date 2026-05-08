import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:pdf_render/pdf_render.dart';
import 'package:quick_pdf/services/document_database.dart';
import 'package:quick_pdf/services/file_picker_service.dart';
import 'package:quick_pdf/services/ocr_service.dart';
import 'package:quick_pdf/ui/compress_screen.dart';
import 'package:quick_pdf/ui/convert_screen.dart';
import 'package:quick_pdf/ui/merge_screen.dart';
import 'package:quick_pdf/ui/ocr_text_screen.dart';
import 'package:quick_pdf/ui/pdf_viewer_screen.dart';
import 'package:quick_pdf/ui/scanner_screen.dart';
import 'package:quick_pdf/ui/widgets/search_delegate.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isProcessing = false;
  final OcrService _ocrService = OcrService();
  final _db = DocumentDatabase();

  @override
  void dispose() {
    _ocrService.dispose();
    super.dispose();
  }

  // ─── Quick actions ───────────────────────────────────────────────────────

  Future<void> _quickScan() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ScannerScreen()),
    );
  }

  Future<void> _quickConvert() async {
    final result = await FilePickerService.pickMultipleFiles(
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'bmp'],
    );
    if (result == null || result.isEmpty || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ConvertScreen(initialImages: result)),
    );
  }

  Future<void> _quickMerge() async {
    final result = await FilePickerService.pickMultipleFiles(
      allowedExtensions: ['pdf'],
    );
    if (result == null || result.isEmpty || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => MergeScreen(initialFiles: result)),
    );
  }

  Future<void> _quickCompress() async {
    final result = await FilePickerService.pickMultipleFiles(
      allowedExtensions: ['pdf'],
    );
    if (result == null || result.isEmpty || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CompressScreen(file: result.first)),
    );
  }

  Future<void> _quickExtract() async {
    final result = await FilePickerService.pickMultipleFiles(
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (result == null || result.isEmpty || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => OcrTextScreen(file: result.first)),
    );
  }

  // ─── Document open ────────────────────────────────────────────────────────

  Future<void> _onDocumentTap(String path) async {
    await _db.updateLastOpened(path);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PDFViewerScreen(pdfPath: path)),
    );
  }

  // ─── Add files ───────────────────────────────────────────────────────────

  Future<void> _addFiles() async {
    final result = await FilePickerService.pickMultipleFiles(
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (!mounted || result == null || result.isEmpty) return;

    setState(() => _isProcessing = true);

    for (final file in result) {
      final pages = await _ocrService.extractText(file);
      final textContent =
          pages.isNotEmpty ? pages.map((p) => p.text).join('\n\n') : null;
      final thumbPath = await _generateThumbnail(file.path);
      await _db.insertDocument(file.path,
          textContent: textContent, thumbnailPath: thumbPath);
    }

    if (!mounted) return;
    setState(() => _isProcessing = false);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          'Added ${result.length} file${result.length == 1 ? '' : 's'}'),
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<String?> _generateThumbnail(String path) async {
    try {
      final ext = path.split('.').last.toLowerCase();
      final dir = await getApplicationDocumentsDirectory();
      final outPath =
          '${dir.path}/thumb_${DateTime.now().millisecondsSinceEpoch}.png';

      if (ext == 'pdf') {
        final doc = await PdfDocument.openFile(path);
        final page = await doc.getPage(1);
        final rendered = await page.render(width: 200);
        final uiImage = await rendered.createImageIfNotAvailable();
        final bd = await uiImage.toByteData(format: ui.ImageByteFormat.png);
        await doc.dispose();
        if (bd != null) {
          await File(outPath).writeAsBytes(bd.buffer.asUint8List());
          return outPath;
        }
      } else if (['jpg', 'jpeg', 'png', 'bmp', 'webp'].contains(ext)) {
        final bytes = await File(path).readAsBytes();
        final original = img.decodeImage(Uint8List.fromList(bytes));
        if (original != null) {
          final thumb = img.copyResize(original, width: 200);
          await File(outPath).writeAsBytes(img.encodePng(thumb));
          return outPath;
        }
      }
    } catch (_) {}
    return null;
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QuickPDF'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () =>
                showSearch(context: context, delegate: DocumentSearchDelegate()),
          ),
        ],
      ),
      body: Stack(
        children: [
          _DocumentGrid(
            onDocumentTap: _onDocumentTap,
            onDocumentDelete: (path) => _db.deleteDocument(path),
            header: _QuickActionsStrip(
              onScan: _quickScan,
              onConvert: _quickConvert,
              onMerge: _quickMerge,
              onCompress: _quickCompress,
              onExtract: _quickExtract,
            ),
          ),
          if (_isProcessing)
            ColoredBox(
              color: Colors.black.withValues(alpha: 0.45),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 14),
                    Text('Importing files…',
                        style: TextStyle(color: Colors.white, fontSize: 15)),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isProcessing ? null : _addFiles,
        icon: const Icon(Icons.add),
        label: const Text('Add Files'),
      ),
    );
  }
}

// ─── Quick-actions strip ─────────────────────────────────────────────────────




class _QuickActionsStrip extends StatelessWidget {
  final VoidCallback onScan;
  final VoidCallback onConvert;
  final VoidCallback onMerge;
  final VoidCallback onCompress;
  final VoidCallback onExtract;

  const _QuickActionsStrip({
    required this.onScan,
    required this.onConvert,
    required this.onMerge,
    required this.onCompress,
    required this.onExtract,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text('Quick Actions',
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: cs.onSurfaceVariant)),
        ),
        SizedBox(
          height: 80,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              _ActionChip(icon: Icons.camera_alt, label: 'Scan', color: cs.primary, onTap: onScan),
              _ActionChip(icon: Icons.image, label: 'Convert', color: Colors.green.shade600, onTap: onConvert),
              _ActionChip(icon: Icons.merge_type, label: 'Merge', color: Colors.orange.shade700, onTap: onMerge),
              _ActionChip(icon: Icons.compress, label: 'Compress', color: Colors.red.shade600, onTap: onCompress),
              _ActionChip(icon: Icons.text_snippet_outlined, label: 'Extract', color: Colors.indigo.shade600, onTap: onExtract),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
          child: Text('Recent',
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: cs.onSurfaceVariant)),
        ),
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 72,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      color: color,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Document grid ────────────────────────────────────────────────────────────

class _DocumentGrid extends StatefulWidget {
  final Future<void> Function(String) onDocumentTap;
  final Future<void> Function(String) onDocumentDelete;
  final Widget header;

  const _DocumentGrid({
    required this.onDocumentTap,
    required this.onDocumentDelete,
    required this.header,
  });

  @override
  State<_DocumentGrid> createState() => _DocumentGridState();
}

class _DocumentGridState extends State<_DocumentGrid> {
  final _db = DocumentDatabase();
  List<Map<String, dynamic>> _docs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _db.addListener(_reload);
    _load();
  }

  @override
  void dispose() {
    _db.removeListener(_reload);
    super.dispose();
  }

  void _reload() => _load();

  Future<void> _load() async {
    final docs = await _db.getRecentDocuments(limit: 20);
    if (mounted) setState(() { _docs = docs; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: widget.header),
        if (_docs.isEmpty)
          SliverFillRemaining(child: _buildEmpty(context))
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 96),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (_, i) => _DocCard(
                  doc: _docs[i],
                  onTap: () => widget.onDocumentTap(_docs[i]['path'] ?? ''),
                  onDelete: () =>
                      widget.onDocumentDelete(_docs[i]['path'] ?? ''),
                ),
                childCount: _docs.length,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.72,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.folder_open_outlined,
              size: 80, color: Colors.grey.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text('No documents yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey)),
          const SizedBox(height: 6),
          Text('Tap "Add Files" or use a quick action above',
              style: TextStyle(color: Colors.grey[500], fontSize: 13)),
        ],
      ),
    );
  }
}

class _DocCard extends StatelessWidget {
  final Map<String, dynamic> doc;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _DocCard({
    required this.doc,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final name = doc['name'] as String? ?? 'Unknown';
    final size = (doc['size'] as int?) ?? 0;
    final thumbPath = doc['thumbnail_path'] as String?;
    final cs = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: () => _showOptions(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Thumbnail
            Expanded(
              child: Container(
                color: cs.surfaceContainerHighest,
                child: _buildThumb(thumbPath, cs),
              ),
            ),
            // File info
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _fmtSize(size),
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumb(String? path, ColorScheme cs) {
    if (path != null && File(path).existsSync()) {
      return Image.file(File(path), fit: BoxFit.cover);
    }
    return Center(
      child: Icon(Icons.picture_as_pdf, size: 48, color: cs.error),
    );
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete'),
              onTap: () { Navigator.pop(context); onDelete(); },
            ),
          ],
        ),
      ),
    );
  }

  String _fmtSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}
