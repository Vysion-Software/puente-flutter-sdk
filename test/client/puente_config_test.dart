import 'package:puente_railway/puente_railway.dart';
import 'package:test/test.dart';

void main() {
  group('PuenteConfig auth-source validation', () {
    test('throws when neither apiKey nor tokenProvider is provided', () {
      expect(
        () => PuenteConfig(environment: PuenteEnvironment.production),
        throwsArgumentError,
      );
      expect(() => PuenteConfig.testnet(), throwsArgumentError);
      expect(() => PuenteConfig.sandbox(), throwsArgumentError);
      expect(() => PuenteConfig.production(), throwsArgumentError);
    });

    test('accepts apiKey alone (server-side sk_ keys)', () {
      final config = PuenteConfig.production(apiKey: 'sk_live_x');
      expect(config.apiKey, 'sk_live_x');
      expect(config.tokenProvider, isNull);
    });

    test('accepts tokenProvider alone (mobile-safe)', () {
      final config = PuenteConfig.production(
        tokenProvider: () async => 'session_token',
      );
      expect(config.apiKey, isEmpty);
      expect(config.tokenProvider, isNotNull);
    });

    test('accepts both — tokenProvider takes precedence at the transport', () {
      final config = PuenteConfig.testnet(
        apiKey: 'sk_testnet_x',
        tokenProvider: () async => 'session_token',
      );
      expect(config.tokenProvider, isNotNull);
      expect(config.apiKey, 'sk_testnet_x');
    });

    test('mock environment allows an empty apiKey', () {
      final config = PuenteConfig(environment: PuenteEnvironment.mock);
      expect(config.apiKey, isEmpty);
      expect(config.baseUrl.scheme, 'mock');
    });
  });
}
