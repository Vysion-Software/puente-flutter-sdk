import 'package:equatable/equatable.dart';

/// Legal/compliance review state of a policy-driven onboarding path.
///
/// The app labels paths honestly from this flag ("may take longer to
/// review") instead of hardcoding region assumptions. Never present a
/// `requiresLegalReview` path as fully supported.
enum LegalReviewStatus {
  approvedPolicy('approved_policy'),
  requiresLegalReview('requires_legal_review'),
  mockOnly('mock_only'),
  unknown('unknown');

  final String wire;
  const LegalReviewStatus(this.wire);

  static LegalReviewStatus fromWire(String? value) {
    if (value == null) return LegalReviewStatus.unknown;
    for (final s in LegalReviewStatus.values) {
      if (s.wire == value) return s;
    }
    return LegalReviewStatus.unknown;
  }
}

/// How strongly the region policy asks for a sensitive identifier.
enum IdentifierRequirementLevel {
  required('required'),

  /// Exactly one identifier from the one-of group must be provided
  /// (e.g. US: SSN or ITIN — an ITIN holder without an SSN is not blocked).
  requiredOneOf('required_one_of'),

  /// May be provided; the UI must not pressure the user for it.
  optional('optional'),
  unknown('unknown');

  final String wire;
  const IdentifierRequirementLevel(this.wire);

  static IdentifierRequirementLevel fromWire(String? value) {
    if (value == null) return IdentifierRequirementLevel.unknown;
    for (final s in IdentifierRequirementLevel.values) {
      if (s.wire == value) return s;
    }
    return IdentifierRequirementLevel.unknown;
  }
}

/// An identity document the backend policy allows for the region.
class PolicyDocumentOption extends Equatable {
  /// Wire vocab: `us_drivers_license | us_state_id | us_passport |
  /// mexican_passport | ine | foreign_passport | consular_id |
  /// proof_of_address`.
  final String documentType;

  /// Issuing countries accepted for this option; empty = any.
  final List<String> issuingCountries;
  final LegalReviewStatus legalReviewStatus;

  /// True → this path routes to manual review even on provider approval.
  final bool manualReviewRequired;

  const PolicyDocumentOption({
    required this.documentType,
    required this.issuingCountries,
    required this.legalReviewStatus,
    required this.manualReviewRequired,
  });

  factory PolicyDocumentOption.fromJson(Map<String, dynamic> json) =>
      PolicyDocumentOption(
        documentType: json['document_type'] as String,
        issuingCountries:
            (json['issuing_countries'] as List<dynamic>? ?? const <dynamic>[])
                .cast<String>(),
        legalReviewStatus:
            LegalReviewStatus.fromWire(json['legal_review_status'] as String?),
        manualReviewRequired: json['manual_review_required'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'document_type': documentType,
        'issuing_countries': issuingCountries,
        'legal_review_status': legalReviewStatus.wire,
        'manual_review_required': manualReviewRequired,
      };

  @override
  List<Object?> get props =>
      [documentType, issuingCountries, legalReviewStatus, manualReviewRequired];
}

/// A sensitive identifier the region policy may collect. Identifiers that
/// are absent from the policy are NOT collected at all (data minimization) —
/// the app must not render fields for them.
class PolicyIdentifierRequirement extends Equatable {
  /// Wire vocab: `ssn | itin | curp | rfc | nss`.
  final String identifierType;
  final IdentifierRequirementLevel requirement;

  /// l10n key explaining why this is asked.
  final String reasonKey;
  final LegalReviewStatus legalReviewStatus;

  const PolicyIdentifierRequirement({
    required this.identifierType,
    required this.requirement,
    required this.reasonKey,
    required this.legalReviewStatus,
  });

  factory PolicyIdentifierRequirement.fromJson(Map<String, dynamic> json) =>
      PolicyIdentifierRequirement(
        identifierType: json['identifier_type'] as String,
        requirement:
            IdentifierRequirementLevel.fromWire(json['requirement'] as String?),
        reasonKey: json['reason_key'] as String? ?? '',
        legalReviewStatus:
            LegalReviewStatus.fromWire(json['legal_review_status'] as String?),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'identifier_type': identifierType,
        'requirement': requirement.wire,
        'reason_key': reasonKey,
        'legal_review_status': legalReviewStatus.wire,
      };

  @override
  List<Object?> get props =>
      [identifierType, requirement, reasonKey, legalReviewStatus];
}

/// A selectable option (intended use / expected volume band) that may carry
/// a manual-review flag.
class PolicyChoiceOption extends Equatable {
  final String id;
  final bool manualReview;

  const PolicyChoiceOption({required this.id, required this.manualReview});

