import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quick_pdf/providers/theme_provider.dart';
import 'package:path_provider/path_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _storageUsed = '…';
  bool _clearingCache = false;

  @override
  void initState() {
    super.initState();
    _calcStorage();
  }

  Future<void> _calcStorage() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      int total = 0;
      await for (final e in dir.list(recursive: true, followLinks: false)) {
        if (e is File) total += await e.length();
      }
      if (mounted) {
        setState(() => _storageUsed = total < 1024 * 1024
            ? '${(total / 1024).toStringAsFixed(1)} KB'
            : '${(total / 1024 / 1024).toStringAsFixed(2)} MB');
      }
    } catch (_) {
      if (mounted) setState(() => _storageUsed = 'Unknown');
    }
  }

  Future<void> _clearCache() async {
    setState(() => _clearingCache = true);
    try {
      final dir = await getApplicationDocumentsDirectory();
      int freed = 0, count = 0;
      await for (final e in dir.list(recursive: true, followLinks: false)) {
        if (e is File) {
          final n = e.path.split('/').last.toLowerCase();
          if (n.startsWith('thumb_') || n.startsWith('ocr_') ||
              n.endsWith('.tmp') || n.endsWith('.cache')) {
            freed += await e.length();
            await e.delete();
            count++;
          }
        }
      }
      await _calcStorage();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(count > 0
              ? 'Cleared $count files (${_fmt(freed)} freed)'
              : 'Nothing to clear'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), behavior: SnackBarBehavior.floating));
      }
    } finally {
      if (mounted) setState(() => _clearingCache = false);
    }
  }

  String _fmt(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Appearance ──
          _CardSection(
            title: 'Appearance',
            children: [
              SwitchListTile(
                secondary: Icon(isDark ? Icons.dark_mode : Icons.light_mode,
                    color: cs.primary),
                title: const Text('Dark Mode'),
                subtitle: Text(isDark ? 'Dark theme active' : 'Light theme active'),
                value: isDark,
                onChanged: (_) => ref.read(themeProvider.notifier).toggleTheme(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Storage ──
          _CardSection(
            title: 'Storage',
            children: [
              ListTile(
                leading: Icon(Icons.storage, color: cs.primary),
                title: const Text('Used by QuickPDF'),
                subtitle: Text(_storageUsed),
                trailing: _clearingCache
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : TextButton(
                        onPressed: _clearCache,
                        child: const Text('Clear cache'),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Privacy ──
          _CardSection(
            title: 'Privacy',
            children: [
              ListTile(
                leading: Icon(Icons.shield_outlined, color: cs.primary),
                title: const Text('100% Offline'),
                subtitle: const Text(
                    'All processing happens on your device. Nothing is uploaded.'),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: Icon(Icons.policy_outlined, color: cs.primary),
                title: const Text('Privacy Policy'),
                trailing:
                    Icon(Icons.chevron_right, color: Colors.grey[400]),
                onTap: () => _showPrivacyPolicy(context),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── About ──
          _CardSection(
            title: 'About',
            children: [
              ListTile(
                leading: Icon(Icons.info_outline, color: cs.primary),
                title: const Text('QuickPDF'),
                subtitle: const Text('Version 1.0.0 · Built with Flutter'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicy(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: const SingleChildScrollView(
          child: MarkdownBody(data: '''
## QuickPDF Privacy Policy

QuickPDF is offline-first. We do not collect, store, or transmit any personal data.

- All PDF and image processing happens locally on your device
- No files are uploaded to external servers
- No metadata or content is shared with third parties
- Temporary files are cleaned up automatically

QuickPDF only requests permissions needed for core features:
- **Camera** – document scanning
- **Storage** – reading and saving files

*Last updated: May 2026*
'''),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _CardSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _CardSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(title,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ),
        Card(child: Column(children: children)),
      ],
    );
  }
}
