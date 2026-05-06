import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/models/ui_models.dart';
import '../../core/ui/components/primary_cta_button.dart';
import '../../theme/app_tokens.dart';
import 'ticket_wallet_screen.dart';

class TicketCheckoutScreen extends StatefulWidget {
  const TicketCheckoutScreen({super.key, required this.draft});
  final UiTicketOrderDraft draft;

  @override
  State<TicketCheckoutScreen> createState() => _TicketCheckoutScreenState();
}

class _TicketCheckoutScreenState extends State<TicketCheckoutScreen> {
  TicketCheckoutState _state = TicketCheckoutState.review;
  bool _paychangu = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      backgroundColor: AppColors.backgroundLight,
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            _StepHeader(state: _state),
            const SizedBox(height: 12),
            Expanded(child: _buildStateBody(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildStateBody(BuildContext context) {
    switch (_state) {
      case TicketCheckoutState.review:
        return _ReviewStep(
          draft: widget.draft,
          onContinue: () => setState(() => _state = TicketCheckoutState.paymentMethod),
        );
      case TicketCheckoutState.paymentMethod:
        return _PaymentStep(
          paychangu: _paychangu,
          onChanged: (v) => setState(() => _paychangu = v),
          onContinue: _startProcessing,
        );
      case TicketCheckoutState.processing:
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.primary),
              SizedBox(height: 10),
              Text('Processing payment...', style: TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        );
      case TicketCheckoutState.success:
        return _SuccessStep(
          onOpenWallet: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const TicketWalletScreen()),
            );
          },
        );
    }
  }

  void _startProcessing() {
    setState(() => _state = TicketCheckoutState.processing);
    Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _state = TicketCheckoutState.success);
      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Thank You for Donating'),
          content: const Text(
            'Your support helps preserve Malawi cultural heritage and educational programs.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    });
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.state});
  final TicketCheckoutState state;

  @override
  Widget build(BuildContext context) {
    int index;
    switch (state) {
      case TicketCheckoutState.review:
        index = 1;
      case TicketCheckoutState.paymentMethod:
        index = 2;
      case TicketCheckoutState.processing:
      case TicketCheckoutState.success:
        index = 3;
    }

    return Row(
      children: [
        _StepChip(label: 'Review', active: index >= 1),
        const SizedBox(width: 8),
        _StepChip(label: 'Payment', active: index >= 2),
        const SizedBox(width: 8),
        _StepChip(label: 'Confirm', active: index >= 3),
      ],
    );
  }
}

class _StepChip extends StatelessWidget {
  const _StepChip({required this.label, required this.active});
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: active ? Colors.white : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _ReviewStep extends StatelessWidget {
  const _ReviewStep({required this.draft, required this.onContinue});
  final UiTicketOrderDraft draft;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
              const Text('Order Summary', style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text('Adult: ${draft.adult}'),
              Text('Student: ${draft.student}'),
              Text('International: ${draft.international}'),
              const SizedBox(height: 8),
              Text(draft.donationLabel, style: const TextStyle(color: AppColors.primary)),
              const SizedBox(height: 8),
              Text(
                draft.totalLabel,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
        const Spacer(),
        PrimaryCtaButton(label: 'Continue to Payment', onPressed: onContinue),
      ],
    );
  }
}

class _PaymentStep extends StatelessWidget {
  const _PaymentStep({
    required this.paychangu,
    required this.onChanged,
    required this.onContinue,
  });

  final bool paychangu;
  final ValueChanged<bool> onChanged;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        RadioListTile<bool>(
          value: true,
          groupValue: paychangu,
          onChanged: (v) => onChanged(v ?? true),
          title: const Text('PayChangu (Placeholder)'),
        ),
        RadioListTile<bool>(
          value: false,
          groupValue: paychangu,
          onChanged: (v) => onChanged(v ?? false),
          title: const Text('Card / Mobile Money (Placeholder)'),
        ),
        const Spacer(),
        PrimaryCtaButton(label: 'Confirm Payment', onPressed: onContinue),
      ],
    );
  }
}

class _SuccessStep extends StatelessWidget {
  const _SuccessStep({required this.onOpenWallet});
  final VoidCallback onOpenWallet;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 80),
        const SizedBox(height: 10),
        const Text(
          'Purchase Complete',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        const Text(
          'Your digital ticket is now available in My Tickets.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        PrimaryCtaButton(label: 'Open My Tickets', onPressed: onOpenWallet),
      ],
    );
  }
}
