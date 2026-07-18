import 'package:equatable/equatable.dart';

/// One itemized fee on a deposit route quote.
///
/// Fees are **backend/provider truth** — the SDK never computes, sums, or
/// converts them. [amountUsd] is a display-only decimal string.
class DepositFee extends Equatable {
  /// Fee classification slug (`"gas"`, `"service"`, …). Backend-defined
  /// vocabulary; render, don't branch on it for money logic.
  final String kind;

  /// Fee amount in minor units of the fee's own token, when the provider
  /// itemized one. `null` when only the USD value is known.
  final int? amountMinor;

  /// Fee value in USD as a **display-only decimal string** — never parse
  /// it into money arithmetic.
  final String amountUsd;

  /// Human-readable label from the provider (`"Gas receiver fee"`).
  final String? label;

  /// Build a [DepositFee].
  const DepositFee({
    required this.kind,
    required this.amountUsd,
    this.amountMinor,
    this.label,
  });

  /// Decode from the wire shape.
  factory DepositFee.fromJson(Map<String, dynamic> json) => DepositFee(
        kind: json['kind'] as String? ?? 'unknown',
        amountMinor: json['amount_minor'] as int?,
        amountUsd: json['amount_usd']?.toString() ?? '0',
        label: json['label'] as String?,
      );

  /// Encode back to the wire shape. Round-trips through [fromJson].
  Map<String, dynamic> toJson() => <String, dynamic>{
        'kind': kind,
        if (amountMinor != null) 'amount_minor': amountMinor,
        'amount_usd': amountUsd,
        if (label != null) 'label': label,
      };

  @override
  List<Object?> get props => [kind, amountMinor, amountUsd, label];
}

/// Regional display estimate attached to a deposit quote/session.
///
/// **Everything here is display-only.** The customer liability is always
/// credited in USDC minor units; MXN (or any non-USD currency) is shown
/// as a labeled *indicative* estimate — no FX liability exists until an
/// FX conversion actually executes, and none does in this flow.
class DepositDisplayEstimate extends Equatable {
  /// Display currency code (`"USD"`, `"MXN"`).
  final String currency;

  /// Estimated credit in [currency] minor units, verbatim from the wire.
  /// USD is 1:1 with the expected USDC credit; the backend sends `null`
  /// for MXN in this MVP (no FX rate exists until a conversion executes).
  final int? estimatedCreditMinor;

  /// Indicative FX rate used for the estimate, as a decimal string
  /// (`"1"` for USD). `null` when the backend attached no rate (MXN).
  final String? fxRate;

  /// FX labeling — the backend sends `"indicative"`: the rate is not a
  /// commitment and the credited USDC amount is the only truth.
  final String fxType;

  /// Build a [DepositDisplayEstimate].
  const DepositDisplayEstimate({
    required this.currency,
    this.estimatedCreditMinor,
    this.fxRate,
    this.fxType = 'indicative',
  });

  /// Decode from the wire shape.
  factory DepositDisplayEstimate.fromJson(Map<String, dynamic> json) =>
      DepositDisplayEstimate(
        currency: json['currency'] as String? ?? 'USD',
        estimatedCreditMinor: json['estimated_credit_minor'] as int?,
        fxRate: json['fx_rate']?.toString(),
        fxType: json['fx_type'] as String? ?? 'indicative',
      );

  /// Encode back to the wire shape. Round-trips through [fromJson].
  Map<String, dynamic> toJson() => <String, dynamic>{
        'currency': currency,
        'estimated_credit_minor': estimatedCreditMinor,
        'fx_rate': fxRate,
        'fx_type': fxType,
      };

  @override
  List<Object?> get props => [currency, estimatedCreditMinor, fxRate, fxType];
}

/// A deposit route quote (`POST /v1/deposit-sessions/{id}/quotes`).
///
/// All amounts are integer minor units taken **verbatim from the
/// backend** — the SDK performs no fee, FX, or slippage math. The quote
/// is time-boxed: past [expiresAt] the backend rejects `prepare` with
/// `409 quote_expired` and the client must re-quote.
class DepositQuote extends Equatable {
  /// Source amount being deposited, in source-asset minor units.
  final int sourceAmountMinor;

  /// Expected USDC delivered to the deposit address, in USDC minor units
  /// (6 decimals). Fees are already netted out by the backend.
  final int expectedDestinationMinor;

  /// Worst-case (slippage-bounded) USDC delivery, in USDC minor units.
  final int minimumDestinationMinor;

  /// Itemized provider fees. Informational; totals come from the wire.
  final List<DepositFee> fees;

  /// Total fees in USD as a **display-only decimal string**.
  final String totalFeesUsd;

  /// When this quote lapses. The backend enforces its own TTL
  /// (`DEPOSIT_QUOTE_TTL_SECS`); this is authoritative.
  final DateTime expiresAt;

  /// Labeled indicative display estimate, when the server sent one.
  final DepositDisplayEstimate? display;

  /// Build a [DepositQuote].
  const DepositQuote({
    required this.sourceAmountMinor,
    required this.expectedDestinationMinor,
    required this.minimumDestinationMinor,
    required this.fees,
    required this.totalFeesUsd,
    required this.expiresAt,
    this.display,
  });

  /// True when [expiresAt] has passed *relative to [now]*. The caller
  /// passes its own clock so SDK behavior is deterministic in tests.
  bool isExpired(DateTime now) => !now.isBefore(expiresAt);

  /// Decode from the wire shape. Throws [FormatException] when required
  /// integer amounts or the expiry are missing/mistyped.
  factory DepositQuote.fromJson(Map<String, dynamic> json) => DepositQuote(
        sourceAmountMinor: _requireInt(json, 'source_amount_minor'),
        expectedDestinationMinor:
            _requireInt(json, 'expected_destination_minor'),
        minimumDestinationMinor: _requireInt(json, 'minimum_destination_minor'),
        fees: (json['fees'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(DepositFee.fromJson)
            .toList(growable: false),
        totalFeesUsd: json['total_fees_usd']?.toString() ?? '0',
        expiresAt: _requireDate(json, 'expires_at'),
        display: json['display'] is Map
            ? DepositDisplayEstimate.fromJson(
                (json['display'] as Map).cast<String, dynamic>())
            : null,
      );

  /// Encode back to the wire shape. Round-trips through [fromJson].
  Map<String, dynamic> toJson() => <String, dynamic>{
        'source_amount_minor': sourceAmountMinor,
        'expected_destination_minor': expectedDestinationMinor,
        'minimum_destination_minor': minimumDestinationMinor,
        'fees': fees.map((f) => f.toJson()).toList(growable: false),
        'total_fees_usd': totalFeesUsd,
        'expires_at': expiresAt.toUtc().toIso8601String(),
        if (display != null) 'display': display!.toJson(),
      };

  static int _requireInt(Map<String, dynamic> json, String key) {
    final raw = json[key];
    if (raw is! int) {
      throw FormatException(
        'DepositQuote.fromJson: missing/invalid "$key" — '
        'got ${raw.runtimeType}',
      );
    }
    return raw;
  }

  static DateTime _requireDate(Map<String, dynamic> json, String key) {
    final raw = json[key];
    if (raw is! String) {
      throw FormatException(
        'DepositQuote.fromJson: missing/invalid "$key" — '
        'got ${raw.runtimeType}',
      );
    }
    return DateTime.parse(raw).toUtc();
  }

  @override
  List<Object?> get props => [
        sourceAmountMinor,
        expectedDestinationMinor,
        minimumDestinationMinor,
        fees,
        totalFeesUsd,
        expiresAt,
        display,
      ];
}
