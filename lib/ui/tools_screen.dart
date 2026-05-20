import 'package:flutter/material.dart';
import 'package:quick_pdf/services/file_picker_service.dart';
import 'package:quick_pdf/ui/compress_screen.dart';
import 'package:quick_pdf/ui/convert_screen.dart';
import 'package:quick_pdf/ui/format_converter_screen.dart';
import 'package:quick_pdf/ui/merge_screen.dart';
import 'package:quick_pdf/ui/ocr_text_screen.dart';
import 'package:quick_pdf/ui/annotate_pdf_screen.dart';
import 'package:quick_pdf/ui/batch_screen.dart';
import 'package:quick_pdf/ui/export_text_screen.dart';
import 'package:quick_pdf/ui/page_manager_screen.dart';
import 'package:quick_pdf/ui/password_protect_screen.dart';
import 'package:quick_pdf/ui/pdf_security_screen.dart';
import 'package:quick_pdf/ui/sign_pdf_screen.dart';
import 'package:quick_pdf/ui/watermark_screen.dart';
import 'package:quick_pdf/ui/scanner_screen.dart';
import 'package:quick_pdf/ui/split_screen.dart';

class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tools')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _header(context, 'Create'),
          _Tool(
            icon: Icons.camera_alt,
            color: Colors.blue.shade600,
            title: 'Scan Document',
            subtitle: 'Use your camera to scan pages into a PDF',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ScannerScreen()),
            ),
          ),
          _Tool(
            icon: Icons.image,
            color: Colors.green.shade600,
            title: 'Images to PDF',
            subtitle: 'Convert photos and images into a single PDF',
            onTap: () async {
              final r = await FilePickerService.pickMultipleFiles(
                  allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'bmp']);
              if (r == null || r.isEmpty || !context.mounted) return;
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ConvertScreen(initialImages: r)));
            },
          ),
          const Divider(indent: 16, endIndent: 16, height: 24),
          _header(context, 'PDF Tools'),
          _Tool(
            icon: Icons.merge_type,
            color: Colors.orange.shade700,
            title: 'Merge PDFs',
            subtitle: 'Combine multiple PDFs, choose pages per document',
            onTap: () async {
              final r = await FilePickerService.pickMultipleFiles(
                  allowedExtensions: ['pdf']);
              if (r == null || r.isEmpty || !context.mounted) return;
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => MergeScreen(initialFiles: r)));
            },
          ),
          _Tool(
            icon: Icons.call_split,
            color: Colors.deepPurple.shade500,
            title: 'Split PDF',
            subtitle: 'Extract pages or split into individual PDF files',
            onTap: () async {
              final r = await FilePickerService.pickMultipleFiles(
                  allowedExtensions: ['pdf']);
              if (r == null || r.isEmpty || !context.mounted) return;
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => SplitScreen(file: r.first)));
            },
          ),
          _Tool(
            icon: Icons.compress,
            color: Colors.red.shade600,
            title: 'Compress PDF',
            subtitle: 'Reduce file size with adjustable quality presets',
            onTap: () async {
              final r = await FilePickerService.pickMultipleFiles(
                  allowedExtensions: ['pdf']);
              if (r == null || r.isEmpty || !context.mounted) return;
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => CompressScreen(file: r.first)));
            },
          ),
          const Divider(indent: 16, endIndent: 16, height: 24),
          _header(context, 'Convert & Extract'),
          _Tool(
            icon: Icons.swap_horiz,
            color: Colors.teal.shade600,
            title: 'Format Converter',
            subtitle: 'PDF → JPEG / PNG  ·  Images → PDF',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const FormatConverterScreen()),
            ),
          ),
          _Tool(
            icon: Icons.text_snippet_outlined,
            color: Colors.indigo.shade600,
            title: 'Extract Text (OCR)',
            subtitle: 'Read text from PDFs and images — fully offline',
            onTap: () async {
              final r = await FilePickerService.pickMultipleFiles(
                allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'bmp', 'webp'],
              );
              if (r == null || r.isEmpty || !context.mounted) return;
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => OcrTextScreen(file: r.first)));
            },
          ),
          _Tool(
            icon: Icons.text_fields,
            color: Colors.deepOrange.shade600,
            title: 'Export Text',
            subtitle: 'OCR all pages and export as .txt',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const ExportTextScreen())),
          ),
          const Divider(indent: 16, endIndent: 16, height: 24),
          _header(context, 'Annotate & Sign'),
          _Tool(
            icon: Icons.draw_outlined,
            color: Colors.purple.shade600,
            title: 'Annotate PDF',
            subtitle: 'Draw on PDF pages with pen and highlighter',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const AnnotatePdfScreen())),
          ),
          _Tool(
            icon: Icons.draw,
            color: Colors.green.shade700,
            title: 'Sign PDF',
            subtitle: 'Draw and place your signature on a PDF',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const SignPdfScreen())),
          ),
          const Divider(indent: 16, endIndent: 16, height: 24),
          _header(context, 'Batch'),
          _Tool(
            icon: Icons.playlist_add_check,
            color: Colors.amber.shade800,
            title: 'Batch Processing',
            subtitle: 'Apply one operation to multiple PDFs at once',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const BatchScreen())),
          ),
          const Divider(indent: 16, endIndent: 16, height: 24),
          _header(context, 'Organise'),
          _Tool(
            icon: Icons.view_module,
            color: Colors.pink.shade600,
            title: 'Page Manager',
            subtitle: 'Reorder, delete, and rotate PDF pages',
            onTap: () async {
              final r = await FilePickerService.pickMultipleFiles(
                  allowedExtensions: ['pdf']);
              if (r == null || r.isEmpty || !context.mounted) return;
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => PageManagerScreen(pdfFile: r.first)));
            },
          ),
          _Tool(
            icon: Icons.water_drop_outlined,
            color: Colors.cyan.shade700,
            title: 'Watermark',
            subtitle: 'Add a text watermark to all pages',
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const WatermarkScreen())),
          ),
          const Divider(indent: 16, endIndent: 16, height: 24),
          _header(context, 'Security & Metadata'),
          _Tool(
            icon: Icons.lock_outline,
            color: Colors.blueGrey.shade600,
            title: 'Password Protect',
            subtitle: 'Encrypt a PDF or remove its password',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const PasswordProtectScreen())),
          ),
          _Tool(
            icon: Icons.edit_document,
            color: Colors.brown.shade500,
            title: 'Edit Metadata',
            subtitle: 'Set title, author, and subject of a PDF',
            onTap: () async {
              final r = await FilePickerService.pickMultipleFiles(
                  allowedExtensions: ['pdf']);
              if (r == null || r.isEmpty || !context.mounted) return;
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => EditMetadataScreen(pdfFile: r.first)));
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Text(text,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant)),
    );
  }
}

class _Tool extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _Tool({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(subtitle,
          style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      trailing: Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
      onTap: onTap,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}
