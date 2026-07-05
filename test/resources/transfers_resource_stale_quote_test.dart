import 'package:clock/clock.dart';
import 'package:puente_railway/puente_railway.dart';
import 'package:test/test.dart';

void main() {
  group('TransfersResource.createFromQuote stale-quote guard', () {
    test('throws StaleQuoteException when quote.expiresAt is in the past',
        () async {
      final PuenteClient client = PuenteClient.mock();
      addTearDown(client.close);

      final DateTime now = DateTime.utc(2026, 6, 20, 12, 0, 0);
      final Quote stale = Quote(
        id: 'qt_stale_abc',
        sourceAmount: const Money.fromMinor(1000, Currency.usd),
        targetAmount: const Money.fromMinor(19730, Currency.mxn),
        exchangeRate: 19.73,
        fee: const Money.fromMinor(50, Currency.usd),
        expiresAt: now.subtract(const Duration(seconds: 1)),
        createdAt: now.subtract(const Duration(minutes: 2)),
      );

      await withClock(Clock.fixed(now), () async {
        await expectLater(
          () => client.transfers.createFromQuote(
            quote: stale,
            receiverClabe: '012180012345678901',
            receiverName: 'María García López',
          ),
          throwsA(isA<StaleQuoteException>()
              .having((StaleQuoteException e) => e.quoteId, 'quoteId',
                  'qt_stale_abc')
              .having((StaleQuoteException e) => e.expiresAt, 'expiresAt',
                  stale.expiresAt)),
        );
      });
    });

    test('forwards to create() when quote.expiresAt is in the future',
        () async {
      // MockTransport's `quotes.create` is the cleanest way to manufacture a
      // valid quote against the mock backend; we then immediately use it.
      final PuenteClient client = PuenteClient.mock();
      addTearDown(client.close);

      final Quote fresh = await client.quotes.create(
        sourceAmount: const Money.fromMinor(10000, Currency.usd),
        targetCurrency: Currency.mxn,
      );

      final Transfer t = await client.transfers.createFromQuote(
        quote: fresh,
        receiverClabe: '012180012345678901',
        receiverName: 'María García López',
      );
      expect(t.id, startsWith('tx_'));
    });

    test('StaleQuoteException is a PuenteException', () {
      final DateTime t = DateTime.utc(2026, 6, 20);
      final StaleQuoteException e = StaleQuoteException(
        quoteId: 'qt_x',
        expiresAt: t,
        detectedAt: t.add(const Duration(seconds: 1)),
      );
      expect(e, isA<PuenteException>());
      expect(e.message, contains('qt_x'));
    });
  });
}
