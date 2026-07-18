import 'package:puente_railway/puente_railway.dart';
import 'package:puente_railway/testing.dart';
import 'package:test/test.dart';

/// Contract tests: the mock must answer with the design doc's EXACT
/// stable error vocabulary (`docs/deposits-external-wallet-design.md`)
/// so client branching logic written against the mock keeps working
/// against the real backend.
void main() {
  group('Mock deposits contract', () {
    late MockTransport transport;
    late PuenteClient client;

    setUp(() {
      transport = MockTransport(
        seed: 11,
        settlementLatency: Duration.zero,
        networkLatency: Duration.zero,
      );
      client = PuenteClient.withTransport(
        config: PuenteConfig.mock(),
        transport: transport,
        ownsTransport: true,
      );
    });

    tearDown(() => client.close());

    Future<DepositSession> create({
      String userId = 'usr_contract',
      String network = 'base',
      String? assetId,
      int amountMinor = 5000000,
    }) =>
        client.deposits.createSession(
          userId: userId,
          sourceNetwork: network,
          sourceAssetId:
              assetId ?? 'base:0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913',
          sourceWalletAddress: '0xUserWallet',
          sourceAmountMinor: amountMinor,
        );

    Matcher apiError(int statusCode, String code) => isA<ApiException>()
        .having((e) => e.statusCode, 'statusCode', statusCode)
        .having((e) => e.code, 'code', code);

    test('404 deposit_not_found for unknown sessions', () async {
      await expectLater(
        client.deposits.retrieve('dep_nope'),
        throwsA(apiError(404, 'deposit_not_found')),
      );
      await expectLater(
        client.deposits.getQuote('dep_nope'),
        throwsA(apiError(404, 'deposit_not_found')),
      );
      await expectLater(
        client.deposits.events('dep_nope'),
        throwsA(apiError(404, 'deposit_not_found')),
      );
    });

    test('400 unsupported_asset for assets outside the allowlist', () async {
      await expectLater(
        create(assetId: 'base:0x000000000000000000000000000000000000dead'),
        throwsA(apiError(400, 'unsupported_asset')),
      );
    });

    test('503 capability_unavailable for Solana-source deposits', () async {
      await expectLater(
        create(network: 'solana', assetId: 'solana:SomeMint'),
        throwsA(apiError(503, 'capability_unavailable')),
      );
    });

    test('400 amount bounds: below minimum and above maximum', () async {
      await expectLater(
        create(amountMinor: 999999), // < 1 USDC fixture minimum
        throwsA(apiError(400, 'amount_below_minimum')),
      );
      await expectLater(
        create(amountMinor: 10000000001), // > 10k USDC fixture maximum
        throwsA(apiError(400, 'amount_above_maximum')),
      );
    });

    test('503 deposits_disabled on every route when toggled off', () async {
      final session = await create();
      transport.depositsEnabled = false;
      await expectLater(
        client.deposits.getSupportedAssets(),
        throwsA(apiError(503, 'deposits_disabled')),
      );
      await expectLater(
        create(),
        throwsA(apiError(503, 'deposits_disabled')),
      );
      await expectLater(
        client.deposits.retrieve(session.id),
        throwsA(apiError(503, 'deposits_disabled')),
      );
      transport.depositsEnabled = true;
      expect((await client.deposits.retrieve(session.id)).id, session.id);
    });

    test('409 quote_required when preparing before any quote', () async {
      final session = await create();
      await expectLater(
        client.deposits.prepare(session.id),
        throwsA(apiError(409, 'quote_required')),
      );
    });

    test('409 illegal_state for out-of-order hops', () async {
      final session = await create();
      // Submission before prepare.
      await expectLater(
        client.deposits.reportSubmission(session.id, transactionHash: '0x1'),
        throwsA(apiError(409, 'illegal_state')),
      );
      // Quote after prepare (re-quote is only legal until prepared).
      await client.deposits.getQuote(session.id);
      await client.deposits.prepare(session.id);
      await expectLater(
        client.deposits.getQuote(session.id),
        throwsA(apiError(409, 'illegal_state')),
      );
    });

    test('mock-events pin failure codes exactly', () async {
      Future<void> pin(String scenario, DepositStatus status) async {
        final session = await create(userId: 'usr_$scenario');
        await client.deposits.getQuote(session.id);
        await client.deposits.prepare(session.id);
        await client.deposits.sendMockEvent(session.id, 'submitted');
        final failed =
            await client.deposits.sendMockEvent(session.id, scenario);
        expect(failed.status, status);
        expect(failed.failureCode, status.wire);
        expect(failed.status.isFailure, isTrue);
      }

      await pin('wrong_asset', DepositStatus.wrongAsset);
      await pin('route_failed', DepositStatus.routeFailed);
      await pin('underpay', DepositStatus.amountMismatch);
    });

    test('mock-events reject terminal sessions with 409 illegal_state',
        () async {
      final session = await create(userId: 'usr_terminal');
      await client.deposits.getQuote(session.id);
      await client.deposits.sendMockEvent(session.id, 'quote_expired');
      await expectLater(
        client.deposits.sendMockEvent(session.id, 'quote'),
        throwsA(apiError(409, 'illegal_state')),
      );
    });

    test('unknown mock scenario is a 422', () async {
      final session = await create(userId: 'usr_scenario');
      await expectLater(
        client.deposits.sendMockEvent(session.id, 'time_travel'),
        throwsA(isA<ValidationException>()),
      );
    });

    test('sweep advances credited → swept (post-credit, internal)', () async {
      final session = await create(userId: 'usr_sweep');
      await client.deposits.getQuote(session.id);
      await client.deposits.prepare(session.id);
      final credited = await client.deposits
          .reportSubmission(session.id, transactionHash: '0xfeed');
      expect(credited.status, DepositStatus.credited);
      final swept = await client.deposits.sendMockEvent(session.id, 'sweep');
      expect(swept.status, DepositStatus.swept);
      expect(swept.status.isSettled, isTrue);
      expect(swept.sweptAt, isNotNull);
      // The customer-visible settled amount never changed post-credit.
      expect(swept.actualDestinationMinor, credited.actualDestinationMinor);
    });

    test('idempotency replay: same key returns the same session', () async {
      const key = 'deposit-gesture-42';
      final first = await client.deposits.createSession(
        userId: 'usr_idem',
        sourceNetwork: 'base',
        sourceAssetId: 'base:0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913',
        sourceWalletAddress: '0xUserWallet',
        sourceAmountMinor: 5000000,
        idempotencyKey: key,
      );
      final retry = await client.deposits.createSession(
        userId: 'usr_idem',
        sourceNetwork: 'base',
        sourceAssetId: 'base:0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913',
        sourceWalletAddress: '0xUserWallet',
        sourceAmountMinor: 5000000,
        idempotencyKey: key,
      );
      expect(retry.id, first.id);
      expect(await client.deposits.list(userId: 'usr_idem'), hasLength(1));
    });

    test('quote fixture math is integer passthrough, labeled fixture-only',
        () async {
      final session = await create(userId: 'usr_quote_pin');
      final quoted = await client.deposits.getQuote(session.id);
      final quote = quoted.quote!;
      const fees = MockTransport.depositGasFeeUsdcFixtureMinor +
          MockTransport.depositServiceFeeUsdcFixtureMinor;
      // 5 USDC in, fixture fees out, 1% slippage floor — mirrors the
      // backend mock's DEFAULT policy shape; real numbers ALWAYS come
      // from the backend quote.
      expect(quote.sourceAmountMinor, 5000000);
      expect(quote.expectedDestinationMinor, 5000000 - fees);
      expect(quote.minimumDestinationMinor, (5000000 - fees) * 99 ~/ 100);
      expect(quote.totalFeesUsd, '0.35');
      expect(quote.display!.currency, 'USD');
      expect(quote.display!.fxType, 'indicative');
    });

    test('MXN display estimate is labeled indicative with the fixture rate',
        () async {
      final session = await client.deposits.createSession(
        userId: 'usr_mxn',
        sourceNetwork: 'base',
        sourceAssetId: 'base:0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913',
        sourceWalletAddress: '0xUserWallet',
        sourceAmountMinor: 100000000,
        displayCurrency: 'MXN',
      );
      final quoted = await client.deposits.getQuote(session.id);
      final display = quoted.quote!.display!;
      expect(display.currency, 'MXN');
      expect(display.fxType, 'indicative');
      expect(display.fxRate, '19.73');
      expect(quoted.displayEstimate, display);
    });
  });
}
