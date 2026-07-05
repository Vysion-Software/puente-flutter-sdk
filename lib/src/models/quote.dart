import 'package:equatable/equatable.dart';

import 'currency.dart';
import 'currency_leg.dart';
import 'fee_breakdown.dart';
import 'money.dart';

/// A FX + fee snapshot good for a short window, returned from
/// `POST /v1/quotes`.
///
/// Quotes are stateless: the server may quote the same pair many times at
/// the same rate, but each [id] is single-use and may be passed to
/// `POST /v1/transfers` exactly once to convert into a real money
/// movement.
///
/// Every monetary value on a quote is **backend truth** — the SDK never
/// computes fees, FX, totals, or margins; it deserializes what the
/// treasury decided.
class Quote extends Equatable {
  /// Server-side identifier (a UUID on the current backend; `qt_…` on
  /// legacy fixtures).
  final String id;

  /// Amount the sender will be debited (in the source currency).
  final Money sourceAmount;

  /// Amount the recipient will receive (in the target currency).
  final Money targetAmount;

  /// FX rate at quote time, returned for **display only**. Authoritative
  /// math is done server-side; [sourceAmount] / [targetAmount] / [fee] in
  /// minor units are the values to trust. On the current backend this is
  /// parsed from the decimal string `fx_rate` via `double.tryParse` (0 on
  /// unparseable input) — never round-trip it into money arithmetic.
  ///
  /// Convention: `targetAmount / sourceAmount` in major units, so a rate of
  /// `19.73` means $1 USD → 19.73 MXN.
  final double exchangeRate;

  /// Total backend fee in the source currency. Displayed to the user as
  /// "Pesito takes X cents." Comes verbatim from the wire
  /// (`total_fee_minor` on the current backend).
  final Money fee;

  /// Quote expiration time. Past [expiresAt] the server will reject the
  /// quote on `POST /v1/transfers` with `409 quote_expired`.
  final DateTime expiresAt;

  /// Server timestamp when the quote was created. The current backend
  /// doesn't echo one on quotes; the SDK falls back to [expiresAt].
  final DateTime createdAt;

  /// Itemized backend fees (`fee_breakdown`), when the server sent them.
  final FeeBreakdown? feeBreakdown;

  /// Treasury settlement leg (`currency_leg`), when the server sent it.
  final CurrencyLeg? currencyLeg;

  /// Backend transfer classification (`"p2p_same_region"`,
  /// `"cross_border"`, …), when the server sent it. Raw string — the set
  /// is backend-defined.
  final String? transferType;

  /// Total cost to the sender (`total_cost_minor`, source currency), when
  /// the server sent it. Never derived locally from amount + fee.
  final Money? totalCost;

  /// Build a [Quote].
  const Quote({
    required this.id,
    required this.sourceAmount,
    required this.targetAmount,
    required this.exchangeRate,
    required this.fee,
    required this.expiresAt,
    required this.createdAt,
    this.feeBreakdown,
    this.currencyLeg,
    this.transferType,
    this.totalCost,
  });

  /// True when the quote's [expiresAt] has passed *relative to [now]*. The
  /// caller passes its own clock so SDK behavior is deterministic in tests.
  bool isExpired(DateTime now) => !now.isBefore(expiresAt);

