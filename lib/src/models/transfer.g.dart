// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transfer.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Transfer _$TransferFromJson(Map<String, dynamic> json) => Transfer(
      id: json['id'] as String,
      status: $enumDecode(_$TransferStatusEnumMap, json['status'],
          unknownValue: TransferStatus.unknown),
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$TransferToJson(Transfer instance) => <String, dynamic>{
      'id': instance.id,
      'status': _$TransferStatusEnumMap[instance.status]!,
      'created_at': instance.createdAt.toIso8601String(),
    };

const _$TransferStatusEnumMap = {
  TransferStatus.pending: 'pending',
  TransferStatus.processing: 'processing',
  TransferStatus.settled: 'settled',
  TransferStatus.failed: 'failed',
  TransferStatus.cancelled: 'cancelled',
  TransferStatus.unknown: 'unknown',
};
