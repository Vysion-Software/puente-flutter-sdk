import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../exceptions/api_exception.dart';
import '../exceptions/auth_exception.dart';
import '../exceptions/puente_exception.dart';
import '../exceptions/rate_limit_exception.dart';
import '../exceptions/validation_exception.dart';

class PuenteHttpClient {
  final http.Client client;
  final String baseUrl;
  final Duration timeout;

  PuenteHttpClient({
    required this.client,
    required this.baseUrl,
    required this.timeout,
  });

  Future<Map<String, dynamic>> get(String path, {Map<String, String>? query}) async {
    final uri = _buildUri(path, query);
    return _send(http.Request('GET', uri));
  }

  Future<Map<String, dynamic>> post(String path, {Map<String, dynamic>? body}) async {
    final uri = _buildUri(path, null);
    final request = http.Request('POST', uri);
    if (body != null) {
      request.body = jsonEncode(body);
    }
    return _send(request);
  }

  Future<Map<String, dynamic>> patch(String path, {Map<String, dynamic>? body}) async {
    final uri = _buildUri(path, null);
    final request = http.Request('PATCH', uri);
    if (body != null) {
      request.body = jsonEncode(body);
    }
    return _send(request);
  }

  Uri _buildUri(String path, Map<String, String>? query) {
    final uri = Uri.parse('$baseUrl$path');
    if (query != null && query.isNotEmpty) {
      return uri.replace(queryParameters: query);
    }
    return uri;
  }

  Future<Map<String, dynamic>> _send(http.Request request) async {
    try {
      final response = await client.send(request).timeout(timeout);
      final responseBody = await response.stream.bytesToString();
      return _processResponse(response.statusCode, responseBody, response.headers);
    } on TimeoutException {
      throw const PuenteException('Request timed out');
    } catch (e) {
      if (e is PuenteException) rethrow;
      throw PuenteException('Network error: $e');
    }
  }

  Map<String, dynamic> _processResponse(
      int statusCode, String body, Map<String, String> headers) {
    Map<String, dynamic> data = {};
    if (body.isNotEmpty) {
      try {
        data = jsonDecode(body);
      } catch (_) {}
    }

    final requestId = headers['x-request-id'] ?? data['request_id'] as String?;
    final message = data['message'] as String? ?? 'An error occurred';

    if (statusCode >= 200 && statusCode < 300) {
      return data;
    } else if (statusCode == 401 || statusCode == 403) {
      throw AuthException(message);
    } else if (statusCode == 422) {
      final fieldErrors = (data['errors'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(key, value.toString()),
          ) ??
          {};
      throw ValidationException(message, fieldErrors: fieldErrors);
    } else if (statusCode == 429) {
      Duration? retryAfter;
      final retryAfterHeader = headers['retry-after'];
      if (retryAfterHeader != null) {
        final seconds = int.tryParse(retryAfterHeader);
        if (seconds != null) retryAfter = Duration(seconds: seconds);
      }
      throw RateLimitException(message, retryAfter: retryAfter);
    }

    throw ApiException(message, statusCode: statusCode, requestId: requestId);
  }

  void close() {
    client.close();
  }
}
