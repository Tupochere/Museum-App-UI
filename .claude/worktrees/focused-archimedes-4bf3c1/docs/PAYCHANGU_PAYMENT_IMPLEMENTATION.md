# PayChangu Payment Integration Plan
> For Claude Code — Read this fully before making any changes.
> You have Supabase MCP access — use it to run all SQL migrations directly.

---

## What Already Exists (Do NOT Break)

### Payment-Related Screens

| File | Role | Current State |
|------|------|---------------|
| `lib/features/tickets/tickets_donation_screen.dart` | Main screen — ticket types + donation amount picker | UI complete, no real payment |
| `lib/features/tickets/ticket_checkout_screen.dart` | 3-step checkout: Review → Payment Method → Success | UI complete, uses `Timer` fake delay |
| `lib/features/tickets/ticket_wallet_screen.dart` | Shows purchased tickets as QR codes | UI complete, shows hardcoded mock ticket |
| `lib/features/tickets/tickets_hub_screen.dart` | Entry hub to tickets/donation section | Exists, not read — preserve as-is |

### Key Model
`lib/core/models/ui_models.dart` contains `UiTicketOrderDraft`:
```dart
class UiTicketOrderDraft {
  final int adult;           // count of adult tickets
  final int student;         // count of student tickets
  final int international;   // count of international tickets
  final String donationLabel; // e.g. "+ $5.00 donation"
  final String totalLabel;   // e.g. "MWK 4000"
}
```
Also contains `TicketCheckoutState` enum: `review, paymentMethod, processing, success`.

### Current Fake Flow
`ticket_checkout_screen.dart` → `_startProcessing()` uses `Timer(2s)` to fake success.
This is what gets replaced with the real PayChangu flow.

### Existing Dependencies
```yaml
supabase_flutter: ^2.0.0
flutter_dotenv: ^5.1.0
shared_preferences: ^2.2.2
connectivity_plus: ^5.0.2
```

---

## Pricing Reference (from tickets_donation_screen.dart)

| Ticket Type | Price |
|-------------|-------|
| Adult | MWK 2,000 |
| Student | MWK 1,000 |
| International | $10 USD (convert to MWK at checkout) |
| Donation presets | $5 / $10 / $20 USD |

> **Important:** PayChangu works in MWK. All USD amounts (international ticket, donations) must be converted to MWK before sending to PayChangu. Use a fixed exchange rate stored in Supabase `app_config` table (see Step 1d below).

---

## Step 1: Supabase Database Setup (Use Supabase MCP)

Run all SQL below using Supabase MCP. Do not skip any step.

### 1a. Create `ticket_orders` table

```sql
CREATE TABLE IF NOT EXISTS ticket_orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tx_ref TEXT UNIQUE NOT NULL,
  visitor_name TEXT NOT NULL,
  visitor_email TEXT NOT NULL,
  adult_count INTEGER DEFAULT 0,
  student_count INTEGER DEFAULT 0,
  international_count INTEGER DEFAULT 0,
  donation_amount_mwk INTEGER DEFAULT 0,
  ticket_amount_mwk INTEGER NOT NULL,
  total_amount_mwk INTEGER NOT NULL,
  currency TEXT DEFAULT 'MWK',
  payment_status TEXT DEFAULT 'pending'
    CHECK (payment_status IN ('pending', 'processing', 'success', 'failed', 'cancelled')),
  payment_channel TEXT,
  paychangu_charge_id TEXT,
  is_monthly_donation BOOLEAN DEFAULT false,
  visit_date DATE DEFAULT CURRENT_DATE,
  qr_code_data TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ticket_orders_tx_ref ON ticket_orders(tx_ref);
CREATE INDEX IF NOT EXISTS idx_ticket_orders_email ON ticket_orders(visitor_email);
CREATE INDEX IF NOT EXISTS idx_ticket_orders_status ON ticket_orders(payment_status);
```

### 1b. Create `donations` table

