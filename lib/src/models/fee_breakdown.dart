import 'package:equatable/equatable.dart';

import 'currency.dart';
import 'money.dart';

/// Itemized fees the backend charged (or quoted) for a transfer, exactly as
/// computed server-side.
///
/// Wire shape (all amounts are minor-unit integers in a single shared
/// `currency`):
///
/// ```json
/// {
///   "flat_fee_minor": 100,
///   "fx_spread_fee_minor": 0,
///   "vendor_fee_minor": 0,
///   "total_fee_minor": 100,
///   "currency": "USD"
/// }
/// ```
///
/// This is a **decode-only value type**: the SDK never calculates fees.
/// In particular [totalFee] is taken verbatim from the wire — it is never
/// summed locally from the components. If the backend's total disagrees
/// with the components, the backend's total is what the user is shown.
class FeeBreakdown extends Equatable {
  /// Flat (per-transfer) fee component.
  final Money flatFee;

  /// FX-spread fee component.
  final Money fxSpreadFee;

  /// Pass-through vendor fee component (e.g. Etherfuse, network).
  final Money vendorFee;

  /// Total fee **as reported by the backend** — never computed client-side.
  final Money totalFee;

  /// Build a [FeeBreakdown].
  const FeeBreakdown({
    required this.flatFee,
    required this.fxSpreadFee,
    required this.vendorFee,
    required this.totalFee,
  });

  /// Decode from the backend's `fee_breakdown` wire shape.
  factory FeeBreakdown.fromJson(Map<String, dynamic> json) {
    final currency = Currency.fromCode(json['currency'] as String);
    return FeeBreakdown(
      flatFee: Money.fromMinor(json['flat_fee_minor'] as int, currency),
      fxSpreadFee:
          Money.fromMinor(json['fx_spread_fee_minor'] as int, currency),
      vendorFee: Money.fromMinor(json['vendor_fee_minor'] as int, currency),
      totalFee: Money.fromMinor(json['total_fee_minor'] as int, currency),
    );
  }

  /// Encode back to the wire shape (used when re-serializing quotes and
  /// transfers; the SDK never mutates the values).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'flat_fee_minor': flatFee.minorUnits,
        'fx_spread_fee_minor': fxSpreadFee.minorUnits,
        'vendor_fee_minor': vendorFee.minorUnits,
        'total_fee_minor': totalFee.minorUnits,
        'currency': totalFee.currency.code,
      };

  @override
  List<Object?> get props => [flatFee, fxSpreadFee, vendorFee, totalFee];
}
