import 'package:flutter/material.dart';

import '../../features/tickets/tickets_hub_screen.dart';
import '../../services/payment_service.dart';
import '../../theme/app_tokens.dart';

/// Checks if the user has a valid ticket for today before allowing navigation.
/// If not, shows a bottom sheet prompting them to buy a ticket.
class TicketGate {
  static final _paymentService = PaymentService();

  /// Call before navigating to a gated feature (Scan, AR, AI Guide).
  /// Returns true if the user has access, false if blocked.
  static Future<bool> checkAccess(BuildContext context) async {
    final hasTicket = await _paymentService.hasValidTicketForToday();
    if (hasTicket) return true;

    if (!context.mounted) return false;

    // Show paywall bottom sheet
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _TicketRequiredSheet(),
    );

    return false;
  }

  /// Wraps a navigation action with the ticket check.
  /// Usage: `TicketGate.navigate(context, () => const ScanScreen())`
  static Future<void> navigate(
    BuildContext context,
    Widget Function() screenBuilder,
  ) async {
    final allowed = await checkAccess(context);
    if (!allowed || !context.mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screenBuilder()),
    );
  }
}

class _TicketRequiredSheet extends StatelessWidget {
  const _TicketRequiredSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.surfaceBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Icon
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(20),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.confirmation_number_outlined,
              size: 36,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 20),

          const Text(
            'Ticket Required',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AppColors.textMain,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'You need a valid ticket for today to access\nthis feature. Purchase one to unlock\nScanning, AR, and AI Guide.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppColors.textMuted),
          ),
          const SizedBox(height: 24),

          // Buy ticket button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close sheet
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const TicketsHubScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Buy a Ticket',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Dismiss
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Maybe Later',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}
