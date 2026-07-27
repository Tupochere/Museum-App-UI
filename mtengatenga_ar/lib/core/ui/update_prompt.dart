import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/app_update_installer.dart';
import '../services/update_service.dart';
import '../../theme/app_tokens.dart';

/// Shows an industry-standard update dialog offering the newer release found by
/// [UpdateService]. The APK is downloaded in-app and handed to the system
/// package installer; opening the release in a browser is the fallback whenever
/// that path is unavailable or fails.
class UpdatePrompt {
  const UpdatePrompt._();

  static Future<void> show(BuildContext context, AppUpdateInfo info) {
    return showDialog<void>(
      context: context,
      // Dismissal is gated by the dialog's own PopScope so a download in
      // flight can't be cancelled by a stray tap on the barrier.
      barrierDismissible: true,
      builder: (context) => _UpdateDialog(info: info),
    );
  }
}

/// Where the update flow currently is. Drives the dialog's action row.
enum _UpdateStage {
  /// Offering the update.
  idle,

  /// "Install unknown apps" has not been granted yet.
  needsPermission,

  /// APK transfer in progress.
  downloading,

  /// Handing off to the system package installer.
  installing,

  /// Something failed; the browser fallback is offered.
  failed,
}

class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog({required this.info});

  final AppUpdateInfo info;

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog>
    with WidgetsBindingObserver {
  _UpdateStage _stage = _UpdateStage.idle;
  UpdateDownloadProgress? _progress;
  String? _errorMessage;

  AppUpdateInstaller? get _installer =>
      GetIt.instance.isRegistered<AppUpdateInstaller>()
          ? GetIt.instance<AppUpdateInstaller>()
          : null;

  bool get _isBusy =>
      _stage == _UpdateStage.downloading || _stage == _UpdateStage.installing;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_stage == _UpdateStage.downloading) {
      _installer?.cancelDownload();
    }
    super.dispose();
  }

  /// Android hands control back here after the "Install unknown apps" settings
  /// screen closes. Rather than leaving the user staring at the same "Allow"
  /// button they just satisfied, re-check the permission and carry straight on
  /// with the download they originally asked for.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (_stage != _UpdateStage.needsPermission) return;
    _resumeAfterPermission();
  }

  Future<void> _resumeAfterPermission() async {
    final installer = _installer;
    if (installer == null) return;
    if (!await installer.canInstall()) return; // still denied — leave the prompt
    if (!mounted) return;
    await _startUpdate();
  }

  /// Fallback path — hands the release URL to the system browser. This is what
  /// the dialog did before in-app installs existed.
  Future<void> _openInBrowser() async {
    final uri = Uri.parse(widget.info.downloadUrl);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (launched && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _startUpdate() async {
    final installer = _installer;
    if (installer == null || !installer.isSupported) {
      await _openInBrowser();
      return;
    }

    if (!await installer.canInstall()) {
      if (!mounted) return;
      setState(() => _stage = _UpdateStage.needsPermission);
      return;
    }

    setState(() {
      _stage = _UpdateStage.downloading;
      _progress = null;
      _errorMessage = null;
    });

    try {
      final path = await installer.download(
        widget.info,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() => _progress = progress);
        },
      );

      if (!mounted) return;
      setState(() => _stage = _UpdateStage.installing);

      // The OS installer takes over from here; it always asks the user to
      // confirm, and the app is usually replaced before this returns.
      await installer.install(path);
    } on AppUpdateException catch (error) {
      if (!mounted) return;
      setState(() {
        _stage = _UpdateStage.failed;
        _errorMessage = error.message;
      });
    }
  }

  Future<void> _openInstallSettings() async {
    final opened = await _installer?.openInstallSettings() ?? false;
    if (!mounted) return;
    if (!opened) {
      setState(() {
        _stage = _UpdateStage.failed;
        _errorMessage = 'Could not open your device settings.';
      });
    }
  }

  void _cancelDownload() {
    _installer?.cancelDownload();
    setState(() {
      _stage = _UpdateStage.idle;
      _progress = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final highlights = _ReleaseNotes.highlights(widget.info.releaseNotes);

    return PopScope(
      canPop: !_isBusy,
      child: Dialog(
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
              _Header(version: widget.info.version),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
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
                      if (_stage == _UpdateStage.needsPermission)
                        const _Notice(
                          icon: Icons.lock_open_rounded,
                          text:
                              'Android needs your permission to install apps from '
                              'Mtengatenga. Turn on "Allow from this source" and '
                              'the download starts as soon as you come back.',
                        ),
                      if (_stage == _UpdateStage.failed && _errorMessage != null)
                        _Notice(
                          icon: Icons.error_outline_rounded,
                          text: _errorMessage!,
                          isError: true,
                        ),
                    ],
                  ),
                ),
              ),
              _ActionArea(
                stage: _stage,
                progress: _progress,
                onUpdate: _startUpdate,
                onCancelDownload: _cancelDownload,
                onOpenSettings: _openInstallSettings,
                onOpenInBrowser: _openInBrowser,
                onDismiss: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The dialog's bottom section: buttons, or download progress while busy.
class _ActionArea extends StatelessWidget {
  const _ActionArea({
    required this.stage,
    required this.progress,
    required this.onUpdate,
    required this.onCancelDownload,
    required this.onOpenSettings,
    required this.onOpenInBrowser,
    required this.onDismiss,
  });

  final _UpdateStage stage;
  final UpdateDownloadProgress? progress;
  final VoidCallback onUpdate;
  final VoidCallback onCancelDownload;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenInBrowser;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: switch (stage) {
        _UpdateStage.downloading => _DownloadProgress(
            progress: progress,
            onCancel: onCancelDownload,
          ),
        _UpdateStage.installing => const _StatusRow(
            text: 'Opening installer…',
          ),
        _UpdateStage.needsPermission => _ButtonRow(
            secondaryLabel: 'Not now',
            onSecondary: onDismiss,
            primaryLabel: 'Open settings',
            primaryIcon: Icons.settings_rounded,
            onPrimary: onOpenSettings,
          ),
        _UpdateStage.failed => _ButtonRow(
            secondaryLabel: 'Close',
            onSecondary: onDismiss,
            primaryLabel: 'Open in browser',
            primaryIcon: Icons.open_in_new_rounded,
            onPrimary: onOpenInBrowser,
          ),
        _UpdateStage.idle => _ButtonRow(
            secondaryLabel: 'Not now',
            onSecondary: onDismiss,
            primaryLabel: 'Update',
            primaryIcon: Icons.download_rounded,
            onPrimary: onUpdate,
          ),
      },
    );
  }
}

