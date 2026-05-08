import 'dart:io';
import 'package:flutter/material.dart';
import 'package:quick_pdf/core/pdf_manager.dart';
import 'package:quick_pdf/services/document_database.dart';
import 'package:quick_pdf/services/file_picker_service.dart';
import 'package:quick_pdf/ui/pdf_viewer_screen.dart';

class ConvertScreen extends StatefulWidget {
  final List<File> initialImages;
  const ConvertScreen({super.key, required this.initialImages});

  @override
  State<ConvertScreen> createState() => _ConvertScreenState();
}

class _ConvertScreenState extends State<ConvertScreen> {
  late List<File> _images;

  // Options
  String _pageSize = 'A4'; // 'A4' | 'Letter' | 'A3' | 'fit'
  bool _landscape = false;
  int _quality = 85;       // 90 high / 72 medium / 50 low
  double _margin = 20.0;   // PDF points: 0 / 20 / 40

  bool _isConverting = false;

  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _images = List.from(widget.initialImages);
    final ts = DateTime.now();
    _nameController.text =
        'Document_${ts.year}${_d(ts.month)}${_d(ts.day)}_${_d(ts.hour)}${_d(ts.minute)}';
  }

  String _d(int n) => n.toString().padLeft(2, '0');

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // ─── Image management ────────────────────────────────────────────────────

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = _images.removeAt(oldIndex);
      _images.insert(newIndex, item);
    });
  }

  Future<void> _addMore() async {
    final picked = await FilePickerService.pickMultipleFiles(
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'bmp'],
    );
    if (picked != null && picked.isNotEmpty) {
      setState(() => _images.addAll(picked));
    }
  }

  void _removeImage(int index) {
    setState(() => _images.removeAt(index));
  }

  // ─── Conversion ──────────────────────────────────────────────────────────

  Future<void> _convert() async {
    if (_images.isEmpty) return;
    setState(() => _isConverting = true);

    try {
      final File pdf = await PDFManager.convertImagesToPDF(
        _images,
        pageSize: _pageSize,
        landscape: _landscape && _pageSize != 'fit',
        quality: _quality,
        margin: _margin,
        outputName: _nameController.text.trim(),
      );

      await DocumentDatabase().insertDocument(pdf.path);
      PDFManager.hapticFeedbackSuccess();

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => PDFViewerScreen(pdfPath: pdf.path),
          ),
        );
      }
    } catch (e) {
      PDFManager.hapticFeedbackError();
      if (mounted) {
        setState(() => _isConverting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Conversion failed: $e')),
        );
      }
    }
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Convert to PDF'),
        actions: [
          if (!_isConverting)
            TextButton(
              onPressed: _images.isNotEmpty ? _convert : null,
              child: Text(
                'Convert',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _images.isNotEmpty
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey,
                ),
              ),
            ),
        ],
      ),
      body: _isConverting ? _buildProgress() : _buildContent(),
    );
  }

  Widget _buildProgress() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          Text(
            'Creating PDF from ${_images.length} image${_images.length == 1 ? '' : 's'}…',
            style: const TextStyle(fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        Expanded(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildNameField()),
              SliverToBoxAdapter(child: _buildOptionsCard()),
              SliverToBoxAdapter(child: _buildImageListHeader()),
              SliverReorderableList(
                itemCount: _images.length,
                onReorder: _onReorder,
                itemBuilder: (_, i) => _buildImageTile(i),
              ),
              SliverToBoxAdapter(child: _buildAddMoreButton()),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
            ],
          ),
        ),
        _buildConvertBar(),
      ],
    );
  }

  // ─── Options ─────────────────────────────────────────────────────────────

  Widget _buildNameField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: TextField(
        controller: _nameController,
        decoration: const InputDecoration(
          labelText: 'PDF name',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.picture_as_pdf),
          suffixText: '.pdf',
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildOptionsCard() {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          children: [
            _optionRow('Page size', _pageSizeSelector()),
            if (_pageSize != 'fit') ...[
              const Divider(height: 16),
              _optionRow('Orientation', _orientationSelector()),
            ],
            const Divider(height: 16),
            _optionRow('Quality', _qualitySelector()),
            const Divider(height: 16),
            _optionRow('Margins', _marginsSelector()),
          ],
        ),
      ),
    );
  }

  Widget _optionRow(String label, Widget control) {
    return Row(
      children: [
        SizedBox(
          width: 88,
          child: Text(
            label,
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
        ),
        Expanded(child: control),
      ],
    );
  }

  Widget _pageSizeSelector() {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'A4', label: Text('A4')),
        ButtonSegment(value: 'Letter', label: Text('Letter')),
        ButtonSegment(value: 'A3', label: Text('A3')),
        ButtonSegment(value: 'fit', label: Text('Fit image')),
      ],
      selected: {_pageSize},
      onSelectionChanged: (v) => setState(() => _pageSize = v.first),
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Widget _orientationSelector() {
    return SegmentedButton<bool>(
      segments: const [
        ButtonSegment(
          value: false,
          icon: Icon(Icons.stay_current_portrait, size: 16),
          label: Text('Portrait'),
        ),
        ButtonSegment(
          value: true,
          icon: Icon(Icons.stay_current_landscape, size: 16),
          label: Text('Landscape'),
        ),
      ],
      selected: {_landscape},
      onSelectionChanged: (v) => setState(() => _landscape = v.first),
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Widget _qualitySelector() {
    return SegmentedButton<int>(
      segments: const [
        ButtonSegment(value: 90, label: Text('High')),
        ButtonSegment(value: 72, label: Text('Medium')),
        ButtonSegment(value: 50, label: Text('Low')),
      ],
      selected: {_quality},
      onSelectionChanged: (v) => setState(() => _quality = v.first),
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Widget _marginsSelector() {
    return SegmentedButton<double>(
      segments: const [
        ButtonSegment(value: 0.0, label: Text('None')),
        ButtonSegment(value: 20.0, label: Text('Normal')),
        ButtonSegment(value: 40.0, label: Text('Wide')),
      ],
      selected: {_margin},
      onSelectionChanged: (v) => setState(() => _margin = v.first),
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  // ─── Image list ──────────────────────────────────────────────────────────

  Widget _buildImageListHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
      child: Row(
        children: [
          Text(
            'Images (${_images.length})',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: _addMore,
            icon: const Icon(Icons.add_photo_alternate, size: 18),
            label: const Text('Add more'),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageTile(int index) {
    final file = _images[index];
    // Use both path and index in key to handle duplicate files gracefully
    return Material(
      key: ValueKey('${file.path}_$index'),
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        child: Row(
          children: [
            // Page number
            Container(
              width: 28,
              height: 36,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
              alignment: Alignment.center,
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.file(
                file,
                width: 52,
                height: 68,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 52,
                  height: 68,
                  color: Colors.grey[200],
                  child: const Icon(Icons.broken_image, color: Colors.grey),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // File info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.path.split('/').last,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  FutureBuilder<FileStat>(
                    future: file.stat(),
                    builder: (_, snap) {
                      if (!snap.hasData) return const SizedBox.shrink();
                      final kb = snap.data!.size / 1024;
                      return Text(
                        kb >= 1024
                            ? '${(kb / 1024).toStringAsFixed(1)} MB'
                            : '${kb.toStringAsFixed(0)} KB',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            // Remove button
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              color: Colors.grey[500],
              visualDensity: VisualDensity.compact,
              tooltip: 'Remove',
              onPressed: () => _removeImage(index),
            ),
            // Drag handle
            ReorderableDragStartListener(
              index: index,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.drag_handle, color: Colors.grey[400]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddMoreButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: OutlinedButton.icon(
        onPressed: _addMore,
        icon: const Icon(Icons.add_photo_alternate),
        label: const Text('Add more images'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(44),
        ),
      ),
    );
  }

  // ─── Bottom bar ──────────────────────────────────────────────────────────

  Widget _buildConvertBar() {
    final String sizeLabel = _pageSizeLabel();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_images.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '${_images.length} page${_images.length == 1 ? '' : 's'} · $sizeLabel · ${_qualityLabel()}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _images.isNotEmpty ? _convert : null,
                icon: const Icon(Icons.picture_as_pdf),
                label: Text(
                  _images.isEmpty
                      ? 'Add images to convert'
                      : 'Convert ${_images.length} image${_images.length == 1 ? '' : 's'} to PDF',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _pageSizeLabel() {
    if (_pageSize == 'fit') return 'Fit to image';
    if (_landscape) return '$_pageSize Landscape';
    return '$_pageSize Portrait';
  }

  String _qualityLabel() {
    if (_quality >= 85) return 'High quality';
    if (_quality >= 65) return 'Medium quality';
    return 'Low quality';
  }
}
