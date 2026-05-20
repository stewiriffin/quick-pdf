import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:quick_pdf/core/pdf_manager.dart';
import 'package:quick_pdf/services/document_database.dart';
import 'package:quick_pdf/services/file_picker_service.dart';
import 'package:quick_pdf/services/ocr_service.dart';
import 'package:quick_pdf/ui/compress_screen.dart';
import 'package:quick_pdf/ui/convert_screen.dart';
import 'package:quick_pdf/ui/merge_screen.dart';
import 'package:quick_pdf/ui/format_converter_screen.dart';
import 'package:quick_pdf/ui/ocr_text_screen.dart';
import 'package:quick_pdf/ui/page_manager_screen.dart';
import 'package:quick_pdf/ui/password_protect_screen.dart';
import 'package:quick_pdf/ui/pdf_security_screen.dart';
import 'package:quick_pdf/ui/watermark_screen.dart';
import 'package:quick_pdf/ui/pdf_viewer_screen.dart';
import 'package:quick_pdf/ui/scanner_screen.dart';
import 'package:quick_pdf/ui/split_screen.dart';
import 'package:quick_pdf/ui/widgets/search_delegate.dart';
import 'package:quick_pdf/services/ad_service.dart';

String _fmtSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
}

String _relativeDate(String? isoDate) {
  if (isoDate == null) return '';
  final dt = DateTime.tryParse(isoDate);
  if (dt == null) return '';
  final diff = DateTime.now().difference(dt);
  if (diff.inDays >= 365) return '${(diff.inDays / 365).floor()}y ago';
  if (diff.inDays >= 30) return '${(diff.inDays / 30).floor()}mo ago';
  if (diff.inDays >= 1) return '${diff.inDays}d ago';
  if (diff.inHours >= 1) return '${diff.inHours}h ago';
  if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
  return 'Just now';
}