/// Progress bar plus a cancel affordance, shown while the APK transfers.
class _DownloadProgress extends StatelessWidget {
  const _DownloadProgress({required this.progress, required this.onCancel});

  final UpdateDownloadProgress? progress;
  final VoidCallback onCancel;

  static String _megabytes(int bytes) =>
      (bytes / (1024 * 1024)).toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final current = progress;
    final ratio = current?.ratio;
    final total = current?.totalBytes;

    final label = current == null
        ? 'Starting download…'
        : total != null
            ? '${_megabytes(current.receivedBytes)} of ${_megabytes(total)} MB'
            : '${_megabytes(current.receivedBytes)} MB';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 6,
            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Text(
                ratio == null ? label : '${(ratio * 100).round()}%  ·  $label',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            TextButton(
              onPressed: onCancel,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textMuted,
              ),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ],
    );
  }
}

/// Spinner plus a short status line, for steps the user can't cancel.
class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}

/// The standard secondary/primary button pair used by every resting state.
class _ButtonRow extends StatelessWidget {
  const _ButtonRow({
    required this.secondaryLabel,
    required this.onSecondary,
    required this.primaryLabel,
    required this.primaryIcon,
    required this.onPrimary,
  });

  final String secondaryLabel;
  final VoidCallback onSecondary;
  final String primaryLabel;
  final IconData primaryIcon;
  final VoidCallback onPrimary;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: onSecondary,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.textMuted,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          child: Text(secondaryLabel),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
          onPressed: onPrimary,
          icon: Icon(primaryIcon, size: 18),
          label: Text(
            primaryLabel,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

/// An inline informational or error callout inside the dialog body.
class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.text,
    this.isError = false,
  });

  final IconData icon;
  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? Colors.red.shade700 : AppColors.primary;

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: isError ? color : AppColors.textMain,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dialog title block: update icon, headline, and the offered version.
///
/// Deliberately flat — it sits on the card surface rather than in a filled
/// banner, so the terracotta reads as accent (icon, button, bullets) instead
/// of dominating the dialog.
class _Header extends StatelessWidget {
  const _Header({required this.version});

  final String version;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 4),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.rocket_launch_rounded,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Update available',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textMain,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Version $version',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
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