```sql
CREATE TABLE IF NOT EXISTS donations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tx_ref TEXT UNIQUE NOT NULL REFERENCES ticket_orders(tx_ref),
  donor_name TEXT,
  donor_email TEXT,
  amount_mwk INTEGER NOT NULL,
  is_monthly BOOLEAN DEFAULT false,
  payment_status TEXT DEFAULT 'pending',
  created_at TIMESTAMPTZ DEFAULT now()
);
```

### 1c. Enable Row Level Security

```sql
ALTER TABLE ticket_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE donations ENABLE ROW LEVEL SECURITY;

-- Allow anonymous inserts (visitors buying tickets without login)
CREATE POLICY "Public insert ticket_orders" ON ticket_orders
  FOR INSERT WITH CHECK (true);

-- Allow reading own orders by email (for wallet screen)
CREATE POLICY "Read own ticket_orders" ON ticket_orders
  FOR SELECT USING (true);

CREATE POLICY "Public insert donations" ON donations
  FOR INSERT WITH CHECK (true);

CREATE POLICY "Read own donations" ON donations
  FOR SELECT USING (true);
```

### 1d. Create `app_config` table (for exchange rate + PayChangu mode)

```sql
CREATE TABLE IF NOT EXISTS app_config (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  description TEXT,
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Seed config values
INSERT INTO app_config (key, value, description) VALUES
  ('usd_to_mwk_rate', '1800', 'USD to MWK exchange rate for ticket pricing'),
  ('paychangu_mode', 'test', 'PayChangu mode: test or live'),
  ('museum_callback_url', 'https://mtengatenga-museum.com/payment/callback', 'PayChangu callback URL'),
  ('museum_return_url', 'https://mtengatenga-museum.com/payment/return', 'PayChangu return URL after payment')
ON CONFLICT (key) DO NOTHING;
```

### 1e. Create a database function to auto-update `updated_at`

```sql
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_ticket_orders_updated_at
  BEFORE UPDATE ON ticket_orders
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
```

---

## Step 2: Add PayChangu Flutter SDK

Add to `mtengatenga_ar/pubspec.yaml` under `dependencies`:

```yaml
paychangu_flutter: ^0.0.3
```

Run `flutter pub get` after adding.

The `paychangu_flutter` SDK depends on `webview_flutter` and `http` — these will be pulled in automatically.

---

## Step 3: Add Environment Variables

Add to `mtengatenga_ar/.env`:
```
PAYCHANGU_SECRET_KEY=your_paychangu_secret_key_here
PAYCHANGU_TEST_MODE=true
```

Also add these keys to `mtengatenga_ar/.env.example` (without values):
```
PAYCHANGU_SECRET_KEY=
PAYCHANGU_TEST_MODE=true
```

Get your secret key from: https://dashboard.paychangu.com → Settings → API & Webhooks.

---

## Step 4: Create PayChangu Payment Service

**File to create:** `mtengatenga_ar/lib/services/payment_service.dart`

This service handles:
- Generating unique `tx_ref` per transaction
- Calculating total MWK from ticket counts + donation
- Creating a `ticket_orders` record in Supabase (status: `pending`) BEFORE launching payment
- Building a `PaymentRequest` for the PayChangu SDK
- Verifying the transaction after `onSuccess` callback
- Updating the `ticket_orders` record in Supabase with final status
- Generating a QR code data string for the digital ticket

### Class structure:

