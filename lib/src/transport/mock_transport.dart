import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:uuid/uuid.dart';

import '../models/currency.dart';
import '../models/money.dart';
import 'puente_request.dart';
import 'puente_response.dart';
import 'puente_transport.dart';

/// In-memory transport that serves canned responses for every route the
/// SDK calls.
///
/// This is the SDK's `PuenteEnvironment.mock` backend and also the
/// default for unit tests. It is deterministic given a fixed seed, so
/// the same demo flow produces the same ids and exchange rates across
/// runs.
///
/// What's modelled:
/// * `POST /quotes` — returns a fresh quote with a sane FX rate per pair.
/// * `POST /transfers` — accepts a `quote_id`, stores a [Transfer]-shaped
///   doc keyed on the idempotency key.
/// * `GET /transfers/:id` — returns the stored doc. Advances the status
///   from `pending` → `processing` → `settled` over [settlementLatency]
///   so demos see a real lifecycle.
/// * `GET /transfers` — returns the full list, newest first.
/// * `POST /transfers/:id/cancel` — flips to `cancelled` unless already
///   terminal.
/// * `POST /accounts`, `GET /accounts/:id`, `PATCH /accounts/:id`.
/// * `GET /clabe/:clabe` — returns a plausible bank-name lookup. CLABEs
///   ending in `00` are reported as `valid=false` for negative-path
///   testing.
/// * Idempotency: requests with the same `Idempotency-Key` on `POST`
///   return the same stored response.
///
/// What's NOT modelled (and would mean the demo isn't testing the real
/// thing): rate limits, network jitter, server-side validation beyond
/// shape, real CETES / USDC ledger movement. For those, use the live
/// Puente backend.
class MockTransport implements PuenteTransport {
  /// Build a [MockTransport]. Pass [seed] for deterministic ids.
  MockTransport({
    int seed = 0,
    this.settlementLatency = const Duration(seconds: 2),
    this.networkLatency = const Duration(milliseconds: 80),
    Map<String, double>? exchangeRates,
  })  : _random = math.Random(seed),
        _uuid = const Uuid(),
        _rates = Map.unmodifiable(exchangeRates ?? _defaultRates);

  /// Wall-clock delay between `pending` → `processing` → `settled`. The
  /// transport schedules a [Timer] when a transfer is created so reads
  /// after the latency reflect the next state.
  final Duration settlementLatency;

  /// Simulated per-request latency. Set to [Duration.zero] in unit tests
  /// for snappier runs.
  final Duration networkLatency;

  final Map<String, double> _rates;
  final math.Random _random;
  final Uuid _uuid;

  // In-memory stores keyed by id.
  final Map<String, Map<String, dynamic>> _transfers = {};
  final Map<String, Map<String, dynamic>> _accounts = {};

  // Idempotency map: idempotency-key → already-returned response body.
  final Map<String, _CachedResponse> _idempotencyCache = {};

  // Timers we own; cancelled on close().
  final List<Timer> _timers = [];

  static const Map<String, double> _defaultRates = <String, double>{
    'USD->MXN': 19.73,
    'MXN->USD': 1 / 19.73,
    'USD->USDC': 1.0,
    'USDC->USD': 1.0,
    'USDC->MXN': 19.73,
    'MXN->USDC': 1 / 19.73,
  };

  @override
  Future<PuenteResponse> send(PuenteRequest request) async {
    await Future<void>.delayed(networkLatency);

    final method = request.method.toUpperCase();
    final path = request.path;

    // Idempotent replay for unsafe methods.
    final key = request.idempotencyKey;
    if (key != null && (method == 'POST' || method == 'PUT')) {
      final cached = _idempotencyCache[key];
      if (cached != null) return cached.response;
    }

    try {
      final response = await _route(method, path, request);
      if (key != null && (method == 'POST' || method == 'PUT')) {
        _idempotencyCache[key] = _CachedResponse(response, clock.now());
      }
      return response;
    } on _MockError catch (e) {
      return _jsonResponse(e.statusCode, {
        'error': e.code,
        'message': e.message,
      });
    }
  }

  Future<PuenteResponse> _route(
      String method, String path, PuenteRequest request) async {
    // /quotes
    if (method == 'POST' && path == '/quotes') return _createQuote(request);

    // /transfers + /transfers/:id (+ /cancel)
    if (method == 'POST' && path == '/transfers') {
      return _createTransfer(request);
    }
    if (method == 'GET' && path == '/transfers') return _listTransfers(request);
    final transferIdMatch = RegExp(r'^/transfers/([^/]+)$').firstMatch(path);
    if (transferIdMatch != null) {
      if (method == 'GET') return _getTransfer(transferIdMatch.group(1)!);
    }
    final cancelMatch = RegExp(r'^/transfers/([^/]+)/cancel$').firstMatch(path);
    if (cancelMatch != null && method == 'POST') {
      return _cancelTransfer(cancelMatch.group(1)!);
    }

    // /accounts
    if (method == 'POST' && path == '/accounts') return _createAccount(request);
    final accountIdMatch = RegExp(r'^/accounts/([^/]+)$').firstMatch(path);
    if (accountIdMatch != null) {
      final id = accountIdMatch.group(1)!;
      if (method == 'GET') return _getAccount(id);
      if (method == 'PATCH') return _updateAccount(id, request);
    }

    // /clabe/:clabe
    final clabeMatch = RegExp(r'^/clabe/([0-9]+)$').firstMatch(path);
    if (clabeMatch != null && method == 'GET') {
      return _lookupClabe(clabeMatch.group(1)!);
    }

    return _jsonResponse(404, {
      'error': 'route_not_found',
      'message': 'mock transport has no handler for $method $path',
    });
  }

