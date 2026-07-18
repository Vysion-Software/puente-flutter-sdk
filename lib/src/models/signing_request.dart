import 'package:equatable/equatable.dart';

/// Provider-neutral signing request handed to the user's external wallet.
///
/// The Puente backend builds these server-side (validating destination,
/// spender, and amounts against its allowlists) and the client passes
/// them to the wallet **without interpretation** — the SDK never
/// constructs, mutates, or signs transactions.
///
/// Discriminated on the wire by `"type"`:
///
/// * `evm_transaction` → [EvmTransactionSigningRequest]
/// * `evm_erc20_approval` → [EvmErc20ApprovalSigningRequest]
/// * `solana_transaction` → [SolanaTransactionSigningRequest]
/// * anything else → [UnknownSigningRequest] (never throws — a new
///   backend variant must not crash a deployed app)
///
/// Being a Dart 3 `sealed` class, a `switch` over the union is
/// exhaustively checked at compile time.
sealed class PuenteSigningRequest extends Equatable {
  /// Const base constructor for subclasses.
  const PuenteSigningRequest();

  /// The wire discriminator (`"evm_transaction"`, …). For
  /// [UnknownSigningRequest] this is whatever the server sent.
  String get type;

  /// Decode a signing request, dispatching on `"type"`. Unrecognized
  /// types decode to [UnknownSigningRequest] — this factory never throws
  /// on a new variant.
  factory PuenteSigningRequest.fromJson(Map<String, dynamic> json) {
    switch (json['type']) {
      case 'evm_transaction':
        return EvmTransactionSigningRequest.fromJson(json);
      case 'evm_erc20_approval':
        return EvmErc20ApprovalSigningRequest.fromJson(json);
      case 'solana_transaction':
        return SolanaTransactionSigningRequest.fromJson(json);
      default:
        return UnknownSigningRequest.fromJson(json);
    }
  }

  /// Encode back to the wire shape (includes `"type"`).
  Map<String, dynamic> toJson();
}

/// An unsigned EVM transaction the wallet should sign and broadcast
/// (`"type": "evm_transaction"`).
///
/// Numeric-looking fields ([value], [gasLimit], fee caps) are **decimal
/// strings** on the wire — they can exceed 2^63 and are passed through
/// verbatim to the wallet, never parsed into money math by the SDK.
final class EvmTransactionSigningRequest extends PuenteSigningRequest {
  /// EVM chain id (e.g. `8453` for Base).
  final int chainId;

  /// Sender address — must be the connected wallet's address.
  final String from;

  /// Contract (or recipient) address to call.
  final String to;

  /// ABI-encoded calldata, `0x`-prefixed hex.
  final String data;

  /// Native value to attach, in wei, as a decimal string (usually `"0"`).
  final String value;

  /// Optional gas limit (decimal string); `null` → wallet estimates.
  final String? gasLimit;

  /// Optional EIP-1559 max fee per gas (decimal string).
  final String? maxFeePerGas;

  /// Optional EIP-1559 max priority fee per gas (decimal string).
  final String? maxPriorityFeePerGas;

  /// Build an [EvmTransactionSigningRequest].
  const EvmTransactionSigningRequest({
    required this.chainId,
    required this.from,
    required this.to,
    required this.data,
    required this.value,
    this.gasLimit,
    this.maxFeePerGas,
    this.maxPriorityFeePerGas,
  });

  @override
  String get type => 'evm_transaction';

  /// Decode from the wire shape.
  factory EvmTransactionSigningRequest.fromJson(Map<String, dynamic> json) =>
      EvmTransactionSigningRequest(
        chainId: _parseChainId(json['chain_id']),
        from: json['from'] as String? ?? '',
        to: json['to'] as String? ?? '',
        data: json['data'] as String? ?? '',
        value: json['value']?.toString() ?? '0',
        gasLimit: json['gas_limit']?.toString(),
        maxFeePerGas: json['max_fee_per_gas']?.toString(),
        maxPriorityFeePerGas: json['max_priority_fee_per_gas']?.toString(),
      );

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': type,
        'chain_id': chainId,
        'from': from,
        'to': to,
        'data': data,
        'value': value,
        'gas_limit': gasLimit,
        'max_fee_per_gas': maxFeePerGas,
        'max_priority_fee_per_gas': maxPriorityFeePerGas,
      };

  @override
  List<Object?> get props => [
        chainId,
        from,
        to,
        data,
        value,
        gasLimit,
        maxFeePerGas,
        maxPriorityFeePerGas,
      ];
}

/// An exact-amount ERC-20 `approve` the wallet must sign before the route
/// transaction can pull the tokens (`"type": "evm_erc20_approval"`).
///
/// The backend builds the calldata server-side after validating [spender]
/// against the provider's returned route contract; approvals are
/// exact-amount by policy, never unlimited.
final class EvmErc20ApprovalSigningRequest extends PuenteSigningRequest {
  /// EVM chain id (e.g. `8453` for Base).
  final int chainId;

