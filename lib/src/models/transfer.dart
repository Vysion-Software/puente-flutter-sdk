import 'package:equatable/equatable.dart';

import 'money.dart';

/// Lifecycle states a transfer passes through, from creation to terminal
/// settlement (or failure).
///
/// Wire format is snake_case strings. Unknown values map to
/// [TransferStatus.unknown] so a server-side enum extension doesn't crash
/// older clients.
enum TransferStatus {
  /// Server accepted the request but hasn't started executing.
  pending('pending'),

  /// Funds are in flight (on-chain leg confirmed, fiat leg in progress).
  processing('processing'),

  /// Beneficiary credited; terminal success state.
  settled('settled'),

  /// Terminal failure.
  failed('failed'),

  /// Caller cancelled before settlement.
  cancelled('cancelled'),

  /// Wire format not recognized by this SDK build.
  unknown('unknown');

  /// JSON wire value.
  final String wire;
  const TransferStatus(this.wire);

  /// Parse a wire value into the enum, defaulting to [unknown] on miss.
  static TransferStatus fromWire(String? value) {
    if (value == null) return TransferStatus.unknown;
    for (final s in TransferStatus.values) {
      if (s.wire == value) return s;
    }
    return TransferStatus.unknown;
  }

  /// Terminal states never advance further. Use in poll loops to stop early.
  bool get isTerminal =>
      this == TransferStatus.settled ||
      this == TransferStatus.failed ||
      this == TransferStatus.cancelled;
}

/// A money movement instructed via Puente Railway.
///
/// Mirrors the response shape Puente will emit on `POST /v1/transfers`
/// and `GET /v1/transfers/:id` (see Puente issue #9, #10). Today only
/// the [MockTransport] returns this shape — the live `puente-api` does
/// not yet serve `/v1/transfers`.
class Transfer extends Equatable {
  /// Server-side identifier (`tx_…`).
  final String id;

  /// Current lifecycle state.
  final TransferStatus status;

  /// Source amount the sender is debited.
  final Money sourceAmount;

  /// Target amount the recipient is credited (or expected to be).
  final Money targetAmount;

  /// Recipient's CLABE (18-digit Mexican bank routing).
  final String? receiverClabe;

  /// Recipient's legal name.
  final String? receiverName;

  /// Optional sender-supplied memo (≤140 chars, displayed in the receipt).
  final String? memo;

  /// Server timestamp when the transfer was first created.
  final DateTime createdAt;

  /// Server timestamp when the transfer reached its current [status],
  /// or `null` if the server didn't report one.
  final DateTime? updatedAt;

  /// Free-form payment reference returned by the settlement leg (e.g. the
  /// SPEI tracking key). `null` while still processing.
  final String? reference;

  /// Build a [Transfer]. All money-bearing fields are [Money] (no doubles).
  const Transfer({
    required this.id,
    required this.status,
    required this.sourceAmount,
    required this.targetAmount,
    required this.createdAt,
    this.receiverClabe,
    this.receiverName,
    this.memo,
    this.updatedAt,
    this.reference,
  });

  /// Decode from the JSON shape Puente uses on the wire.
  factory Transfer.fromJson(Map<String, dynamic> json) => Transfer(
        id: json['id'] as String,
        status: TransferStatus.fromWire(json['status'] as String?),
        sourceAmount: Money.fromJson(
            (json['source_amount'] as Map).cast<String, dynamic>()),
        targetAmount: Money.fromJson(
            (json['target_amount'] as Map).cast<String, dynamic>()),
        receiverClabe: json['receiver_clabe'] as String?,
        receiverName: json['receiver_name'] as String?,
        memo: json['memo'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
        updatedAt: json['updated_at'] is String
            ? DateTime.parse(json['updated_at'] as String).toUtc()
            : null,
        reference: json['reference'] as String?,
      );

  /// Encode to the JSON shape Puente accepts on the wire.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'status': status.wire,
        'source_amount': sourceAmount.toJson(),
        'target_amount': targetAmount.toJson(),
        if (receiverClabe != null) 'receiver_clabe': receiverClabe,
        if (receiverName != null) 'receiver_name': receiverName,
        if (memo != null) 'memo': memo,
        'created_at': createdAt.toUtc().toIso8601String(),
        if (updatedAt != null)
          'updated_at': updatedAt!.toUtc().toIso8601String(),
        if (reference != null) 'reference': reference,
      };

  @override
  List<Object?> get props => [
        id,
        status,
        sourceAmount,
        targetAmount,
        receiverClabe,
        receiverName,
        memo,
        createdAt,
        updatedAt,
        reference,
      ];
}
