import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/update_service.dart';
import '../../theme/app_tokens.dart';

/// Shows a non-dismissive-until-acknowledged dialog offering the user the
/// newer release found by [UpdateService]. Delegates the actual download to
/// the system browser (GitHub serves the APK directly).
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
    return AlertDialog(
      backgroundColor: AppColors.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      title: const Row(
        children: [
          Icon(Icons.system_update, color: AppColors.primary),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Update available',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: AppColors.textMain,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Version ${info.version} is ready to download.',
            style: const TextStyle(color: AppColors.textMain),
          ),
          if (info.releaseNotes.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              "What's new",
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 160),
              child: SingleChildScrollView(
                child: Text(
                  info.releaseNotes,
                  style: const TextStyle(color: AppColors.textMuted, height: 1.4),
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Later',
            style: TextStyle(color: AppColors.textMuted),
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          onPressed: () => _download(context),
          child: const Text('Download'),
        ),
      ],
    );
  }
}
