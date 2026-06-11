import 'package:equatable/equatable.dart';

/// Vocabulary of webhook event types Puente Railway emits to merchant
/// endpoints.
///
/// These are **product-shaped** events — distinct from the
/// **Etherfuse-shaped** events Puente receives on its inbound
/// `/webhooks/etherfuse` channel (`order_updated`, `swap_updated`, etc.).
/// See Puente proposed issue `puente-102-define-product-events` and
/// `puente-103-outbound-webhook-format`.
enum WebhookEventType {
  /// `POST /v1/transfers` accepted; on-chain leg not yet confirmed.
  transferCreated('transfer.created'),

  /// On-chain leg confirmed; fiat leg pending.
  transferConfirmed('transfer.confirmed'),

  /// Beneficiary credited; terminal success.
  transferSettled('transfer.settled'),

  /// Reversal window closed; transfer is final.
  transferFinalized('transfer.finalized'),

  /// Caller cancelled before settlement.
  transferCancelled('transfer.cancelled'),

  /// Terminal failure (any leg).
  transferFailed('transfer.failed'),

  /// `Quote.expiresAt` reached without a `POST /v1/transfers`.
  quoteExpired('quote.expired'),

  /// Account verification result changed (`pending` → `verified` /
  /// `rejected`).
  accountVerified('account.verified'),

  /// Wire format not recognized by this SDK build.
  unknown('unknown');

  /// JSON wire value (dot-separated, past-tense — Stripe convention).
  final String wire;
  const WebhookEventType(this.wire);

  /// Parse a wire value into the enum, defaulting to [unknown].
  static WebhookEventType fromWire(String? value) {
    if (value == null) return WebhookEventType.unknown;
    for (final t in WebhookEventType.values) {
      if (t.wire == value) return t;
    }
    return WebhookEventType.unknown;
  }
}

/// A typed wrapper around the JSON payload of a Puente Railway webhook
/// delivery.
///
/// [data] is left as `Map<String, dynamic>` rather than a tighter union
/// because the event vocabulary still drifts as new product surfaces land
/// (see `puente-102-define-product-events`). Pull a typed model from the
/// payload with e.g. `Transfer.fromJson(event.data)` when [type] is one
/// of the transfer events.
class WebhookEvent extends Equatable {
  /// Discriminant. Use [WebhookEventType.unknown] as a forward-compat
  /// catch-all.
  final WebhookEventType type;

  /// Free-form event payload. Shape varies by [type].
  final Map<String, dynamic> data;

  /// Server timestamp when the event was emitted.
  final DateTime createdAt;

  /// Optional event id for at-least-once delivery deduplication.
  final String? id;

  /// Build a [WebhookEvent].
  const WebhookEvent({
    required this.type,
    required this.data,
    required this.createdAt,
    this.id,
  });

  /// Decode from the JSON shape Puente uses on the wire.
  factory WebhookEvent.fromJson(Map<String, dynamic> json) => WebhookEvent(
        id: json['id'] as String?,
        type: WebhookEventType.fromWire(json['type'] as String?),
        data: (json['data'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{},
        createdAt: json['created_at'] is String
            ? DateTime.parse(json['created_at'] as String).toUtc()
            : DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );

  /// Encode to the JSON shape Puente sends on the wire.
  Map<String, dynamic> toJson() => <String, dynamic>{
        if (id != null) 'id': id,
        'type': type.wire,
        'data': data,
        'created_at': createdAt.toUtc().toIso8601String(),
      };

  @override
  List<Object?> get props => [id, type, data, createdAt];
}
