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
/// SDK calls. **Dev/test-only** — import it from
/// `package:puente_railway/testing.dart`, never ship it in a release
/// build (`PuenteClient` refuses `PuenteEnvironment.mock` in release
/// mode).
///
/// This is the SDK's `PuenteEnvironment.mock` backend and also the
/// default for unit tests. It is deterministic given a fixed seed, so
/// the same demo flow produces the same ids across runs.
///
/// ## Fixture policy (NOT production truth)
///
/// The mock performs **no financial computation of its own** beyond
/// emitting fixtures that mirror the backend's default policy:
///
/// * Same-currency quotes → `p2p_same_region`, `fx_rate "1"`, destination
///   equals source, and a **zero** total fee (the backend's default
///   same-region policy).
/// * Cross-currency quotes → `cross_border`, a flat fee fixture of
///   [crossBorderFlatFeeFixtureMinor] minor units of the source currency
///   (fx-spread and vendor fixtures are 0), and a destination amount
///   converted at the fixed [_fixtureRates] table.
/// * Transfers always take their amounts and fees **verbatim from the
///   stored quote** they reference — the mock never recomputes them.
///
/// Real fees, FX rates, totals, and margins ALWAYS come from the Puente
/// backend quote; these fixtures exist only so offline demos and unit
/// tests exercise the same wire shapes the backend serves.
///
/// What's modelled:
/// * `POST /quotes` (alias `/quote`) — returns a quote in the current
///   backend shape (`quote_id`, `*_minor`, `fx_rate`, `fee_breakdown`, …)
///   plus the legacy keys, so old and new parsers both work.
/// * `POST /transfers` — accepts a `quote_id`, resolves the stored quote
///   (404 `quote_not_found` when unknown, 409 `quote_expired` when past
///   `expires_at`), and stores a [Transfer]-shaped doc.
/// * `GET /transfers/:id` — returns the stored doc. Advances the status
///   from `pending` → `processing` → `settled` over [settlementLatency]
///   so demos see a real lifecycle.
/// * `GET /transfers/:id/receipt` — the settlement receipt (409-shaped
///   `receipt_unavailable: …` until settled), with a deterministic cNFT
///   fixture.
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
        _rates = Map.unmodifiable(exchangeRates ?? _fixtureRates);

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
  final Map<String, Map<String, dynamic>> _quotes = {};
  final Map<String, Map<String, dynamic>> _transfers = {};
  final Map<String, Map<String, dynamic>> _accounts = {};

  // Idempotency map: idempotency-key → already-returned response body.
  final Map<String, _CachedResponse> _idempotencyCache = {};

  // Timers we own; cancelled on close().
  final List<Timer> _timers = [];

  /// Dev fixture rates — the real rate ALWAYS comes from the backend
  /// quote. Fixed (never market-driven) so tests and demos are
  /// deterministic.
  static const Map<String, double> _fixtureRates = <String, double>{
    'USD->MXN': 19.73,
    'MXN->USD': 1 / 19.73,
    'USD->USDC': 1.0,
    'USDC->USD': 1.0,
    'USDC->MXN': 19.73,
    'MXN->USDC': 1 / 19.73,
  };

  /// Dev fixture: flat fee (minor units of the source currency) applied
  /// to cross-border quotes. Mirrors the backend's *default* policy shape
  /// only — the real fee ALWAYS comes from the backend quote.
  static const int crossBorderFlatFeeFixtureMinor = 100;

  /// How long a mock quote stays valid. Mirrors the backend default.
  static const Duration _quoteTtl = Duration(minutes: 2);

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
    // /quotes (the backend also serves the /quote alias).
    if (method == 'POST' && (path == '/quotes' || path == '/quote')) {
      return _createQuote(request);
    }

    // /transfers + /transfers/:id (+ /cancel, /receipt)
    if (method == 'POST' && path == '/transfers') {
      return _createTransfer(request);
    }
    if (method == 'GET' && path == '/transfers') return _listTransfers(request);
    final transferIdMatch = RegExp(r'^/transfers/([^/]+)$').firstMatch(path);
    if (transferIdMatch != null) {
      if (method == 'GET') return _getTransfer(transferIdMatch.group(1)!);
    }
    final receiptMatch =
        RegExp(r'^/transfers/([^/]+)/receipt$').firstMatch(path);
    if (receiptMatch != null && method == 'GET') {
      return _transferReceipt(receiptMatch.group(1)!);
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

    // Prefer the current backend keys; fall back to the legacy SDK shape.
    final Money src;
    if (body['source_amount_minor'] is int &&
        body['source_currency'] is String) {
      src = Money.fromMinor(
        body['source_amount_minor'] as int,
        Currency.fromCode(body['source_currency'] as String),
      );
    } else {
      src = _readMoney(body, 'source_amount');
    }
    final tgtCode =
        (body['destination_currency'] ?? body['target_currency']) as String?;
    if (tgtCode == null) {
      throw const _MockError(
          422, 'invalid_request', 'destination_currency required');
    }
    final tgtCurrency = Currency.fromCode(tgtCode);

    // Fixture policy — mirrors the backend's DEFAULTS, documented above.
    // Not production truth: the real backend decides fees, FX, and legs.
    final int destinationMinor;
    final String fxRate;
    final int flatFeeMinor;
    final String transferType;
    final String currencyLeg;
    if (src.currency == tgtCurrency) {
      // Same-region P2P fixture: zero fee, rate "1", destination == source.
      destinationMinor = src.minorUnits;
      fxRate = '1';
      flatFeeMinor = 0;
      transferType = 'p2p_same_region';
      currencyLeg = 'USDC';
    } else {
      final pair = '${src.currency.code}->${tgtCurrency.code}';
      final rate = _rates[pair];
      if (rate == null) {
        throw _MockError(
          422,
          'unsupported_pair',
          'mock transport has no fixture rate for $pair',
        );
      }
      destinationMinor =
          (src.minorUnits * tgtCurrency.scale * rate ~/ src.currency.scale)
              .toInt();
      fxRate = rate.toString();
      flatFeeMinor = crossBorderFlatFeeFixtureMinor;
      transferType = 'cross_border';
      currencyLeg = tgtCurrency == Currency.mxn ? 'CETES' : 'USDC';
    }
    // Fixture components: fx-spread and vendor are always 0 in the mock.
    const fxSpreadFeeMinor = 0;
    const vendorFeeMinor = 0;
    final totalFeeMinor = flatFeeMinor + fxSpreadFeeMinor + vendorFeeMinor;

    final id = 'qt_${_uuid.v4().replaceAll('-', '').substring(0, 12)}';
    final now = clock.now();
    final tgt = Money.fromMinor(destinationMinor, tgtCurrency);
    final quote = <String, dynamic>{
      // Current backend shape (POST /v1/quotes response).
      'quote_id': id,
      'source_amount_minor': src.minorUnits,
      'source_currency': src.currency.code,
      'destination_amount_minor': destinationMinor,
      'destination_currency': tgtCurrency.code,
      'fx_rate': fxRate,
      'total_fee_minor': totalFeeMinor,
      'total_cost_minor': src.minorUnits + totalFeeMinor,
      'expires_at': now.add(_quoteTtl).toUtc().toIso8601String(),
      'transfer_type': transferType,
      'currency_leg': currencyLeg,
      'fee_breakdown': <String, dynamic>{
        'flat_fee_minor': flatFeeMinor,
        'fx_spread_fee_minor': fxSpreadFeeMinor,
        'vendor_fee_minor': vendorFeeMinor,
        'total_fee_minor': totalFeeMinor,
        'currency': src.currency.code,
      },
      // Legacy shape, kept alongside so older parsers keep working.
      'id': id,
      'source_amount': src.toJson(),
      'target_amount': tgt.toJson(),
      'exchange_rate': double.parse(fxRate),
      'fee': Money.fromMinor(totalFeeMinor, src.currency).toJson(),
      'created_at': now.toUtc().toIso8601String(),
    };
    _quotes[id] = quote;
    return _jsonResponse(200, quote);
  }

  // ------------------------------------------------------------- transfers
  PuenteResponse _createTransfer(PuenteRequest request) {
    final body = _decodeBody(request);
    final quoteId = body['quote_id'] as String?;
    if (quoteId == null) {
      throw const _MockError(422, 'invalid_request', 'quote_id required');
    }

    // Resolve the referenced quote — amounts and fees come from it
    // verbatim; the mock NEVER recomputes them.
    final quote = _quotes[quoteId];
    if (quote == null) {
      throw _MockError(404, 'quote_not_found', 'quote $quoteId not found');
    }
    final expiresAt = DateTime.parse(quote['expires_at'] as String);
    if (!clock.now().toUtc().isBefore(expiresAt)) {
      throw _MockError(
          409, 'quote_expired', 'quote $quoteId expired at $expiresAt');
    }

    final receiverName = body['receiver_name'] as String?;
    if (receiverName == null || receiverName.trim().isEmpty) {
      throw const _MockError(422, 'invalid_request', 'receiver_name required');
    }
    final receiverClabe = body['receiver_clabe'] as String?;
    final memo = body['memo'] as String?;
    final transferType = quote['transfer_type'] as String;
    if (transferType == 'cross_border') {
      if (receiverClabe == null || receiverClabe.length != 18) {
        throw const _MockError(
            422, 'invalid_request', 'receiver_clabe must be 18 digits');
      }
    } else {
      // P2P mirrors the backend contract: both user ids are required.
      if (body['sender_user_id'] is! String ||
          body['receiver_user_id'] is! String) {
        throw const _MockError(422, 'invalid_request',
            'sender_user_id and receiver_user_id required for p2p transfers');
      }
    }

    final id = 'tx_${_uuid.v4().replaceAll('-', '').substring(0, 16)}';
    final now = clock.now();
    final stored = <String, dynamic>{
      'id': id,
      'status': 'pending',
      // Verbatim from the quote — never recomputed here.
      'source_amount': <String, dynamic>{
        'amount': quote['source_amount_minor'],
        'currency': quote['source_currency'],
      },
      'target_amount': <String, dynamic>{
        'amount': quote['destination_amount_minor'],
        'currency': quote['destination_currency'],
      },
      if (receiverClabe != null) 'receiver_clabe': receiverClabe,
      'receiver_name': receiverName,
      if (memo != null) 'memo': memo,
      'created_at': now.toUtc().toIso8601String(),
      'updated_at': now.toUtc().toIso8601String(),
      'reference': null,
      'quote_id': quoteId,
      'transfer_type': transferType,
      'fee_breakdown': quote['fee_breakdown'],
      // Carried for the receipt route (harmless extra keys on the wire).
      'currency_leg': quote['currency_leg'],
      'fx_rate': quote['fx_rate'],
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
        final settledAt = clock.now().toUtc().toIso8601String();
        doc['status'] = 'settled';
        doc['updated_at'] = settledAt;
        doc['settled_at'] = settledAt;
        doc['reference'] =
            'SPEI-${_random.nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
      }));
    } else {
      // No latency configured (unit tests) — settle synchronously.
      stored['status'] = 'settled';
      stored['settled_at'] = now.toUtc().toIso8601String();
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

  PuenteResponse _transferReceipt(String id) {
    final doc = _transfers[id];
    if (doc == null) {
      throw _MockError(404, 'not_found', 'transfer $id not found');
    }
    final status = doc['status'] as String;
    if (status != 'settled') {
      // 409 with the backend's `receipt_unavailable: …` error shape.
      throw _MockError(
        409,
        'receipt_unavailable: transfer $id is $status',
        'receipt unavailable: transfer $id is $status',
      );
    }
    final sourceCurrency = (doc['source_amount'] as Map)['currency'] as String;
    final suffix = id.length > 6 ? id.substring(id.length - 6) : id;
    return _jsonResponse(200, <String, dynamic>{
      'transaction_id': id,
      'status': 'settled',
      'transfer_type': doc['transfer_type'],
      'currency_leg': doc['currency_leg'],
      'source_amount': doc['source_amount'],
      'target_amount': doc['target_amount'],
      'fx_rate': doc['fx_rate'],
      'fee_breakdown': doc['fee_breakdown'],
      // Vendor-cost fixture: all zeros — real costs come from the backend.
      'vendor_costs': <String, dynamic>{
        'etherfuse_minor': 0,
        'network_minor': 0,
        'other_minor': 0,
        'currency': sourceCurrency,
      },
      'reference': doc['reference'],
      'memo': doc['memo'],
      'receiver_name': doc['receiver_name'],
      'created_at': doc['created_at'],
      'settled_at': doc['settled_at'] ?? doc['updated_at'],
      // Deterministic cNFT fixture.
      'cnft': <String, dynamic>{
        'folio': 'PES-${suffix.toUpperCase()}',
        'asset_id': null,
        'metadata_uri': 'mock://receipts/$id',
        'mint_signature': null,
      },
    });
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
    _quotes.clear();
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
