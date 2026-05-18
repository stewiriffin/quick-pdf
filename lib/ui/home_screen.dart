import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:pdf_render/pdf_render.dart';
import 'package:share_plus/share_plus.dart';
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
import 'package:quick_pdf/services/ad_service.dart';

enum _SortMode { recent, name, size, added }

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

  // ─── Quick actions ─────────────────────────────────────────────────────────

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

  // ─── Document open ──────────────────────────────────────────────────────────

  Future<void> _onDocumentTap(String path) async {
    await _db.updateLastOpened(path);
    if (!mounted) return;
    final ext = path.split('.').last.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'bmp', 'webp'].contains(ext)) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => _ImageViewerScreen(path: path)),
      );
    } else {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PDFViewerScreen(pdfPath: path)),
      );
    }
  }

  // ─── Add files ─────────────────────────────────────────────────────────────

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

    AdService().showInterstitialIfReady();
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

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QuickPDF'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => showSearch(
                context: context, delegate: DocumentSearchDelegate()),
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

// ─── Quick-actions strip ──────────────────────────────────────────────────────

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
              _ActionChip(
                  icon: Icons.camera_alt,
                  label: 'Scan',
                  color: cs.primary,
                  onTap: onScan),
              _ActionChip(
                  icon: Icons.image,
                  label: 'Convert',
                  color: Colors.green.shade600,
                  onTap: onConvert),
              _ActionChip(
                  icon: Icons.merge_type,
                  label: 'Merge',
                  color: Colors.orange.shade700,
                  onTap: onMerge),
              _ActionChip(
                  icon: Icons.compress,
                  label: 'Compress',
                  color: Colors.red.shade600,
                  onTap: onCompress),
              _ActionChip(
                  icon: Icons.text_snippet_outlined,
                  label: 'Extract',
                  color: Colors.indigo.shade600,
                  onTap: onExtract),
            ],
          ),
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
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(label,
                    style: TextStyle(
                        fontSize: 11,
                        color: color,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Document grid / list ─────────────────────────────────────────────────────

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
  _SortMode _sortMode = _SortMode.recent;
  bool _isGridView = true;

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
    final docs = await _db.getRecentDocuments(limit: 50);
    if (mounted) {
      setState(() {
        _docs = docs;
        _loading = false;
        _applySort();
      });
    }
  }

  void _applySort() {
    switch (_sortMode) {
      case _SortMode.recent:
        // DB already returns lastOpened DESC
        break;
      case _SortMode.name:
        _docs.sort((a, b) =>
            (a['name'] as String? ?? '')
                .toLowerCase()
                .compareTo((b['name'] as String? ?? '').toLowerCase()));
        break;
      case _SortMode.size:
        _docs.sort((a, b) =>
            (b['size'] as int? ?? 0).compareTo(a['size'] as int? ?? 0));
        break;
      case _SortMode.added:
        _docs.sort((a, b) =>
            (b['dateAdded'] as String? ?? '')
                .compareTo(a['dateAdded'] as String? ?? ''));
        break;
    }
  }

  // ─── Rename ───────────────────────────────────────────────────────────────

  Future<void> _renameDoc(String path, String name) async {
    final ext =
        name.contains('.') ? name.substring(name.lastIndexOf('.')) : '';
    final nameWithoutExt =
        ext.isNotEmpty ? name.substring(0, name.lastIndexOf('.')) : name;
    final controller = TextEditingController(text: nameWithoutExt);

    final String? newBaseName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'New name',
            suffixText: ext,
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () =>
                  Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Rename')),
        ],
      ),
    );

    controller.dispose();
    if (newBaseName == null ||
        newBaseName.isEmpty ||
        newBaseName == nameWithoutExt) {
      return;
    }

    try {
      final file = File(path);
      final newPath = '${file.parent.path}/$newBaseName$ext';
      await file.rename(newPath);
      await _db.updatePath(path, newPath);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Rename failed: $e'),
              behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final cs = Theme.of(context).colorScheme;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: widget.header),

        // ── Sort & view-toggle bar ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 4),
            child: Row(
              children: [
                Text(
                  _docs.isEmpty
                      ? 'Documents'
                      : '${_docs.length} document${_docs.length == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: cs.onSurfaceVariant),
                ),
                const Spacer(),
                // Sort popup
                PopupMenuButton<_SortMode>(
                  tooltip: 'Sort',
                  icon: Icon(Icons.sort, size: 20, color: cs.onSurfaceVariant),
                  initialValue: _sortMode,
                  onSelected: (mode) {
                    setState(() {
                      _sortMode = mode;
                      _applySort();
                    });
                  },
                  itemBuilder: (_) => [
                    _sortItem(_SortMode.recent, Icons.access_time, 'Recently opened'),
                    _sortItem(_SortMode.added, Icons.calendar_today, 'Date added'),
                    _sortItem(_SortMode.name, Icons.sort_by_alpha, 'Name'),
                    _sortItem(_SortMode.size, Icons.data_usage, 'File size'),
                  ],
                ),
                // Grid/List toggle
                IconButton(
                  tooltip: _isGridView ? 'List view' : 'Grid view',
                  icon: Icon(
                    _isGridView ? Icons.view_list : Icons.grid_view,
                    size: 20,
                    color: cs.onSurfaceVariant,
                  ),
                  onPressed: () =>
                      setState(() => _isGridView = !_isGridView),
                ),
              ],
            ),
          ),
        ),

        if (_docs.isEmpty)
          SliverFillRemaining(child: _buildEmpty(context))
        else if (_isGridView)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 96),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (_, i) => _DocCard(
                  doc: _docs[i],
                  onTap: () =>
                      widget.onDocumentTap(_docs[i]['path'] ?? ''),
                  onDelete: () =>
                      widget.onDocumentDelete(_docs[i]['path'] ?? ''),
                  onRename: () => _renameDoc(
                      _docs[i]['path'] ?? '', _docs[i]['name'] ?? ''),
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
          )
        else
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 96),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => _DocListItem(
                  doc: _docs[i],
                  onTap: () =>
                      widget.onDocumentTap(_docs[i]['path'] ?? ''),
                  onDelete: () =>
                      widget.onDocumentDelete(_docs[i]['path'] ?? ''),
                  onRename: () => _renameDoc(
                      _docs[i]['path'] ?? '', _docs[i]['name'] ?? ''),
                ),
                childCount: _docs.length,
              ),
            ),
          ),
      ],
    );
  }

  PopupMenuItem<_SortMode> _sortItem(
      _SortMode mode, IconData icon, String label) {
    final selected = _sortMode == mode;
    return PopupMenuItem(
      value: mode,
      child: Row(
        children: [
          Icon(icon,
              size: 18,
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : null),
          const SizedBox(width: 10),
          Text(label,
              style: TextStyle(
                  fontWeight:
                      selected ? FontWeight.w600 : FontWeight.normal)),
          if (selected) ...[
            const Spacer(),
            Icon(Icons.check,
                size: 16,
                color: Theme.of(context).colorScheme.primary),
          ],
        ],
      ),
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
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: Colors.grey)),
          const SizedBox(height: 6),
          Text('Tap "Add Files" or use a quick action above',
              style: TextStyle(color: Colors.grey[500], fontSize: 13)),
        ],
      ),
    );
  }
}

