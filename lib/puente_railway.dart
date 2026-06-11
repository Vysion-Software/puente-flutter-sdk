/// Official Dart/Flutter SDK for [Puente Railway][puente] — the
/// Solana + Etherfuse settlement rail behind Pesito.
///
/// Quick start:
///
/// ```dart
/// import 'package:puente_railway/puente_railway.dart';
///
/// final puente = PuenteClient(
///   config: PuenteConfig.testnet(apiKey: 'sk_testnet_…'),
/// );
///
/// final result = await puente.remittance.send(
///   sourceAmount: Money.fromMinor(100_00, Currency.usd),
///   targetCurrency: Currency.mxn,
///   receiverClabe: '012180012345678901',
///   receiverName: 'María García López',
/// );
/// await for (final t in puente.remittance.watch(result.transfer.id)) {
///   print('${t.id}: ${t.status.wire}');
/// }
/// ```
///
/// For an offline-friendly setup (unit tests, demos, CI):
///
/// ```dart
/// final puente = PuenteClient.mock();
/// ```
///
/// [puente]: https://github.com/Vysion-Software/Puente
library puente_railway;

// Client + config.
export 'src/client/puente_client.dart';
export 'src/client/puente_config.dart' show PuenteConfig, PuenteEnvironment;
export 'src/client/puente_remittance.dart';

// Models.
export 'src/models/models.dart';

// Resources.
export 'src/resources/accounts_resource.dart';
export 'src/resources/clabe_resource.dart';
export 'src/resources/quotes_resource.dart';
export 'src/resources/transfers_resource.dart';

// Exceptions.
export 'src/exceptions/exceptions.dart';

// Transport (advanced — most apps don't need these).
export 'src/transport/http_transport.dart';
export 'src/transport/mock_transport.dart';
export 'src/transport/puente_request.dart';
export 'src/transport/puente_response.dart';
export 'src/transport/puente_transport.dart';

// Observability.
export 'src/observability/puente_observer.dart';

// Webhooks.
export 'src/webhooks/webhook_verifier.dart';
