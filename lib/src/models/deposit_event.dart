import 'package:equatable/equatable.dart';

import 'deposit_status.dart';

/// One append-only audit entry from a deposit session's transition log
/// (`GET /v1/deposit-sessions/{id}/events`).
///
/// Events mirror the backend's wire doc exactly: `{from_status,
/// to_status, detail, created_at}` — every status transition with a
/// sanitized detail payload. Read-only — clients render the timeline,
/// nothing more.
class DepositEvent extends Equatable {
  /// Status before the transition.
  final DepositStatus? fromStatus;

  /// Status after the transition.
  final DepositStatus toStatus;

  /// Sanitized transition detail (provider snapshot excerpts, failure
  /// context). Free-form JSON object; may be `null`.
  final Map<String, dynamic>? detail;

  /// Server timestamp of the transition.
  final DateTime createdAt;

  /// Build a [DepositEvent].
  const DepositEvent({
    required this.toStatus,
    required this.createdAt,
    this.fromStatus,
    this.detail,
  });

  /// Decode from the wire shape.
  factory DepositEvent.fromJson(Map<String, dynamic> json) => DepositEvent(
        fromStatus: json['from_status'] is String
            ? DepositStatus.fromWire(json['from_status'] as String)
            : null,
        toStatus: DepositStatus.fromWire(json['to_status'] as String?),
        detail: json['detail'] is Map
            ? (json['detail'] as Map).cast<String, dynamic>()
            : null,
        createdAt: json['created_at'] is String
            ? DateTime.parse(json['created_at'] as String).toUtc()
            : DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );

  /// Encode back to the wire shape. Round-trips through [fromJson].
  Map<String, dynamic> toJson() => <String, dynamic>{
        if (fromStatus != null) 'from_status': fromStatus!.wire,
        'to_status': toStatus.wire,
        if (detail != null) 'detail': detail,
        'created_at': createdAt.toUtc().toIso8601String(),
      };

  @override
  List<Object?> get props => [fromStatus, toStatus, detail, createdAt];
}
