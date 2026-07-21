import 'package:flutter/material.dart';
import '../../core/ui/states/state_view.dart';
import '../../theme/app_tokens.dart';

class TicketWalletScreen extends StatelessWidget {
  const TicketWalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(title: const Text('My Tickets')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.surfaceBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Upcoming Ticket',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: AppColors.textMain,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'MTENGATENGA AR MUSEUM • 1 Adult',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2EDE4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.qr_code_2, size: 72, color: AppColors.textMain),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const AppEmptyState(
            title: 'No Past Tickets',
            message: 'Completed visits and receipts will appear here.',
          ),
        ],
      ),
    );
  }
}
