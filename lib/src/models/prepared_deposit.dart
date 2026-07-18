import 'package:equatable/equatable.dart';

import 'deposit_session.dart';
import 'signing_request.dart';

/// Result of `POST /v1/deposit-sessions/{id}/prepare` — the session plus
/// the typed signing handoff for the external wallet.
///
/// Signing order: sign+broadcast [approval] first when non-null (exact
/// allowance for the route [spender]), then [transaction]. Both payloads
/// are built and validated server-side; the SDK passes them through
/// verbatim.
class PreparedDeposit extends Equatable {
  /// The full post-prepare session (status `prepared`, route locked).
  final DepositSession session;

  /// ERC-20 approval to sign first, or `null` when the existing
  /// allowance already covers the route.
  final PuenteSigningRequest? approval;

  /// The route transaction to sign and broadcast after [approval].
  final PuenteSigningRequest transaction;

  /// The route provider's contract approved to spend the source tokens.
  /// Validated server-side against the provider's returned route before
  /// the approval calldata was built.
  final String? spender;

  /// Provider route id assigned at prepare time. Opaque.
  final String? providerRouteId;

  /// Build a [PreparedDeposit].
  const PreparedDeposit({
    required this.session,
    required this.transaction,
    this.approval,
    this.spender,
    this.providerRouteId,
  });

  /// Decode from the prepare response (a session doc with `approval`,
  /// `transaction`, `spender`, `provider_route_id` added). Throws
  /// [FormatException] when `transaction` is missing — a prepare response
  /// without a transaction to sign is malformed.
  factory PreparedDeposit.fromJson(Map<String, dynamic> json) {
    final session = DepositSession.fromJson(json);
    final transaction = session.transaction;
    if (transaction == null) {
      throw const FormatException(
        'PreparedDeposit.fromJson: missing "transaction" signing request',
      );
    }
    return PreparedDeposit(
      session: session,
      approval: session.approval,
      transaction: transaction,
      spender: session.spender,
      providerRouteId: session.providerRouteId,
    );
  }

  /// Encode back to the wire shape (delegates to the session, which
  /// already carries the prepare fields).
  Map<String, dynamic> toJson() => session.toJson();

  @override
  List<Object?> get props =>
      [session, approval, transaction, spender, providerRouteId];
}
