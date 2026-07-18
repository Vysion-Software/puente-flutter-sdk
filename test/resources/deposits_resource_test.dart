import 'package:clock/clock.dart';
import 'package:puente_railway/puente_railway.dart';
import 'package:puente_railway/testing.dart';
import 'package:test/test.dart';

/// A transport that answers every request with one canned response —
/// used to prove malformed server output surfaces as a typed exception.
class _StaticTransport implements PuenteTransport {
  final PuenteResponse response;
  _StaticTransport(this.response);

  @override
  Future<PuenteResponse> send(PuenteRequest request) async => response;

  @override
  void close() {}
}

void main() {
  group('DepositsResource flow (mock backend)', () {
    late PuenteClient client;

    setUp(() {
      client = PuenteClient.mock(
        seed: 7,
        settlementLatency: Duration.zero,
        networkLatency: Duration.zero,
      );
    });

    tearDown(() => client.close());

    Future<DepositSession> createSession({String userId = 'usr_flow'}) async {
      final assets = await client.deposits.getSupportedAssets();
      final asset = assets.firstWhere((a) => a.network == 'base');
      return client.deposits.createSession(
        userId: userId,
        sourceNetwork: asset.network,
        sourceAssetId: asset.id,
        sourceWalletAddress: '0xUserWallet',
        sourceAmountMinor: 100000000, // 100 USDC (6 decimals)
      );
    }

    test('create → quote → prepare → submit → watch to credited', () async {
      final assets = await client.deposits.getSupportedAssets();
      expect(assets, hasLength(2));
      expect(assets.every((a) => a.enabled), isTrue);
      expect(assets.map((a) => a.network), containsAll(['base', 'ethereum']));

      final session = await createSession();
      expect(session.id, startsWith('dep_'));
      expect(session.status, DepositStatus.created);
      expect(session.destinationNetwork, 'solana');
      expect(session.destinationMint, MockTransport.depositUsdcMintFixture);
      expect(session.destinationAddress, isNotNull);
      expect(session.quote, isNull);

      final quoted = await client.deposits.getQuote(session.id);
      expect(quoted.status, DepositStatus.quoted);
      final quote = quoted.quote!;
      // Integer passthrough of the mock's fixture policy — the SDK does
      // NO math; these pins prove the wire values arrive verbatim.
      const fixtureFees = MockTransport.depositGasFeeUsdcFixtureMinor +
          MockTransport.depositServiceFeeUsdcFixtureMinor;
      expect(quote.sourceAmountMinor, 100000000);
      expect(quote.expectedDestinationMinor, 100000000 - fixtureFees);
      expect(
          quote.minimumDestinationMinor, (100000000 - fixtureFees) * 99 ~/ 100);
      expect(quote.fees, hasLength(2));
      expect(quote.display!.fxType, 'indicative');
      expect(quoted.expectedDestinationMinor, quote.expectedDestinationMinor);

      final prepared = await client.deposits.prepare(session.id);
      expect(prepared.session.status, DepositStatus.prepared);
      expect(prepared.providerRouteId, startsWith('rt_'));
      expect(prepared.spender, MockTransport.depositSpenderFixture);
      final approval = prepared.approval;
      expect(approval, isA<EvmErc20ApprovalSigningRequest>());
      final erc20 = approval as EvmErc20ApprovalSigningRequest;
      expect(erc20.spender, prepared.spender);
      expect(erc20.amountMinor, '100000000'); // exact-amount, never unlimited
      expect(erc20.chainId, 8453);
      expect(prepared.transaction, isA<EvmTransactionSigningRequest>());

      final submitted = await client.deposits.reportSubmission(
        session.id,
        transactionHash: '0xabc123',
      );
      // Zero settlement latency → the mock settles synchronously.
      expect(submitted.status, DepositStatus.credited);
      expect(submitted.sourceTxHash, '0xabc123');
      expect(submitted.actualDestinationMinor, quote.expectedDestinationMinor);
      expect(submitted.creditedAt, isNotNull);
      expect(submitted.destinationTxSignature, isNotNull);

      final seen = await client.deposits
          .watch(
            session.id,
            pollInterval: const Duration(milliseconds: 5),
            timeout: const Duration(seconds: 2),
          )
          .toList();
      expect(seen, isNotEmpty);
      expect(seen.last.status, DepositStatus.credited);
      expect(seen.last.status.isTerminal, isTrue);

      final events = await client.deposits.events(session.id);
      expect(events.first.fromStatus, isNull);
      expect(events.first.toStatus, DepositStatus.created);
      expect(
        events.map((e) => e.toStatus).toList(),
        containsAllInOrder(const [
          DepositStatus.created,
          DepositStatus.quoted,
          DepositStatus.prepared,
          DepositStatus.submitted,
          DepositStatus.routing,
          DepositStatus.destinationDetected,
          DepositStatus.credited,
        ]),
      );
    });

    test('re-quote is legal until prepared and replaces the quote', () async {
      final session = await createSession(userId: 'usr_requote');
      final first = await client.deposits.getQuote(session.id);
      final second = await client.deposits.getQuote(session.id);
      expect(second.status, DepositStatus.quoted);
      expect(second.quote, isNotNull);
      expect(second.quote!.expiresAt.isBefore(first.quote!.expiresAt), isFalse);
    });

    test('compliance_hold holds the credit, releases, then credits', () async {
      final session = await createSession(userId: 'usr_hold');
      await client.deposits.getQuote(session.id);
      await client.deposits.prepare(session.id);
      await client.deposits.sendMockEvent(session.id, 'submitted');
      await client.deposits.sendMockEvent(session.id, 'settle');

      final held =
          await client.deposits.sendMockEvent(session.id, 'compliance_hold');
      expect(held.status, DepositStatus.complianceHold);
      // A hold is NOT terminal — watch keeps polling through it.
      expect(held.status.isTerminal, isFalse);

      final released =
          await client.deposits.sendMockEvent(session.id, 'compliance_release');
      expect(released.status, DepositStatus.destinationDetected);

      final credited =
          await client.deposits.sendMockEvent(session.id, 'credit');
      expect(credited.status, DepositStatus.credited);
      expect(credited.creditedAt, isNotNull);

      final events = await client.deposits.events(session.id);
      expect(
        events.map((e) => e.toStatus).toList(),
        containsAllInOrder(const [
          DepositStatus.complianceHold,
          DepositStatus.destinationDetected,
          DepositStatus.credited,
        ]),
      );
    });

    test('watch streams distinct states through a mock-event progression',
        () async {
      final session = await createSession(userId: 'usr_watch');
      await client.deposits.getQuote(session.id);
      await client.deposits.prepare(session.id);

      final statuses = <DepositStatus>[];
      final done = client.deposits
          .watch(
            session.id,
            pollInterval: const Duration(milliseconds: 10),
            timeout: const Duration(seconds: 5),
          )
          .forEach((s) => statuses.add(s.status));

      for (final scenario in const [
        'submitted',
        'routing',
        'settle',
        'compliance_hold',
        'compliance_release',
        'credit',
      ]) {
        await client.deposits.sendMockEvent(session.id, scenario);
        await Future<void>.delayed(const Duration(milliseconds: 40));
      }
      await done;

      expect(statuses.last, DepositStatus.credited);
      expect(statuses, contains(DepositStatus.complianceHold));
      // Each yielded state is distinct from its predecessor.
      for (var i = 1; i < statuses.length; i++) {
        expect(statuses[i], isNot(statuses[i - 1]));
      }
    });

    test('expired quote → prepare throws StaleQuoteException; re-quote heals',
        () async {
      final t0 = DateTime.utc(2026, 7, 17, 12);
      late String id;
      await withClock(Clock.fixed(t0), () async {
        final session = await createSession(userId: 'usr_expiry');
        id = session.id;
        final quoted = await client.deposits.getQuote(id);
        expect(quoted.quote!.isExpired(t0), isFalse);
      });
      // 5 minutes later the 2-minute fixture TTL has lapsed.
      await withClock(Clock.fixed(t0.add(const Duration(minutes: 5))),
          () async {
        await expectLater(
          client.deposits.prepare(id),
          throwsA(isA<StaleQuoteException>()),
        );
        // The session is still quotable — re-quote and prepare succeed.
        await client.deposits.getQuote(id);
        final prepared = await client.deposits.prepare(id);
        expect(prepared.session.status, DepositStatus.prepared);
      });
    });

    test('quote_expired mock scenario is a terminal failure for watch',
        () async {
      final session = await createSession(userId: 'usr_qexp');
      await client.deposits.getQuote(session.id);
      final expired =
          await client.deposits.sendMockEvent(session.id, 'quote_expired');
      expect(expired.status, DepositStatus.quoteExpired);
      expect(expired.status.isTerminal, isTrue);
      expect(expired.failureCode, 'quote_expired');

      final seen = await client.deposits
          .watch(
            session.id,
            pollInterval: const Duration(milliseconds: 5),
            timeout: const Duration(seconds: 2),
          )
          .toList();
      expect(seen.last.status, DepositStatus.quoteExpired);
    });

    test('list filters by user and pages newest first', () async {
      final a = await createSession(userId: 'usr_list');
      final b = await createSession(userId: 'usr_list');
      await createSession(userId: 'usr_other');

      final mine = await client.deposits.list(userId: 'usr_list');
      expect(mine, hasLength(2));
      expect(mine.map((s) => s.id), containsAll([a.id, b.id]));

      final firstPage =
          await client.deposits.list(userId: 'usr_list', limit: 1);
      expect(firstPage, hasLength(1));
      final secondPage = await client.deposits.list(
          userId: 'usr_list', limit: 1, startingAfter: firstPage.first.id);
      expect(secondPage, hasLength(1));
      expect(secondPage.first.id, isNot(firstPage.first.id));
    });

    test('same user gets the same deposit address across sessions', () async {
      final first = await createSession(userId: 'usr_addr');
      final second = await createSession(userId: 'usr_addr');
      final other = await createSession(userId: 'usr_addr2');
      expect(first.destinationAddress, second.destinationAddress);
      expect(first.destinationAddress, isNot(other.destinationAddress));
    });
  });

  group('DepositsResource malformed responses', () {
    test('non-session 200 body throws a typed FormatException', () async {
      final resource = DepositsResource(_StaticTransport(const PuenteResponse(
        statusCode: 200,
        headers: <String, String>{'content-type': 'application/json'},
        body: '{"unexpected": true}',
      )));
      await expectLater(
        resource.retrieve('dep_x'),
        throwsFormatException,
      );
    });

    test('prepare response without a transaction throws FormatException',
        () async {
      final resource = DepositsResource(_StaticTransport(const PuenteResponse(
        statusCode: 200,
        headers: <String, String>{'content-type': 'application/json'},
        body: '{"id":"dep_x","status":"prepared","source_amount_minor":1,'
            '"created_at":"2026-07-17T12:00:00.000Z"}',
      )));
      await expectLater(
        resource.prepare('dep_x'),
        throwsFormatException,
      );
    });
  });

  group('DepositsResource.deriveHopKey', () {
    test('derives stable per-hop keys from one base key', () {
      expect(DepositsResource.deriveHopKey('gesture-1', 'quote'),
          'gesture-1:quote');
      expect(DepositsResource.deriveHopKey('gesture-1', 'prepare'),
          'gesture-1:prepare');
    });
  });
}
