import 'dart:async';
import 'dart:math';
import 'package:http/http.dart' as http;

class RetryInterceptor extends http.BaseClient {
  final http.Client _inner;
  final int _maxRetries;
  final int _baseDelayMs;
  final int _jitterMs;

  RetryInterceptor(
    this._inner, {
    int maxRetries = 3,
    int baseDelayMs = 500,
    int jitterMs = 100,
  })  : _maxRetries = maxRetries,
        _baseDelayMs = baseDelayMs,
        _jitterMs = jitterMs;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    int attempt = 0;
    while (true) {
      http.StreamedResponse? response;
      try {
        final reqCopy = _copyRequest(request);
        response = await _inner.send(reqCopy);

        if (attempt >= _maxRetries || !_shouldRetry(response.statusCode)) {
          return response;
        }
      } catch (e) {
        if (attempt >= _maxRetries) rethrow;
      }

      attempt++;
      final delay = _calculateDelay(attempt);
      await Future.delayed(delay);
    }
  }

  bool _shouldRetry(int statusCode) {
    return statusCode == 429 || (statusCode >= 500 && statusCode < 600);
  }

  Duration _calculateDelay(int attempt) {
    final backoff = _baseDelayMs * pow(2, attempt - 1);
    final jitter = (Random().nextDouble() * 2 - 1) * _jitterMs; // ± jitterMs
    return Duration(milliseconds: (backoff + jitter).round());
  }

  http.BaseRequest _copyRequest(http.BaseRequest request) {
    if (request is http.Request) {
      final copy = http.Request(request.method, request.url)
        ..headers.addAll(request.headers)
        ..bodyBytes = request.bodyBytes
        ..encoding = request.encoding;
      return copy;
    }
    // We expect standard http.Request usage from our client wrapper.
    throw UnsupportedError('Retry interceptor only supports http.Request');
  }
}