```dart
class PaymentService {
  PaymentService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  // Generates a unique transaction reference
  String generateTxRef() =>
      'mtg-${DateTime.now().millisecondsSinceEpoch}-${...random 4 chars}';

  // Returns total in MWK (tickets + donation)
  // USD amounts use the 'usd_to_mwk_rate' from app_config
  Future<int> calculateTotalMwk({
    required int adultCount,
    required int studentCount,
    required int internationalCount,
    required int donationAmountUsd, // 0 if no donation
  }) async { ... }

  // Creates a pending order record in Supabase
  // Returns the generated tx_ref
  Future<String> createPendingOrder({
    required String txRef,
    required String visitorName,
    required String visitorEmail,
    required int adultCount,
    required int studentCount,
    required int internationalCount,
    required int donationAmountMwk,
    required int totalAmountMwk,
    required bool isMonthlyDonation,
  }) async { ... }

  // Verifies a transaction with PayChangu after onSuccess
  // Updates the ticket_orders record with payment_status = 'success'
  // Generates and stores qr_code_data
  Future<bool> verifyAndFinaliseOrder({
    required PayChangu paychangu,
    required String txRef,
    required int expectedAmountMwk,
  }) async { ... }

  // Marks order as cancelled or failed
  Future<void> updateOrderStatus(String txRef, String status) async { ... }

  // Fetches successful orders for the wallet screen
  Future<List<Map<String, dynamic>>> getCompletedOrders() async { ... }
}
```

---

## Step 5: Update `UiTicketOrderDraft`

**File:** `mtengatenga_ar/lib/core/models/ui_models.dart`

Expand `UiTicketOrderDraft` to carry the data needed for payment:

```dart
class UiTicketOrderDraft {
  const UiTicketOrderDraft({
    required this.adult,
    required this.student,
    required this.international,
    required this.donationLabel,
    required this.totalLabel,
    // NEW fields:
    this.donationAmountUsd = 0,
    this.totalAmountMwk = 0,
    this.isMonthlyDonation = false,
  });

  final int adult;
  final int student;
  final int international;
  final String donationLabel;
  final String totalLabel;
  // NEW:
  final int donationAmountUsd;
  final int totalAmountMwk;
  final bool isMonthlyDonation;
}
```

Update `tickets_donation_screen.dart` to populate these new fields when constructing the draft and navigating to checkout.

---

## Step 6: Wire `ticket_checkout_screen.dart` to Real PayChangu

**File:** `mtengatenga_ar/lib/features/tickets/ticket_checkout_screen.dart`

This is the most important change. Here is exactly what to replace and how:

### 6a. Add a visitor info step

The payment method currently shows two radio options (`PayChangu (Placeholder)` and `Card / Mobile Money (Placeholder)`). Replace the entire `_PaymentStep` widget with a real visitor info form:

**New `_PaymentStep` collects:**
- First name (required)
- Last name (required)  
- Email address (required, validated)
- A confirm button labelled "Pay with PayChangu"

Store collected info in `_TicketCheckoutScreenState` as `String _firstName`, `_lastName`, `_email`.

### 6b. Replace `_startProcessing()` entirely

Remove the `Timer` fake. Replace with this real flow:

```
1. setState → processing
2. PaymentService.createPendingOrder(...) → get txRef
3. Build PaymentRequest using:
   - txRef from step 2
   - firstName, lastName, email from visitor form
   - currency: Currency.MWK
   - amount: draft.totalAmountMwk
   - callbackUrl: fetched from app_config or hardcoded fallback
   - returnUrl: same
4. Navigate to PayChangu WebView:
   Navigator.push → Scaffold with paychangu.launchPayment(...)
     onSuccess: _onPaymentSuccess(txRef, response)
     onError: _onPaymentError(txRef, error)
     onCancel: _onPaymentCancelled(txRef)
5. On success callback:
   - PaymentService.verifyAndFinaliseOrder(txRef, expectedAmount)
   - If verified: setState → success
   - If not verified: show error snackbar, setState → paymentMethod
```

### 6c. Keep the 3-step header `_StepHeader` working

The step header chip labels can stay the same. The `paymentMethod` step now acts as the info collection step. No visual change needed.

### 6d. Keep `_SuccessStep` and navigation to `TicketWalletScreen` exactly as-is

---

## Step 7: Update `TicketWalletScreen` to Show Real Tickets

**File:** `mtengatenga_ar/lib/features/tickets/ticket_wallet_screen.dart`

Currently shows a hardcoded mock ticket. Update to:

