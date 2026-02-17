import 'package:flutter/material.dart';
import '../../theme/app_tokens.dart';

class ScanHelpScreen extends StatelessWidget {
  const ScanHelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(title: const Text('Scan Help')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: const [
          _HelpCard(
            icon: Icons.center_focus_strong,
            title: 'How to Scan',
            text: 'Center the artifact in the frame and hold your phone steady for 2-3 seconds.',
          ),
          _HelpCard(
            icon: Icons.wb_sunny_outlined,
            title: 'Lighting Tips',
            text: 'Use bright, even light. Avoid strong backlight and reflective glare.',
          ),
          _HelpCard(
            icon: Icons.straighten,
            title: 'Distance & Angle',
            text: 'Stand 0.5-1.5m away and keep the entire artifact visible.',
          ),
          _HelpCard(
            icon: Icons.help_outline,
            title: 'Not Detecting?',
            text: 'Clean camera lens, retry from a different angle, or use manual artifact browse.',
          ),
        ],
      ),
    );
  }
}

class _HelpCard extends StatelessWidget {
  const _HelpCard({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
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
          )
        ],
      ),
    );
  }
}