  /// Decode from either wire shape Puente uses:
  ///
  /// * **Current backend** — keyed by `quote_id`, with
  ///   `source_amount_minor` / `destination_amount_minor` integers,
  ///   `fx_rate` decimal string, `total_fee_minor`, `total_cost_minor`,
  ///   `transfer_type`, `currency_leg`, and `fee_breakdown`.
  /// * **Legacy** — keyed by `id`, with `source_amount` / `target_amount`
  ///   Money objects, numeric `exchange_rate`, and a `fee` Money object.
  factory Quote.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('quote_id')) return Quote._fromBackendJson(json);
    return Quote._fromLegacyJson(json);
  }

  /// Current Rust-backend shape (`POST /v1/quotes` response).
  factory Quote._fromBackendJson(Map<String, dynamic> json) {
    final sourceCurrency = Currency.fromCode(json['source_currency'] as String);
    final destinationCurrency =
        Currency.fromCode(json['destination_currency'] as String);
    final expiresAt = DateTime.parse(json['expires_at'] as String).toUtc();
    return Quote(
      id: json['quote_id'] as String,
      sourceAmount:
          Money.fromMinor(json['source_amount_minor'] as int, sourceCurrency),
      targetAmount: Money.fromMinor(
          json['destination_amount_minor'] as int, destinationCurrency),
      // Display only — the string keeps full precision on the wire.
      exchangeRate: double.tryParse(json['fx_rate'] as String? ?? '') ?? 0,
      fee: Money.fromMinor(json['total_fee_minor'] as int, sourceCurrency),
      expiresAt: expiresAt,
      createdAt: json['created_at'] is String
          ? DateTime.parse(json['created_at'] as String).toUtc()
          : expiresAt,
      feeBreakdown: json['fee_breakdown'] is Map
          ? FeeBreakdown.fromJson(
              (json['fee_breakdown'] as Map).cast<String, dynamic>())
          : null,
      currencyLeg: json['currency_leg'] is String
          ? CurrencyLeg.fromWire(json['currency_leg'] as String)
          : null,
      transferType: json['transfer_type'] as String?,
      totalCost: json['total_cost_minor'] is int
          ? Money.fromMinor(json['total_cost_minor'] as int, sourceCurrency)
          : null,
    );
  }

  /// Legacy SDK shape (kept so existing fixtures and stored quotes parse).
  factory Quote._fromLegacyJson(Map<String, dynamic> json) => Quote(
        id: json['id'] as String,
        sourceAmount: Money.fromJson(
            (json['source_amount'] as Map).cast<String, dynamic>()),
        targetAmount: Money.fromJson(
            (json['target_amount'] as Map).cast<String, dynamic>()),
        exchangeRate: (json['exchange_rate'] as num).toDouble(),
        fee: Money.fromJson((json['fee'] as Map).cast<String, dynamic>()),
        expiresAt: DateTime.parse(json['expires_at'] as String).toUtc(),
        createdAt: json['created_at'] is String
            ? DateTime.parse(json['created_at'] as String).toUtc()
            : DateTime.parse(json['expires_at'] as String).toUtc(),
        feeBreakdown: json['fee_breakdown'] is Map
            ? FeeBreakdown.fromJson(
                (json['fee_breakdown'] as Map).cast<String, dynamic>())
            : null,
        currencyLeg: json['currency_leg'] is String
            ? CurrencyLeg.fromWire(json['currency_leg'] as String)
            : null,
        transferType: json['transfer_type'] as String?,
        totalCost: json['total_cost'] is Map
            ? Money.fromJson(
                (json['total_cost'] as Map).cast<String, dynamic>())
            : null,
      );

  /// Encode to the legacy JSON shape (plus the treasury fields when
  /// present). Round-trips through [Quote.fromJson].
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'source_amount': sourceAmount.toJson(),
        'target_amount': targetAmount.toJson(),
        'exchange_rate': exchangeRate,
        'fee': fee.toJson(),
        'expires_at': expiresAt.toUtc().toIso8601String(),
        'created_at': createdAt.toUtc().toIso8601String(),
        if (feeBreakdown != null) 'fee_breakdown': feeBreakdown!.toJson(),
        if (currencyLeg != null) 'currency_leg': currencyLeg!.wire,
        if (transferType != null) 'transfer_type': transferType,
        if (totalCost != null) 'total_cost': totalCost!.toJson(),
      };

  @override
  List<Object?> get props => [
        id,
        sourceAmount,
        targetAmount,
        exchangeRate,
        fee,
        expiresAt,
        createdAt,
        feeBreakdown,
        currencyLeg,
        transferType,
        totalCost,
      ];
}
