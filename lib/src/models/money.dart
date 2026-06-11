import 'package:equatable/equatable.dart';

import 'currency.dart';

/// A signed monetary amount in a single [Currency], stored as an integer
/// count of minor units.
///
/// Why integers? Floating-point arithmetic loses cents at the boundary
/// (`0.1 + 0.2 != 0.3`); a payment system that loses cents goes out of
/// business. Every amount in the Puente Railway SDK is an integer.
///
/// Why a tagged currency? Currency mismatches at the ledger boundary
/// produce the most expensive bugs in fintech. [Money] arithmetic throws
/// on a mismatch instead of silently producing garbage.
///
/// Example:
/// ```dart
/// final twentyBucks = Money.fromMinor(2000, Currency.usd);
/// final fifty = Money.major(50, Currency.usd);
/// final fee = Money.fromDecimal('1.99', Currency.usd);
/// twentyBucks + fifty; // OK
/// twentyBucks + Money.major(50, Currency.mxn); // throws StateError
/// ```
class Money extends Equatable {
  /// Signed minor-unit amount. e.g. `cents` for USD, `centavos` for MXN,
  /// `lamports` for SOL.
  final int minorUnits;

  /// The currency this amount is denominated in.
  final Currency currency;

  /// Build from an explicit minor-unit integer.
  const Money.fromMinor(this.minorUnits, this.currency);

  /// Build from a "natural" major-unit count.
  ///
  /// Example: `Money.major(50, Currency.usd)` → 50.00 USD (5000 cents).
  /// Note that this only accepts whole-major-unit amounts; for fractional
  /// values (`12.34`) use [Money.fromDecimal].
  factory Money.major(int major, Currency currency) =>
      Money.fromMinor(major * currency.scale, currency);

  /// Build from a decimal string (`"12.34"`).
  ///
  /// Parsed exactly via integer arithmetic on the digits — no
  /// `double.parse`, so no floating-point loss. The fractional portion is
  /// padded or truncated to match [Currency.decimals].
  ///
  /// Throws [FormatException] on malformed input (multiple dots, non-digit
  /// characters, missing integer part).
  factory Money.fromDecimal(String value, Currency currency) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Money.fromDecimal: empty string');
    }

    var sign = 1;
    var body = trimmed;
    if (body.startsWith('-')) {
      sign = -1;
      body = body.substring(1);
    } else if (body.startsWith('+')) {
      body = body.substring(1);
    }

    final dot = body.indexOf('.');
    final intPart = dot < 0 ? body : body.substring(0, dot);
    final fracRaw = dot < 0 ? '' : body.substring(dot + 1);
    if (intPart.isEmpty || !_isAllDigits(intPart)) {
      throw FormatException(
        'Money.fromDecimal: bad integer part in "$value"',
      );
    }
    if (fracRaw.contains('.') ||
        (fracRaw.isNotEmpty && !_isAllDigits(fracRaw))) {
      throw FormatException(
        'Money.fromDecimal: bad fractional part in "$value"',
      );
    }

    final decimals = currency.decimals;
    final fracPadded = fracRaw.padRight(decimals, '0').substring(
          0,
          fracRaw.length > decimals ? decimals : fracRaw.length,
        );
    // After padding/truncating, frac is exactly `decimals` characters.
    final fracFull = (fracPadded + ('0' * (decimals - fracPadded.length)))
        .substring(0, decimals);

    final whole = int.parse(intPart);
    final frac = decimals == 0 ? 0 : int.parse(fracFull);
    return Money.fromMinor(sign * (whole * currency.scale + frac), currency);
  }

  /// Zero in [currency].
  factory Money.zero(Currency currency) => Money.fromMinor(0, currency);

  static bool _isAllDigits(String s) {
    for (final r in s.codeUnits) {
      if (r < 0x30 || r > 0x39) return false;
    }
    return true;
  }

  /// Major-unit form as a `double`. **Display only** — never round-trip
  /// money through doubles.
  double get majorUnits => minorUnits / currency.scale;

  /// True when the amount is zero, ignoring sign.
  bool get isZero => minorUnits == 0;

  /// True when the amount is strictly less than zero.
  bool get isNegative => minorUnits < 0;

  /// Same-currency addition.
  ///
  /// Throws [StateError] when [other] has a different currency, to keep
  /// mismatch bugs loud.
  Money operator +(Money other) {
    _assertSameCurrency(other, '+');
    return Money.fromMinor(minorUnits + other.minorUnits, currency);
  }

  /// Same-currency subtraction.
  Money operator -(Money other) {
    _assertSameCurrency(other, '-');
    return Money.fromMinor(minorUnits - other.minorUnits, currency);
  }

  /// Negate in place.
  Money operator -() => Money.fromMinor(-minorUnits, currency);

  void _assertSameCurrency(Money other, String op) {
    if (other.currency != currency) {
      throw StateError(
        'Money $op: currency mismatch ${currency.code} vs ${other.currency.code}',
      );
    }
  }

  /// Render as a decimal string with the currency's natural precision.
  ///
  /// Example: `Money.fromMinor(1234, Currency.usd).format()` → `"12.34 USD"`.
  /// Pass `withCode: false` to skip the trailing currency code.
  String format({bool withCode = true}) {
    final decimals = currency.decimals;
    final sign = minorUnits < 0 ? '-' : '';
    final abs = minorUnits.abs();
    if (decimals == 0) {
      return withCode ? '$sign$abs ${currency.code}' : '$sign$abs';
    }
    final scale = currency.scale;
    final whole = abs ~/ scale;
    final frac = (abs % scale).toString().padLeft(decimals, '0');
    final body = '$sign$whole.$frac';
    return withCode ? '$body ${currency.code}' : body;
  }

  @override
  String toString() => format();

  /// JSON shape used by Puente: `{ "amount": <minor>, "currency": "USD" }`.
  /// The legacy `"cents"` key from earlier SDK versions is still accepted by
  /// [fromJson] for compatibility but is not emitted by [toJson].
  factory Money.fromJson(Map<String, dynamic> json) {
    final raw = json['amount'] ?? json['cents'] ?? json['minor_units'];
    if (raw is! int) {
      throw FormatException(
        'Money.fromJson: missing/invalid "amount" — got ${raw.runtimeType}',
      );
    }
    final code = json['currency'];
    if (code is! String) {
      throw const FormatException(
        'Money.fromJson: missing/invalid "currency"',
      );
    }
    return Money.fromMinor(raw, Currency.fromCode(code));
  }

  /// Serialize as the wire shape `{ "amount": <minor>, "currency": "USD" }`.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'amount': minorUnits,
        'currency': currency.code,
      };

  @override
  List<Object?> get props => [minorUnits, currency];
}
