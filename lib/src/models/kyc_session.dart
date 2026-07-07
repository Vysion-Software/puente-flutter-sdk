import 'package:equatable/equatable.dart';

import 'kyc_status.dart';

/// A verification session (`POST /v1/kyc/sessions`,
/// `GET /v1/kyc/sessions/current`).
///
/// `clientToken` is present ONLY on the creation response (mirrors Incode's
/// `/omni/start` handoff — the short-lived token the provider's mobile SDK
/// initializes with). It is never persisted server-side and never returned
/// again; treat it as ephemeral.
class KycSession extends Equatable {
  final String sessionId;

  /// `mock` | `incode`.
  final String provider;

  /// Opaque provider ref (Incode interviewId / mock ref).
  final String? providerSessionRef;
  final VerificationSessionStatus status;
  final String? failureReason;
  final KycStatus kycStatus;
  final DateTime expiresAt;

  /// True when an in-flight session already existed and was returned
  /// instead of creating a duplicate.
  final bool duplicate;
  final String? clientToken;

  const KycSession({
    required this.sessionId,
    required this.provider,
    required this.status,
    required this.kycStatus,
    required this.expiresAt,
    required this.duplicate,
    this.providerSessionRef,
    this.failureReason,
    this.clientToken,
  });

  factory KycSession.fromJson(Map<String, dynamic> json) => KycSession(
        sessionId: json['session_id'] as String,
        provider: json['provider'] as String? ?? 'unknown',
        providerSessionRef: json['provider_session_ref'] as String?,
        status: VerificationSessionStatus.fromWire(json['status'] as String?),
        failureReason: json['failure_reason'] as String?,
        kycStatus: KycStatus.fromWire(json['kyc_status'] as String?),
        expiresAt: json['expires_at'] is String
            ? DateTime.parse(json['expires_at'] as String).toUtc()
            : DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        duplicate: json['duplicate'] as bool? ?? false,
        clientToken: json['client_token'] as String?,
      );

  /// Deliberately EXCLUDES `clientToken` — session tokens must not
  /// round-trip through JSON caches or logs.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'session_id': sessionId,
        'provider': provider,
        if (providerSessionRef != null)
          'provider_session_ref': providerSessionRef,
        'status': status.wire,
        if (failureReason != null) 'failure_reason': failureReason,
        'kyc_status': kycStatus.wire,
        'expires_at': expiresAt.toIso8601String(),
        'duplicate': duplicate,
      };

  @override
  String toString() =>
      'KycSession($sessionId, $provider, ${status.wire}, token: ****)';

  @override
  List<Object?> get props => [
        sessionId,
        provider,
        providerSessionRef,
        status,
        failureReason,
        kycStatus,
        expiresAt,
        duplicate,
        clientToken,
      ];
}

/// Result of driving the MOCK verification lifecycle
/// (`POST /v1/kyc/sessions/{id}/mock-events` — VENDOR_MODE=mock only; the
/// route does not exist in live mode).
class MockKycEventResult extends Equatable {
  final String sessionId;
  final VerificationSessionStatus status;
  final KycStatus kycStatus;

  const MockKycEventResult({
    required this.sessionId,
    required this.status,
    required this.kycStatus,
  });

  factory MockKycEventResult.fromJson(Map<String, dynamic> json) =>
      MockKycEventResult(
        sessionId: json['session_id'] as String,
        status: VerificationSessionStatus.fromWire(json['status'] as String?),
        kycStatus: KycStatus.fromWire(json['kyc_status'] as String?),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'session_id': sessionId,
        'status': status.wire,
        'kyc_status': kycStatus.wire,
      };

  @override
  List<Object?> get props => [sessionId, status, kycStatus];
}
