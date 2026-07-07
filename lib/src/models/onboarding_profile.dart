import 'package:equatable/equatable.dart';

import 'kyc_status.dart';
import 'account.dart' show KycTier;

/// Result of `POST /v1/onboarding/applicants`.
///
/// SECURITY: `applicantToken` is returned exactly ONCE (creation or
/// rotation) and is the bearer credential for every applicant-scoped call.
/// Store it in platform secure storage; it is never retrievable again.
/// Re-creating the same `externalUserId` ROTATES the token (the deliberate
/// app-restart / lost-storage recovery path — the old token is invalidated).
class ApplicantCredentials extends Equatable {
  final String applicantId;
  final String applicantToken;
  final KycStatus kycStatus;
  final KycTier kycTier;

  /// False when the applicant already existed and the token was rotated.
  final bool created;

  const ApplicantCredentials({
    required this.applicantId,
    required this.applicantToken,
    required this.kycStatus,
    required this.kycTier,
    required this.created,
  });

  factory ApplicantCredentials.fromJson(Map<String, dynamic> json) =>
      ApplicantCredentials(
        applicantId: json['applicant_id'] as String,
        applicantToken: json['applicant_token'] as String,
        kycStatus: KycStatus.fromWire(json['kyc_status'] as String?),
        kycTier: KycTier.fromWire(json['kyc_tier'] as String?),
        created: json['created'] as bool? ?? true,
      );

  /// Deliberately EXCLUDES the token — credentials must not round-trip
  /// through JSON caches or logs.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'applicant_id': applicantId,
        'kyc_status': kycStatus.wire,
        'kyc_tier': kycTier.wire,
        'created': created,
      };

  @override
  String toString() =>
      'ApplicantCredentials($applicantId, $kycStatus, token: ****)';

  @override
  List<Object?> get props =>
      [applicantId, applicantToken, kycStatus, kycTier, created];
}

/// A sensitive identifier as the backend exposes it: type + last4 ONLY.
/// Raw SSN/ITIN/CURP values are never returned by any endpoint.
class MaskedIdentifier extends Equatable {
  /// `ssn | itin | curp | rfc | nss`.
  final String type;
  final String last4;

  const MaskedIdentifier({required this.type, required this.last4});

  factory MaskedIdentifier.fromJson(Map<String, dynamic> json) =>
      MaskedIdentifier(
        type: json['type'] as String,
        last4: json['last4'] as String? ?? '',
      );

  Map<String, dynamic> toJson() =>
      <String, dynamic>{'type': type, 'last4': last4};

  /// Display form, e.g. `•••• 6789`.
  String get masked => '•••• $last4';

  @override
  List<Object?> get props => [type, last4];
}

/// The identity document the applicant chose (type + issuing country only —
/// document images live with the verification provider, never in Puente).
class IdentityDocumentChoice extends Equatable {
  final String type;
  final String? issuingCountry;

  const IdentityDocumentChoice({required this.type, this.issuingCountry});

  factory IdentityDocumentChoice.fromJson(Map<String, dynamic> json) =>
      IdentityDocumentChoice(
        type: json['type'] as String,
        issuingCountry: json['issuing_country'] as String?,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': type,
        if (issuingCountry != null) 'issuing_country': issuingCountry,
      };

  @override
  List<Object?> get props => [type, issuingCountry];
}

class OnboardingAddress extends Equatable {
  final String? line1;
  final String? line2;
  final String? city;
  final String? state;
  final String? postalCode;
  final String? country;

  const OnboardingAddress({
    this.line1,
    this.line2,
    this.city,
    this.state,
    this.postalCode,
    this.country,
  });

  factory OnboardingAddress.fromJson(Map<String, dynamic> json) =>
      OnboardingAddress(
        line1: json['line1'] as String?,
        line2: json['line2'] as String?,
        city: json['city'] as String?,
        state: json['state'] as String?,
        postalCode: json['postal_code'] as String?,
        country: json['country'] as String?,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (line1 != null) 'line1': line1,
        if (line2 != null) 'line2': line2,
        if (city != null) 'city': city,
        if (state != null) 'state': state,
        if (postalCode != null) 'postal_code': postalCode,
        if (country != null) 'country': country,
      };

  @override
  List<Object?> get props => [line1, line2, city, state, postalCode, country];
}

/// Consent snapshot: which disclosure version the applicant accepted, when,
/// and whether it is still the current version.
class OnboardingConsent extends Equatable {
  final String? disclosureVersion;
  final DateTime? consentAt;
  final bool current;

  const OnboardingConsent({
    required this.current,
    this.disclosureVersion,
    this.consentAt,
  });

  factory OnboardingConsent.fromJson(Map<String, dynamic> json) =>
      OnboardingConsent(
        disclosureVersion: json['disclosure_version'] as String?,
        consentAt: json['consent_at'] is String
            ? DateTime.parse(json['consent_at'] as String).toUtc()
            : null,
        current: json['current'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (disclosureVersion != null) 'disclosure_version': disclosureVersion,
        if (consentAt != null) 'consent_at': consentAt!.toIso8601String(),
        'current': current,
      };

  @override
  List<Object?> get props => [disclosureVersion, consentAt, current];
}

/// The applicant's onboarding profile as the backend exposes it
/// (`GET/PUT /v1/onboarding/profile`). Region-aware and masked: sensitive
/// identifiers surface as [MaskedIdentifier]; sections that were never
/// collected are simply null.
class OnboardingProfile extends Equatable {
  final String applicantId;
  final String externalUserId;
  final KycStatus kycStatus;
  final KycTier kycTier;
  final bool requiresManualReview;
  final String? phone;
  final String? email;
  final String? legalFirstName;
  final String? legalMiddleName;
  final String? legalLastName;

