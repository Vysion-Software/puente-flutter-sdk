import 'package:equatable/equatable.dart';

import 'money.dart';

/// A FX + fee snapshot good for a short window, returned from
/// `POST /v1/quotes`.
///
/// Quotes are stateless: the server may quote the same pair many times at
/// the same rate, but each [id] is single-use and may be passed to
/// `POST /v1/transfers` exactly once to convert into a real money
/// movement.
class Quote extends Equatable {
  /// Server-side identifier (`qt_…`).
  final String id;

  /// Amount the sender will be debited (in the source currency).
  final Money sourceAmount;

  /// Amount the recipient will receive (in the target currency).
  final Money targetAmount;

  /// Mid-rate at quote time, returned for display. Authoritative math is
  /// done with [sourceAmount] / [targetAmount] / [fee] in minor units; this
  /// field is a UX convenience.
  ///
  /// Convention: `targetAmount / sourceAmount` in major units, so a rate of
  /// `19.73` means $1 USD → 19.73 MXN.
  final double exchangeRate;

  /// Total Puente fee in the source currency, already netted into
  /// [sourceAmount]. Displayed to the user as "Pesito takes X cents."
  final Money fee;

  /// Quote expiration time. Past [expiresAt] the server will reject the
  /// quote on `POST /v1/transfers` with `409 quote_expired`.
  final DateTime expiresAt;

  /// Server timestamp when the quote was created.
  final DateTime createdAt;

  /// Build a [Quote].
  const Quote({
    required this.id,
    required this.sourceAmount,
    required this.targetAmount,
    required this.exchangeRate,
    required this.fee,
    required this.expiresAt,
    required this.createdAt,
  });

  /// True when the quote's [expiresAt] has passed *relative to [now]*. The
  /// caller passes its own clock so SDK behavior is deterministic in tests.
  bool isExpired(DateTime now) => !now.isBefore(expiresAt);

  /// Decode from the JSON shape Puente uses on the wire.
  factory Quote.fromJson(Map<String, dynamic> json) => Quote(
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
      );

  /// Encode to the JSON shape Puente accepts on the wire.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'source_amount': sourceAmount.toJson(),
        'target_amount': targetAmount.toJson(),
        'exchange_rate': exchangeRate,
        'fee': fee.toJson(),
        'expires_at': expiresAt.toUtc().toIso8601String(),
        'created_at': createdAt.toUtc().toIso8601String(),
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
      ];
}
