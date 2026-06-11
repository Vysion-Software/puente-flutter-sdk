import 'package:puente_railway/puente_railway.dart';
import 'package:test/test.dart';

/// End-to-end integration: the exact flow Pesito's mobile demo will run
/// against `PuenteEnvironment.mock` for the testnet showcase.
///
/// Step by step:
///   1. CLABE lookup confirms the recipient bank.
///   2. Quote shows the user the FX + fee.
///   3. Transfer is created with a deterministic idempotency key.
///   4. Status stream watches lifecycle until settled.
///   5. Listing shows the new transfer at the top.
void main() {
  test('demo flow — Pesito testnet showcase end-to-end', () async {
    final puente = PuenteClient.mock(
      seed: 42,
      settlementLatency: const Duration(milliseconds: 100),
      networkLatency: Duration.zero,
    );
    addTearDown(puente.close);

    // 1. Confirm recipient bank.
    final bank = await puente.clabe.lookup('012180012345678901');
    expect(bank.bankName, 'BBVA México');
    expect(bank.valid, isTrue);

    // 2. Quote.
    final quote = await puente.quotes.create(
      sourceAmount: Money.fromDecimal('100.00', Currency.usd),
      targetCurrency: Currency.mxn,
    );
    expect(quote.sourceAmount.minorUnits, 10000);
    expect(quote.targetAmount.currency, Currency.mxn);

    // 3. Execute transfer with a deterministic idempotency key.
    const idempotencyKey = 'pesito-demo-tx-42';
    final transfer = await puente.transfers.create(
      quoteId: quote.id,
      receiverClabe: bank.clabe,
      receiverName: 'María García López',
      memo: 'Para la familia',
      idempotencyKey: idempotencyKey,
    );
    expect(transfer.id, startsWith('tx_'));
    expect(transfer.status, TransferStatus.pending);

    // 4. Watch lifecycle. We expect at least one non-pending state and
    // an eventual terminal state within the watch timeout.
    final seen = <TransferStatus>[];
    await for (final t in puente.transfers.watch(
      transfer.id,
      pollInterval: const Duration(milliseconds: 20),
      timeout: const Duration(seconds: 5),
    )) {
      seen.add(t.status);
      if (t.status.isTerminal) break;
    }
    expect(seen.last, TransferStatus.settled);
    expect(seen, contains(TransferStatus.pending));

    // 5. Retry with the same idempotency key — no new movement.
    final retry = await puente.transfers.create(
      quoteId: quote.id,
      receiverClabe: bank.clabe,
      receiverName: 'María García López',
      memo: 'Para la familia',
      idempotencyKey: idempotencyKey,
    );
    expect(retry.id, transfer.id);
  });
}
