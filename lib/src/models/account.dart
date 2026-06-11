import 'package:equatable/equatable.dart';

/// KYC tier the account currently holds.
///
/// Mirrors `SUPPORTED_KYC_TIERS` in Pesito's Cloud Functions and the
/// equivalent gating in Puente's `puente-risk` crate.
enum KycTier {
  /// No KYC submitted; account can only hold/send small amounts.
  none('none'),

  /// Tier-1: basic identity (name + DOB + ID number).
  tier1('tier1'),

  /// Tier-2: full identity + document verification + liveness.
  tier2('tier2');

  /// JSON wire value.
  final String wire;
  const KycTier(this.wire);

  /// Parse a wire value into the enum, defaulting to [none].
  static KycTier fromWire(String? value) {
    if (value == null) return KycTier.none;
    for (final t in KycTier.values) {
      if (t.wire == value) return t;
    }
    return KycTier.none;
  }
}

/// A sender or recipient identity registered with Puente.
class Account extends Equatable {
  /// Server-side identifier (`acct_…`).
  final String id;

  /// Legal first name.
  final String firstName;

  /// Legal last name(s).
  final String lastName;

  /// Email address. Format-checked server-side, not here.
  final String email;

  /// E.164 phone number (`+<country><digits>`).
  final String phone;

  /// Current KYC tier. Drives per-transaction limits server-side.
  final KycTier kycTier;

  /// Server timestamp when the account was created.
  final DateTime createdAt;

  /// Build an [Account].
  const Account({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.createdAt,
    this.kycTier = KycTier.none,
  });

  /// Convenience helper for UI: `"First Last"`.
  String get displayName => '$firstName $lastName'.trim();

  /// Decode from the JSON shape Puente uses on the wire.
  factory Account.fromJson(Map<String, dynamic> json) => Account(
        id: json['id'] as String,
        firstName: json['first_name'] as String,
        lastName: json['last_name'] as String,
        email: json['email'] as String,
        phone: json['phone'] as String,
        kycTier: KycTier.fromWire(json['kyc_tier'] as String?),
        createdAt: json['created_at'] is String
            ? DateTime.parse(json['created_at'] as String).toUtc()
            : DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );

  /// Encode to the JSON shape Puente accepts on the wire.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'phone': phone,
        'kyc_tier': kycTier.wire,
        'created_at': createdAt.toUtc().toIso8601String(),
      };

  @override
  List<Object?> get props =>
      [id, firstName, lastName, email, phone, kycTier, createdAt];
}
