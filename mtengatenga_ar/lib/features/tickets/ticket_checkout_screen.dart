import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/models/ui_models.dart';
import '../../core/services/auth_state.dart';
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

enum _CheckoutStep { review, visitDate, processing, success }

class _TicketCheckoutScreenState extends State<TicketCheckoutScreen> {
  _CheckoutStep _step = _CheckoutStep.review;

  final _paymentService = PaymentService();
  final _authState = GetIt.instance<AuthStateNotifier>();

  // Visit date — defaults to today
  DateTime _selectedDate = DateTime.now();

  // Calculated at checkout time using live rate
  int _finalTotalMwk = 0;
  int _donationMwk = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      backgroundColor: AppColors.backgroundLight,
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            _StepHeader(step: _step),
            const SizedBox(height: 12),
            Expanded(child: _buildStepBody(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildStepBody(BuildContext context) {
    switch (_step) {
      case _CheckoutStep.review:
        return _ReviewStep(
          draft: widget.draft,
          onContinue: () => setState(() => _step = _CheckoutStep.visitDate),
        );
      case _CheckoutStep.visitDate:
        return _VisitDateStep(
          selectedDate: _selectedDate,
          onDateChanged: (date) => setState(() => _selectedDate = date),
          onContinue: _startProcessing,
        );
      case _CheckoutStep.processing:
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
      case _CheckoutStep.success:
        return _SuccessStep(
          visitDate: _selectedDate,
          onOpenWallet: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const TicketWalletScreen()),
            );
          },
        );
    }
  }

  Future<void> _startProcessing() async {
    setState(() => _step = _CheckoutStep.processing);

    try {
      // Get user details from auth profile
      final profile = _authState.profile;
      final user = _authState.user;
      final fullName = profile?.fullName ?? user?.email ?? 'Visitor';
      final email = profile?.email ?? user?.email ?? '';

      // Split name for PayChangu (requires first/last)
      final nameParts = fullName.split(' ');
      final firstName = nameParts.first;
      final lastName = nameParts.length > 1
          ? nameParts.sublist(1).join(' ')
          : firstName;

      final visitDateStr =
          _selectedDate.toIso8601String().split('T').first;

      // Calculate the real total using live exchange rate
      _finalTotalMwk = await _paymentService.calculateTotalMwk(
        adultCount: widget.draft.adult,
        studentCount: widget.draft.student,
        internationalCount: widget.draft.international,
        donationAmountUsd: widget.draft.donationAmountUsd,
      );

      _donationMwk = await _paymentService.calculateTotalMwk(
        adultCount: 0,
        studentCount: 0,
        internationalCount: 0,
        donationAmountUsd: widget.draft.donationAmountUsd,
      );

      final ticketMwk = _finalTotalMwk - _donationMwk;
      final txRef = _paymentService.generateTxRef();

      await _paymentService.createPendingOrder(
        txRef: txRef,
        visitorName: fullName,
        visitorEmail: email,
        adultCount: widget.draft.adult,
        studentCount: widget.draft.student,
        internationalCount: widget.draft.international,
        donationAmountMwk: _donationMwk,
        ticketAmountMwk: ticketMwk,
        totalAmountMwk: _finalTotalMwk,
        isMonthlyDonation: widget.draft.isMonthlyDonation,
        visitDate: visitDateStr,
      );

      final checkoutUrl = await _paymentService.createPaymentSession(
        txRef: txRef,
        firstName: firstName,
        lastName: lastName,
        email: email,
        amountMwk: _finalTotalMwk,
        callbackUrl: 'https://mtengatenga-museum.com/payment/callback',
        returnUrl: 'https://mtengatenga-museum.com/payment/return',
      );

      if (!mounted) return;

      final result = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (_) => _PaymentWebViewScreen(
            checkoutUrl: checkoutUrl,
            callbackUrl: 'https://mtengatenga-museum.com/payment/callback',
            returnUrl: 'https://mtengatenga-museum.com/payment/return',
          ),
        ),
      );

      if (!mounted) return;

      if (result == 'success') {
        await _onPaymentSuccess(txRef);
      } else {
        await _onPaymentCancelled(txRef);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment error: $e')),
      );
      setState(() => _step = _CheckoutStep.visitDate);
    }
  }

  Future<void> _onPaymentSuccess(String txRef) async {
    setState(() => _step = _CheckoutStep.processing);

    final verified = await _paymentService.verifyAndFinaliseOrder(
      txRef: txRef,
      expectedAmountMwk: _finalTotalMwk,
    );

    if (!mounted) return;

    if (verified) {
      setState(() => _step = _CheckoutStep.success);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Payment verification failed. Please contact support.')),
      );
      setState(() => _step = _CheckoutStep.visitDate);
    }
  }

  Future<void> _onPaymentCancelled(String txRef) async {
    await _paymentService.updateOrderStatus(txRef, 'cancelled');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Payment cancelled.')),
    );
    setState(() => _step = _CheckoutStep.visitDate);
  }
}