1. On `initState`, call `PaymentService.getCompletedOrders()`
2. If orders exist, display each as a ticket card with:
   - Ticket type summary (e.g. "1 Adult • 1 Student")
   - Visit date
   - QR code widget built from `qr_code_data` field
   - Payment channel (e.g. "Airtel Money")
3. If no orders, show the existing `AppEmptyState` widget (already in the file)
4. Show a `CircularProgressIndicator` while loading

> For the QR code display, use the `qr_flutter` package (add to pubspec.yaml):
> ```yaml
> qr_flutter: ^4.1.0
> ```

---

## Step 8: Update `tickets_donation_screen.dart` — Fix Draft Construction

**File:** `mtengatenga_ar/lib/features/tickets/tickets_donation_screen.dart`

The `BUY NOW` button currently constructs a `UiTicketOrderDraft` with only basic string fields. Update it to also set the new fields:

```dart
final draft = UiTicketOrderDraft(
  adult: adult,
  student: student,
  international: international,
  donationLabel: donationLabel,
  totalLabel: 'MWK ${ticketTotalMWK.toString()}',
  // NEW:
  donationAmountUsd: _donationAmountUsd(), // helper that reads _customDonation or preset
  totalAmountMwk: ticketTotalMWK,          // already computed as int
  isMonthlyDonation: monthly,
);
```

Add a helper `int _donationAmountUsd()` that returns:
- Custom donation value if `_customDonation.text` is a valid number
- 5 if `donationPreset == 0`
- 10 if `donationPreset == 1`
- 20 if `donationPreset == 2`

Note: The `ticketTotalMWK` getter in this file does NOT yet include the donation conversion. That final MWK total (tickets + donation in MWK) will be calculated by `PaymentService.calculateTotalMwk()` at checkout time using the live rate from Supabase. So pass the raw donation USD amount in the draft and let `PaymentService` do the conversion.

---

## Step 9: PayChangu SDK Usage Pattern

Here is the exact integration pattern to follow in `ticket_checkout_screen.dart`:

```dart
import 'package:paychangu_flutter/paychangu_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Initialise once in the State class:
final _paychangu = PayChangu(
  PayChanguConfig(
    secretKey: dotenv.env['PAYCHANGU_SECRET_KEY'] ?? '',
    isTestMode: dotenv.env['PAYCHANGU_TEST_MODE'] == 'true',
  ),
);

// Build the payment request:
final request = PaymentRequest(
  txRef: txRef,                          // from PaymentService.createPendingOrder
  firstName: _firstName,
  lastName: _lastName,
  email: _email,
  currency: Currency.MWK,
  amount: draft.totalAmountMwk,          // integer MWK
  callbackUrl: 'https://mtengatenga-museum.com/payment/callback',
  returnUrl: 'https://mtengatenga-museum.com/payment/return',
);

// Launch as a new route (WebView):
Navigator.of(context).push(
  MaterialPageRoute(
    builder: (_) => Scaffold(
      appBar: AppBar(title: const Text('Secure Payment')),
      body: _paychangu.launchPayment(
        request: request,
        onSuccess: (response) => _onPaymentSuccess(txRef, response),
        onError: (error) => _onPaymentError(txRef, error),
        onCancel: () => _onPaymentCancelled(txRef),
      ),
    ),
  ),
);
```

> **Always verify after `onSuccess`** — call `_paychangu.verifyTransaction(txRef)` and validate amount, currency and txRef match before calling the order a success.

---

## Step 10: QR Code Data Format

When generating `qr_code_data` in `PaymentService.verifyAndFinaliseOrder()`, use this JSON string format:

```json
{
  "museum": "Mtengatenga Cultural Museum",
  "tx_ref": "mtg-1234567890-abcd",
  "visitor": "John Doe",
  "tickets": "1 Adult, 1 Student",
  "date": "2026-03-26",
  "valid": true
}
```

