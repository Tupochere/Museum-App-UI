import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/update_service.dart';
import '../../theme/app_tokens.dart';

/// Shows an industry-standard update dialog offering the newer release found by
/// [UpdateService]. Delegates the actual download to the system browser (GitHub
/// serves the APK directly).
class UpdatePrompt {
  const UpdatePrompt._();

  static Future<void> show(BuildContext context, AppUpdateInfo info) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => _UpdateDialog(info: info),
    );
  }
}

class _UpdateDialog extends StatelessWidget {
  const _UpdateDialog({required this.info});

  final AppUpdateInfo info;

  Future<void> _download(BuildContext context) async {
    final uri = Uri.parse(info.downloadUrl);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (launched && context.mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final highlights = _ReleaseNotes.highlights(info.releaseNotes);

    return Dialog(
      backgroundColor: AppColors.surfaceCard,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(version: info.version),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "What's new",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...highlights.map((line) => _Highlight(text: line)),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textMuted,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                    ),
                    child: const Text('Not now'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 22, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    onPressed: () => _download(context),
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text(
                      'Update',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Terracotta banner with the update icon and version chip.
class _Header extends StatelessWidget {
  const _Header({required this.version});

  final String version;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.lg),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.rocket_launch_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Update available',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Version $version',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A single bulleted "what's new" line.
class _Highlight extends StatelessWidget {
  const _Highlight({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.check_circle_rounded,
              size: 18,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
                color: AppColors.textMain,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Turns a raw GitHub release body (markdown) into a short list of clean,
/// human-readable highlights. Drops changelog links, headings, and markdown
/// noise so end users never see raw `**` or bare URLs.
class _ReleaseNotes {
  static const _fallback = ['Bug fixes and performance improvements.'];

  static List<String> highlights(String raw) {
    final lines = raw
        .split(RegExp(r'[\r\n]+'))
        .map(_clean)
        .where((l) => l.isNotEmpty)
        .where((l) => !_isNoise(l))
        .take(6)
        .toList();
    return lines.isEmpty ? _fallback : lines;
  }

  /// Strips markdown markers, list bullets, and heading hashes from a line.
  static String _clean(String line) {
    var l = line.trim();
    l = l.replaceAll(RegExp(r'^[#>\-\*\+\s]+'), ''); // leading bullets/headings
    l = l.replaceAll(RegExp(r'\*\*|__|`'), ''); // bold/inline-code markers
    // Collapse markdown links [text](url) down to just the text.
    l = l.replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^)]+\)'), (m) => m[1] ?? '');
    return l.trim();
  }

  /// True for lines that carry no value to an end user.
  static bool _isNoise(String line) {
    final lower = line.toLowerCase();
    if (lower.startsWith('full changelog')) return true;
    if (lower.startsWith("what's changed")) return true;
    if (RegExp(r'^https?://\S+$').hasMatch(line)) return true; // bare URL
    if (lower.startsWith('by @') || lower.contains(' in http')) return true;
    return false;
  }
}
