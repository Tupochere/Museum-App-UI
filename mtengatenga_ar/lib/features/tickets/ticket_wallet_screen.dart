import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/ui/states/state_view.dart';
import '../../services/payment_service.dart';
import '../../theme/app_tokens.dart';

class TicketWalletScreen extends StatefulWidget {
  const TicketWalletScreen({super.key});

  @override
  State<TicketWalletScreen> createState() => _TicketWalletScreenState();
}

class _TicketWalletScreenState extends State<TicketWalletScreen> {
  final _paymentService = PaymentService();
  late Future<List<Map<String, dynamic>>> _ordersFuture;

  @override
  void initState() {
    super.initState();
    _ordersFuture = _paymentService.getCompletedOrders();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(title: const Text('My Tickets')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _ordersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          final orders = snapshot.data ?? [];

          if (orders.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: AppEmptyState(
                title: 'No Tickets Yet',
                message: 'Purchase a ticket to see it here.',
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: orders.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _TicketCard(order: orders[index]),
          );
        },
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.order});
  final Map<String, dynamic> order;

  String _ticketSummary() {
    final parts = <String>[];
    final adult = order['adult_count'] as int? ?? 0;
    final student = order['student_count'] as int? ?? 0;
    final intl = order['international_count'] as int? ?? 0;
    if (adult > 0) parts.add('$adult Adult');
    if (student > 0) parts.add('$student Student');
    if (intl > 0) parts.add('$intl International');
    return parts.isEmpty ? 'Ticket' : parts.join(' \u2022 ');
  }

  @override
  Widget build(BuildContext context) {
    final visitDate = order['visit_date'] as String? ?? '';
    final channel = order['payment_channel'] as String?;
    final qrData = order['qr_code_data'] as String?;

    return Container(
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
          Text(
            'MTENGATENGA AR MUSEUM \u2022 ${_ticketSummary()}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
          ),
          if (visitDate.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Visit: $visitDate',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
          ],
          if (channel != null && channel.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Paid via $channel',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (qrData != null && qrData.isNotEmpty)
            Center(
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 180,
                backgroundColor: Colors.white,
              ),
            )
          else
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
    );
  }
}
