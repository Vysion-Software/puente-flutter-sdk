import 'package:equatable/equatable.dart';

import 'deposit_quote.dart';
import 'deposit_status.dart';
import 'signing_request.dart';

/// An external-wallet deposit session — the client view of a Puente
/// `deposit_intent` (`POST /v1/deposit-sessions`,
/// `GET /v1/deposit-sessions/{id}`).
///
/// The backend is the sole financial authority: every amount here is an
/// integer minor-unit value deserialized **verbatim from the wire**. The
/// SDK renders state and hands [approval]/[transaction] to the external
/// wallet; it never computes fees, FX, or slippage.
class DepositSession extends Equatable {
  /// Public session id (`dep_…`). Path parameter for every per-session
  /// endpoint.
  final String id;

  /// The end user this deposit belongs to (merchant-scoped `user_id`).
  final String? userId;

  /// Current lifecycle state. Authoritative; poll via
  /// `DepositsResource.watch`.
  final DepositStatus status;

  /// Routing provider slug (`"mock"`, `"trustware"`). Informational.
  final String? provider;

  /// Compliance risk state (`"none"`, `"hold"`, `"released"`, …).
  /// `"hold"` accompanies [DepositStatus.complianceHold]; the vocabulary
  /// is backend-defined — render, don't branch on it for money logic.
  final String? riskStatus;

  /// Ledger transaction id of the customer credit. Non-null exactly once
  /// the deposit has been credited; the definitive settlement proof.
  final String? ledgerTransactionId;

  /// Index of the detected settlement event at the deposit address.
  final int? destinationEventIndex;

  /// Source network slug (`"base"`, `"ethereum"`).
  final String? sourceNetwork;

  /// Source asset id (`"{network}:{contract_address}"`) from the
  /// supported-assets allowlist.
  final String? sourceAssetId;

  /// Source token contract address, echoed by the backend.
  final String? sourceToken;

  /// Decimals of the source token's minor unit.
  final int? sourceTokenDecimals;

  /// The user's external wallet address funds will come from.
  final String? sourceWalletAddress;

  /// Deposit amount in source-asset minor units. Integer passthrough.
  final int sourceAmountMinor;

  /// Destination network — always `"solana"` in this MVP.
  final String? destinationNetwork;

  /// Destination SPL mint (native Circle USDC on Solana).
  final String? destinationMint;

  /// The user-specific Puente deposit address funds must arrive at.
  /// Assigned server-side; attribution is by address.
  final String? destinationAddress;

  /// Expected USDC delivery in minor units (from the active quote).
  final int? expectedDestinationMinor;

  /// Slippage-bounded minimum USDC delivery in minor units.
  final int? minimumDestinationMinor;

  /// USDC actually settled on-chain, in minor units. The ledger credits
  /// THIS amount — never the expected/quoted one. `null` until settled.
  final int? actualDestinationMinor;

  /// The active route quote, once `POST …/quotes` has run.
  final DepositQuote? quote;

  /// Provider route id, set by `prepare`. Opaque.
  final String? providerRouteId;

  /// The route contract approved to spend the source tokens, set by
  /// `prepare`. Echoed for wallet-side display; validated server-side.
  final String? spender;

  /// ERC-20 approval to sign first, when the current allowance is
  /// insufficient. `null` when no approval is needed. Set by `prepare`.
  final PuenteSigningRequest? approval;

  /// The route transaction to sign and broadcast. Set by `prepare`.
  final PuenteSigningRequest? transaction;

  /// Source-chain transaction hash reported via `reportSubmission`.
  /// A hint only — the server verifies settlement independently.
  final String? sourceTxHash;

  /// Solana transaction signature of the verified settlement.
  final String? destinationTxSignature;

  /// Stable failure code when [status] is a failure terminal
  /// (`"route_failed"`, `"wrong_asset"`, …). `null` otherwise.
  final String? failureCode;

  /// Human-oriented failure detail, when the server sent one.
  final String? failureDetails;

  /// Requested display currency (`"USD"`, `"MXN"`).
  final String? displayCurrency;

  /// Labeled indicative display estimate for [displayCurrency].
  final DepositDisplayEstimate? displayEstimate;

  /// Server timestamp when the session was created.
  final DateTime createdAt;

  /// Server timestamp of the last state change.
  final DateTime? updatedAt;

  /// When the client reported the source transaction as broadcast.
  final DateTime? submittedAt;

  /// When USDC was detected at the deposit address (`confirmed`).
  final DateTime? detectedAt;

