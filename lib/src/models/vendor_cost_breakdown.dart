import 'package:equatable/equatable.dart';

import 'currency.dart';
import 'money.dart';

/// Vendor costs the backend attributes to a settled transfer, exposed on
/// receipts for treasury/margin reporting.
///
/// Wire shape (all amounts are minor-unit integers in a single shared
/// `currency`):
///
/// ```json
/// {
///   "etherfuse_minor": 0,
///   "network_minor": 0,
///   "other_minor": 0,
///   "currency": "USD"
/// }
/// ```
///
/// **Decode-only value type**: the SDK never computes, sums, or reconciles
/// vendor costs — it only deserializes what the backend reports.
class VendorCostBreakdown extends Equatable {
  /// Cost attributed to the Etherfuse leg.
  final Money etherfuse;

  /// Network (on-chain) cost.
  final Money network;

  /// Anything the backend doesn't itemize further.
  final Money other;

  /// Build a [VendorCostBreakdown].
  const VendorCostBreakdown({
    required this.etherfuse,
    required this.network,
    required this.other,
  });

  /// Decode from the backend's `vendor_costs` wire shape.
  factory VendorCostBreakdown.fromJson(Map<String, dynamic> json) {
    final currency = Currency.fromCode(json['currency'] as String);
    return VendorCostBreakdown(
      etherfuse: Money.fromMinor(json['etherfuse_minor'] as int, currency),
      network: Money.fromMinor(json['network_minor'] as int, currency),
      other: Money.fromMinor(json['other_minor'] as int, currency),
    );
  }

  @override
  List<Object?> get props => [etherfuse, network, other];
}
