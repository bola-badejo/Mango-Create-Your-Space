// Client for the MangoChain Cloud Functions.
//
// The app never writes balances. It asks the server, which validates every
// request against the ledger rules. Calls use the HTTPS callable protocol
// directly with the user's Firebase ID token, so no extra package is needed.
import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;

/// A ledger request was refused or failed. [message] is safe to show.
class LedgerException implements Exception {
  LedgerException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => message;
}

class MangoLedgerClient {
  MangoLedgerClient._();

  static final MangoLedgerClient instance = MangoLedgerClient._();

  /// Region the functions are deployed to (Firebase's default).
  static const String region = 'us-central1';

  Uri _endpoint(String name) {
    final projectId = Firebase.app().options.projectId;
    return Uri.parse('https://$region-$projectId.cloudfunctions.net/$name');
  }

  Future<Map<String, dynamic>> call(
    String name, [
    Map<String, dynamic> data = const {},
  ]) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw LedgerException('unauthenticated', 'Sign in to use your wallet.');
    }
    final token = await user.getIdToken();
    if (token == null) {
      throw LedgerException('unauthenticated', 'Sign in again to use your wallet.');
    }

    final http.Response response;
    try {
      response = await http
          .post(
            _endpoint(name),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'data': data}),
          )
          .timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw LedgerException('deadline-exceeded',
          'The wallet service took too long to answer. Check your connection and try again.');
    } catch (_) {
      throw LedgerException('unavailable',
          "Couldn't reach the wallet service. Check your connection and try again.");
    }

    Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw LedgerException('internal',
          'Unexpected response from the wallet service (${response.statusCode}).');
    }
    final error = body['error'];
    if (error is Map) {
      throw LedgerException(
        (error['status'] ?? 'internal').toString().toLowerCase(),
        (error['message'] ?? 'The wallet request failed.').toString(),
      );
    }
    final result = body['result'];
    if (result is Map<String, dynamic>) return result;
    return {'value': result};
  }

  Future<Map<String, dynamic>> openAccount() => call('ledgerOpenAccount');

  Future<Map<String, dynamic>> checkIn() => call('ledgerCheckIn');

  Future<Map<String, dynamic>> startSession({
    required String contentType,
    required String contentId,
    String? spaceId,
  }) =>
      call('ledgerStartSession', {
        'contentType': contentType,
        'contentId': contentId,
        if (spaceId != null) 'spaceId': spaceId,
      });

  Future<Map<String, dynamic>> endSession() => call('ledgerEndSession');

  /// [amountUnits] is in base units (1 MNG = 100,000,000).
  Future<Map<String, dynamic>> transfer({
    required String to,
    required BigInt amountUnits,
    String? memo,
    required String idempotencyKey,
  }) =>
      call('ledgerTransfer', {
        'to': to,
        'amount': amountUnits.toString(),
        if (memo != null && memo.isNotEmpty) 'memo': memo,
        'idempotencyKey': idempotencyKey,
      });

  Future<Map<String, dynamic>> proof(String txId) =>
      call('ledgerProof', {'txId': txId});
}