// ---------------------------------------------------------------------------
// PayChangu WebView screen
// ---------------------------------------------------------------------------

class _PaymentWebViewScreen extends StatefulWidget {
  const _PaymentWebViewScreen({
    required this.checkoutUrl,
    required this.returnUrl,
    required this.callbackUrl,
  });

  final String checkoutUrl;
  final String returnUrl;
  final String callbackUrl;

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
            if (request.url.startsWith(widget.returnUrl) ||
                request.url.startsWith(widget.callbackUrl)) {
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
// Step header
// ---------------------------------------------------------------------------

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.step});
  final _CheckoutStep step;

  @override
  Widget build(BuildContext context) {
    int index;
    switch (step) {
      case _CheckoutStep.review:
        index = 1;
      case _CheckoutStep.visitDate:
        index = 2;
      case _CheckoutStep.processing:
      case _CheckoutStep.success:
        index = 3;
    }

    return Row(
      children: [
        _StepChip(label: 'Review', active: index >= 1),
        const SizedBox(width: 8),
        _StepChip(label: 'Visit Date', active: index >= 2),
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
// Review step
// ---------------------------------------------------------------------------

class _ReviewStep extends StatefulWidget {
  const _ReviewStep({required this.draft, required this.onContinue});
  final UiTicketOrderDraft draft;
  final VoidCallback onContinue;

  @override
  State<_ReviewStep> createState() => _ReviewStepState();
}

class _ReviewStepState extends State<_ReviewStep> {
  final _paymentService = PaymentService();
  int? _usdToMwk;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRate();
  }

  Future<void> _loadRate() async {
    try {
      final total = await _paymentService.calculateTotalMwk(
        adultCount: 0,
        studentCount: 0,
        internationalCount: 1,
        donationAmountUsd: 0,
      );
      // internationalCount=1 at $10 → total = 10 * rate, so rate = total / 10
      if (mounted) setState(() { _usdToMwk = total ~/ 10; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.draft;
    final rate = _usdToMwk ?? 0;
    final hasInternational = d.international > 0;
    final hasDonation = d.donationAmountUsd > 0;
    final needsRate = hasInternational || hasDonation;

    // Calculate line items
    final adultMwk = d.adult * 2000;
    final studentMwk = d.student * 1000;
    final internationalMwk = d.international * 10 * rate;
    final donationMwk = d.donationAmountUsd * rate;
    final totalMwk = adultMwk + studentMwk + internationalMwk + donationMwk;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: _loading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(color: AppColors.primary),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Order Summary',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 14),

                        // Ticket line items
                        if (d.adult > 0)
                          _LineItem(
                            label: 'Adult × ${d.adult}',
                            detail: '${d.adult} × MWK 2,000',
                            amount: 'MWK ${_formatNum(adultMwk)}',
                          ),
                        if (d.student > 0)
                          _LineItem(
                            label: 'Student × ${d.student}',
                            detail: '${d.student} × MWK 1,000',
                            amount: 'MWK ${_formatNum(studentMwk)}',
                          ),
                        if (hasInternational)
                          _LineItem(
                            label: 'International × ${d.international}',
                            detail: '${d.international} × \$10 × MWK $rate/USD',
                            amount: 'MWK ${_formatNum(internationalMwk)}',
                          ),

                        if (hasDonation) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Divider(height: 1),
                          ),
                          _LineItem(
                            label: 'Donation',
                            detail: '\$${d.donationAmountUsd} × MWK $rate/USD',
                            amount: 'MWK ${_formatNum(donationMwk)}',
                            color: AppColors.primary,
                          ),
                        ],

                        // Exchange rate note
                        if (needsRate && rate > 0) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withAlpha(15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.currency_exchange,
                                    size: 16, color: AppColors.primary),
                                const SizedBox(width: 8),
                                Text(
                                  'Exchange rate: 1 USD = MWK $rate',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Divider(height: 1, thickness: 1.5),
                        ),

                        // Total
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              'MWK ${_formatNum(totalMwk)}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        PrimaryCtaButton(
          label: 'Choose Visit Date',
          onPressed: _loading ? null : widget.onContinue,
        ),
      ],
    );
  }

  String _formatNum(int n) {
    if (n >= 1000) {
      final s = n.toString();
      final buf = StringBuffer();
      for (var i = 0; i < s.length; i++) {
        if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
        buf.write(s[i]);
      }
      return buf.toString();
    }
    return n.toString();
  }
}