  /// ERC-20 token contract being approved.
  final String token;

  /// The route provider's contract that will spend the tokens.
  final String spender;

  /// Exact approval amount in token minor units, as a **decimal string**
  /// (can exceed 2^63; passed through verbatim, never computed on).
  final String amountMinor;

  /// Sender address — must be the connected wallet's address.
  final String from;

  /// Transaction target — the [token] contract.
  final String to;

  /// ABI-encoded `approve(spender, amount)` calldata, `0x`-prefixed.
  final String data;

  /// Native value to attach, in wei, as a decimal string (always `"0"`).
  final String value;

  /// Build an [EvmErc20ApprovalSigningRequest].
  const EvmErc20ApprovalSigningRequest({
    required this.chainId,
    required this.token,
    required this.spender,
    required this.amountMinor,
    required this.from,
    required this.to,
    required this.data,
    required this.value,
  });

  @override
  String get type => 'evm_erc20_approval';

  /// Decode from the wire shape.
  factory EvmErc20ApprovalSigningRequest.fromJson(Map<String, dynamic> json) =>
      EvmErc20ApprovalSigningRequest(
        chainId: _parseChainId(json['chain_id']),
        token: json['token'] as String? ?? '',
        spender: json['spender'] as String? ?? '',
        amountMinor: json['amount_minor']?.toString() ?? '0',
        from: json['from'] as String? ?? '',
        to: json['to'] as String? ?? '',
        data: json['data'] as String? ?? '',
        value: json['value']?.toString() ?? '0',
      );

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': type,
        'chain_id': chainId,
        'token': token,
        'spender': spender,
        'amount_minor': amountMinor,
        'from': from,
        'to': to,
        'data': data,
        'value': value,
      };

  @override
  List<Object?> get props =>
      [chainId, token, spender, amountMinor, from, to, data, value];
}

/// A pre-serialized Solana transaction the wallet should sign and send
/// (`"type": "solana_transaction"`).
final class SolanaTransactionSigningRequest extends PuenteSigningRequest {
  /// Solana cluster (`"mainnet-beta"`, `"devnet"`, …).
  final String network;

  /// Serialization encoding of [serializedTransaction] (`"base64"`).
  final String encoding;

  /// The unsigned transaction, serialized per [encoding]. Opaque to the
  /// SDK — handed to the wallet verbatim.
  final String serializedTransaction;

  /// Public keys whose signatures the transaction requires.
  final List<String> requiredSigners;

  /// Build a [SolanaTransactionSigningRequest].
  const SolanaTransactionSigningRequest({
    required this.network,
    required this.encoding,
    required this.serializedTransaction,
    required this.requiredSigners,
  });

  @override
  String get type => 'solana_transaction';

  /// Decode from the wire shape.
  factory SolanaTransactionSigningRequest.fromJson(Map<String, dynamic> json) =>
      SolanaTransactionSigningRequest(
        network: json['network'] as String? ?? '',
        encoding: json['encoding'] as String? ?? 'base64',
        serializedTransaction: json['serialized_transaction'] as String? ?? '',
        requiredSigners:
            (json['required_signers'] as List<dynamic>? ?? const <dynamic>[])
                .whereType<String>()
                .toList(growable: false),
      );

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': type,
        'network': network,
        'encoding': encoding,
        'serialized_transaction': serializedTransaction,
        'required_signers': requiredSigners,
      };

  @override
  List<Object?> get props =>
      [network, encoding, serializedTransaction, requiredSigners];
}

/// Forward-compatibility fallback for signing-request types this SDK
/// build doesn't know. The raw payload is preserved in [payload] so a
/// newer wallet integration layer can still act on it if it chooses;
/// UIs should treat it as "please update the app".
final class UnknownSigningRequest extends PuenteSigningRequest {
  @override
  final String type;

  /// The raw wire payload, verbatim (including `"type"`).
  final Map<String, dynamic> payload;

  /// Build an [UnknownSigningRequest].
  const UnknownSigningRequest({required this.type, required this.payload});

  /// Decode from any wire shape; never throws.
  factory UnknownSigningRequest.fromJson(Map<String, dynamic> json) =>
      UnknownSigningRequest(
        type: json['type']?.toString() ?? 'unknown',
        payload: json,
      );

  @override
  Map<String, dynamic> toJson() => Map<String, dynamic>.from(payload);

  @override
  List<Object?> get props => [type, payload];
}

/// Chain ids arrive as JSON numbers (`8453`) but tolerate strings
/// (`"8453"`) — providers are inconsistent. `0` on unparseable input.
int _parseChainId(Object? raw) {
  if (raw is int) return raw;
  if (raw is String) return int.tryParse(raw) ?? 0;
  return 0;
}
