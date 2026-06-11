import 'package:uuid/uuid.dart';

import '../exceptions/api_exception.dart';
import '../exceptions/auth_exception.dart';
import '../exceptions/rate_limit_exception.dart';
import '../exceptions/validation_exception.dart';
import '../transport/puente_request.dart';
import '../transport/puente_response.dart';
import '../transport/puente_transport.dart';

/// Shared plumbing every resource (`QuotesResource`, `TransfersResource`,
/// …) builds on top of. Handles:
///
/// * Sending the request through the transport.
/// * Translating non-2xx responses into the typed exception hierarchy.
/// * Generating idempotency keys for unsafe HTTP methods when the
///   caller didn't provide one.
abstract class ResourceBase {
  /// Build a resource against a [PuenteTransport].
  ResourceBase(this.transport, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  /// Underlying transport. Tests may pass a [MockTransport].
  final PuenteTransport transport;

  final Uuid _uuid;

  /// Generate a fresh UUIDv4 — the SDK's default idempotency key for
  /// money-moving requests that don't supply one.
  String newIdempotencyKey() => _uuid.v4();

  /// Send [request] and assert a successful response. Translates
  /// non-2xx into typed exceptions before returning.
  Future<PuenteResponse> request(PuenteRequest request) async {
    final response = await transport.send(request);
    if (response.isSuccessful) return response;
    throw _exceptionFor(response);
  }

  Exception _exceptionFor(PuenteResponse response) {
    final body = response.jsonObject;
    final message = (body['message'] as String?) ??
        (body['error'] as String?) ??
        'HTTP ${response.statusCode}';
    final code = body['error'] as String?;
    final requestId = response.requestId;

    switch (response.statusCode) {
      case 401:
      case 403:
        return AuthException(
          message,
          statusCode: response.statusCode,
          code: code,
          body: body,
          requestId: requestId,
        );
      case 422:
        final raw = body['errors'] ?? body['field_errors'];
        final fieldErrors = <String, String>{};
        if (raw is Map) {
          raw.forEach((k, v) {
            if (k is String) {
              fieldErrors[k] = v?.toString() ?? '';
            }
          });
        }
        return ValidationException(
          message,
          statusCode: response.statusCode,
          fieldErrors: fieldErrors,
          code: code,
          body: body,
          requestId: requestId,
        );
      case 429:
        final retryAfter = _parseRetryAfter(response.headers['retry-after']);
        return RateLimitException(
          message,
          statusCode: response.statusCode,
          retryAfter: retryAfter,
          code: code,
          body: body,
          requestId: requestId,
        );
      default:
        return ApiException(
          message,
          statusCode: response.statusCode,
          code: code,
          body: body,
          requestId: requestId,
        );
    }
  }

  Duration? _parseRetryAfter(String? header) {
    if (header == null) return null;
    final seconds = int.tryParse(header.trim());
    if (seconds == null || seconds < 0) return null;
    return Duration(seconds: seconds);
  }
}
