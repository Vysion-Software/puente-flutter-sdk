import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'transfer.g.dart';

enum TransferStatus {
  @JsonValue('pending')
  pending,
  @JsonValue('processing')
  processing,
  @JsonValue('settled')
  settled,
  @JsonValue('failed')
  failed,
  @JsonValue('cancelled')
  cancelled,
  @JsonValue('unknown')
  unknown,
}

@JsonSerializable()
class Transfer extends Equatable {
  final String id;
  @JsonKey(unknownEnumValue: TransferStatus.unknown)
  final TransferStatus status;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  const Transfer({
    required this.id,
    required this.status,
    required this.createdAt,
  });

  factory Transfer.fromJson(Map<String, dynamic> json) => _$TransferFromJson(json);

  Map<String, dynamic> toJson() => _$TransferToJson(this);

  @override
  List<Object?> get props => [id, status, createdAt];
}
