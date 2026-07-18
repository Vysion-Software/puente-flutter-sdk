import 'package:equatable/equatable.dart';

/// A source asset the backend accepts for external-wallet deposits —
/// one entry of `GET /v1/deposit-assets`.
///
/// The list is a **server-side allowlist** from Puente config
/// (`DEPOSIT_ALLOWED_SOURCE_ASSETS`); nothing is inferred from symbols
/// client-side. Amount bounds are integer minor units at [decimals].
class SupportedDepositAsset extends Equatable {
  /// Stable asset identifier, `"{network}:{contract_address}"` — e.g.
  /// `"base:0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913"`. Pass this as
  /// `sourceAssetId` when creating a deposit session.
  final String id;

  /// Source network slug (`"base"`, `"ethereum"`, …).
  final String network;

  /// Chain id **as a string** (matches the provider convention — e.g.
  /// `"8453"` for Base; non-EVM chains use names).
  final String chainId;

  /// Ticker symbol for display (`"USDC"`). Never used for routing.
  final String symbol;

  /// Human-readable asset name (`"USD Coin"`).
  final String name;

  /// Number of decimals in the asset's minor unit (6 for USDC).
  final int decimals;

  /// Smallest accepted deposit, in minor units of this asset.
  final int minAmountMinor;

  /// Largest accepted deposit, in minor units of this asset.
  final int maxAmountMinor;

  /// Whether the backend currently accepts this asset. Disabled assets
  /// are still listed so the UI can explain instead of silently hiding.
  final bool enabled;

  /// Build a [SupportedDepositAsset].
  const SupportedDepositAsset({
    required this.id,
    required this.network,
    required this.chainId,
    required this.symbol,
    required this.name,
    required this.decimals,
    required this.minAmountMinor,
    required this.maxAmountMinor,
    required this.enabled,
  });

  /// Decode from the `GET /v1/deposit-assets` wire shape.
  factory SupportedDepositAsset.fromJson(Map<String, dynamic> json) =>
      SupportedDepositAsset(
        id: json['id'] as String,
        network: json['network'] as String,
        chainId: json['chain_id']?.toString() ?? '',
        symbol: json['symbol'] as String? ?? '',
        name: json['name'] as String? ?? '',
        decimals: json['decimals'] as int? ?? 0,
        minAmountMinor: json['min_amount_minor'] as int? ?? 0,
        maxAmountMinor: json['max_amount_minor'] as int? ?? 0,
        enabled: json['enabled'] as bool? ?? false,
      );

  /// Encode back to the wire shape. Round-trips through [fromJson].
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'network': network,
        'chain_id': chainId,
        'symbol': symbol,
        'name': name,
        'decimals': decimals,
        'min_amount_minor': minAmountMinor,
        'max_amount_minor': maxAmountMinor,
        'enabled': enabled,
      };

  @override
  List<Object?> get props => [
        id,
        network,
        chainId,
        symbol,
        name,
        decimals,
        minAmountMinor,
        maxAmountMinor,
        enabled,
      ];
}
