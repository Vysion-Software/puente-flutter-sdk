/// Dev-only fixture adapter for the Puente Railway SDK.
///
/// ```dart
/// import 'package:puente_railway/testing.dart';
/// ```
///
/// Exposes [MockTransport], the in-memory backend behind
/// `PuenteEnvironment.mock` and `PuenteClient.mock()`. It serves
/// **deterministic dev fixtures** that mirror the real backend's wire
/// contract — fixture fees, fixture FX rates, fixture receipts — and is
/// never a source of production truth: real fees, rates, totals, and
/// margins ALWAYS come from the Puente backend.
///
/// Import this library from tests, demos, and dev tooling only.
/// `PuenteClient` refuses `PuenteEnvironment.mock` in release builds.
library;

export 'src/transport/mock_transport.dart';
