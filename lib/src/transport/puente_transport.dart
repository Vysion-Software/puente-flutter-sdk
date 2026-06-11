import 'puente_request.dart';
import 'puente_response.dart';

/// The interface every transport implements. Concrete implementations:
///
/// * [HttpTransport] — talks to a real Puente Railway server over HTTPS.
/// * [MockTransport] — in-memory fixtures, no network. Used by tests and
///   by the SDK's `PuenteEnvironment.mock` configuration.
/// * [FakeTransport] — record/replay against canned JSON fixtures (golden
///   tests, regression suites).
///
/// Transports are responsible for the wire — URL construction, body
/// encoding, header merging, retries — but **not** for typed error
/// mapping. That happens in the resource layer above.
abstract class PuenteTransport {
  /// Send [request] and return the decoded response. Throws
  /// [TransportException] when the request can't reach the server;
  /// returns the response otherwise (even on 4xx/5xx).
  Future<PuenteResponse> send(PuenteRequest request);

  /// Release any resources (HTTP client, in-memory stores, etc.).
  void close();
}
