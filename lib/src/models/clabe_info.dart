import 'package:equatable/equatable.dart';

/// Result of a Mexican CLABE lookup.
///
/// CLABE (Clave Bancaria Estandarizada) is the 18-digit standardized
/// account number used by SPEI. The first 3 digits identify the bank;
/// the SDK calls this out so callers don't have to parse it themselves.
class ClabeInfo extends Equatable {
  /// The CLABE that was looked up.
  final String clabe;

  /// Human-readable bank name (`"BBVA México"`).
  final String bankName;

  /// 3-digit bank code (`"012"` = BBVA).
  final String bankCode;

  /// True when the CLABE passed checksum + bank-prefix validation.
  ///
  /// A `false` value means **don't use this CLABE for a real transfer.**
  /// The server still returned a record (so [bankName] / [bankCode] may
  /// be the best-guess match), but Puente will reject a transfer at
  /// settlement time.
  final bool valid;

  /// Build a [ClabeInfo].
  const ClabeInfo({
    required this.clabe,
    required this.bankName,
    required this.bankCode,
    required this.valid,
  });

  /// Decode from the JSON shape Puente uses on the wire.
  factory ClabeInfo.fromJson(Map<String, dynamic> json) => ClabeInfo(
        clabe: json['clabe'] as String,
        bankName: json['bank_name'] as String,
        bankCode: json['bank_code'] as String,
        valid: json['valid'] as bool? ?? false,
      );

  /// Encode to the JSON shape Puente accepts on the wire.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'clabe': clabe,
        'bank_name': bankName,
        'bank_code': bankCode,
        'valid': valid,
      };

  @override
  List<Object?> get props => [clabe, bankName, bankCode, valid];
}