  /// When the settlement reached `finalized` commitment.
  final DateTime? confirmedAt;

  /// When the customer ledger balance was credited.
  final DateTime? creditedAt;

  /// When the post-credit treasury sweep confirmed (internal).
  final DateTime? sweptAt;

  /// Build a [DepositSession].
  const DepositSession({
    required this.id,
    required this.status,
    required this.sourceAmountMinor,
    required this.createdAt,
    this.userId,
    this.provider,
    this.riskStatus,
    this.ledgerTransactionId,
    this.destinationEventIndex,
    this.sourceNetwork,
    this.sourceAssetId,
    this.sourceToken,
    this.sourceTokenDecimals,
    this.sourceWalletAddress,
    this.destinationNetwork,
    this.destinationMint,
    this.destinationAddress,
    this.expectedDestinationMinor,
    this.minimumDestinationMinor,
    this.actualDestinationMinor,
    this.quote,
    this.providerRouteId,
    this.spender,
    this.approval,
    this.transaction,
    this.sourceTxHash,
    this.destinationTxSignature,
    this.failureCode,
    this.failureDetails,
    this.displayCurrency,
    this.displayEstimate,
    this.updatedAt,
    this.submittedAt,
    this.detectedAt,
    this.confirmedAt,
    this.creditedAt,
    this.sweptAt,
  });

  /// Decode from the wire shape. Throws [FormatException] when the
  /// response is not a deposit session (missing `id`, `created_at`, or
  /// `source_amount_minor`) so malformed server output surfaces as a
  /// typed error instead of a cast crash.
  factory DepositSession.fromJson(Map<String, dynamic> json) => DepositSession(
        id: _requireString(json, 'id'),
        userId: json['user_id'] as String?,
        status: DepositStatus.fromWire(json['status'] as String?),
        provider: json['provider'] as String?,
        riskStatus: json['risk_status'] as String?,
        ledgerTransactionId: json['ledger_transaction_id'] as String?,
        destinationEventIndex: json['destination_event_index'] as int?,
        sourceNetwork: json['source_network'] as String?,
        sourceAssetId: json['source_asset_id'] as String?,
        sourceToken: json['source_token'] as String?,
        sourceTokenDecimals: json['source_token_decimals'] as int?,
        sourceWalletAddress: json['source_wallet_address'] as String?,
        sourceAmountMinor: _requireInt(json, 'source_amount_minor'),
        destinationNetwork: json['destination_network'] as String?,
        destinationMint: json['destination_mint'] as String?,
        destinationAddress: json['destination_address'] as String?,
        expectedDestinationMinor: json['expected_destination_minor'] as int?,
        minimumDestinationMinor: json['minimum_destination_minor'] as int?,
        actualDestinationMinor: json['actual_destination_minor'] as int?,
        quote: json['quote'] is Map
            ? DepositQuote.fromJson(
                (json['quote'] as Map).cast<String, dynamic>())
            : null,
        providerRouteId: json['provider_route_id'] as String?,
        spender: json['spender'] as String?,
        approval: json['approval'] is Map
            ? PuenteSigningRequest.fromJson(
                (json['approval'] as Map).cast<String, dynamic>())
            : null,
        transaction: json['transaction'] is Map
            ? PuenteSigningRequest.fromJson(
                (json['transaction'] as Map).cast<String, dynamic>())
            : null,
        sourceTxHash: json['source_tx_hash'] as String?,
        destinationTxSignature: json['destination_tx_signature'] as String?,
        failureCode: json['failure_code'] as String?,
        failureDetails: json['failure_details'] as String?,
        displayCurrency: json['display_currency'] as String?,
        displayEstimate: json['display_estimate'] is Map
            ? DepositDisplayEstimate.fromJson(
                (json['display_estimate'] as Map).cast<String, dynamic>())
            : null,
        createdAt: _requireDate(json, 'created_at'),
        updatedAt: _optDate(json['updated_at']),
        submittedAt: _optDate(json['submitted_at']),
        detectedAt: _optDate(json['detected_at']),
        confirmedAt: _optDate(json['confirmed_at']),
        creditedAt: _optDate(json['credited_at']),
        sweptAt: _optDate(json['swept_at']),
      );

