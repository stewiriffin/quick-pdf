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

  String _getThemeModeName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System (Default)';
    }
  }

  Future<void> _showThemeModeDialog(BuildContext context) async {
    final ThemeMode currentMode = ref.read(themeProvider);
    final ThemeMode? newMode = await showDialog<ThemeMode>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Theme Mode'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                ListTile(
                  leading: Radio<ThemeMode>(
                    value: ThemeMode.light,
                    groupValue: currentMode,
                    onChanged: (ThemeMode? value) {
                      Navigator.of(context).pop(value);
                    },
                  ),
                  title: const Text('Light'),
                ),
                ListTile(
                  leading: Radio<ThemeMode>(
                    value: ThemeMode.dark,
                    groupValue: currentMode,
                    onChanged: (ThemeMode? value) {
                      Navigator.of(context).pop(value);
                    },
                  ),
                  title: const Text('Dark'),
                ),
                ListTile(
                  leading: Radio<ThemeMode>(
                    value: ThemeMode.system,
                    groupValue: currentMode,
                    onChanged: (ThemeMode? value) {
                      Navigator.of(context).pop(value);
                    },
                  ),
                  title: const Text('System (Default)'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (newMode != null && newMode != currentMode) {
      ref.read(themeProvider.notifier).setThemeMode(newMode);
    }
  }

  @override
  Widget build(BuildContext context) {
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
            ListTile(
              title: const Text('Theme Mode'),
              subtitle: Text(_getThemeModeName(ref.watch(themeProvider))),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showThemeModeDialog(context),
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
                title: const Text('Privacy First'),
                subtitle: const Text(
                    'All document processing is on-device. Ads are served by Google AdMob and require internet access.'),
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
                subtitle: const Text('Version 1.0.1 · Built with Flutter'),
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
        contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        content: const SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: MarkdownBody(data: _kPrivacyPolicy),
          ),
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

  static const String _kPrivacyPolicy = '''
## QuickPDF Privacy Policy

**Effective date: May 2026 · Version 1.0.1**

QuickPDF ("the app") is an offline document management tool developed for Android.
This policy explains what data the app accesses, how it is used, and your rights.

---

### 1. Data We Collect

QuickPDF itself collects **no personal data**. The app has no accounts, no servers,
and performs no uploads of your files or documents.

The app displays ads via **Google AdMob**, which may collect:
- Device Advertising ID
- IP address / approximate location
- App interaction data (for ad relevance)

See Section 5 for full details on advertising.

---

### 2. Permissions Used

| Permission | Why it is needed |
|---|---|
| **Camera** | Capture photos for document scanning |
| **Storage (read)** | Open PDF and image files you select |
| **Storage (write)** | Save processed PDFs to your device |
| **Internet** | Required by Google AdMob to serve ads |
| **Advertising ID** | Used by AdMob for personalised ads |

No permission is used beyond its stated purpose.

---

### 3. Files & Documents

- Files you open or create are stored **only on your device**.
- QuickPDF never uploads, syncs, or transmits any file content.
- Temporary files (thumbnails, scan images) are stored in the app's private
  directory and cleaned up automatically. Clear manually via **Settings → Clear cache**.

---

### 4. OCR & Text Recognition

Text recognition is performed **fully offline** using Google ML Kit's on-device
models. Recognised text never leaves your device.

---

### 5. Advertising (Google AdMob)

QuickPDF uses **Google AdMob** to display banner and interstitial ads.
AdMob is a third-party advertising service operated by Google LLC.

**What AdMob may collect:**
- Advertising ID (Android AAID) for ad personalisation
- IP address and approximate geographic location
- App usage signals for ad frequency and relevance

**Your choices:**
- To opt out of personalised ads: **Android Settings → Google → Ads →
  Opt out of Ads Personalisation**
- To reset your Advertising ID: **Android Settings → Google → Ads →
  Reset advertising ID**

Google's Privacy Policy: https://policies.google.com/privacy
Google AdMob Terms: https://developers.google.com/admob/terms

---

### 6. Third-Party SDKs

| SDK | Purpose | Sends data off-device? |
|---|---|---|
| Google AdMob | Advertising | Yes (ad targeting — see §5) |
| Google ML Kit | On-device OCR | No |

No analytics, crash-reporting, or other tracking SDKs are used.

---

### 7. Children's Privacy

QuickPDF does not knowingly target or collect data from children under 13.
AdMob is configured for general audiences. If you believe a child has provided
personal information via ads, contact us at the address below.

---

### 8. Changes to This Policy

If a future update changes how data is handled, this policy will be updated,
the effective date revised, and users notified via the Play Store update notes.

---

### 9. Contact

Questions about this policy:
**stewiegriffin3108ia@gmail.com**

*Document processing is fully local. Only ad serving requires internet access.*
''';
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