  // ---------------------------------------------------------------- quotes
  PuenteResponse _createQuote(PuenteRequest request) {
    final body = _decodeBody(request);
    final src = _readMoney(body, 'source_amount');
    final tgtCode = body['target_currency'] as String?;
    if (tgtCode == null) {
      throw const _MockError(
          422, 'invalid_request', 'target_currency required');
    }
    final tgtCurrency = Currency.fromCode(tgtCode);

    final pair = '${src.currency.code}->${tgtCurrency.code}';
    final rate = _rates[pair];
    if (rate == null) {
      throw _MockError(
        422,
        'unsupported_pair',
        'mock transport has no rate for $pair',
      );
    }

    const feeRatioBps = 50; // 0.50%
    final feeMinor = (src.minorUnits * feeRatioBps) ~/ 10000;
    final fee = Money.fromMinor(feeMinor, src.currency);
    final netSourceMinor = src.minorUnits - feeMinor;
    final ratioMinor =
        (netSourceMinor * tgtCurrency.scale * rate ~/ src.currency.scale)
            .toInt();
    final tgt = Money.fromMinor(ratioMinor, tgtCurrency);

    final id = 'qt_${_uuid.v4().replaceAll('-', '').substring(0, 12)}';
    final now = clock.now();
    final quote = <String, dynamic>{
      'id': id,
      'source_amount': src.toJson(),
      'target_amount': tgt.toJson(),
      'exchange_rate': rate,
      'fee': fee.toJson(),
      'created_at': now.toUtc().toIso8601String(),
      'expires_at':
          now.add(const Duration(minutes: 2)).toUtc().toIso8601String(),
    };
    return _jsonResponse(201, quote);
  }

  // ------------------------------------------------------------- transfers
  PuenteResponse _createTransfer(PuenteRequest request) {
    final body = _decodeBody(request);
    final quoteId = body['quote_id'] as String?;
    final receiverClabe = body['receiver_clabe'] as String?;
    final receiverName = body['receiver_name'] as String?;
    final memo = body['memo'] as String?;

    if (quoteId == null) {
      throw const _MockError(422, 'invalid_request', 'quote_id required');
    }
    if (receiverClabe == null || receiverClabe.length != 18) {
      throw const _MockError(
          422, 'invalid_request', 'receiver_clabe must be 18 digits');
    }
    if (receiverName == null || receiverName.trim().isEmpty) {
      throw const _MockError(422, 'invalid_request', 'receiver_name required');
    }

    final source = body['source_amount'] is Map
        ? Money.fromJson((body['source_amount'] as Map).cast<String, dynamic>())
        : const Money.fromMinor(10000, Currency.usd);
    final target = body['target_amount'] is Map
        ? Money.fromJson((body['target_amount'] as Map).cast<String, dynamic>())
        : Money.fromMinor((source.minorUnits * 1973) ~/ 100, Currency.mxn);

    final id = 'tx_${_uuid.v4().replaceAll('-', '').substring(0, 16)}';
    final now = clock.now();
    final stored = <String, dynamic>{
      'id': id,
      'status': 'pending',
      'source_amount': source.toJson(),
      'target_amount': target.toJson(),
      'receiver_clabe': receiverClabe,
      'receiver_name': receiverName,
      if (memo != null) 'memo': memo,
      'created_at': now.toUtc().toIso8601String(),
      'updated_at': now.toUtc().toIso8601String(),
      'reference': null,
    };
    _transfers[id] = stored;

    // Advance status over real time so polling demos see a lifecycle.
    if (settlementLatency > Duration.zero) {
      _timers.add(Timer(settlementLatency ~/ 2, () {
        final doc = _transfers[id];
        if (doc == null || doc['status'] != 'pending') return;
        doc['status'] = 'processing';
        doc['updated_at'] = clock.now().toUtc().toIso8601String();
      }));
      _timers.add(Timer(settlementLatency, () {
        final doc = _transfers[id];
        if (doc == null || doc['status'] != 'processing') return;
        doc['status'] = 'settled';
        doc['updated_at'] = clock.now().toUtc().toIso8601String();
        doc['reference'] =
            'SPEI-${_random.nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
      }));
    } else {
      // No latency configured (unit tests) — settle synchronously.
      stored['status'] = 'settled';
      stored['reference'] = 'SPEI-MOCK';
    }

    return _jsonResponse(201, stored);
  }

