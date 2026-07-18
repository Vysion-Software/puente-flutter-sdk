import 'package:puente_railway/puente_railway.dart';
import 'package:puente_railway/testing.dart';
import 'package:test/test.dart';

/// Contract tests: the mock must answer with the REAL backend's exact
/// wire contract — status codes, stable error vocabulary, and scenario
/// names — verified against a running `VENDOR_MODE=mock` Puente API
/// (see `test/integration/deposits_live_backend_test.dart` for the live
/// proof). Client branching logic written against the mock must keep
/// working against the real backend.
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
          sourceWalletAddress: '0x1111111111111111111111111111111111111111',
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

    test('422 unsupported_asset for assets outside the allowlist', () async {
      await expectLater(
        create(assetId: 'base:0x000000000000000000000000000000000000dead'),
        throwsA(apiError(422, 'unsupported_asset')),
      );
    });

    test('422 unsupported_network for networks outside the allowlist',
        () async {
      // Solana-source included: the default allowlist has no solana
      // entries, so the real backend rejects it as unsupported_network.
      await expectLater(
        create(network: 'solana', assetId: 'solana:SomeMint'),
        throwsA(apiError(422, 'unsupported_network')),
      );
      await expectLater(
        create(network: 'polygon', assetId: 'polygon:0x1'),
        throwsA(apiError(422, 'unsupported_network')),
      );
    });

    test('422 amount bounds: below minimum and above maximum', () async {
      await expectLater(
        create(amountMinor: 999999), // < 1 USDC fixture minimum
        throwsA(apiError(422, 'amount_below_minimum')),
      );
      await expectLater(
        create(amountMinor: 10000000001), // > 10k USDC fixture maximum
        throwsA(apiError(422, 'amount_above_maximum')),
      );
    });

    test('POST without an Idempotency-Key answers 400 plain text', () async {
      // Mirror the backend idempotency middleware exactly: 400 with a
      // non-JSON body. Sent through the raw transport because the
      // resource layer always generates a key.
      final response = await transport.send(const PuenteRequest(
        method: 'POST',
        path: '/deposit-sessions',
        body: <String, dynamic>{'user_id': 'usr_x'},
      ));
      expect(response.statusCode, 400);
      expect(response.body, 'Missing Idempotency-Key');
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
      await client.deposits.prepare(session.id);
      await client.deposits.sendMockEvent(session.id, 'submitted');
      await client.deposits.sendMockEvent(session.id, 'route_failed');
      await expectLater(
        client.deposits.sendMockEvent(session.id, 'quote'),
        throwsA(apiError(409, 'illegal_state')),
      );
    });

    test('unknown mock scenario is 400 invalid_request (backend shape)',
        () async {
      // The backend answers 400 {"error":"invalid_request: unknown
      // scenario \"…\""} — the SDK strips the detail after ':' so the
      // stable code is invalid_request. There is NO quote_expired
      // scenario on the backend (quote expiry is TTL-driven).
      final session = await create(userId: 'usr_scenario');
      await expectLater(
        client.deposits.sendMockEvent(session.id, 'time_travel'),
        throwsA(apiError(400, 'invalid_request')),
      );
      await expectLater(
        client.deposits.sendMockEvent(session.id, 'quote_expired'),
        throwsA(apiError(400, 'invalid_request')),
      );
    });

    test('settle_finalized credits; re-finalizing is an idempotent 200',
        () async {
      final session = await create(userId: 'usr_sfin');
      await client.deposits.getQuote(session.id);
      await client.deposits.prepare(session.id);
      await client.deposits
          .reportSubmission(session.id, transactionHash: 'feedbeef');
      final credited =
          await client.deposits.sendMockEvent(session.id, 'settle_finalized');
      expect(credited.status, DepositStatus.credited);
      expect(credited.ledgerTransactionId, isNotNull);
      // The backend credits exactly once — a repeat settle_finalized is a
      // 200 no-op, never a double credit.
      final again =
          await client.deposits.sendMockEvent(session.id, 'settle_finalized');
      expect(again.status, DepositStatus.credited);
      expect(again.ledgerTransactionId, credited.ledgerTransactionId);
    });

    test('settle_finalized at/above the threshold parks in compliance_hold',
        () async {
      final session = await create(
        userId: 'usr_bighold',
        amountMinor: 8000000000, // 8k USDC ≥ 5k threshold
      );
      await client.deposits.getQuote(session.id);
      await client.deposits.prepare(session.id);
      await client.deposits
          .reportSubmission(session.id, transactionHash: 'bighold01');
      final held =
          await client.deposits.sendMockEvent(session.id, 'settle_finalized');
      expect(held.status, DepositStatus.complianceHold);
      expect(held.riskStatus, 'hold');
      expect(held.ledgerTransactionId, isNull);
      // Release + credit → credited exactly once (smoke.sh steps 20–21).
      final released =
          await client.deposits.sendMockEvent(session.id, 'compliance_release');
      expect(released.status, DepositStatus.complianceHold);
      expect(released.riskStatus, 'released');
      final credited =
          await client.deposits.sendMockEvent(session.id, 'credit');
      expect(credited.status, DepositStatus.credited);
      expect(credited.ledgerTransactionId, isNotNull);
    });

    test('sweep advances credited → swept (post-credit, internal)', () async {
      final session = await create(userId: 'usr_sweep');
      await client.deposits.getQuote(session.id);
      await client.deposits.prepare(session.id);
      await client.deposits
          .reportSubmission(session.id, transactionHash: 'sweephash1');
      final credited =
          await client.deposits.sendMockEvent(session.id, 'settle_finalized');
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
        sourceWalletAddress: '0x1111111111111111111111111111111111111111',
        sourceAmountMinor: 5000000,
        idempotencyKey: key,
      );
      final retry = await client.deposits.createSession(
        userId: 'usr_idem',
        sourceNetwork: 'base',
        sourceAssetId: 'base:0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913',
        sourceWalletAddress: '0x1111111111111111111111111111111111111111',
        sourceAmountMinor: 5000000,
        idempotencyKey: key,
      );
      expect(retry.id, first.id);
      expect(await client.deposits.list(userId: 'usr_idem'), hasLength(1));
    });

    test('quote fixture math mirrors the backend mock exactly', () async {
      final session = await create(userId: 'usr_quote_pin');
      final quoted = await client.deposits.getQuote(session.id);
      final quote = quoted.quote!;
      // 5 USDC in: 0.4% service (20 000) + $0.18 gas (180 000) out, 1%
      // slippage floor — the backend `MockDepositProvider` policy. Real
      // numbers ALWAYS come from the backend quote.
      const serviceFee =
          5000000 * MockTransport.depositServiceFeeBpsFixture ~/ 10000;
      const fees = serviceFee + MockTransport.depositGasFeeUsdcFixtureMinor;
      expect(quote.sourceAmountMinor, 5000000);
      expect(quote.expectedDestinationMinor, 5000000 - fees);
      expect(quote.minimumDestinationMinor, (5000000 - fees) * 99 ~/ 100);
      expect(quote.totalFeesUsd, '0.200000');
      expect(quote.fees.map((f) => f.kind),
          containsAll(['Service fee', 'Gas receiver fee']));
      // kind == label on the real wire (vendor strings verbatim).
      for (final fee in quote.fees) {
        expect(fee.kind, fee.label);
      }
      expect(quote.display!.currency, 'USD');
      expect(quote.display!.estimatedCreditMinor, 5000000 - fees);
      expect(quote.display!.fxRate, '1');
      expect(quote.display!.fxType, 'indicative');
    });

    test('MXN display estimate is labeled indicative with NO rate', () async {
      // The real backend attaches no MXN estimate and no rate in this
      // MVP — no FX liability exists until a conversion executes.
      final session = await client.deposits.createSession(
        userId: 'usr_mxn',
        sourceNetwork: 'base',
        sourceAssetId: 'base:0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913',
        sourceWalletAddress: '0x1111111111111111111111111111111111111111',
        sourceAmountMinor: 100000000,
        displayCurrency: 'MXN',
      );
      final quoted = await client.deposits.getQuote(session.id);
      final display = quoted.quote!.display!;
      expect(display.currency, 'MXN');
      expect(display.fxType, 'indicative');
      expect(display.fxRate, isNull);
      expect(display.estimatedCreditMinor, isNull);
      expect(quoted.displayEstimate, display);
    });
  });
}