class _LineItem extends StatelessWidget {
  const _LineItem({
    required this.label,
    required this.detail,
    required this.amount,
    this.color,
  });
  final String label;
  final String detail;
  final String amount;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: color ?? AppColors.textMain,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: color ?? AppColors.textMain,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Visit Date step (replaces old Visitor Info step)
// ---------------------------------------------------------------------------

class _VisitDateStep extends StatelessWidget {
  const _VisitDateStep({
    required this.selectedDate,
    required this.onDateChanged,
    required this.onContinue,
  });

  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateChanged;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final formatted = DateFormat('EEEE, d MMMM yyyy').format(selectedDate);
    final isToday = DateUtils.isSameDay(selectedDate, DateTime.now());

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
              const Text(
                'When are you visiting?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textMain,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Your ticket is valid for the selected day only.',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
              const SizedBox(height: 16),

              // Selected date display
              GestureDetector(
                onTap: () => _pickDate(context),
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundLight,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(color: AppColors.primary, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today,
                          color: AppColors.primary, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              formatted,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textMain,
                              ),
                            ),
                            if (isToday)
                              const Text(
                                'Today',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const Icon(Icons.edit_calendar,
                          color: AppColors.textMuted, size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Quick-select chips
              Row(
                children: [
                  _DateChip(
                    label: 'Today',
                    selected: isToday,
                    onTap: () => onDateChanged(DateTime.now()),
                  ),
                  const SizedBox(width: 8),
                  _DateChip(
                    label: 'Tomorrow',
                    selected: DateUtils.isSameDay(
                      selectedDate,
                      DateTime.now().add(const Duration(days: 1)),
                    ),
                    onTap: () => onDateChanged(
                      DateTime.now().add(const Duration(days: 1)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _DateChip(
                    label: 'Pick Date',
                    selected: false,
                    onTap: () => _pickDate(context),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Spacer(),
        PrimaryCtaButton(
          label: 'Pay with PayChangu',
          icon: Icons.lock,
          onPressed: onContinue,
        ),
      ],
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.surfaceCard,
              onSurface: AppColors.textMain,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) onDateChanged(picked);
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withAlpha(25)
              : AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.surfaceBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? AppColors.primary : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Success step
// ---------------------------------------------------------------------------

class _SuccessStep extends StatelessWidget {
  const _SuccessStep({required this.visitDate, required this.onOpenWallet});
  final DateTime visitDate;
  final VoidCallback onOpenWallet;

  @override
  Widget build(BuildContext context) {
    final formatted = DateFormat('EEEE, d MMMM yyyy').format(visitDate);

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
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primary.withAlpha(20),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.calendar_today,
                  size: 14, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                'Valid for $formatted',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        PrimaryCtaButton(label: 'Open My Tickets', onPressed: onOpenWallet),
      ],
    );
  }
}
