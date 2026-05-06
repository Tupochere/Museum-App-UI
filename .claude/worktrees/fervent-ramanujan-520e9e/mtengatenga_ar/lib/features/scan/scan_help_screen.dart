import 'package:flutter/material.dart';
import '../../theme/app_tokens.dart';

class ScanHelpScreen extends StatelessWidget {
  const ScanHelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const helpSteps = <_HelpStep>[
      _HelpStep(
        icon: Icons.wb_sunny_outlined,
        title: 'Lighting Tips',
        text: 'Use bright, even light and avoid strong glare directly on the artifact.',
        imageAsset: 'assets/images/scan_help_lighting_glare.png',
      ),
      _HelpStep(
        icon: Icons.center_focus_strong,
        title: 'Frame the Artifact',
        text: 'Center the artifact in the frame and hold your phone steady for 2-3 seconds.',
        imageAsset: 'assets/images/scan_help_frame_artifact.png',
      ),
      _HelpStep(
        icon: Icons.help_outline,
        title: 'If Detection Is Unstable',
        text: 'Clean your lens and move any object blocking the camera view before retrying.',
        imageAsset: 'assets/images/scan_help_clear_view.png',
      ),
      _HelpStep(
        icon: Icons.straighten,
        title: 'Distance & Angle',
        text: 'Stand about 0.5m-1.5m away and keep the full artifact visible while scanning.',
        imageAsset: 'assets/images/scan_help_distance_angle.png',
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(title: const Text('Scan Help')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.md),
            child: Text(
              'Follow these steps for better artifact detection.',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
              ),
            ),
          ),
          ...helpSteps.map(
            (step) => _HelpCard(
              icon: step.icon,
              title: step.title,
              text: step.text,
              imageAsset: step.imageAsset,
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpStep {
  const _HelpStep({
    required this.icon,
    required this.title,
    required this.text,
    required this.imageAsset,
  });

  final IconData icon;
  final String title;
  final String text;
  final String imageAsset;
}

class _HelpCard extends StatelessWidget {
  const _HelpCard({
    required this.icon,
    required this.title,
    required this.text,
    required this.imageAsset,
  });

  final IconData icon;
  final String title;
  final String text;
  final String imageAsset;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.md)),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Image.asset(
                imageAsset,
                fit: BoxFit.cover,
                errorBuilder: (context, _, __) => Container(
                  color: AppColors.backgroundLight,
                  child: Center(
                    child: Icon(
                      icon,
                      size: 40,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textMain,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        text,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
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
