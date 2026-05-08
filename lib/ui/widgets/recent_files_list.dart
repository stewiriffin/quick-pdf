import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:quick_pdf/services/document_database.dart';

class RecentFilesList extends StatefulWidget {
  final Function(String) onDocumentTap;
  final Function(String) onDocumentDelete;

  const RecentFilesList({
    super.key,
    required this.onDocumentTap,
    required this.onDocumentDelete,
  });

  @override
  State<RecentFilesList> createState() => _RecentFilesListState();
}

class _RecentFilesListState extends State<RecentFilesList> {
  final _db = DocumentDatabase();
  List<Map<String, dynamic>> _documents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _db.addListener(_reload);
    _loadDocuments();
  }

  @override
  void dispose() {
    _db.removeListener(_reload);
    super.dispose();
  }

  void _reload() => _loadDocuments();

  Future<void> _loadDocuments() async {
    final docs = await _db.getRecentDocuments();
    if (mounted) {
      setState(() {
        _documents = docs;
        _isLoading = false;
      });
    }
  }

  Future<void> _shareDocument(String path, String name) async {
    try {
      await Share.shareXFiles([XFile(path)], subject: name);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share: $e')),
        );
      }
    }
  }

  Future<void> _renameDocument(String path, String currentName) async {
    final ext = currentName.contains('.')
        ? currentName.substring(currentName.lastIndexOf('.'))
        : '';
    final nameWithoutExt = ext.isNotEmpty
        ? currentName.substring(0, currentName.lastIndexOf('.'))
        : currentName;

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
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Rename'),
          ),
        ],
      ),
    );

    if (newBaseName == null || newBaseName.isEmpty || newBaseName == nameWithoutExt) {
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
          SnackBar(content: Text('Rename failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_documents.isEmpty) {
      return const Center(
        child: Text(
          'No recent documents\nTap "+" to add files',
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.builder(
      itemCount: _documents.length,
      itemBuilder: (context, index) =>
          _buildDocumentItem(context, _documents[index]),
    );
  }

  Widget _buildDocumentItem(BuildContext context, Map<String, dynamic> doc) {
    final String path = doc['path'] ?? '';
    final String name = doc['name'] ?? 'Unknown';
    final int size = doc['size'] ?? 0;
    final String? thumbnailPath = doc['thumbnail_path'];

    return Dismissible(
      key: Key(path),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => widget.onDocumentDelete(path),
      child: ListTile(
        leading: SizedBox(
          width: 40,
          height: 40,
          child: thumbnailPath != null && File(thumbnailPath).existsSync()
              ? Image.file(File(thumbnailPath), fit: BoxFit.cover)
              : const Icon(Icons.picture_as_pdf, color: Colors.red, size: 40),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${(size / 1024).toStringAsFixed(1)} KB',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        onTap: () => widget.onDocumentTap(path),
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'share') {
              await _shareDocument(path, name);
            } else if (value == 'rename') {
              await _renameDocument(path, name);
            } else if (value == 'delete') {
              widget.onDocumentDelete(path);
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: 'share',
              child: ListTile(leading: Icon(Icons.share), title: Text('Share')),
            ),
            PopupMenuItem(
              value: 'rename',
              child: ListTile(leading: Icon(Icons.edit), title: Text('Rename')),
            ),
            PopupMenuItem(
              value: 'delete',
              child: ListTile(leading: Icon(Icons.delete), title: Text('Delete')),
            ),
          ],
        ),
      ),
    );
  }
}