  PuenteResponse _getTransfer(String id) {
    final doc = _transfers[id];
    if (doc == null) {
      throw _MockError(404, 'not_found', 'transfer $id not found');
    }
    return _jsonResponse(200, doc);
  }

  PuenteResponse _listTransfers(PuenteRequest request) {
    final limit = int.tryParse(request.query['limit'] ?? '20') ?? 20;
    final docs = _transfers.values.toList()
      ..sort((a, b) {
        final ai = a['created_at'] as String? ?? '';
        final bi = b['created_at'] as String? ?? '';
        return bi.compareTo(ai);
      });
    final slice = docs.take(limit).toList();
    return _jsonResponse(200, <String, dynamic>{'data': slice});
  }

  PuenteResponse _cancelTransfer(String id) {
    final doc = _transfers[id];
    if (doc == null) {
      throw _MockError(404, 'not_found', 'transfer $id not found');
    }
    final status = doc['status'] as String;
    if (status == 'settled' || status == 'failed' || status == 'cancelled') {
      throw _MockError(409, 'terminal_state', 'transfer $id is $status');
    }
    doc['status'] = 'cancelled';
    doc['updated_at'] = clock.now().toUtc().toIso8601String();
    return _jsonResponse(200, doc);
  }

  // -------------------------------------------------------------- accounts
  PuenteResponse _createAccount(PuenteRequest request) {
    final body = _decodeBody(request);
    final firstName = body['first_name'] as String?;
    final lastName = body['last_name'] as String?;
    final email = body['email'] as String?;
    final phone = body['phone'] as String?;
    if (firstName == null ||
        lastName == null ||
        email == null ||
        phone == null) {
      throw const _MockError(422, 'invalid_request',
          'first_name, last_name, email, phone required');
    }
    final id = 'acct_${_uuid.v4().replaceAll('-', '').substring(0, 16)}';
    final now = clock.now();
    final stored = <String, dynamic>{
      'id': id,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'phone': phone,
      'kyc_tier': 'none',
      'created_at': now.toUtc().toIso8601String(),
    };
    _accounts[id] = stored;
    return _jsonResponse(201, stored);
  }

  PuenteResponse _getAccount(String id) {
    final doc = _accounts[id];
    if (doc == null) {
      throw _MockError(404, 'not_found', 'account $id not found');
    }
    return _jsonResponse(200, doc);
  }

  PuenteResponse _updateAccount(String id, PuenteRequest request) {
    final doc = _accounts[id];
    if (doc == null) {
      throw _MockError(404, 'not_found', 'account $id not found');
    }
    final body = _decodeBody(request);
    if (body['phone'] is String) doc['phone'] = body['phone'];
    return _jsonResponse(200, doc);
  }

  // ----------------------------------------------------------------- clabe
  PuenteResponse _lookupClabe(String clabe) {
    if (clabe.length != 18) {
      throw const _MockError(422, 'invalid_request', 'clabe must be 18 digits');
    }
    final prefix = clabe.substring(0, 3);
    final banks = <String, String>{
      '012': 'BBVA México',
      '014': 'Santander',
      '021': 'HSBC',
      '044': 'Scotiabank',
      '072': 'Banorte',
      '646': 'STP',
    };
    final bankName = banks[prefix] ?? 'Unknown Bank';
    // Suffix `00` flips invalid for negative-path testing.
    final valid = !clabe.endsWith('00') && banks.containsKey(prefix);
    return _jsonResponse(200, <String, dynamic>{
      'clabe': clabe,
      'bank_name': bankName,
      'bank_code': prefix,
      'valid': valid,
    });
  }

  // ------------------------------------------------------------- internals
  PuenteResponse _jsonResponse(int status, Object body) {
    final encoded = jsonEncode(body);
    final requestId = 'req_${_uuid.v4().replaceAll('-', '').substring(0, 16)}';
    return PuenteResponse(
      statusCode: status,
      headers: <String, String>{
        'content-type': 'application/json',
        'x-request-id': requestId,
      },
      body: encoded,
    );
  }

  Map<String, dynamic> _decodeBody(PuenteRequest request) {
    final body = request.body;
    if (body is Map<String, dynamic>) return body;
    if (body is Map) return body.cast<String, dynamic>();
    final encoded = request.encodedBody();
    if (encoded.isEmpty) return const <String, dynamic>{};
    return (jsonDecode(encoded) as Map).cast<String, dynamic>();
  }

  Money _readMoney(Map<String, dynamic> body, String key) {
    final raw = body[key];
    if (raw is! Map) {
      throw _MockError(422, 'invalid_request', '$key must be an object');
    }
    return Money.fromJson(raw.cast<String, dynamic>());
  }

  @override
  void close() {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
    _transfers.clear();
    _accounts.clear();
    _idempotencyCache.clear();
  }
}

class _MockError implements Exception {
  final int statusCode;
  final String code;
  final String message;
  const _MockError(this.statusCode, this.code, this.message);
}

class _CachedResponse {
  final PuenteResponse response;
  final DateTime cachedAt;
  const _CachedResponse(this.response, this.cachedAt);
}
