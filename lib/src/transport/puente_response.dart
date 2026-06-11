import 'dart:convert';

/// Wire-decoded response handed back from a [PuenteTransport].
class PuenteResponse {
  /// HTTP status code returned by the server (or synthesized by the mock).
  final int statusCode;

  /// Response headers, lowercased keys for case-insensitive lookup.
  final Map<String, String> headers;

  /// Raw response body bytes as a UTF-8 string. Use [json] for parsed
  /// JSON.
  final String body;

  /// Build a [PuenteResponse].
  const PuenteResponse({
    required this.statusCode,
    required this.headers,
    required this.body,
  });

  /// True for 2xx responses.
  bool get isSuccessful => statusCode >= 200 && statusCode < 300;

  /// `X-Request-Id` echoed by the server (or the `request_id` field in
  /// the body if the header was missing).
  String? get requestId {
    final hdr = headers['x-request-id'];
    if (hdr != null) return hdr;
    final body = json;
    if (body is Map && body['request_id'] is String) {
      return body['request_id'] as String;
    }
    return null;
  }

  /// Body decoded as JSON (Map / List / primitive). Returns `null` when
  /// the body is empty or not valid JSON.
  Object? get json {
    if (body.isEmpty) return null;
    try {
      return jsonDecode(body);
    } on FormatException {
      return null;
    }
  }

  /// Body decoded as a `Map<String, dynamic>`. Returns an empty map if
  /// the body is not a JSON object.
  Map<String, dynamic> get jsonObject {
    final decoded = json;
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return decoded.cast<String, dynamic>();
    return const <String, dynamic>{};
  }

  /// Body decoded as a JSON array, returned as `List<dynamic>` (or
  /// `null` if the body wasn't an array).
  List<dynamic>? get jsonArray {
    final decoded = json;
    if (decoded is List) return decoded;
    return null;
  }
}