Store it as a string in `ticket_orders.qr_code_data`. Display it in `TicketWalletScreen` using the `qr_flutter` package's `QrImageView` widget.

---

## File Summary — What Claude Code Should Create/Modify

| Action | File | What to do |
|--------|------|-----------|
| **CREATE** | `lib/services/payment_service.dart` | New PayChangu service |
| **MODIFY** | `lib/core/models/ui_models.dart` | Add fields to `UiTicketOrderDraft` |
| **MODIFY** | `lib/features/tickets/ticket_checkout_screen.dart` | Replace fake Timer with real PayChangu flow + visitor info form |
| **MODIFY** | `lib/features/tickets/tickets_donation_screen.dart` | Update draft construction to populate new fields |
| **MODIFY** | `lib/features/tickets/ticket_wallet_screen.dart` | Load real tickets from Supabase, display QR |
| **MODIFY** | `mtengatenga_ar/pubspec.yaml` | Add `paychangu_flutter` and `qr_flutter` |
| **MODIFY** | `mtengatenga_ar/.env` | Add `PAYCHANGU_SECRET_KEY` and `PAYCHANGU_TEST_MODE` |
| **DB via MCP** | Supabase | Run all SQL from Step 1 |

---

## Implementation Order

Follow this exact order to avoid breaking the app:

1. Run all Supabase SQL (Step 1) using Supabase MCP
2. Add `paychangu_flutter` and `qr_flutter` to `pubspec.yaml` (Step 2)
3. Add env vars to `.env` (Step 3)
4. Create `payment_service.dart` (Step 4)
5. Update `UiTicketOrderDraft` in `ui_models.dart` (Step 5)
6. Update `tickets_donation_screen.dart` draft construction (Step 8 — do before Step 6 so types match)
7. Wire `ticket_checkout_screen.dart` to real PayChangu (Step 6)
8. Update `ticket_wallet_screen.dart` to show real tickets (Step 7)

---

## Testing Checklist

After implementation, test with PayChangu **test mode** (`isTestMode: true`):

- [ ] BUY NOW button on `tickets_donation_screen` navigates to checkout with correct totals
- [ ] Review step shows correct adult/student/international counts and donation
- [ ] Payment step collects first name, last name, email with validation
- [ ] "Pay with PayChangu" opens the PayChangu WebView
- [ ] After test payment in WebView, `onSuccess` fires and transaction is verified
- [ ] Supabase `ticket_orders` row updated from `pending` → `success`
- [ ] `TicketCheckoutScreen` transitions to success step (NOT fake timer)
- [ ] "Open My Tickets" navigates to wallet showing the real purchased ticket
- [ ] QR code renders correctly in wallet screen
- [ ] Cancelling payment WebView returns user to payment step (not crash)
- [ ] Failed payment shows an error snackbar and returns to payment step
- [ ] `ticket_orders` row updated to `cancelled` or `failed` on non-success

---

## Important Notes for Claude Code

- **Do NOT change the UI in `tickets_donation_screen.dart`** — it is visually polished. Only update the draft construction at the BUY NOW press.
- **Do NOT change the step header or success screen** in `ticket_checkout_screen.dart` — only replace the fake `_startProcessing()` logic.
- Use `AppColors.primary` (terracotta `0xFFD2691E`) for any new UI elements to stay consistent with the existing design.
- The app uses `flutter_dotenv` for env vars — access keys using `dotenv.env['KEY_NAME']`.
- `SupabaseService` pattern in `lib/services/supabase_service.dart` shows the correct service pattern — follow the same constructor injection style for `PaymentService`.
- International tickets are priced in USD in the UI but always charged in MWK to PayChangu — the conversion happens in `PaymentService.calculateTotalMwk()`.
- PayChangu `amount` field is an **integer** (not double) — always pass MWK as a whole number.
- Start in test mode. Switch to live by setting `PAYCHANGU_TEST_MODE=false` in `.env` and updating the `paychangu_mode` value in Supabase `app_config`.
