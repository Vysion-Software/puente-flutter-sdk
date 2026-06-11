import 'package:http/http.dart' as http;

import '../observability/puente_observer.dart';
import '../resources/accounts_resource.dart';
import '../resources/clabe_resource.dart';
import '../resources/quotes_resource.dart';
import '../resources/transfers_resource.dart';
import '../transport/http_transport.dart';
import '../transport/mock_transport.dart';
import '../transport/puente_transport.dart';
import 'puente_config.dart';
import 'puente_remittance.dart';

/// The Puente Railway SDK front door.
///
/// A [PuenteClient] holds a [PuenteTransport] (real HTTP or mock) and
/// exposes one resource per backend domain object, plus the high-level
/// [remittance] facade for the common "quote → send → watch" path
/// Pesito follows.
///
/// Construct via:
/// * `PuenteClient(config: ...)` for the canonical path.
/// * `PuenteClient.mock()` for an in-memory client with no network.
/// * `PuenteClient.withTransport(...)` when you want to inject a
///   custom [PuenteTransport] (e.g. record/replay in golden tests).
///
/// All public methods are async. The client is reentrant — safe to
/// share a single instance across an entire Flutter app.
///
/// Example:
/// ```dart
/// final puente = PuenteClient(
///   config: PuenteConfig.testnet(
///     apiKey: 'sk_testnet_…',
///     merchantId: 'merchant_pesito',
///   ),
/// );
///
/// final result = await puente.remittance.send(
///   sourceAmount: Money.fromMinor(100_00, Currency.usd),
///   targetCurrency: Currency.mxn,
///   receiverClabe: '012180012345678901',
///   receiverName: 'María García López',
/// );
/// await for (final tx in puente.remittance.watch(result.transfer.id)) {
///   print('${tx.id}: ${tx.status.wire}');
/// }
/// ```
class PuenteClient {
  /// Build a [PuenteClient] with a config.
  ///
  /// When [PuenteConfig.environment] is [PuenteEnvironment.mock], the
  /// SDK installs a [MockTransport] automatically — no HTTP traffic.
  /// Otherwise an [HttpTransport] is constructed. Pass [innerHttpClient]
  /// to inject a custom `http.Client` (e.g. one that pins TLS roots).
  factory PuenteClient({
    required PuenteConfig config,
    PuenteObserver? observer,
    http.Client? innerHttpClient,
  }) {
    final transport = config.environment == PuenteEnvironment.mock
        ? MockTransport()
        : HttpTransport(
            config: config,
            observer: observer,
            inner: innerHttpClient,
          );
    return PuenteClient.withTransport(
      config: config,
      transport: transport,
      observer: observer,
      ownsTransport: true,
    );
  }

  /// Convenience constructor for an in-memory mock client.
  ///
  /// Equivalent to `PuenteClient(config: PuenteConfig.mock())`.
  factory PuenteClient.mock({
    String apiKey = 'sk_mock',
    String? merchantId,
    int seed = 0,
    Duration settlementLatency = const Duration(seconds: 2),
    Duration networkLatency = const Duration(milliseconds: 80),
  }) {
    final config = PuenteConfig.mock(apiKey: apiKey, merchantId: merchantId);
    final transport = MockTransport(
      seed: seed,
      settlementLatency: settlementLatency,
      networkLatency: networkLatency,
    );
    return PuenteClient.withTransport(
      config: config,
      transport: transport,
      ownsTransport: true,
    );
  }

  /// Build with an explicit [PuenteTransport] — for tests, golden
  /// suites, or any consumer that wants to plug in a custom backend.
  PuenteClient.withTransport({
    required this.config,
    required PuenteTransport transport,
    PuenteObserver? observer,
    bool ownsTransport = false,
  })  : _transport = transport,
        observer = observer ?? const PuenteObserver.silent(),
        _ownsTransport = ownsTransport,
        quotes = QuotesResource(transport),
        transfers = TransfersResource(transport),
        accounts = AccountsResource(transport),
        clabe = ClabeResource(transport),
        remittance = PuenteRemittance(
          quotes: QuotesResource(transport),
          transfers: TransfersResource(transport),
        );

  /// The configuration this client was built with.
  final PuenteConfig config;

  /// The observer attached to this client. Defaults to a silent no-op.
  final PuenteObserver observer;

  final PuenteTransport _transport;
  final bool _ownsTransport;

  /// Quote management.
  final QuotesResource quotes;

  /// Transfer lifecycle.
  final TransfersResource transfers;

  /// Account / KYC management.
  final AccountsResource accounts;

  /// CLABE lookup.
  final ClabeResource clabe;

  /// High-level `quote → send → watch` facade. Most apps should use
  /// this; the lower-level [quotes] / [transfers] are available for
  /// explicit control.
  final PuenteRemittance remittance;

  /// Release the underlying transport. Safe to call multiple times.
  void close() {
    if (_ownsTransport) _transport.close();
  }
}
