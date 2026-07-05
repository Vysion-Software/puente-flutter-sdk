import 'package:equatable/equatable.dart';

/// What a client is allowed to *ask for*: execute a previously issued
/// backend quote against a beneficiary.
///
/// The intent is the ONLY thing a client submits to `POST /v1/transfers`.
/// Amounts, FX, and fees always come from the referenced backend quote
/// ([quoteId]) — an intent carries no monetary values, so a compromised or
/// buggy client cannot alter what the treasury charges or delivers.
///
/// Field requirements mirror the backend contract:
/// * [receiverClabe] — required for cross-border transfers (18-digit
///   Mexican CLABE); omitted for P2P.
/// * [senderUserId] + [receiverUserId] — both required for P2P
///   (same-region) transfers; omitted for cross-border.
class TransferIntent extends Equatable {
  /// The single-use backend quote to execute.
  final String quoteId;

  /// Beneficiary's legal name.
  final String receiverName;

  /// Beneficiary's 18-digit CLABE (cross-border only).
  final String? receiverClabe;

  /// Optional sender-supplied memo.
  final String? memo;

  /// Sending user id (P2P only).
  final String? senderUserId;

  /// Receiving user id (P2P only).
  final String? receiverUserId;

  /// Build a [TransferIntent].
  const TransferIntent({
    required this.quoteId,
    required this.receiverName,
    this.receiverClabe,
    this.memo,
    this.senderUserId,
    this.receiverUserId,
  });

  /// Encode the exact `POST /v1/transfers` request body.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'quote_id': quoteId,
        'receiver_name': receiverName,
        if (receiverClabe != null) 'receiver_clabe': receiverClabe,
        if (memo != null) 'memo': memo,
        if (senderUserId != null) 'sender_user_id': senderUserId,
        if (receiverUserId != null) 'receiver_user_id': receiverUserId,
      };

  @override
  List<Object?> get props => [
        quoteId,
        receiverName,
        receiverClabe,
        memo,
        senderUserId,
        receiverUserId,
      ];
}
