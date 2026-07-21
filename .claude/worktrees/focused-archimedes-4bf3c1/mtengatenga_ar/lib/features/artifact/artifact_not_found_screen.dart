import 'package:flutter/material.dart';
import '../../core/ui/components/primary_cta_button.dart';
import '../../theme/app_tokens.dart';
import '../scan/scan_help_screen.dart';

class ArtifactNotFoundScreen extends StatelessWidget {
  const ArtifactNotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(title: const Text('Artifact Not Found')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 80, color: AppColors.primary),
            const SizedBox(height: 14),
            const Text(
              'We could not match this artifact',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppColors.textMain,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              'Try better lighting, hold the phone steady, and keep the object inside the frame.',
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            PrimaryCtaButton(
              label: 'Open Scan Help',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ScanHelpScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
