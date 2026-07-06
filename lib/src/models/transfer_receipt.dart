import 'package:equatable/equatable.dart';

import 'currency_leg.dart';
import 'fee_breakdown.dart';
import 'money.dart';
import 'receipt_metadata.dart';
import 'transfer.dart';
import 'vendor_cost_breakdown.dart';

/// The settlement receipt for a transfer, returned by
/// `GET /v1/transfers/{id}/receipt` — available only once the transfer is
/// `settled` (the backend answers `409 receipt_unavailable` before that).
///
/// **Decode-only value type.** Every amount, rate, fee, and cost on a
/// receipt is backend truth; the SDK deserializes and displays, never
/// recomputes.
class TransferReceipt extends Equatable {
  /// The transfer's server-side identifier.
  final String transactionId;

  /// Lifecycle state — always [TransferStatus.settled] on a real receipt.
  final TransferStatus status;

  /// Backend transfer classification (`"p2p_same_region"`,
  /// `"cross_border"`, …). Kept as a raw string: the set is
  /// backend-defined and may grow.
  final String transferType;

  /// Which treasury leg carried the funds.
  final CurrencyLeg currencyLeg;

  /// Amount the sender was debited.
  final Money sourceAmount;

  /// Amount the beneficiary was credited.
  final Money targetAmount;

  /// Executed FX rate as a decimal **string, display only** — never parse
  /// it for arithmetic; authoritative amounts are [sourceAmount] /
  /// [targetAmount].
  final String fxRate;

  /// Itemized fees charged, as reported by the backend.
  final FeeBreakdown? feeBreakdown;

  /// Vendor costs the backend attributed to this transfer.
  final VendorCostBreakdown? vendorCosts;

  /// Settlement-leg payment reference (e.g. SPEI tracking key).
  final String? reference;

  /// Sender-supplied memo.
  final String? memo;

  /// Beneficiary's legal name.
  final String? receiverName;

  /// When the transfer was created.
  final DateTime createdAt;

  /// When the transfer settled.
  final DateTime settledAt;

  /// The cNFT proof block, or `null` when the backend hasn't minted one.
  final ReceiptMetadata? cnft;

  /// Build a [TransferReceipt].
  const TransferReceipt({
    required this.transactionId,
    required this.status,
    required this.transferType,
    required this.currencyLeg,
    required this.sourceAmount,
    required this.targetAmount,
    required this.fxRate,
    required this.createdAt,
    required this.settledAt,
    this.feeBreakdown,
    this.vendorCosts,
    this.reference,
    this.memo,
    this.receiverName,
    this.cnft,
  });

  /// Decode from the backend's receipt wire shape.
  factory TransferReceipt.fromJson(Map<String, dynamic> json) =>
      TransferReceipt(
        transactionId: json['transaction_id'] as String,
        status: TransferStatus.fromWire(json['status'] as String?),
        // `transfer_type` and `fx_rate` come from
        // external_transfers.metadata->>… which can be JSON null for
        // pre-treasury transfers (or, in tests, for backends that omit
        // the field). Fall back to safe defaults rather than throwing —
        // callers already treat both as opaque display strings.
        transferType: (json['transfer_type'] as String?) ?? '',
        currencyLeg: CurrencyLeg.fromWire(json['currency_leg'] as String?),
        sourceAmount: Money.fromJson(
            (json['source_amount'] as Map).cast<String, dynamic>()),
        targetAmount: Money.fromJson(
            (json['target_amount'] as Map).cast<String, dynamic>()),
        fxRate: (json['fx_rate'] as String?) ?? '',
        feeBreakdown: json['fee_breakdown'] is Map
            ? FeeBreakdown.fromJson(
                (json['fee_breakdown'] as Map).cast<String, dynamic>())
            : null,
        vendorCosts: json['vendor_costs'] is Map
            ? VendorCostBreakdown.fromJson(
                (json['vendor_costs'] as Map).cast<String, dynamic>())
            : null,
        reference: json['reference'] as String?,
        memo: json['memo'] as String?,
        receiverName: json['receiver_name'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
        settledAt: DateTime.parse(json['settled_at'] as String).toUtc(),
        cnft: json['cnft'] is Map
            ? ReceiptMetadata.fromJson(
                (json['cnft'] as Map).cast<String, dynamic>())
            : null,
      );

  @override
  List<Object?> get props => [
        transactionId,
        status,
        transferType,
        currencyLeg,
        sourceAmount,
        targetAmount,
        fxRate,
        feeBreakdown,
        vendorCosts,
        reference,
        memo,
        receiverName,
        createdAt,
        settledAt,
        cnft,
      ];
}