  /// Encode back to the wire shape. Round-trips through [fromJson].
  Map<String, dynamic> toJson() => <String, dynamic>{
        'object': 'deposit_session',
        'id': id,
        if (userId != null) 'user_id': userId,
        'status': status.wire,
        if (provider != null) 'provider': provider,
        if (riskStatus != null) 'risk_status': riskStatus,
        if (ledgerTransactionId != null)
          'ledger_transaction_id': ledgerTransactionId,
        if (destinationEventIndex != null)
          'destination_event_index': destinationEventIndex,
        if (sourceNetwork != null) 'source_network': sourceNetwork,
        if (sourceAssetId != null) 'source_asset_id': sourceAssetId,
        if (sourceToken != null) 'source_token': sourceToken,
        if (sourceTokenDecimals != null)
          'source_token_decimals': sourceTokenDecimals,
        if (sourceWalletAddress != null)
          'source_wallet_address': sourceWalletAddress,
        'source_amount_minor': sourceAmountMinor,
        if (destinationNetwork != null)
          'destination_network': destinationNetwork,
        if (destinationMint != null) 'destination_mint': destinationMint,
        if (destinationAddress != null)
          'destination_address': destinationAddress,
        if (expectedDestinationMinor != null)
          'expected_destination_minor': expectedDestinationMinor,
        if (minimumDestinationMinor != null)
          'minimum_destination_minor': minimumDestinationMinor,
        if (actualDestinationMinor != null)
          'actual_destination_minor': actualDestinationMinor,
        if (quote != null) 'quote': quote!.toJson(),
        if (providerRouteId != null) 'provider_route_id': providerRouteId,
        if (spender != null) 'spender': spender,
        if (approval != null) 'approval': approval!.toJson(),
        if (transaction != null) 'transaction': transaction!.toJson(),
        if (sourceTxHash != null) 'source_tx_hash': sourceTxHash,
        if (destinationTxSignature != null)
          'destination_tx_signature': destinationTxSignature,
        if (failureCode != null) 'failure_code': failureCode,
        if (failureDetails != null) 'failure_details': failureDetails,
        if (displayCurrency != null) 'display_currency': displayCurrency,
        if (displayEstimate != null)
          'display_estimate': displayEstimate!.toJson(),
        'created_at': createdAt.toUtc().toIso8601String(),
        if (updatedAt != null)
          'updated_at': updatedAt!.toUtc().toIso8601String(),
        if (submittedAt != null)
          'submitted_at': submittedAt!.toUtc().toIso8601String(),
        if (detectedAt != null)
          'detected_at': detectedAt!.toUtc().toIso8601String(),
        if (confirmedAt != null)
          'confirmed_at': confirmedAt!.toUtc().toIso8601String(),
        if (creditedAt != null)
          'credited_at': creditedAt!.toUtc().toIso8601String(),
        if (sweptAt != null) 'swept_at': sweptAt!.toUtc().toIso8601String(),
      };

  static String _requireString(Map<String, dynamic> json, String key) {
    final raw = json[key];
    if (raw is! String || raw.isEmpty) {
      throw FormatException(
        'DepositSession.fromJson: missing/invalid "$key" — '
        'got ${raw.runtimeType}',
      );
    }
    return raw;
  }

  static int _requireInt(Map<String, dynamic> json, String key) {
    final raw = json[key];
    if (raw is! int) {
      throw FormatException(
        'DepositSession.fromJson: missing/invalid "$key" — '
        'got ${raw.runtimeType}',
      );
    }
    return raw;
  }

  static DateTime _requireDate(Map<String, dynamic> json, String key) {
    final raw = json[key];
    if (raw is! String) {
      throw FormatException(
        'DepositSession.fromJson: missing/invalid "$key" — '
        'got ${raw.runtimeType}',
      );
    }
    return DateTime.parse(raw).toUtc();
  }

  static DateTime? _optDate(Object? raw) =>
      raw is String ? DateTime.parse(raw).toUtc() : null;

  @override
  List<Object?> get props => [
        id,
        userId,
        status,
        provider,
        riskStatus,
        ledgerTransactionId,
        destinationEventIndex,
        sourceNetwork,
        sourceAssetId,
        sourceToken,
        sourceTokenDecimals,
        sourceWalletAddress,
        sourceAmountMinor,
        destinationNetwork,
        destinationMint,
        destinationAddress,
        expectedDestinationMinor,
        minimumDestinationMinor,
        actualDestinationMinor,
        quote,
        providerRouteId,
        spender,
        approval,
        transaction,
        sourceTxHash,
        destinationTxSignature,
        failureCode,
        failureDetails,
        displayCurrency,
        displayEstimate,
        createdAt,
        updatedAt,
        submittedAt,
        detectedAt,
        confirmedAt,
        creditedAt,
        sweptAt,
      ];
}
