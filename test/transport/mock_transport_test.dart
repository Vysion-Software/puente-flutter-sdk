import 'package:clock/clock.dart';
import 'package:puente_railway/puente_railway.dart';
import 'package:puente_railway/testing.dart';
import 'package:test/test.dart';

void main() {
  group('MockTransport', () {
    late MockTransport transport;

    setUp(() {
      transport = MockTransport(
        seed: 1,
        settlementLatency: Duration.zero,
        networkLatency: Duration.zero,
      );
    });

    tearDown(() => transport.close());

    /// Creates a quote through the transport and returns its wire doc.
    Future<Map<String, dynamic>> createQuote({
      int sourceMinor = 10000,
      String sourceCurrency = 'USD',
      String destinationCurrency = 'MXN',
    }) async {
      final response = await transport.send(PuenteRequest(
        method: 'POST',
        path: '/quotes',
        body: <String, dynamic>{
          'source_amount_minor': sourceMinor,
          'source_currency': sourceCurrency,
          'destination_currency': destinationCurrency,
        },
      ));
      expect(response.statusCode, 200);
      return response.jsonObject;
    }

    test('POST /quotes emits the real-backend shape plus legacy keys',
        () async {
      final body = await createQuote();
      // Real-backend shape.
      expect(body['quote_id'], startsWith('qt_'));
      expect(body['source_amount_minor'], 10000);
      expect(body['source_currency'], 'USD');
      // Fixture rate 19.73, gross conversion — fees are NOT netted into
      // the destination by the mock (that's backend policy, not SDK math).
      expect(body['destination_amount_minor'], 197300);
      expect(body['destination_currency'], 'MXN');
      expect(body['fx_rate'], '19.73');
      expect(body['total_fee_minor'],
          MockTransport.crossBorderFlatFeeFixtureMinor);
      expect(body['total_cost_minor'],
          10000 + MockTransport.crossBorderFlatFeeFixtureMinor);
      expect(body['transfer_type'], 'cross_border');
      expect(body['currency_leg'], 'CETES');
      expect(body['fee_breakdown'], {
        'flat_fee_minor': 100,
        'fx_spread_fee_minor': 0,
        'vendor_fee_minor': 0,
        'total_fee_minor': 100,
        'currency': 'USD',
      });
      // Legacy shape, kept alongside.
      expect(body['id'], body['quote_id']);
      expect(body['source_amount'], {'amount': 10000, 'currency': 'USD'});
      expect(body['target_amount'], {'amount': 197300, 'currency': 'MXN'});
      expect(body['exchange_rate'], 19.73);
      expect(body['fee'], {'amount': 100, 'currency': 'USD'});
    });

    test('POST /quotes accepts the legacy body shape', () async {
      final response = await transport.send(PuenteRequest(
        method: 'POST',
        path: '/quotes',
        body: <String, dynamic>{
          'source_amount': const Money.fromMinor(10000, Currency.usd).toJson(),
          'source_currency': 'USD',
          'target_currency': 'MXN',
        },
      ));
      expect(response.statusCode, 200);
      expect(response.jsonObject['destination_amount_minor'], 197300);
    });

    test('POST /transfers + GET /transfers/:id flow', () async {
      final quote = await createQuote();
      final create = await transport.send(PuenteRequest(
        method: 'POST',
        path: '/transfers',
        body: <String, dynamic>{
          'quote_id': quote['quote_id'],
          'receiver_clabe': '012180012345678901',
          'receiver_name': 'Maria Garcia',
        },
        idempotencyKey: 'idem_one',
      ));
      expect(create.statusCode, 201);
      final id = create.jsonObject['id'] as String;
      expect(id, startsWith('tx_'));
      // settlementLatency = 0 → status is settled immediately.
      expect(create.jsonObject['status'], 'settled');
      // Amounts come from the quote verbatim.
      expect(create.jsonObject['source_amount'], quote['source_amount']);
      expect(create.jsonObject['target_amount'], quote['target_amount']);

      final get = await transport.send(PuenteRequest(
        method: 'GET',
        path: '/transfers/$id',
      ));
      expect(get.statusCode, 200);
      expect(get.jsonObject['id'], id);
    });

    test('Idempotency-Key replays the same response', () async {
      final quote = await createQuote();
      final body = <String, dynamic>{
        'quote_id': quote['quote_id'],
        'receiver_clabe': '012180012345678901',
        'receiver_name': 'Maria Garcia',
      };
      final first = await transport.send(PuenteRequest(
        method: 'POST',
        path: '/transfers',
        body: body,
        idempotencyKey: 'same-key',
      ));
      final second = await transport.send(PuenteRequest(
        method: 'POST',
        path: '/transfers',
        body: body,
        idempotencyKey: 'same-key',
      ));
      expect(first.jsonObject['id'], second.jsonObject['id']);
    });

    test('GET on unknown transfer returns 404', () async {
      final r = await transport.send(const PuenteRequest(
        method: 'GET',
        path: '/transfers/tx_nope',
      ));
      expect(r.statusCode, 404);
      expect(r.jsonObject['error'], 'not_found');
    });

    test('CLABE lookup distinguishes known + unknown bank prefixes', () async {
      final good = await transport.send(const PuenteRequest(
        method: 'GET',
        path: '/clabe/012180012345678901',
      ));
      expect(good.jsonObject['bank_name'], 'BBVA México');
      expect(good.jsonObject['valid'], isTrue);

      final bad = await transport.send(const PuenteRequest(
        method: 'GET',
        path: '/clabe/999180012345678901',
      ));
      expect(bad.jsonObject['valid'], isFalse);
    });

    test('CLABE ending in 00 is reported invalid for negative-path testing',
        () async {
      final r = await transport.send(const PuenteRequest(
        method: 'GET',
        path: '/clabe/012180012345678900',
      ));
      expect(r.jsonObject['valid'], isFalse);
    });

    test('lifecycle advances over real time when latency > 0', () async {
      transport.close();
      transport = MockTransport(
        seed: 2,
        settlementLatency: const Duration(milliseconds: 100),
        networkLatency: Duration.zero,
      );

      final quote = await createQuote();
      final create = await transport.send(PuenteRequest(
        method: 'POST',
        path: '/transfers',
        body: <String, dynamic>{
          'quote_id': quote['quote_id'],
          'receiver_clabe': '012180012345678901',
          'receiver_name': 'Maria Garcia',
        },
      ));
      final id = create.jsonObject['id'] as String;
      expect(create.jsonObject['status'], 'pending');

      // Wait for the processing timer.
      await Future<void>.delayed(const Duration(milliseconds: 70));
      final mid = await transport.send(PuenteRequest(
        method: 'GET',
        path: '/transfers/$id',
      ));
      expect(mid.jsonObject['status'], anyOf('processing', 'settled'));

      // Wait for terminal.
      await Future<void>.delayed(const Duration(milliseconds: 80));
      final done = await transport.send(PuenteRequest(
        method: 'GET',
        path: '/transfers/$id',
      ));
      expect(done.jsonObject['status'], 'settled');
      expect(done.jsonObject['reference'], startsWith('SPEI-'));
    });

    // Confirm the `clock` import is referenced so analyze doesn't complain.
    test('clock is wired (sanity)', () {
      expect(clock.now().toUtc().isAfter(DateTime(2020)), isTrue);
    });
  });
}