  /// ISO `YYYY-MM-DD`, kept as a string (a display value, never date math).
  final String? dateOfBirth;
  final OnboardingAddress address;
  final String? residenceCountry;
  final String? region;
  final String? transferCorridor;
  final String? intendedUse;
  final String? sourceOfFunds;
  final String? expectedVolumeBand;
  final MaskedIdentifier? sensitiveIdentifier;
  final IdentityDocumentChoice? document;
  final OnboardingConsent consent;
  final String? policyVersion;

  /// `editable` | `review_required` — whether profile fields may still be
  /// changed directly or must go through a correction request.
  final String fieldEditability;
  final bool complete;
  final List<String> missing;
  final DateTime? updatedAt;

  const OnboardingProfile({
    required this.applicantId,
    required this.externalUserId,
    required this.kycStatus,
    required this.kycTier,
    required this.requiresManualReview,
    required this.address,
    required this.consent,
    required this.fieldEditability,
    required this.complete,
    required this.missing,
    this.phone,
    this.email,
    this.legalFirstName,
    this.legalMiddleName,
    this.legalLastName,
    this.dateOfBirth,
    this.residenceCountry,
    this.region,
    this.transferCorridor,
    this.intendedUse,
    this.sourceOfFunds,
    this.expectedVolumeBand,
    this.sensitiveIdentifier,
    this.document,
    this.policyVersion,
    this.updatedAt,
  });

  factory OnboardingProfile.fromJson(Map<String, dynamic> json) {
    final contact =
        json['contact'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    final profile =
        json['profile'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    final address = profile['address'] as Map<String, dynamic>? ??
        const <String, dynamic>{};
    return OnboardingProfile(
      applicantId: json['applicant_id'] as String,
      externalUserId: json['external_user_id'] as String? ?? '',
      kycStatus: KycStatus.fromWire(json['kyc_status'] as String?),
      kycTier: KycTier.fromWire(json['kyc_tier'] as String?),
      requiresManualReview: json['requires_manual_review'] as bool? ?? false,
      phone: contact['phone'] as String?,
      email: contact['email'] as String?,
      legalFirstName: profile['legal_first_name'] as String?,
      legalMiddleName: profile['legal_middle_name'] as String?,
      legalLastName: profile['legal_last_name'] as String?,
      dateOfBirth: profile['date_of_birth'] as String?,
      address: OnboardingAddress.fromJson(address),
      residenceCountry: profile['residence_country'] as String?,
      region: profile['region'] as String?,
      transferCorridor: profile['transfer_corridor'] as String?,
      intendedUse: profile['intended_use'] as String?,
      sourceOfFunds: profile['source_of_funds'] as String?,
      expectedVolumeBand: profile['expected_volume_band'] as String?,
      sensitiveIdentifier: json['sensitive_identifier'] is Map<String, dynamic>
          ? MaskedIdentifier.fromJson(
              json['sensitive_identifier'] as Map<String, dynamic>)
          : null,
      document: json['document'] is Map<String, dynamic>
          ? IdentityDocumentChoice.fromJson(
              json['document'] as Map<String, dynamic>)
          : null,
      consent: OnboardingConsent.fromJson(
          json['consent'] as Map<String, dynamic>? ??
              const <String, dynamic>{}),
      policyVersion: json['policy_version'] as String?,
      fieldEditability: json['field_editability'] as String? ?? 'editable',
      complete: json['complete'] as bool? ?? false,
      missing: (json['missing'] as List<dynamic>? ?? const <dynamic>[])
          .cast<String>(),
      updatedAt: json['updated_at'] is String
          ? DateTime.parse(json['updated_at'] as String).toUtc()
          : null,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'applicant_id': applicantId,
        'external_user_id': externalUserId,
        'kyc_status': kycStatus.wire,
        'kyc_tier': kycTier.wire,
        'requires_manual_review': requiresManualReview,
        'contact': <String, dynamic>{'phone': phone, 'email': email},
        'profile': <String, dynamic>{
          'legal_first_name': legalFirstName,
          'legal_middle_name': legalMiddleName,
          'legal_last_name': legalLastName,
          'date_of_birth': dateOfBirth,
          'address': address.toJson(),
          'residence_country': residenceCountry,
          'region': region,
          'transfer_corridor': transferCorridor,
          'intended_use': intendedUse,
          'source_of_funds': sourceOfFunds,
          'expected_volume_band': expectedVolumeBand,
        },
        if (sensitiveIdentifier != null)
          'sensitive_identifier': sensitiveIdentifier!.toJson(),
        if (document != null) 'document': document!.toJson(),
        'consent': consent.toJson(),
        if (policyVersion != null) 'policy_version': policyVersion,
        'field_editability': fieldEditability,
        'complete': complete,
        'missing': missing,
        if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      };

  bool get isLocked => fieldEditability == 'review_required';

  @override
  List<Object?> get props => [
        applicantId,
        externalUserId,
        kycStatus,
        kycTier,
        requiresManualReview,
        phone,
        email,
        legalFirstName,
        legalMiddleName,
        legalLastName,
        dateOfBirth,
        address,
        residenceCountry,
        region,
        transferCorridor,
        intendedUse,
        sourceOfFunds,
        expectedVolumeBand,
        sensitiveIdentifier,
        document,
        consent,
        policyVersion,
        fieldEditability,
        complete,
        missing,
        updatedAt,
      ];
}
