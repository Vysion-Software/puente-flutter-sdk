import 'dart:convert';

/// A protocol-agnostic request the SDK hands to a [PuenteTransport].
///
/// Separating "request" from `http.Request` lets the SDK build mock,
/// fake, and real-HTTP transports against a single shape, and keeps the
/// public surface free of `package:http` types so consumers don't have
/// to depend on a particular HTTP library.
class PuenteRequest {
  /// HTTP method (`GET`, `POST`, `PUT`, `PATCH`, `DELETE`).
  final String method;

  /// Path relative to the configured base URL (`/quotes`,
  /// `/transfers/tx_123`).
  final String path;

  /// Query parameters (URL-encoded by the transport).
  final Map<String, String> query;

  /// Headers to send. `Authorization`, `Content-Type`, `Accept`,
  /// `Idempotency-Key`, `X-Request-Id`, and `User-Agent` are filled in
  /// by the SDK's interceptor chain; callers normally pass an empty map.
  final Map<String, String> headers;

  /// Request body. Encoded as JSON when non-`null`.
  final Object? body;

  /// Optional per-request idempotency key. Forwarded as
  /// `Idempotency-Key`. The SDK generates one automatically for
  /// money-moving methods if the caller doesn't supply one.
  final String? idempotencyKey;

  /// Build a [PuenteRequest].
  const PuenteRequest({
    required this.method,
    required this.path,
    this.query = const <String, String>{},
    this.headers = const <String, String>{},
    this.body,
    this.idempotencyKey,
  });

  /// Convert the [body] to a JSON string, or empty when `null`.
  String encodedBody() => body == null ? '' : jsonEncode(body);

  /// Copy with overrides; preserves any field not named.
  PuenteRequest copyWith({
    String? method,
    String? path,
    Map<String, String>? query,
    Map<String, String>? headers,
    Object? body,
    String? idempotencyKey,
  }) =>
      PuenteRequest(
        method: method ?? this.method,
        path: path ?? this.path,
        query: query ?? this.query,
        headers: headers ?? this.headers,
        body: body ?? this.body,
        idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      );
}
