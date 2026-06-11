import 'dart:async';

import 'package:clock/clock.dart';

import '../models/transfer.dart';
import '../transport/puente_request.dart';
import 'resource_base.dart';

/// `POST /v1/transfers` — execute a quoted transfer.
/// `GET /v1/transfers/:id` — retrieve current state.
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

  /// Create a transfer from a quote.
  Future<Transfer> create({
    required String quoteId,
    required String receiverClabe,
    required String receiverName,
    String? memo,
    String? senderAccountId,
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
      },
      idempotencyKey: idempotencyKey ?? newIdempotencyKey(),
    ));
    return Transfer.fromJson(response.jsonObject);
  }

  /// Retrieve a transfer by id.
  Future<Transfer> retrieve(String id) async {
    final response = await request(PuenteRequest(
      method: 'GET',
      path: '/transfers/$id',
    ));
    return Transfer.fromJson(response.jsonObject);
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
