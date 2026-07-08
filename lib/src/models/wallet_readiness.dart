import 'package:equatable/equatable.dart';

import 'account.dart' show KycTier;
import 'kyc_status.dart';

/// Backend-authoritative wallet gate (`GET /v1/wallet/readiness`).
///
/// The app must gate wallet features on [ready] — never on local state or
/// on [KycStatus] alone. `missing` explains what still blocks:
/// `profile_incomplete | consent_required | kyc_not_approved`.
class WalletReadiness extends Equatable {
  final bool ready;
  final KycStatus kycStatus;
  final KycTier kycTier;
  final List<String> missing;

  const WalletReadiness({
    required this.ready,
    required this.kycStatus,
    required this.kycTier,
    required this.missing,
  });

  factory WalletReadiness.fromJson(Map<String, dynamic> json) =>
      WalletReadiness(
        ready: json['ready'] as bool? ?? false,
        kycStatus: KycStatus.fromWire(json['kyc_status'] as String?),
        kycTier: KycTier.fromWire(json['kyc_tier'] as String?),
        missing: (json['missing'] as List<dynamic>? ?? const <dynamic>[])
            .cast<String>(),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'ready': ready,
        'kyc_status': kycStatus.wire,
        'kyc_tier': kycTier.wire,
        'missing': missing,
      };

  @override
  List<Object?> get props => [ready, kycStatus, kycTier, missing];
}
