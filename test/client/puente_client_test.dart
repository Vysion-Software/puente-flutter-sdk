import 'package:puente_railway/puente_railway.dart';
import 'package:test/test.dart';

void main() {
  group('PuenteClient via MockTransport', () {
    late PuenteClient client;

    setUp(() {
      client = PuenteClient.mock(
        seed: 7,
        settlementLatency: Duration.zero,
        networkLatency: Duration.zero,
      );
    });

    tearDown(() => client.close());

    test('quotes.create returns a Quote', () async {
      final q = await client.quotes.create(
        sourceAmount: const Money.fromMinor(10000, Currency.usd),
        targetCurrency: Currency.mxn,
      );
      expect(q.id, startsWith('qt_'));
      expect(q.sourceAmount.currency, Currency.usd);
      expect(q.targetAmount.currency, Currency.mxn);
      expect(q.exchangeRate, greaterThan(10));
    });

    test('transfers.create + retrieve happy path', () async {
      final q = await client.quotes.create(
        sourceAmount: const Money.fromMinor(10000, Currency.usd),
        targetCurrency: Currency.mxn,
      );
      final t = await client.transfers.create(
        quoteId: q.id,
        receiverClabe: '012180012345678901',
        receiverName: 'Maria Garcia',
      );
      expect(t.id, startsWith('tx_'));
      expect(t.status, TransferStatus.settled);
      // With latency = 0 the doc lands settled immediately.

      final fetched = await client.transfers.retrieve(t.id);
      expect(fetched.id, t.id);
    });

    test('transfers.create with invalid CLABE → ValidationException', () async {
      final q = await client.quotes.create(
        sourceAmount: const Money.fromMinor(10000, Currency.usd),
        targetCurrency: Currency.mxn,
      );
      expect(
        () => client.transfers.create(
          quoteId: q.id,
          receiverClabe: '123', // too short
          receiverName: 'X',
        ),
        throwsA(isA<ValidationException>()
            .having((e) => e.statusCode, 'statusCode', 422)),
      );
    });

    test('transfers.cancel works on pending + rejects terminal', () async {
      // Need pending to test cancel path — set non-zero latency.
      client.close();
      client = PuenteClient.mock(
        seed: 8,
        settlementLatency: const Duration(seconds: 5),
        networkLatency: Duration.zero,
      );

      final q = await client.quotes.create(
        sourceAmount: const Money.fromMinor(5000, Currency.usd),
        targetCurrency: Currency.mxn,
      );
      final t = await client.transfers.create(
        quoteId: q.id,
        receiverClabe: '012180012345678901',
        receiverName: 'Maria',
      );
      expect(t.status, TransferStatus.pending);

      final cancelled = await client.transfers.cancel(t.id);
      expect(cancelled.status, TransferStatus.cancelled);

      expect(
        () => client.transfers.cancel(t.id),
        throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'statusCode', 409)),
      );
    });

    test('accounts.create + retrieve + update', () async {
      final a = await client.accounts.create(
        firstName: 'Ana',
        lastName: 'Lopez',
        email: 'ana@example.com',
        phone: '+525555555555',
      );
      expect(a.id, startsWith('acct_'));

      final fetched = await client.accounts.retrieve(a.id);
      expect(fetched, a);

      final updated =
          await client.accounts.update(a.id, phone: '+525555000000');
      expect(updated.phone, '+525555000000');
    });

    test('clabe.lookup matches the mock bank registry', () async {
      final ci = await client.clabe.lookup('012180012345678901');
      expect(ci.bankCode, '012');
      expect(ci.bankName, 'BBVA México');
      expect(ci.valid, isTrue);
    });

    test('remittance.send is a single-call quote → transfer', () async {
      final result = await client.remittance.send(
        sourceAmount: const Money.fromMinor(10000, Currency.usd),
        targetCurrency: Currency.mxn,
        receiverClabe: '012180012345678901',
        receiverName: 'Maria',
        memo: 'Demo',
      );
      expect(result.transfer.id, startsWith('tx_'));
      expect(result.transfer.status, TransferStatus.settled);
      expect(result.quote.id, startsWith('qt_'));
    });
  });
}
