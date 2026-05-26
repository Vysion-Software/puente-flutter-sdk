import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'clabe_info.g.dart';

@JsonSerializable()
class ClabeInfo extends Equatable {
  final String clabe;
  @JsonKey(name: 'bank_name')
  final String bankName;
  @JsonKey(name: 'bank_code')
  final String bankCode;
  final bool valid;

  const ClabeInfo({
    required this.clabe,
    required this.bankName,
    required this.bankCode,
    required this.valid,
  });

  factory ClabeInfo.fromJson(Map<String, dynamic> json) => _$ClabeInfoFromJson(json);

  Map<String, dynamic> toJson() => _$ClabeInfoToJson(this);

  @override
  List<Object?> get props => [clabe, bankName, bankCode, valid];
}
