import 'package:equatable/equatable.dart';

class Money extends Equatable {
  final int cents;
  final String currency;

  const Money({required this.cents, required this.currency});

  double get amount => cents / 100.0;
  
  String format() => '$currency ${amount.toStringAsFixed(2)}';

  Money operator +(Money other) {
    if (currency != other.currency) {
      throw ArgumentError('Cannot add Money with different currencies');
    }
    return Money(cents: cents + other.cents, currency: currency);
  }

  Money operator -(Money other) {
    if (currency != other.currency) {
      throw ArgumentError('Cannot subtract Money with different currencies');
    }
    return Money(cents: cents - other.cents, currency: currency);
  }

  factory Money.fromJson(Map<String, dynamic> json) {
    return Money(
      cents: json['amount'] as int? ?? json['cents'] as int,
      currency: json['currency'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'amount': cents,
    'currency': currency,
  };

  @override
  List<Object?> get props => [cents, currency];
}
