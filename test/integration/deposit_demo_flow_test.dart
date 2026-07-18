import 'package:puente_railway/puente_railway.dart';
import 'package:test/test.dart';

/// End-to-end integration: the exact flow Pesito's "Add money → USDC"
/// screen will run against `PuenteEnvironment.mock`.
///
/// Step by step:
///   1. Supported-assets allowlist populates the asset picker.
///   2. Session creation assigns the user's Solana deposit address.
///   3. Quote shows fees + the labeled indicative estimate.
///   4. Prepare hands the approval + route transaction to the wallet.
///   5. Submission reports the broadcast hash (a hint, not truth).
///   6. Watch streams the lifecycle until the ledger credit.
///   7. Events + listing power the receipt/history screens.
///   8. An idempotent retry creates no second deposit.
void main() {
  test('deposit demo flow — external wallet to credited USDC', () async {
    final puente = PuenteClient.mock(
      seed: 42,
      settlementLatency: const Duration(milliseconds: 100),
      networkLatency: Duration.zero,
    );
    addTearDown(puente.close);

    // 1. Asset picker.
    final assets = await puente.deposits.getSupportedAssets();
    expect(assets, isNotEmpty);
    final usdcOnBase = assets.firstWhere((a) => a.network == 'base');
    expect(usdcOnBase.symbol, 'USDC');
    expect(usdcOnBase.enabled, isTrue);

    // 2. Open a session with a deterministic idempotency key.
    const idempotencyKey = 'pesito-deposit-demo-42';
    final session = await puente.deposits.createSession(
      userId: 'usr_demo',
      sourceNetwork: usdcOnBase.network,
      sourceAssetId: usdcOnBase.id,
      sourceWalletAddress: '0xDemoWallet',
      sourceAmountMinor: 25000000, // 25 USDC
      displayCurrency: 'MXN',
      idempotencyKey: idempotencyKey,
    );
    expect(session.id, startsWith('dep_'));
    expect(session.status, DepositStatus.created);
    expect(session.destinationAddress, isNotNull);

    // 3. Quote — integer minor units, indicative display.
    final quoted = await puente.deposits.getQuote(
      session.id,
      idempotencyKey: DepositsResource.deriveHopKey(idempotencyKey, 'quote'),
    );
    final quote = quoted.quote!;
    expect(quote.expectedDestinationMinor, lessThan(25000000));
    expect(quote.minimumDestinationMinor,
        lessThanOrEqualTo(quote.expectedDestinationMinor));
    expect(quote.display!.fxType, 'indicative');

    // 4. Prepare — the wallet signing handoff.
    final prepared = await puente.deposits.prepare(
      session.id,
      idempotencyKey: DepositsResource.deriveHopKey(idempotencyKey, 'prepare'),
    );
    expect(prepared.approval, isA<EvmErc20ApprovalSigningRequest>());
    expect(prepared.transaction, isA<EvmTransactionSigningRequest>());
    expect(prepared.spender, isNotNull);

    // 5. Report the broadcast (the mock wallet "signed" instantly).
    final submitted = await puente.deposits.reportSubmission(
      session.id,
      transactionHash: '0xdemobroadcast',
      idempotencyKey:
          DepositsResource.deriveHopKey(idempotencyKey, 'submission'),
    );
    expect(submitted.status, DepositStatus.submitted);

    // 6. Watch the lifecycle to the ledger credit.
    final seen = <DepositStatus>[];
    await for (final s in puente.deposits.watch(
      session.id,
      pollInterval: const Duration(milliseconds: 20),
      timeout: const Duration(seconds: 5),
    )) {
      seen.add(s.status);
      if (s.status.isTerminal) break;
    }
    expect(seen.last, DepositStatus.credited);
    expect(seen.length, greaterThanOrEqualTo(2));

    // 7. Receipt/history surfaces.
    final events = await puente.deposits.events(session.id);
    expect(events.first.toStatus, DepositStatus.created);
    expect(events.last.toStatus, DepositStatus.credited);
    final history = await puente.deposits.list(userId: 'usr_demo');
    expect(history.first.id, session.id);
    expect(
        history.first.actualDestinationMinor, quote.expectedDestinationMinor);

    // 8. Retry with the same idempotency key — no new deposit.
    final retry = await puente.deposits.createSession(
      userId: 'usr_demo',
      sourceNetwork: usdcOnBase.network,
      sourceAssetId: usdcOnBase.id,
      sourceWalletAddress: '0xDemoWallet',
      sourceAmountMinor: 25000000,
      displayCurrency: 'MXN',
      idempotencyKey: idempotencyKey,
    );
    expect(retry.id, session.id);
    expect(await puente.deposits.list(userId: 'usr_demo'), hasLength(1));
  });
}
