import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/domain/repositories/artifact_repository.dart';
import '../../core/services/scan_history_service.dart';
import '../../core/services/service_locator.dart';
import '../../core/services/ticket_gate.dart';
import '../../theme/app_tokens.dart';
import '../artifact/artifact_details_screen.dart';
import 'scan_screen.dart';

class ScanHistoryScreen extends StatefulWidget {
  const ScanHistoryScreen({super.key});

  @override
  State<ScanHistoryScreen> createState() => _ScanHistoryScreenState();
}

class _ScanHistoryScreenState extends State<ScanHistoryScreen> {
  List<Map<String, dynamic>> _history = [];
  List<Map<String, dynamic>> _filteredHistory = [];
  bool _loading = true;
  int _filter = 0;

  IArtifactRepository get _artifactRepository => ServiceLocator.instance<IArtifactRepository>();
  ScanHistoryService get _scanHistoryService => ServiceLocator.instance<ScanHistoryService>();

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final history = await _scanHistoryService.getHistory();

      if (!mounted) return;
      setState(() {
        _history = history;
        _applyFilter();
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading history: $error')),
      );
    }
  }

  void _applyFilter() {
    final now = DateTime.now();

    switch (_filter) {
      case 0:
        _filteredHistory = _history.where((item) {
          final scannedAt = DateTime.parse(item['scanned_at'] as String);
          return scannedAt.year == now.year && scannedAt.month == now.month && scannedAt.day == now.day;
        }).toList();
        break;
      case 1:
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        _filteredHistory = _history.where((item) {
          final scannedAt = DateTime.parse(item['scanned_at'] as String);
          return scannedAt.isAfter(weekStart);
        }).toList();
        break;
      default:
        _filteredHistory = _history;
        break;
    }
  }

  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear History'),
        content: const Text('Are you sure you want to clear all scan history?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _scanHistoryService.clearHistory();
      await _loadHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Scan History'),
        actions: [
          if (_history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _clearHistory,
              tooltip: 'Clear history',
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'Today',
                        active: _filter == 0,
                        onTap: () => setState(() {
                          _filter = 0;
                          _applyFilter();
                        }),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'This Week',
                        active: _filter == 1,
                        onTap: () => setState(() {
                          _filter = 1;
                          _applyFilter();
                        }),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'All',
                        active: _filter == 2,
                        onTap: () => setState(() {
                          _filter = 2;
                          _applyFilter();
                        }),
                      ),
                      const Spacer(),
                      if (_history.isNotEmpty)
                        Text(
                          '${_filteredHistory.length} scan${_filteredHistory.length == 1 ? '' : 's'}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: _filteredHistory.isEmpty
                      ? _EmptyState(filter: _filter)
                      : RefreshIndicator(
                          onRefresh: _loadHistory,
                          child: ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filteredHistory.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final entry = _filteredHistory[index];
                              return _HistoryCard(
                                entry: entry,
                                onTap: () => _viewArtifact(entry['artifact_id'] as String),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Future<void> _viewArtifact(String artifactId) async {
    try {
      final artifact = await _artifactRepository.getArtifactById(artifactId);

      if (!mounted) return;

      if (artifact == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Artifact not found')),
        );
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ArtifactDetailsScreen(artifact: artifact)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading artifact: $error')),
      );
    }
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

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.entry,
    required this.onTap,
  });

  final Map<String, dynamic> entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scannedAt = DateTime.parse(entry['scanned_at'] as String);
    final timeDisplay = _formatTime(scannedAt);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(12),
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
                    entry['artifact_name'] as String,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: AppColors.textMain,
                      fontSize: 15,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timeDisplay,
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
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (dateTime.year == now.year && dateTime.month == now.month && dateTime.day == now.day) {
      if (difference.inMinutes < 1) return 'Just now';
      if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
      return 'Today • ${DateFormat('h:mm a').format(dateTime)}';
    }

    final yesterday = now.subtract(const Duration(days: 1));
    if (dateTime.year == yesterday.year && dateTime.month == yesterday.month && dateTime.day == yesterday.day) {
      return 'Yesterday • ${DateFormat('h:mm a').format(dateTime)}';
    }

    if (difference.inDays < 7) return DateFormat('EEEE • h:mm a').format(dateTime);

    return DateFormat('MMM d, yyyy • h:mm a').format(dateTime);
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filter});

  final int filter;

  @override
  Widget build(BuildContext context) {
    String message;
    switch (filter) {
      case 0:
        message = 'No scans today. Start exploring artifacts!';
        break;
      case 1:
        message = 'No scans this week. Visit the museum to scan artifacts.';
        break;
      default:
        message = 'Scanned artifacts will appear here for quick return access.';
        break;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.qr_code_scanner, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              filter == 2 ? 'No Scan History Yet' : 'No Scans Found',
              style: TextStyle(
                fontSize: 20,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => TicketGate.navigate(
                context,
                () => const ScanScreen(),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text(
                'Start Scanning',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