enum _SortMode { recent, name, size, added }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  bool _isProcessing = false;
  final OcrService _ocrService = OcrService();
  final _db = DocumentDatabase();
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    _ocrService.dispose();
    super.dispose();
  }

  // ─── Quick actions ─────────────────────────────────────────────────────────

  Future<void> _quickScan() => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ScannerScreen()),
      );

  Future<void> _quickConvert() async {
    final r = await FilePickerService.pickMultipleFiles(
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'bmp']);
    if (r == null || r.isEmpty || !mounted) return;
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => ConvertScreen(initialImages: r)));
  }

  Future<void> _quickMerge() async {
    final r = await FilePickerService.pickMultipleFiles(allowedExtensions: ['pdf']);
    if (r == null || r.isEmpty || !mounted) return;
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => MergeScreen(initialFiles: r)));
  }

  Future<void> _quickSplit() async {
    final r = await FilePickerService.pickMultipleFiles(allowedExtensions: ['pdf']);
    if (r == null || r.isEmpty || !mounted) return;
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => SplitScreen(file: r.first)));
  }

  Future<void> _quickCompress() async {
    final r = await FilePickerService.pickMultipleFiles(allowedExtensions: ['pdf']);
    if (r == null || r.isEmpty || !mounted) return;
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => CompressScreen(file: r.first)));
  }

  Future<void> _quickExtract() async {
    final r = await FilePickerService.pickMultipleFiles(
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png']);
    if (r == null || r.isEmpty || !mounted) return;
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => OcrTextScreen(file: r.first)));
  }

  Future<void> _quickFormat() => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const FormatConverterScreen()),
      );

  Future<void> _quickMetadata() async {
    final r = await FilePickerService.pickMultipleFiles(allowedExtensions: ['pdf']);
    if (r == null || r.isEmpty || !mounted) return;
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => EditMetadataScreen(pdfFile: r.first)));
  }

  Future<void> _quickProtect() => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PasswordProtectScreen()),
      );

  Future<void> _quickWatermark() => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const WatermarkScreen()),
      );

  Future<void> _quickPageManager() async {
    final r =
        await FilePickerService.pickMultipleFiles(allowedExtensions: ['pdf']);
    if (r == null || r.isEmpty || !mounted) return;
    await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PageManagerScreen(pdfFile: r.first)));
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
        MaterialPageRoute(
          builder: (_) => PDFViewerScreen(
            pdfPath: path,
            heroTag: 'doc_thumb_$path',
          ),
        ),
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
      final thumbPath = await PDFManager.generateThumbnail(file.path);
      await _db.insertDocument(file.path,
          textContent: textContent, thumbnailPath: thumbPath);
    }

    if (!mounted) return;
    setState(() => _isProcessing = false);

    AdService().recordToolCompletion();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          'Added ${result.length} file${result.length == 1 ? '' : 's'}'),
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ─── FAB quick-add bottom sheet ────────────────────────────────────────────

  void _showQuickAddSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text('Add document',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.camera_alt, color: Colors.blue, size: 18),
              ),
              title: const Text('Scan Document'),
              subtitle: const Text('Use your camera to scan pages'),
              onTap: () { Navigator.pop(context); _quickScan(); },
            ),
            ListTile(
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.folder_open_outlined,
                    color: Colors.green, size: 18),
              ),
              title: const Text('Import from Files'),
              subtitle: const Text('Pick a PDF or image from storage'),
              onTap: () { Navigator.pop(context); _addFiles(); },
            ),
            ListTile(
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.image, color: Colors.orange, size: 18),
              ),
              title: const Text('Images to PDF'),
              subtitle: const Text('Combine photos into a single PDF'),
              onTap: () { Navigator.pop(context); _quickConvert(); },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QuickPDF'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(icon: Icon(Icons.access_time_outlined), text: 'Recent'),
            Tab(icon: Icon(Icons.build_outlined), text: 'Tools'),
          ],
        ),
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
          TabBarView(
            controller: _tabs,
            children: [
              // ── Tab 0: Recent ──
              _DocumentGrid(
                onDocumentTap: _onDocumentTap,
                onDocumentDelete: (path) async {
                  await _db.deleteDocument(path);
                  try { await File(path).delete(); } catch (_) {}
                },
              ),
              // ── Tab 1: Tools ──
              _HomeToolsTab(
                onAddFiles: _isProcessing ? null : _addFiles,
                onScan: _quickScan,
                onConvert: _quickConvert,
                onMerge: _quickMerge,
                onSplit: _quickSplit,
                onCompress: _quickCompress,
                onExtract: _quickExtract,
                onFormat: _quickFormat,
                onMetadata: _quickMetadata,
                onProtect: _quickProtect,
                onWatermark: _quickWatermark,
                onPageManager: _quickPageManager,
              ),
            ],
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
      floatingActionButton: _tabs.index == 0
          ? FloatingActionButton(
              onPressed: _showQuickAddSheet,
              tooltip: 'Add document',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

// ─── Home Tools tab ───────────────────────────────────────────────────────────

class _HomeToolsTab extends StatefulWidget {
  final VoidCallback? onAddFiles;
  final VoidCallback onScan;
  final VoidCallback onConvert;
  final VoidCallback onMerge;
  final VoidCallback onSplit;
  final VoidCallback onCompress;
  final VoidCallback onExtract;
  final VoidCallback onFormat;
  final VoidCallback onMetadata;
  final VoidCallback onProtect;
  final VoidCallback onWatermark;
  final VoidCallback onPageManager;

  const _HomeToolsTab({
    required this.onAddFiles,
    required this.onScan,
    required this.onConvert,
    required this.onMerge,
    required this.onSplit,
    required this.onCompress,
    required this.onExtract,
    required this.onFormat,
    required this.onMetadata,
    required this.onProtect,
    required this.onWatermark,
    required this.onPageManager,
  });

  @override
  State<_HomeToolsTab> createState() => _HomeToolsTabState();
}

class _HomeToolsTabState extends State<_HomeToolsTab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  final List<Animation<double>> _anims = [];

  static const _itemCount = 10; // tiles + headers
  static const _delay = Duration(milliseconds: 40);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: Duration(milliseconds: 300 + _itemCount * _delay.inMilliseconds),
      vsync: this,
    );
    for (int i = 0; i < _itemCount; i++) {
      final start = (i * _delay.inMilliseconds) /
          _ctrl.duration!.inMilliseconds;
      _anims.add(CurvedAnimation(
        parent: _ctrl,
        curve: Interval(start, (start + 0.3).clamp(0.0, 1.0),
            curve: Curves.easeOut),
      ));
    }
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _fade(int index, Widget child) => FadeTransition(
        opacity: index < _anims.length ? _anims[index] : const AlwaysStoppedAnimation(1.0),
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        _fade(0, _groupHeader(context, 'Create')),
        _fade(1, _toolTile(context, Icons.camera_alt, Colors.blue.shade600,
            'Scan Document', 'Use your camera to scan pages into a PDF', widget.onScan)),
        _fade(1, _toolTile(context, Icons.image, Colors.green.shade600,
            'Images to PDF', 'Combine JPG, PNG, WEBP photos into one PDF', widget.onConvert)),
        _fade(1, _toolTile(context, Icons.folder_open_outlined, cs.primary,
            'Import Files', 'Add existing PDFs or images to your library',
            widget.onAddFiles)),
        const Divider(indent: 16, endIndent: 16, height: 20),
        _fade(2, _groupHeader(context, 'Edit')),
        _fade(3, _toolTile(context, Icons.merge_type, Colors.orange.shade700,
            'Merge PDFs', 'Combine multiple PDFs, choose pages per document', widget.onMerge)),
        _fade(4, _toolTile(context, Icons.call_split, Colors.deepPurple.shade500,
            'Split PDF', 'Extract pages or split into individual files', widget.onSplit)),
        _fade(5, _toolTile(context, Icons.compress, Colors.red.shade600,
            'Compress PDF', 'Reduce file size with adjustable quality', widget.onCompress)),
        const Divider(indent: 16, endIndent: 16, height: 20),
        _fade(6, _groupHeader(context, 'Convert')),
        _fade(7, _toolTile(context, Icons.swap_horiz, Colors.teal.shade600,
            'Format Converter', 'PDF → JPEG / PNG  ·  Images → PDF', widget.onFormat)),
        _fade(7, _toolTile(context, Icons.text_snippet_outlined, Colors.indigo.shade600,
            'Extract Text (OCR)', 'Read text from PDFs and images — fully offline', widget.onExtract)),
        const Divider(indent: 16, endIndent: 16, height: 20),
        const Divider(indent: 16, endIndent: 16, height: 20),
        _fade(7, _groupHeader(context, 'Organise')),
        _fade(8, _toolTile(context, Icons.view_module, Colors.pink.shade600,
            'Page Manager', 'Reorder, delete, rotate pages', widget.onPageManager)),
        _fade(8, _toolTile(context, Icons.water_drop_outlined, Colors.cyan.shade700,
            'Watermark', 'Add a text watermark to all pages', widget.onWatermark)),
        const Divider(indent: 16, endIndent: 16, height: 20),
        _fade(9, _groupHeader(context, 'Security')),
        _fade(9, _toolTile(context, Icons.lock_outline, Colors.blueGrey.shade600,
            'Password Protect', 'Encrypt or unlock a PDF', widget.onProtect)),
        _fade(9, _toolTile(context, Icons.edit_document, Colors.brown.shade500,
            'Edit Metadata', 'Set title, author, and subject of a PDF', widget.onMetadata)),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _groupHeader(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );

  Widget _toolTile(BuildContext context, IconData icon, Color color,
      String title, String subtitle, VoidCallback? onTap) {
    final enabled = onTap != null;
    final tileColor = enabled ? color : Colors.grey;
    return ListTile(
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: tileColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: tileColor, size: 20),
      ),
      title: Text(title,
          style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: enabled ? null : Colors.grey)),
      subtitle: Text(subtitle,
          style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      trailing:
          Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
      onTap: onTap,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}

// ─── Document grid / list ─────────────────────────────────────────────────────

class _DocumentGrid extends StatefulWidget {
  final Future<void> Function(String) onDocumentTap;
  final Future<void> Function(String) onDocumentDelete;

  const _DocumentGrid({
    required this.onDocumentTap,
    required this.onDocumentDelete,
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
  String _search = '';
  String _filterType = 'all'; // 'all' | 'pdf' | 'image'
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _db.addListener(_reload);
    _load();
  }

  @override
  void dispose() {
    _db.removeListener(_reload);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _reload() => _load();

  Future<void> _load() async {
    final docs = await _db.getAllDocuments();
    if (mounted) {
      setState(() {
        _docs = docs;
        _loading = false;
        _applySort();
      });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    var list = _docs.where((d) {
      final name = (d['name'] as String? ?? '').toLowerCase();
      final ext = name.split('.').last;
      // Search filter
      if (_search.isNotEmpty &&
          !name.contains(_search.toLowerCase())) {
        return false;
      }
      // Type filter
      if (_filterType == 'pdf' && ext != 'pdf') { return false; }
      if (_filterType == 'image' &&
          !['jpg', 'jpeg', 'png', 'bmp', 'webp'].contains(ext)) { return false; }
      return true;
    }).toList();

    switch (_sortMode) {
      case _SortMode.recent:
        // DB already returns is_favourite DESC, lastOpened DESC
        break;
      case _SortMode.name:
        list.sort((a, b) =>
            (a['name'] as String? ?? '')
                .toLowerCase()
                .compareTo((b['name'] as String? ?? '').toLowerCase()));
        break;
      case _SortMode.size:
        list.sort((a, b) =>
            (b['size'] as int? ?? 0).compareTo(a['size'] as int? ?? 0));
        break;
      case _SortMode.added:
        list.sort((a, b) => (b['dateAdded'] as String? ?? '')
            .compareTo(a['dateAdded'] as String? ?? ''));
        break;
    }
    return list;
  }

  void _applySort() {
    // Now handled by _filtered getter — just trigger rebuild
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

    final filtered = _filtered;

    return CustomScrollView(
      slivers: [
        // ── Search bar ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'Search documents…',
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _search = '');
                        },
                      )
                    : null,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
        ),

        // ── Filter chips + sort/view-toggle ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
            child: Row(
              children: [
                _FilterChip(
                    label: 'All',
                    selected: _filterType == 'all',
                    onTap: () => setState(() => _filterType = 'all')),
                const SizedBox(width: 6),
                _FilterChip(
                    label: 'PDF',
                    selected: _filterType == 'pdf',
                    onTap: () => setState(() => _filterType = 'pdf')),
                const SizedBox(width: 6),
                _FilterChip(
                    label: 'Image',
                    selected: _filterType == 'image',
                    onTap: () => setState(() => _filterType = 'image')),
                const Spacer(),
                PopupMenuButton<_SortMode>(
                  tooltip: 'Sort',
                  icon: Icon(Icons.sort, size: 20, color: cs.onSurfaceVariant),
                  initialValue: _sortMode,
                  onSelected: (mode) =>
                      setState(() { _sortMode = mode; _applySort(); }),
                  itemBuilder: (_) => [
                    _sortItem(_SortMode.recent, Icons.access_time,
                        'Recently opened'),
                    _sortItem(_SortMode.added, Icons.calendar_today,
                        'Date added'),
                    _sortItem(_SortMode.name, Icons.sort_by_alpha, 'Name'),
                    _sortItem(_SortMode.size, Icons.data_usage, 'File size'),
                  ],
                ),
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

        if (filtered.isEmpty)
          SliverFillRemaining(child: _buildEmpty(context))
        else if (_isGridView)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (_, i) => _DocCard(
                  doc: filtered[i],
                  onTap: () =>
                      widget.onDocumentTap(filtered[i]['path'] ?? ''),
                  onDelete: () =>
                      widget.onDocumentDelete(filtered[i]['path'] ?? ''),
                  onRename: () => _renameDoc(
                      filtered[i]['path'] ?? '', filtered[i]['name'] ?? ''),
                  onToggleFavourite: () =>
                      _db.toggleFavourite(filtered[i]['path'] ?? ''),
                ),
                childCount: filtered.length,
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
                  doc: filtered[i],
                  onTap: () =>
                      widget.onDocumentTap(filtered[i]['path'] ?? ''),
                  onDelete: () =>
                      widget.onDocumentDelete(filtered[i]['path'] ?? ''),
                  onRename: () => _renameDoc(
                      filtered[i]['path'] ?? '', filtered[i]['name'] ?? ''),
                ),
                childCount: filtered.length,
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
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(Icons.picture_as_pdf_outlined,
                  size: 48, color: cs.primary),
            ),
            const SizedBox(height: 20),
            Text('No documents yet',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('Tap the + button to scan, import,\nor convert images to PDF',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                textAlign: TextAlign.center),
          ],
        ),
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
  final VoidCallback onToggleFavourite;

  const _DocCard({
    required this.doc,
    required this.onTap,
    required this.onDelete,
    required this.onRename,
    required this.onToggleFavourite,
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
                  Hero(
                    tag: 'doc_thumb_${doc['path']}',
                    child: Container(
                      color: cs.surfaceContainerHighest,
                      child: _buildThumbImage(cs),
                    ),
                  ),
                  // Favourite star
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: onToggleFavourite,
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            (doc['is_favourite'] as int? ?? 0) == 1
                                ? Icons.star
                                : Icons.star_border,
                            color: (doc['is_favourite'] as int? ?? 0) == 1
                                ? Colors.amber
                                : Colors.white.withValues(alpha: 0.8),
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // File type badge
                  Positioned(
                    top: 6,
                    left: 6,
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
                  Row(
                    children: [
                      Text(
                        _fmtSize(_size),
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '·',
                        style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _relativeDate(doc['lastOpened'] as String?),
                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
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
              leading: const Icon(Icons.info_outline),
              title: const Text('Details'),
              onTap: () {
                Navigator.pop(context);
                _showFileDetails(context);
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
              onTap: () async {
                Navigator.pop(context);
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Delete file?'),
                    content: Text(
                        '"$_name" will be permanently deleted from your device.'),
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
                if (confirmed == true) onDelete();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showFileDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _FileDetailsSheet(doc: doc),
    );
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
            title: const Text('Delete file?'),
            content: Text(
                '"$_name" will be permanently deleted from your device.'),
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
            const SizedBox(width: 6),
            Text('·', style: TextStyle(fontSize: 11, color: Colors.grey[400])),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                _relativeDate(doc['lastOpened'] as String?),
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                overflow: TextOverflow.ellipsis,
              ),
            ),
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

}

// ─── Filter chip ─────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? cs.primaryContainer : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight:
                selected ? FontWeight.w700 : FontWeight.normal,
            color: selected
                ? cs.onPrimaryContainer
                : cs.onSurfaceVariant,
          ),
        ),
      ),
    );
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

// ─── File details bottom sheet ────────────────────────────────────────────────

class _FileDetailsSheet extends StatefulWidget {
  final Map<String, dynamic> doc;
  const _FileDetailsSheet({required this.doc});

  @override
  State<_FileDetailsSheet> createState() => _FileDetailsSheetState();
}

class _FileDetailsSheetState extends State<_FileDetailsSheet> {
  int _pageCount = 0;
  bool _loadingPages = true;

  String get _path => widget.doc['path'] as String? ?? '';
  String get _name => widget.doc['name'] as String? ?? 'Unknown';
  String get _ext => _name.split('.').last.toLowerCase();

  @override
  void initState() {
    super.initState();
    if (_ext == 'pdf') {
      PDFManager.getPageCount(_path).then((count) {
        if (mounted) setState(() { _pageCount = count; _loadingPages = false; });
      });
    } else {
      _loadingPages = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final size = widget.doc['size'] as int? ?? 0;
    final thumbPath = widget.doc['thumbnail_path'] as String?;
    final lastOpened = widget.doc['lastOpened'] as String?;
    final dateAdded = widget.doc['dateAdded'] as String?;
    final title = widget.doc['title'] as String?;
    final author = widget.doc['author'] as String?;
    final subject = widget.doc['subject'] as String?;

    File? file;
    FileStat? stat;
    try {
      file = File(_path);
      stat = file.statSync();
    } catch (_) {}

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scroll) => Column(
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
          Expanded(
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                // Thumbnail + name header
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 56,
                        height: 72,
                        child: thumbPath != null
                            ? Image.file(File(thumbPath), fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                    color: cs.surfaceContainerHighest,
                                    child: Icon(Icons.picture_as_pdf,
                                        color: cs.error)))
                            : Container(
                                color: cs.surfaceContainerHighest,
                                child: Icon(
                                  _ext == 'pdf'
                                      ? Icons.picture_as_pdf
                                      : Icons.image,
                                  color: _ext == 'pdf' ? cs.error : Colors.green,
                                )),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 14),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Text(_fmtSize(size),
                              style: TextStyle(
                                  color: cs.onSurfaceVariant, fontSize: 12)),
                          if (!_loadingPages && _pageCount > 0)
                            Text('$_pageCount pages',
                                style: TextStyle(
                                    color: cs.onSurfaceVariant, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                // File path
                _DetailRow(
                  label: 'Path',
                  value: _path,
                  copyable: true,
                  cs: cs,
                ),
                // Dates
                if (dateAdded != null)
                  _DetailRow(
                    label: 'Added',
                    value: _formatDate(dateAdded),
                    cs: cs,
                  ),
                if (lastOpened != null)
                  _DetailRow(
                    label: 'Last opened',
                    value: _formatDate(lastOpened),
                    cs: cs,
                  ),
                if (stat != null)
                  _DetailRow(
                    label: 'Modified',
                    value: _formatDate(stat.modified.toIso8601String()),
                    cs: cs,
                  ),
                // PDF metadata
                if (title != null && title.isNotEmpty) ...[
                  const Divider(),
                  _DetailRow(label: 'Title', value: title, cs: cs),
                ],
                if (author != null && author.isNotEmpty)
                  _DetailRow(label: 'Author', value: author, cs: cs),
                if (subject != null && subject.isNotEmpty)
                  _DetailRow(label: 'Subject', value: subject, cs: cs),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    return '${dt.day}/${dt.month}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool copyable;
  final ColorScheme cs;

  const _DetailRow({
    required this.label,
    required this.value,
    required this.cs,
    this.copyable = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 12),
                softWrap: true),
          ),
          if (copyable)
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Copied to clipboard'),
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 1),
                ));
              },
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child:
                    Icon(Icons.copy, size: 15, color: cs.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }
}
