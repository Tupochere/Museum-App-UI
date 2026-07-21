import 'package:flutter/material.dart';
import '../../core/models/ui_models.dart';
import '../../core/ui/states/state_view.dart';
import '../../theme/app_tokens.dart';
import '../artifact/artifact_details_screen.dart';

class SavedArtifactsScreen extends StatelessWidget {
  const SavedArtifactsScreen({super.key});

  static const _items = [
    UiArtifactSummary(
      id: '1',
      name: 'Ancestral Mask',
      subtitle: 'Gule Wamkulu collection',
      period: '19th Century',
    ),
    UiArtifactSummary(
      id: '2',
      name: 'Ngoni Shield',
      subtitle: 'Warrior regalia',
      period: 'Early 1900s',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Saved Artifacts'),
      ),
      body: _items.isEmpty
          ? const AppEmptyState(
              title: 'No Saved Artifacts',
              message: 'Artifacts you bookmark from scanning and tours will appear here.',
            )
          : ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: _items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = _items[index];
                return InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ArtifactDetailsScreen()),
                    );
                  },
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCard,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.surfaceBorder),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.museum_outlined, color: AppColors.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.textMain,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${item.subtitle} • ${item.period}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: AppColors.textMuted),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
