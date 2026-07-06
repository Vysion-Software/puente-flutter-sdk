import 'dart:async';

import 'package:clock/clock.dart';

import '../exceptions/stale_quote_exception.dart';
import '../models/quote.dart';
import '../models/transfer.dart';
import '../models/transfer_intent.dart';
import '../models/transfer_receipt.dart';
import '../transport/puente_request.dart';
import 'resource_base.dart';

/// `POST /v1/transfers` — execute a quoted transfer.
/// `GET /v1/transfers/:id` — retrieve current state.
/// `GET /v1/transfers/:id/receipt` — settlement receipt (once settled).
/// `GET /v1/transfers` — list recent transfers.
/// `POST /v1/transfers/:id/cancel` — cancel before settlement.
///
/// **Idempotency is mandatory** for `create` and `cancel`. The SDK
/// generates a UUIDv4 if the caller doesn't pass one; reusing the same
/// key for two equal-body requests is safe (the server returns the
/// cached response).
class TransfersResource extends ResourceBase {
  /// Build a [TransfersResource].
  TransfersResource(super.transport);

  /// Create a transfer from a quote id.
  ///
  /// Prefer [createFromQuote] when the caller still has the [Quote] object —
  /// that variant adds a client-side expiry guard so callers receive a typed
  /// [StaleQuoteException] without a round-trip to the server.
  ///
  /// For P2P (same-region) transfers the backend requires both
  /// [senderUserId] and [receiverUserId]; for cross-border transfers it
  /// requires an 18-digit [receiverClabe].
  Future<Transfer> create({
    required String quoteId,
    required String receiverClabe,
    required String receiverName,
    String? memo,
    String? senderAccountId,
    String? senderUserId,
    String? receiverUserId,
    String? idempotencyKey,
  }) async {
    final response = await request(PuenteRequest(
      method: 'POST',
      path: '/transfers',
      body: <String, dynamic>{
        'quote_id': quoteId,
        'receiver_clabe': receiverClabe,
        'receiver_name': receiverName,
        if (memo != null) 'memo': memo,
        if (senderAccountId != null) 'sender_account_id': senderAccountId,
        if (senderUserId != null) 'sender_user_id': senderUserId,
        if (receiverUserId != null) 'receiver_user_id': receiverUserId,
      },
      idempotencyKey: idempotencyKey ?? newIdempotencyKey(),
    ));
    return Transfer.fromJson(response.jsonObject);
  }

  /// Create a transfer from a [TransferIntent] — the typed request body
  /// for `POST /v1/transfers`.
  ///
  /// The intent is the only thing the client submits; every amount, fee,
  /// and rate comes from the backend quote the intent references, so
  /// there is nothing money-shaped for a client to get wrong.
  Future<Transfer> createFromIntent(
    TransferIntent intent, {
    String? idempotencyKey,
  }) async {
    final response = await request(PuenteRequest(
      method: 'POST',
      path: '/transfers',
      body: intent.toJson(),
      idempotencyKey: idempotencyKey ?? newIdempotencyKey(),
    ));
    return Transfer.fromJson(response.jsonObject);
  }

  /// Same as [create] but takes the full [Quote] so the SDK can short-circuit
  /// stale quotes before the network hop.
  ///
  /// Throws [StaleQuoteException] if [quote.isExpired] is true at call time —
  /// callers should re-quote and retry with a fresh idempotency key derived
  /// from the user gesture, not from a clock.
  Future<Transfer> createFromQuote({
    required Quote quote,
    required String receiverClabe,
    required String receiverName,
    String? memo,
    String? senderAccountId,
    String? idempotencyKey,
  }) async {
    final DateTime now = clock.now().toUtc();
    if (quote.isExpired(now)) {
      throw StaleQuoteException.clientGuard(
        quoteId: quote.id,
        expiresAt: quote.expiresAt,
        detectedAt: now,
      );
    }
    return create(
      quoteId: quote.id,
      receiverClabe: receiverClabe,
      receiverName: receiverName,
      memo: memo,
      senderAccountId: senderAccountId,
      idempotencyKey: idempotencyKey,
    );
  }

  /// Retrieve a transfer by id.
  Future<Transfer> retrieve(String id) async {
    final response = await request(PuenteRequest(
      method: 'GET',
      path: '/transfers/$id',
    ));
    return Transfer.fromJson(response.jsonObject);
  }

  /// Retrieve the settlement receipt for a settled transfer —
  /// `GET /v1/transfers/{id}/receipt`.
  ///
  /// The backend only issues receipts for transfers in the `settled`
  /// state; before that it answers `409` with an error of the form
  /// `receipt_unavailable: …`, surfaced here as an `ApiException`.
  Future<TransferReceipt> receipt(String transferId) async {
    final response = await request(PuenteRequest(
      method: 'GET',
      path: '/transfers/$transferId/receipt',
    ));
    return TransferReceipt.fromJson(response.jsonObject);
  }

  /// List recent transfers, newest first.
  ///
  /// Page with [startingAfter] (the last transfer id from the previous
  /// page). [limit] is capped server-side at 100.
  Future<List<Transfer>> list({int limit = 20, String? startingAfter}) async {
    final response = await request(PuenteRequest(
      method: 'GET',
      path: '/transfers',
      query: <String, String>{
        'limit': limit.toString(),
        if (startingAfter != null) 'starting_after': startingAfter,
      },
    ));
    final body = response.jsonObject;
    final data = body['data'] as List<dynamic>? ?? const <dynamic>[];
    return data
        .whereType<Map<String, dynamic>>()
        .map(Transfer.fromJson)
        .toList(growable: false);
  }

  /// Cancel a transfer before it reaches a terminal state.
  ///
  /// Returns the canonical post-cancel doc. Throws `ApiException` with
  /// code `terminal_state` (409) when the transfer is already settled
  /// or failed.
  Future<Transfer> cancel(String id, {String? idempotencyKey}) async {
    final response = await request(PuenteRequest(
      method: 'POST',
      path: '/transfers/$id/cancel',
      idempotencyKey: idempotencyKey ?? newIdempotencyKey(),
    ));
    return Transfer.fromJson(response.jsonObject);
  }

  /// Stream the lifecycle of a transfer by polling [retrieve] on a
  /// jittered cadence until a terminal state is reached.
  ///
  /// Useful for UI screens that want to display "sending… processing…
  /// settled!" without writing the timer logic by hand.
  ///
  /// The stream emits each distinct state and completes when the
  /// transfer reaches [TransferStatus.settled], [TransferStatus.failed],
  /// or [TransferStatus.cancelled]. It also completes after [timeout]
  /// even if no terminal state is reached, so a stuck server doesn't
  /// leak a subscription.
  Stream<Transfer> watch(
    String id, {
    Duration pollInterval = const Duration(seconds: 1),
    Duration timeout = const Duration(minutes: 2),
  }) async* {
    final deadline = clock.now().add(timeout);
    TransferStatus? lastStatus;
    while (clock.now().isBefore(deadline)) {
      final t = await retrieve(id);
      if (lastStatus != t.status) {
        yield t;
        lastStatus = t.status;
      }
      if (t.status.isTerminal) return;
      await Future<void>.delayed(pollInterval);
    }
  }
}
