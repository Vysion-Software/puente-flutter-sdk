import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:puente_railway/puente_railway.dart';
import 'package:test/test.dart';

void main() {
  group('HttpTransport Authorization resolution', () {
    const ping = PuenteRequest(method: 'GET', path: '/transfers');

    MockClient capture(List<http.Request> log) => MockClient((request) async {
          log.add(request);
          return http.Response(
            '{}',
            200,
            headers: <String, String>{'content-type': 'application/json'},
          );
        });

    test('tokenProvider mints a fresh bearer on every request', () async {
      final log = <http.Request>[];
      var calls = 0;
      final transport = HttpTransport(
        config: PuenteConfig.testnet(
          tokenProvider: () async => 'tok_${++calls}',
        ),
        inner: capture(log),
      );
      addTearDown(transport.close);

      await transport.send(ping);
      await transport.send(ping);

      expect(log, hasLength(2));
      expect(log[0].headers['authorization'], 'Bearer tok_1');
      expect(log[1].headers['authorization'], 'Bearer tok_2');
    });

    test('tokenProvider wins over apiKey when both are configured', () async {
      final log = <http.Request>[];
      final transport = HttpTransport(
        config: PuenteConfig.testnet(
          apiKey: 'sk_testnet_should_not_be_sent',
          tokenProvider: () async => 'session_token',
        ),
        inner: capture(log),
      );
      addTearDown(transport.close);

      await transport.send(ping);

      expect(log.single.headers['authorization'], 'Bearer session_token');
    });

    test('static apiKey is used when no tokenProvider is set', () async {
      final log = <http.Request>[];
      final transport = HttpTransport(
        config: PuenteConfig.testnet(apiKey: 'sk_testnet_x'),
        inner: capture(log),
      );
      addTearDown(transport.close);

      await transport.send(ping);

      expect(log.single.headers['authorization'], 'Bearer sk_testnet_x');
    });
  });
}
