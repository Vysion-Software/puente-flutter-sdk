import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'money.dart';

part 'quote.g.dart';

@JsonSerializable(explicitToJson: true)
class Quote extends Equatable {
  final String id;
  @JsonKey(name: 'source_amount')
  final Money sourceAmount;
  @JsonKey(name: 'target_amount')
  final Money targetAmount;
  @JsonKey(name: 'exchange_rate')
  final double exchangeRate;
  final Money fee;
  @JsonKey(name: 'expires_at')
  final DateTime expiresAt;

  const Quote({
    required this.id,
    required this.sourceAmount,
    required this.targetAmount,
    required this.exchangeRate,
    required this.fee,
    required this.expiresAt,
  });

  factory Quote.fromJson(Map<String, dynamic> json) => _$QuoteFromJson(json);

  Map<String, dynamic> toJson() => _$QuoteToJson(this);

  @override
  List<Object?> get props => [id, sourceAmount, targetAmount, exchangeRate, fee, expiresAt];
}
