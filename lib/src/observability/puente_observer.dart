/// Optional logging + tracing hook for SDK consumers.
///
/// The SDK never prints to stdout. Anything an operator might want to
/// see — request started, retry attempted, rate-limit hit, webhook
/// verified — flows through this observer. Default implementation is
/// silent; pass a custom subclass to [PuenteClient] to wire it into
/// Sentry, OpenTelemetry, or `print` in dev.
///
/// All methods are nullable defaults so subclasses can override only
/// what they care about.
abstract class PuenteObserver {
  /// A no-op observer that swallows every event. The SDK default.
  const factory PuenteObserver.silent() = _SilentObserver;

  /// Build the abstract base for subclasses.
  const PuenteObserver();

  /// Called once before a request hits the wire.
  void onRequest(PuenteRequestEvent event) {}

  /// Called when a response (success or HTTP failure) is decoded.
  void onResponse(PuenteResponseEvent event) {}

  /// Called when a request is going to be retried.
  void onRetry(PuenteRetryEvent event) {}

  /// Called when the SDK gives up and is about to throw.
  void onError(PuenteErrorEvent event) {}
}

class _SilentObserver extends PuenteObserver {
  const _SilentObserver();
}

/// A request is about to be sent. [headers] is the merged set; sensitive
/// keys like `Authorization` and `Idempotency-Key` are masked.
class PuenteRequestEvent {
  /// HTTP method.
  final String method;

  /// Full request URL.
  final Uri url;

  /// Sensitive-header-masked map.
  final Map<String, String> headers;

  /// Idempotency key assigned to this request, if any.
  final String? idempotencyKey;

  /// Attempt number (1 = first attempt, 2+ = retry).
  final int attempt;

  /// Build a [PuenteRequestEvent].
  const PuenteRequestEvent({
    required this.method,
    required this.url,
    required this.headers,
    required this.attempt,
    this.idempotencyKey,
  });
}

/// A response was received from the wire.
class PuenteResponseEvent {
  /// HTTP method.
  final String method;

  /// Full request URL.
  final Uri url;

  /// HTTP status code returned by the server.
  final int statusCode;

  /// Server-assigned `X-Request-Id`, when present.
  final String? requestId;

  /// Wall-clock duration from request start to response decode.
  final Duration elapsed;

  /// Attempt number (1 = first attempt, 2+ = retry).
  final int attempt;

  /// Build a [PuenteResponseEvent].
  const PuenteResponseEvent({
    required this.method,
    required this.url,
    required this.statusCode,
    required this.elapsed,
    required this.attempt,
    this.requestId,
  });
}

/// A retry is about to fire.
class PuenteRetryEvent {
  /// HTTP method.
  final String method;

  /// Full request URL.
  final Uri url;

  /// Why we're retrying (server status, transport error).
  final String reason;

  /// Sleep before the next attempt.
  final Duration delay;

  /// 1-indexed attempt number that just failed.
  final int attempt;

  /// Build a [PuenteRetryEvent].
  const PuenteRetryEvent({
    required this.method,
    required this.url,
    required this.reason,
    required this.delay,
    required this.attempt,
  });
}

/// The SDK is about to throw. Wired into [onError] for crash reporting.
class PuenteErrorEvent {
  /// HTTP method, if the failure happened during a request.
  final String? method;

  /// Full request URL, if the failure happened during a request.
  final Uri? url;

  /// Thrown error.
  final Object error;

  /// Stack trace.
  final StackTrace stackTrace;

  /// Build a [PuenteErrorEvent].
  const PuenteErrorEvent({
    required this.error,
    required this.stackTrace,
    this.method,
    this.url,
  });
}