// ─── Grid card ────────────────────────────────────────────────────────────────

class _DocCard extends StatelessWidget {
  final Map<String, dynamic> doc;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onRename;

  const _DocCard({
    required this.doc,
    required this.onTap,
    required this.onDelete,
    required this.onRename,
  });

  String get _name => doc['name'] as String? ?? 'Unknown';
  int get _size => (doc['size'] as int?) ?? 0;
  String? get _thumbPath => doc['thumbnail_path'] as String?;
  String get _ext => _name.split('.').last.toUpperCase();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: () => _showOptions(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: cs.surfaceContainerHighest,
                    child: _buildThumbImage(cs),
                  ),
                  // File type badge
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _ext,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5),
                      ),
                    ),
                  ),
                  // Options button
                  Positioned(
                    top: 2,
                    left: 2,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _showOptions(context),
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(Icons.more_vert,
                              color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _fmtSize(_size),
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbImage(ColorScheme cs) {
    final isPdf = _ext == 'PDF';
    if (_thumbPath != null) {
      return Image.file(
        File(_thumbPath!),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Center(
          child: Icon(
            isPdf ? Icons.picture_as_pdf : Icons.image,
            size: 48,
            color: isPdf ? cs.error : Colors.green,
          ),
        ),
      );
    }
    return Center(
      child: Icon(
        isPdf ? Icons.picture_as_pdf : Icons.image,
        size: 48,
        color: isPdf ? cs.error : Colors.green,
      ),
    );
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                _name,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: const Text('Open'),
              onTap: () {
                Navigator.pop(context);
                onTap();
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Share'),
              onTap: () {
                Navigator.pop(context);
                Share.shareXFiles(
                  [XFile(doc['path'] as String)],
                  subject: _name,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline),
              title: const Text('Rename'),
              onTap: () {
                Navigator.pop(context);
                onRename();
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete',
                  style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                onDelete();
              },
            ),
            const SizedBox(height: 8),
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

// ─── List item ────────────────────────────────────────────────────────────────

class _DocListItem extends StatelessWidget {
  final Map<String, dynamic> doc;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onRename;

  const _DocListItem({
    required this.doc,
    required this.onTap,
    required this.onDelete,
    required this.onRename,
  });

  String get _name => doc['name'] as String? ?? 'Unknown';
  int get _size => (doc['size'] as int?) ?? 0;
  String? get _thumbPath => doc['thumbnail_path'] as String?;
  String get _ext => _name.split('.').last.toUpperCase();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isPdf = _ext == 'PDF';

    return Dismissible(
      key: Key(doc['path'] as String? ?? _name),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        color: Colors.red,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Delete document?'),
            content: Text('Remove "$_name" from your library?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel')),
              TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Delete',
                      style: TextStyle(color: Colors.red))),
            ],
          ),
        );
      },
      onDismissed: (_) => onDelete(),
      child: ListTile(
        onTap: onTap,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            width: 44,
            height: 56,
            child: _thumbPath != null
                ? Image.file(
                    File(_thumbPath!),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: cs.surfaceContainerHighest,
                      child: Icon(
                        isPdf ? Icons.picture_as_pdf : Icons.image,
                        size: 24,
                        color: isPdf ? cs.error : Colors.green,
                      ),
                    ),
                  )
                : Container(
                    color: cs.surfaceContainerHighest,
                    child: Icon(
                      isPdf ? Icons.picture_as_pdf : Icons.image,
                      size: 24,
                      color: isPdf ? cs.error : Colors.green,
                    ),
                  ),
          ),
        ),
        title: Text(
          _name,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(_ext,
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurfaceVariant)),
            ),
            const SizedBox(width: 6),
            Text(_fmtSize(_size),
                style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, size: 18, color: Colors.grey[500]),
          onSelected: (v) {
            switch (v) {
              case 'open':
                onTap();
                break;
              case 'share':
                Share.shareXFiles(
                  [XFile(doc['path'] as String)],
                  subject: _name,
                );
                break;
              case 'rename':
                onRename();
                break;
              case 'delete':
                onDelete();
                break;
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
                value: 'open',
                child: ListTile(
                    dense: true,
                    leading: Icon(Icons.open_in_new, size: 18),
                    title: Text('Open'))),
            const PopupMenuItem(
                value: 'share',
                child: ListTile(
                    dense: true,
                    leading: Icon(Icons.share_outlined, size: 18),
                    title: Text('Share'))),
            const PopupMenuItem(
                value: 'rename',
                child: ListTile(
                    dense: true,
                    leading:
                        Icon(Icons.drive_file_rename_outline, size: 18),
                    title: Text('Rename'))),
            const PopupMenuItem(
                value: 'delete',
                child: ListTile(
                    dense: true,
                    leading: Icon(Icons.delete_outline,
                        size: 18, color: Colors.red),
                    title: Text('Delete',
                        style: TextStyle(color: Colors.red)))),
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

// ─── Simple image viewer ──────────────────────────────────────────────────────

class _ImageViewerScreen extends StatelessWidget {
  final String path;
  const _ImageViewerScreen({required this.path});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          path.split('/').last,
          style: const TextStyle(fontSize: 14),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share',
            onPressed: () => Share.shareXFiles(
              [XFile(path)],
              subject: path.split('/').last,
            ),
          ),
        ],
      ),
      body: InteractiveViewer(
        minScale: 0.5,
        maxScale: 6.0,
        child: Center(child: Image.file(File(path))),
      ),
    );
  }
}
