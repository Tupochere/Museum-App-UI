import 'dart:convert';
import 'dart:math';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class PaymentService {
  PaymentService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String get _secretKey => dotenv.env['PAYCHANGU_SECRET_KEY'] ?? '';
  bool get _isTestMode => dotenv.env['PAYCHANGU_TEST_MODE'] == 'true';

  String get _baseUrl => _isTestMode
      ? 'https://api.paychangu.com'
      : 'https://api.paychangu.com';

  /// Generates a unique transaction reference.
  String generateTxRef() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rand = Random();
    final suffix =
        List.generate(4, (_) => chars[rand.nextInt(chars.length)]).join();
    return 'mtg-${DateTime.now().millisecondsSinceEpoch}-$suffix';
  }

  /// Fetches the USD to MWK exchange rate from app_config.
  Future<int> _getUsdToMwkRate() async {
    final row = await _client
        .from('app_config')
        .select('value')
        .eq('key', 'usd_to_mwk_rate')
        .single();
    return int.parse(row['value'] as String);
  }

  /// Returns total in MWK (tickets + donation).
  /// USD amounts use the 'usd_to_mwk_rate' from app_config.
  Future<int> calculateTotalMwk({
    required int adultCount,
    required int studentCount,
    required int internationalCount,
    required int donationAmountUsd,
  }) async {
    final rate = await _getUsdToMwkRate();

    final adultMwk = adultCount * 2000;
    final studentMwk = studentCount * 1000;
    final internationalMwk = internationalCount * 10 * rate;
    final donationMwk = donationAmountUsd * rate;

    return adultMwk + studentMwk + internationalMwk + donationMwk;
  }

  /// Creates a pending order record in Supabase.
  /// Returns the generated tx_ref.
  Future<String> createPendingOrder({
    required String txRef,
    required String visitorName,
    required String visitorEmail,
    required int adultCount,
    required int studentCount,
    required int internationalCount,
    required int donationAmountMwk,
    required int ticketAmountMwk,
    required int totalAmountMwk,
    required bool isMonthlyDonation,
  }) async {
    await _client.from('ticket_orders').insert({
      'tx_ref': txRef,
      'visitor_name': visitorName,
      'visitor_email': visitorEmail,
      'adult_count': adultCount,
      'student_count': studentCount,
      'international_count': internationalCount,
      'donation_amount_mwk': donationAmountMwk,
      'ticket_amount_mwk': ticketAmountMwk,
      'total_amount_mwk': totalAmountMwk,
      'currency': 'MWK',
      'payment_status': 'pending',
      'is_monthly_donation': isMonthlyDonation,
    });

    // If there's a donation, also insert into donations table
    if (donationAmountMwk > 0) {
      await _client.from('donations').insert({
        'tx_ref': txRef,
        'donor_name': visitorName,
        'donor_email': visitorEmail,
        'amount_mwk': donationAmountMwk,
        'is_monthly': isMonthlyDonation,
        'payment_status': 'pending',
      });
    }

    return txRef;
  }

  /// Calls PayChangu API directly to create a hosted payment session.
  /// Returns the checkout URL to open in a WebView.
  /// This bypasses the SDK's launchPayment which has a 201 status bug.
  Future<String> createPaymentSession({
    required String txRef,
    required String firstName,
    required String lastName,
    required String email,
    required int amountMwk,
    required String callbackUrl,
    required String returnUrl,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/payment'),
      headers: {
        'Authorization': 'Bearer $_secretKey',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'tx_ref': txRef,
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'currency': 'MWK',
        'amount': amountMwk,
        'callback_url': callbackUrl,
        'return_url': returnUrl,
      }),
    );

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = body['data'] as Map<String, dynamic>?;
      final checkoutUrl = data?['checkout_url'] as String?;
      if (checkoutUrl != null && checkoutUrl.isNotEmpty) {
        return checkoutUrl;
      }
      throw Exception('No checkout_url in response');
    }

    throw Exception(
      'PayChangu API error ${response.statusCode}: ${body['message'] ?? response.body}',
    );
  }

  /// Verifies a transaction via the PayChangu API.
  /// Returns true if the payment is confirmed successful.
  Future<bool> verifyTransaction(String txRef) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/verify-payment/$txRef'),
        headers: {
          'Authorization': 'Bearer $_secretKey',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final status = body['status'] as String?;
        return status == 'success';
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Verifies a transaction after onSuccess callback.
  /// Updates the ticket_orders record with payment_status = 'success'.
  /// Generates and stores qr_code_data.
  Future<bool> verifyAndFinaliseOrder({
    required String txRef,
    required int expectedAmountMwk,
  }) async {
    try {
      await verifyTransaction(txRef);

      // Build QR code data
      final orderRow = await _client
          .from('ticket_orders')
          .select()
          .eq('tx_ref', txRef)
          .single();

      final ticketParts = <String>[];
      if ((orderRow['adult_count'] as int) > 0) {
        ticketParts.add('${orderRow['adult_count']} Adult');
      }
      if ((orderRow['student_count'] as int) > 0) {
        ticketParts.add('${orderRow['student_count']} Student');
      }
      if ((orderRow['international_count'] as int) > 0) {
        ticketParts.add('${orderRow['international_count']} International');
      }

      final qrData = jsonEncode({
        'museum': 'Mtengatenga Cultural Museum',
        'tx_ref': txRef,
        'visitor': orderRow['visitor_name'],
        'tickets': ticketParts.join(', '),
        'date': DateTime.now().toIso8601String().split('T').first,
        'valid': true,
      });

      // Update order to success
      await _client.from('ticket_orders').update({
        'payment_status': 'success',
        'qr_code_data': qrData,
      }).eq('tx_ref', txRef);

      // Update donation status if applicable
      if ((orderRow['donation_amount_mwk'] as int) > 0) {
        await _client.from('donations').update({
          'payment_status': 'success',
        }).eq('tx_ref', txRef);
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  /// Marks order as cancelled or failed.
  Future<void> updateOrderStatus(String txRef, String status) async {
    await _client.from('ticket_orders').update({
      'payment_status': status,
    }).eq('tx_ref', txRef);

    // Also update donation if exists
    await _client.from('donations').update({
      'payment_status': status,
    }).eq('tx_ref', txRef);
  }

  /// Fetches successful orders for the wallet screen.
  Future<List<Map<String, dynamic>>> getCompletedOrders() async {
    final rows = await _client
        .from('ticket_orders')
        .select()
        .eq('payment_status', 'success')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }
}
