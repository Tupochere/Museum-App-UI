import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/models/ui_models.dart';
import '../../core/ui/components/primary_cta_button.dart';
import '../../services/payment_service.dart';
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

  final _paymentService = PaymentService();

  // Visitor info
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // Calculated at checkout time using live rate
  int _finalTotalMwk = 0;
  int _donationMwk = 0;
  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

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
          onContinue: () =>
              setState(() => _state = TicketCheckoutState.paymentMethod),
        );
      case TicketCheckoutState.paymentMethod:
        return _VisitorInfoStep(
          formKey: _formKey,
          firstNameController: _firstNameController,
          lastNameController: _lastNameController,
          emailController: _emailController,
          onContinue: _startProcessing,
        );
      case TicketCheckoutState.processing:
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.primary),
              SizedBox(height: 10),
              Text('Processing payment...',
                  style: TextStyle(fontWeight: FontWeight.w700)),
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

  Future<void> _startProcessing() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _state = TicketCheckoutState.processing);

    try {
      // Calculate the real total using live exchange rate
      _finalTotalMwk = await _paymentService.calculateTotalMwk(
        adultCount: widget.draft.adult,
        studentCount: widget.draft.student,
        internationalCount: widget.draft.international,
        donationAmountUsd: widget.draft.donationAmountUsd,
      );

      // Calculate donation portion in MWK
      _donationMwk = await _paymentService.calculateTotalMwk(
        adultCount: 0,
        studentCount: 0,
        internationalCount: 0,
        donationAmountUsd: widget.draft.donationAmountUsd,
      );

      final ticketMwk = _finalTotalMwk - _donationMwk;
      final txRef = _paymentService.generateTxRef();

      final fullName =
          '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}';

      await _paymentService.createPendingOrder(
        txRef: txRef,
        visitorName: fullName,
        visitorEmail: _emailController.text.trim(),
        adultCount: widget.draft.adult,
        studentCount: widget.draft.student,
        internationalCount: widget.draft.international,
        donationAmountMwk: _donationMwk,
        ticketAmountMwk: ticketMwk,
        totalAmountMwk: _finalTotalMwk,
        isMonthlyDonation: widget.draft.isMonthlyDonation,
      );

      // Call PayChangu API directly to get checkout URL
      final checkoutUrl = await _paymentService.createPaymentSession(
        txRef: txRef,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        email: _emailController.text.trim(),
        amountMwk: _finalTotalMwk,
        callbackUrl: 'https://mtengatenga-museum.com/payment/callback',
        returnUrl: 'https://mtengatenga-museum.com/payment/return',
      );

      if (!mounted) return;

      // Open checkout URL in a WebView
      final result = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (_) => _PaymentWebViewScreen(
            checkoutUrl: checkoutUrl,
            returnUrl: 'https://mtengatenga-museum.com/payment/return',
          ),
        ),
      );

      if (!mounted) return;

      if (result == 'success') {
        await _onPaymentSuccess(txRef);
      } else if (result == 'cancelled') {
        await _onPaymentCancelled(txRef);
      } else {
        // User pressed back or unknown state — treat as cancelled
        await _onPaymentCancelled(txRef);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment error: $e')),
      );
      setState(() => _state = TicketCheckoutState.paymentMethod);
    }
  }

  Future<void> _onPaymentSuccess(String txRef) async {
    setState(() => _state = TicketCheckoutState.processing);

    final verified = await _paymentService.verifyAndFinaliseOrder(
      txRef: txRef,
      expectedAmountMwk: _finalTotalMwk,
    );

    if (!mounted) return;

    if (verified) {
      setState(() => _state = TicketCheckoutState.success);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Payment verification failed. Please contact support.')),
      );
      setState(() => _state = TicketCheckoutState.paymentMethod);
    }
  }

  Future<void> _onPaymentCancelled(String txRef) async {
    await _paymentService.updateOrderStatus(txRef, 'cancelled');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Payment cancelled.')),
    );
    setState(() => _state = TicketCheckoutState.paymentMethod);
  }
}

// ---------------------------------------------------------------------------
// PayChangu WebView screen — loads checkout URL, detects return URL
// ---------------------------------------------------------------------------

class _PaymentWebViewScreen extends StatefulWidget {
  const _PaymentWebViewScreen({
    required this.checkoutUrl,
    required this.returnUrl,
  });

  final String checkoutUrl;
  final String returnUrl;

  @override
  State<_PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<_PaymentWebViewScreen> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            // Detect when PayChangu redirects to our return URL
            if (request.url.startsWith(widget.returnUrl)) {
              Navigator.of(context).pop('success');
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.checkoutUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Secure Payment'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop('cancelled'),
        ),
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}

// ---------------------------------------------------------------------------
// Step header (unchanged)
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Review step (unchanged)
// ---------------------------------------------------------------------------

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
              const Text('Order Summary',
                  style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text('Adult: ${draft.adult}'),
              Text('Student: ${draft.student}'),
              Text('International: ${draft.international}'),
              const SizedBox(height: 8),
              Text(draft.donationLabel,
                  style: const TextStyle(color: AppColors.primary)),
              const SizedBox(height: 8),
              Text(
                draft.totalLabel,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
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

// ---------------------------------------------------------------------------
// Visitor info step (replaces old _PaymentStep)
// ---------------------------------------------------------------------------

class _VisitorInfoStep extends StatelessWidget {
  const _VisitorInfoStep({
    required this.formKey,
    required this.firstNameController,
    required this.lastNameController,
    required this.emailController,
    required this.onContinue,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController firstNameController;
  final TextEditingController lastNameController;
  final TextEditingController emailController;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        children: [
          TextFormField(
            controller: firstNameController,
            decoration: const InputDecoration(
              labelText: 'First Name',
              border: OutlineInputBorder(),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'First name is required' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: lastNameController,
            decoration: const InputDecoration(
              labelText: 'Last Name',
              border: OutlineInputBorder(),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Last name is required' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email Address',
              border: OutlineInputBorder(),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Email is required';
              final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
              if (!emailRegex.hasMatch(v.trim())) return 'Enter a valid email';
              return null;
            },
          ),
          const Spacer(),
          PrimaryCtaButton(
            label: 'Pay with PayChangu',
            icon: Icons.lock,
            onPressed: onContinue,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Success step (unchanged)
// ---------------------------------------------------------------------------

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
