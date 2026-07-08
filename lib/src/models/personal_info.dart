import 'package:equatable/equatable.dart';

import 'kyc_status.dart';
import 'onboarding_profile.dart';

/// Latest verification-session summary as shown on Personal Information.
class VerificationSummary extends Equatable {
  final VerificationSessionStatus status;
  final String provider;
  final String? failureReason;

  const VerificationSummary({
    required this.status,
    required this.provider,
    this.failureReason,
  });

  factory VerificationSummary.fromJson(Map<String, dynamic> json) =>
      VerificationSummary(
        status: VerificationSessionStatus.fromWire(json['status'] as String?),
        provider: json['provider'] as String? ?? 'unknown',
        failureReason: json['failure_reason'] as String?,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'status': status.wire,
        'provider': provider,
        if (failureReason != null) 'failure_reason': failureReason,
      };

  @override
  List<Object?> get props => [status, provider, failureReason];
}

/// Region-aware Personal Information view (`GET /v1/me/personal-info`).
///
/// Everything sensitive is masked server-side (identifiers surface as
/// type + last4 only); sections never collected are simply absent. Viewing
/// is audit-logged server-side (the fact of a view, never the values).
class PersonalInfo extends Equatable {
  final OnboardingProfile profile;
  final VerificationSummary? verification;
  final bool manualReviewRequired;
  final bool manualReviewPending;

  const PersonalInfo({
    required this.profile,
    required this.manualReviewRequired,
    required this.manualReviewPending,
    this.verification,
  });

  factory PersonalInfo.fromJson(Map<String, dynamic> json) {
    final manualReview = json['manual_review'] as Map<String, dynamic>? ??
        const <String, dynamic>{};
    return PersonalInfo(
      profile: OnboardingProfile.fromJson(json),
      verification: json['verification'] is Map<String, dynamic>
          ? VerificationSummary.fromJson(
              json['verification'] as Map<String, dynamic>)
          : null,
      manualReviewRequired: manualReview['required'] as bool? ?? false,
      manualReviewPending: manualReview['pending'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        ...profile.toJson(),
        'verification': verification?.toJson(),
        'manual_review': <String, dynamic>{
          'required': manualReviewRequired,
          'pending': manualReviewPending,
        },
      };

  @override
  List<Object?> get props =>
      [profile, verification, manualReviewRequired, manualReviewPending];
}

/// Receipt for a submitted correction request
/// (`POST /v1/me/personal-info/correction-requests`). Corrections to
/// KYC-locked fields are reviewed server-side — never applied directly.
class CorrectionRequestReceipt extends Equatable {
  final String id;

  /// `pending | applied | dismissed`.
  final String status;

  const CorrectionRequestReceipt({required this.id, required this.status});

  factory CorrectionRequestReceipt.fromJson(Map<String, dynamic> json) =>
      CorrectionRequestReceipt(
        id: json['id'] as String,
        status: json['status'] as String? ?? 'pending',
      );

  Map<String, dynamic> toJson() =>
      <String, dynamic>{'id': id, 'status': status};

  @override
  List<Object?> get props => [id, status];
}