  factory PolicyChoiceOption.fromJson(Map<String, dynamic> json) =>
      PolicyChoiceOption(
        id: json['id'] as String,
        manualReview: json['manual_review'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() =>
      <String, dynamic>{'id': id, 'manual_review': manualReview};

  @override
  List<Object?> get props => [id, manualReview];
}

/// A disclosure the user must (or may) accept, versioned so re-consent is
/// forced when content changes.
class PolicyDisclosure extends Equatable {
  final String id;
  final String version;
  final bool required;

  /// Placeholder path — real URLs need product/legal sign-off.
  final String urlPlaceholder;

  const PolicyDisclosure({
    required this.id,
    required this.version,
    required this.required,
    required this.urlPlaceholder,
  });

  factory PolicyDisclosure.fromJson(Map<String, dynamic> json) =>
      PolicyDisclosure(
        id: json['id'] as String,
        version: json['version'] as String,
        required: json['required'] as bool? ?? true,
        urlPlaceholder: json['url_placeholder'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'version': version,
        'required': required,
        'url_placeholder': urlPlaceholder,
      };

  @override
  List<Object?> get props => [id, version, required, urlPlaceholder];
}

/// Backend-owned region policy: which documents, identifiers, corridors,
/// disclosures and choice lists apply to a residence country.
///
/// `GET /v1/onboarding/policy` — the app renders ONLY what this returns.
/// Unsupported countries come back as `supported == false` with empty
/// lists (a calm state, not an error).
class RegionPolicy extends Equatable {
  final String policyVersion;
  final bool supported;
  final String? unsupportedReason;
  final String residenceCountry;

  /// Pesito account region (`us` | `mx`); null when unsupported.
  final String? region;
  final int minAge;
  final List<String> corridors;
  final List<PolicyDocumentOption> documentOptions;
  final List<PolicyIdentifierRequirement> identifierRequirements;
  final String disclosureVersion;
  final List<PolicyDisclosure> disclosures;
  final List<PolicyChoiceOption> intendedUseOptions;
  final List<String> sourceOfFundsOptions;
  final List<PolicyChoiceOption> expectedVolumeBands;

  const RegionPolicy({
    required this.policyVersion,
    required this.supported,
    required this.residenceCountry,
    required this.minAge,
    required this.corridors,
    required this.documentOptions,
    required this.identifierRequirements,
    required this.disclosureVersion,
    required this.disclosures,
    required this.intendedUseOptions,
    required this.sourceOfFundsOptions,
    required this.expectedVolumeBands,
    this.unsupportedReason,
    this.region,
  });

  factory RegionPolicy.fromJson(Map<String, dynamic> json) => RegionPolicy(
        policyVersion: json['policy_version'] as String,
        supported: json['supported'] as bool? ?? false,
        unsupportedReason: json['unsupported_reason'] as String?,
        residenceCountry: json['residence_country'] as String? ?? '',
        region: json['region'] as String?,
        minAge: (json['min_age'] as num?)?.toInt() ?? 18,
        corridors: (json['corridors'] as List<dynamic>? ?? const <dynamic>[])
            .cast<String>(),
        documentOptions: (json['document_options'] as List<dynamic>? ??
                const <dynamic>[])
            .map(
                (d) => PolicyDocumentOption.fromJson(d as Map<String, dynamic>))
            .toList(),
        identifierRequirements: (json['identifier_requirements']
                    as List<dynamic>? ??
                const <dynamic>[])
            .map((d) =>
                PolicyIdentifierRequirement.fromJson(d as Map<String, dynamic>))
            .toList(),
        disclosureVersion: json['disclosure_version'] as String? ?? '',
        disclosures: (json['disclosures'] as List<dynamic>? ??
                const <dynamic>[])
            .map((d) => PolicyDisclosure.fromJson(d as Map<String, dynamic>))
            .toList(),
        intendedUseOptions: (json['intended_use_options'] as List<dynamic>? ??
                const <dynamic>[])
            .map((d) => PolicyChoiceOption.fromJson(d as Map<String, dynamic>))
            .toList(),
        sourceOfFundsOptions:
            (json['source_of_funds_options'] as List<dynamic>? ??
                    const <dynamic>[])
                .cast<String>(),
        expectedVolumeBands: (json['expected_volume_bands'] as List<dynamic>? ??
                const <dynamic>[])
            .map((d) => PolicyChoiceOption.fromJson(d as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'policy_version': policyVersion,
        'supported': supported,
        if (unsupportedReason != null) 'unsupported_reason': unsupportedReason,
        'residence_country': residenceCountry,
        if (region != null) 'region': region,
        'min_age': minAge,
        'corridors': corridors,
        'document_options': documentOptions.map((d) => d.toJson()).toList(),
        'identifier_requirements':
            identifierRequirements.map((d) => d.toJson()).toList(),
        'disclosure_version': disclosureVersion,
        'disclosures': disclosures.map((d) => d.toJson()).toList(),
        'intended_use_options':
            intendedUseOptions.map((d) => d.toJson()).toList(),
        'source_of_funds_options': sourceOfFundsOptions,
        'expected_volume_bands':
            expectedVolumeBands.map((d) => d.toJson()).toList(),
      };

  /// Required disclosure ids — what `submitConsents` must include.
  List<String> get requiredDisclosureIds =>
      disclosures.where((d) => d.required).map((d) => d.id).toList();

  @override
  List<Object?> get props => [
        policyVersion,
        supported,
        unsupportedReason,
        residenceCountry,
        region,
        minAge,
        corridors,
        documentOptions,
        identifierRequirements,
        disclosureVersion,
        disclosures,
        intendedUseOptions,
        sourceOfFundsOptions,
        expectedVolumeBands,
      ];
}
