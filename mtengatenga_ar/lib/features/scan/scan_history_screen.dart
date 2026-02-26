import 'package:flutter/material.dart';
import '../../core/domain/entities/artifact.dart';
import '../../core/models/ui_models.dart';
import '../../core/ui/states/state_view.dart';
import '../../theme/app_tokens.dart';
import '../artifact/artifact_details_screen.dart';
import 'scan_screen.dart';

class ScanHistoryScreen extends StatefulWidget {
  const ScanHistoryScreen({super.key});

  @override
  State<ScanHistoryScreen> createState() => _ScanHistoryScreenState();
}

class _ScanHistoryScreenState extends State<ScanHistoryScreen> {
  int _filter = 0;
  final _records = const [
    UiScanRecord(
      artifactName: 'Ngoni Shield',
      scannedAt: 'Today • 10:48 AM',
      locationHint: 'Hall of Ancestors',
    ),
    UiScanRecord(
      artifactName: 'Kasuda Farming Hoe',
      scannedAt: 'Today • 09:12 AM',
      locationHint: 'Agriculture Gallery',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(title: const Text('Scan History')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                _FilterChip(label: 'Today', active: _filter == 0, onTap: () => setState(() => _filter = 0)),
                const SizedBox(width: 8),
                _FilterChip(label: 'This Week', active: _filter == 1, onTap: () => setState(() => _filter = 1)),
                const SizedBox(width: 8),
                _FilterChip(label: 'All', active: _filter == 2, onTap: () => setState(() => _filter = 2)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _records.isEmpty
                ? AppEmptyState(
                    title: 'No Scan History Yet',
                    message: 'Scanned artifacts will appear here for quick return access.',
                    actionLabel: 'Start Scanning',
                    onAction: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ScanScreen()),
                      );
                    },
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: _records.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = _records[index];
                      return InkWell(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ArtifactDetailsScreen(
                                artifact: _demoArtifact(item.artifactName, item.locationHint),
                              ),
                            ),
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
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.10),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.qr_code_scanner, color: AppColors.primary),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.artifactName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.textMain,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${item.scannedAt} • ${item.locationHint}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Artifact _demoArtifact(String name, String? location) {
    return Artifact(
      id: 'scan-history-$name',
      name: name,
      subtitle: location,
      description: 'Artifact details from scan history are not wired yet.',
      updatedAt: DateTime.now(),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: active ? Colors.white : AppColors.textMain,
          ),
        ),
      ),
    );
  }
}
