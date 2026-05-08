import 'dart:io';
import 'package:flutter/material.dart';
import 'package:quick_pdf/core/pdf_manager.dart';
import 'package:quick_pdf/services/document_database.dart';

class PdfSecurityScreen extends StatefulWidget {
  final File pdfFile;

  const PdfSecurityScreen({super.key, required this.pdfFile});

  @override
  State<PdfSecurityScreen> createState() => _PdfSecurityScreenState();
}

class _PdfSecurityScreenState extends State<PdfSecurityScreen> {
  bool _isProcessing = false;
  String? _author;
  String? _title;

  bool get _hasChanges =>
      (_author?.isNotEmpty ?? false) || (_title?.isNotEmpty ?? false);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Security'),
        centerTitle: true,
      ),
      body: _isProcessing
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'File: ${widget.pdfFile.path.split('/').last}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.orange, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Password encryption requires a native library and is not available in this version. Metadata editing is fully supported.',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Metadata',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Author',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      onChanged: (value) => setState(() => _author = value),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.title),
                      ),
                      onChanged: (value) => setState(() => _title = value),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: _hasChanges ? _applyMetadata : null,
                      icon: const Icon(Icons.save),
                      label: const Text('Save Metadata'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Future<void> _applyMetadata() async {
    setState(() => _isProcessing = true);

    try {
      final updatedFile = await PDFManager.updatePDFMetadata(
        widget.pdfFile,
        author: _author?.isNotEmpty == true ? _author : null,
        title: _title?.isNotEmpty == true ? _title : null,
      );

      await DocumentDatabase().insertDocument(updatedFile.path);

      if (mounted) {
        PDFManager.hapticFeedbackSuccess();
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Metadata saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        PDFManager.hapticFeedbackError();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }
}
