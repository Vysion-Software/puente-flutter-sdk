import 'package:equatable/equatable.dart';

/// The compressed-NFT (cNFT) proof block attached to a settled transfer's
/// receipt — the on-chain "folio" Pesito shows the user.
///
/// **Decode-only value type.** Minting happens server-side; the SDK only
/// deserializes what the backend reports. [assetId] and [mintSignature]
/// are `null` while the mint is still being confirmed.
class ReceiptMetadata extends Equatable {
  /// Human-readable receipt folio (e.g. `"PES-A1B2C3"`).
  final String folio;

  /// Compressed-NFT asset id, once minted.
  final String? assetId;

  /// URI of the receipt metadata document.
  final String metadataUri;

  /// Solana transaction signature of the mint, once confirmed.
  final String? mintSignature;

  /// Build a [ReceiptMetadata].
  const ReceiptMetadata({
    required this.folio,
    required this.metadataUri,
    this.assetId,
    this.mintSignature,
  });

  /// Decode from the backend's `cnft` wire shape.
  factory ReceiptMetadata.fromJson(Map<String, dynamic> json) =>
      ReceiptMetadata(
        folio: json['folio'] as String,
        assetId: json['asset_id'] as String?,
        metadataUri: json['metadata_uri'] as String,
        mintSignature: json['mint_signature'] as String?,
      );

  @override
  List<Object?> get props => [folio, assetId, metadataUri, mintSignature];
}
