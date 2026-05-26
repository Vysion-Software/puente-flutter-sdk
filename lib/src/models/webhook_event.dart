import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'webhook_event.g.dart';

enum WebhookEventType {
  @JsonValue('transferSettled')
  transferSettled,
  @JsonValue('transferFailed')
  transferFailed,
  @JsonValue('transferProcessing')
  transferProcessing,
  @JsonValue('quoteExpired')
  quoteExpired,
  @JsonValue('accountVerified')
  accountVerified,
  @JsonValue('unknown')
  unknown,
}

@JsonSerializable()
class WebhookEvent extends Equatable {
  @JsonKey(unknownEnumValue: WebhookEventType.unknown)
  final WebhookEventType type;
  final Map<String, dynamic> data;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  const WebhookEvent({
    required this.type,
    required this.data,
    required this.createdAt,
  });

  factory WebhookEvent.fromJson(Map<String, dynamic> json) => _$WebhookEventFromJson(json);

  Map<String, dynamic> toJson() => _$WebhookEventToJson(this);

  @override
  List<Object?> get props => [type, data, createdAt];
}
