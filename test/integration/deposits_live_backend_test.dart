/// Live wire-parity integration test for the **external-wallet deposits
/// client** against a REAL running Puente backend (`VENDOR_MODE=mock`,
/// `DEPOSITS_ENABLED=true`).
///
/// Walks the exact `infra/docker/smoke.sh` deposit lifecycle through the
/// SDK — assets → session → quote → prepare → submission →
/// `settle_finalized` → credited → events/list — plus the stable failure
/// shapes (`unsupported_asset`, `deposit_not_found`, `quote_required`),
/// asserting every typed field the SDK models against the live wire.
///
/// ## Gating
///
/// Runs ONLY when `PUENTE_LIVE_URL` (and `PUENTE_LIVE_API_KEY`) are
/// provided — via real environment variables or `-D` defines. Skipped
/// otherwise with setup instructions, so `dart test` needs no backend.
///
/// ## How to run (local backend)
///
/// ```sh
/// # 1. In the Puente repo: postgres up + seeded (repo compose), then
/// #    start the API with DATABASE_URL pointing at the compose
/// #    postgres (see the Puente repo's .env.example for the local
/// #    connection string — host port 55432):
/// PUENTE_ENV=local VENDOR_MODE=mock DEPOSITS_ENABLED=true PORT=8091 \
///   DEPOSIT_ALLOWED_SOURCE_ASSETS='base:0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913:USDC:6' \
///   cargo run -p puente-api
///
/// # 2. In this repo:
/// PUENTE_LIVE_URL=http://127.0.0.1:8091/v1 \
///   PUENTE_LIVE_API_KEY=sk_it_localtest_0123456789abcdef \
///   dart test test/integration/deposits_live_backend_test.dart
/// ```
///
/// (`sk_it_localtest_…` is the documented public local-test seed key —
/// not a secret.)
library;

import 'dart:io';

import 'package:puente_railway/puente_railway.dart';
import 'package:test/test.dart';

const String _kSkipReason = '''
PUENTE_LIVE_URL not set — live deposits walk skipped.

To run against a local Puente backend:
  1. Boot postgres from the Puente repo compose (seeded local-test data,
     host port 55432).
  2. Start the API in mock mode with deposits enabled (DATABASE_URL from
     the Puente repo's .env.example, pointed at the compose postgres):
     PUENTE_ENV=local VENDOR_MODE=mock DEPOSITS_ENABLED=true PORT=8091 \\
       DEPOSIT_ALLOWED_SOURCE_ASSETS='base:0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913:USDC:6' \\
       cargo run -p puente-api
  3. Run:
     PUENTE_LIVE_URL=http://127.0.0.1:8091/v1 \\
       PUENTE_LIVE_API_KEY=sk_it_localtest_0123456789abcdef \\
       dart test test/integration/deposits_live_backend_test.dart
''';

String _env(String name) =>
    Platform.environment[name] ??
    String.fromEnvironment(name, defaultValue: '');

void main() {
  final liveUrl = _env('PUENTE_LIVE_URL');
  final apiKey = _env('PUENTE_LIVE_API_KEY');

  group('Live backend deposits walk', () {
    late PuenteClient client;

    setUpAll(() {
      client = PuenteClient(
        config: PuenteConfig(
          apiKey: apiKey,
          environment: PuenteEnvironment.testnet,
          baseUrlOverride: Uri.parse(liveUrl),
          // Fail fast in a test run — a wrong URL should not retry 3×.
          maxRetries: 1,
        ),
      );
    });

    tearDownAll(() => client.close());

    test('full happy path: assets → … → settle_finalized → credited', () async {
      // ── assets allowlist ─────────────────────────────────────────
      final assets = await client.deposits.getSupportedAssets();
      expect(assets, isNotEmpty,
          reason: 'DEPOSIT_ALLOWED_SOURCE_ASSETS must list ≥1 asset');
      final asset = assets.firstWhere((a) => a.enabled);
      expect(asset.id, contains(':'));
      expect(asset.network, isNotEmpty);
      expect(asset.decimals, greaterThan(0));
      expect(asset.minAmountMinor, greaterThan(0));
      expect(asset.maxAmountMinor, greaterThan(asset.minAmountMinor));

      // ── create session ───────────────────────────────────────────
      // Unique per-run user + amount keep the deterministic mock
      // provider's route identity fresh across repeated runs against
      // the same database.
      final runTag = DateTime.now().millisecondsSinceEpoch;
      final userId = 'sdk_live_$runTag';
      final amountMinor = asset.minAmountMinor + 1000000 + (runTag % 50000000);
      const wallet = '0x2222222222222222222222222222222222222222';

      final baseKey = 'sdk-live-$runTag';
      final session = await client.deposits.createSession(
        userId: userId,
        sourceNetwork: asset.network,
        sourceAssetId: asset.id,
        sourceWalletAddress: wallet,
        sourceAmountMinor: amountMinor,
        displayCurrency: 'USD',
        idempotencyKey: DepositsResource.deriveHopKey(baseKey, 'create'),
      );
      expect(session.id, startsWith('dep_'));
      expect(session.status, DepositStatus.created);
      expect(session.userId, userId);
      expect(session.provider, isNotNull);
      expect(session.riskStatus, 'none');
      expect(session.sourceNetwork, asset.network);
      expect(session.sourceAssetId, asset.id);
      expect(session.sourceWalletAddress, wallet);
      expect(session.sourceAmountMinor, amountMinor);
      expect(session.destinationNetwork, 'solana');
      expect(session.destinationMint, isNotNull);
      expect(session.destinationAddress!.length, greaterThan(20));
      expect(session.quote, isNull);
      expect(session.ledgerTransactionId, isNull);

      // ── retrieve echoes create ───────────────────────────────────
      final fetched = await client.deposits.retrieve(session.id);
      expect(fetched.id, session.id);
      expect(fetched.status, DepositStatus.created);
      expect(fetched.destinationAddress, session.destinationAddress);

      // ── quote ────────────────────────────────────────────────────
      final quoted = await client.deposits.getQuote(
        session.id,
        idempotencyKey: DepositsResource.deriveHopKey(baseKey, 'quote'),
      );
      expect(quoted.status, DepositStatus.quoted);
      final quote = quoted.quote!;
      expect(quote.sourceAmountMinor, amountMinor);
      expect(quote.expectedDestinationMinor, greaterThan(0));
      expect(quote.minimumDestinationMinor,
          lessThanOrEqualTo(quote.expectedDestinationMinor));
      expect(quote.fees, isNotEmpty);
      for (final fee in quote.fees) {
        expect(fee.kind, isNotEmpty);
        expect(fee.amountUsd, isNotEmpty);
      }
      expect(quote.totalFeesUsd, isNotEmpty);
      expect(quote.isExpired(DateTime.now().toUtc()), isFalse,
          reason: 'backend TTL must be in the future at quote time');
      // USD display estimate: 1:1 minor units, labeled indicative.
      final display = quote.display!;
      expect(display.currency, 'USD');
      expect(display.estimatedCreditMinor, quote.expectedDestinationMinor);
      expect(display.fxType, 'indicative');

      // ── prepare: typed signing handoff ───────────────────────────
      final prepared = await client.deposits.prepare(
        session.id,
        idempotencyKey: DepositsResource.deriveHopKey(baseKey, 'prepare'),
      );
      expect(prepared.session.status, DepositStatus.prepared);
      expect(prepared.providerRouteId, isNotNull);
      expect(prepared.providerRouteId, isNotEmpty);
      final tx = prepared.transaction;
      expect(tx, isA<EvmTransactionSigningRequest>());
      final evmTx = tx as EvmTransactionSigningRequest;
      expect(evmTx.chainId, greaterThan(0));
      expect(evmTx.from.toLowerCase(), wallet.toLowerCase());
      expect(evmTx.to, startsWith('0x'));
      expect(evmTx.data, startsWith('0x'));
      expect(int.tryParse(evmTx.value), isNotNull,
          reason: 'value is a decimal string');
      // ERC-20 source ⇒ exact-amount approval present.
      final approval = prepared.approval;
      expect(approval, isA<EvmErc20ApprovalSigningRequest>());
      final erc20 = approval as EvmErc20ApprovalSigningRequest;
      expect(erc20.amountMinor, '$amountMinor',
          reason: 'exact-amount approval, never unlimited');
      expect(erc20.spender, prepared.spender);
      expect(erc20.token.toLowerCase(),
          prepared.session.sourceToken!.toLowerCase());

      // ── submission (hash is a hint) ──────────────────────────────
      final submitted = await client.deposits.reportSubmission(
        session.id,
        transactionHash: 'sdklive$runTag',
        idempotencyKey: DepositsResource.deriveHopKey(baseKey, 'submission'),
      );
      expect(submitted.status, DepositStatus.submitted);
      expect(submitted.sourceTxHash, 'sdklive$runTag');
      expect(submitted.submittedAt, isNotNull);

      // ── settle_finalized → credited ──────────────────────────────
      await client.deposits.sendMockEvent(session.id, 'settle_finalized');
      final credited = await client.deposits
          .watch(
            session.id,
            pollInterval: const Duration(milliseconds: 500),
            timeout: const Duration(seconds: 30),
          )
          .last;
      expect(credited.status, DepositStatus.credited);
      expect(credited.ledgerTransactionId, isNotNull,
          reason: 'the ledger credit is the settlement proof');
      expect(credited.actualDestinationMinor, quote.expectedDestinationMinor,
          reason: 'the mock settles exactly the quoted amount');
      expect(credited.creditedAt, isNotNull);
      expect(credited.detectedAt, isNotNull);
      expect(credited.confirmedAt, isNotNull);
      expect(credited.destinationTxSignature, isNotNull);
      expect(credited.status.isTerminal, isTrue);

      // ── events audit trail ───────────────────────────────────────
      final events = await client.deposits.events(session.id);
      expect(events, isNotEmpty);
      expect(events.first.fromStatus, DepositStatus.created);
      expect(events.first.toStatus, DepositStatus.quoted);
      expect(events.last.toStatus, DepositStatus.credited);
      for (final event in events) {
        expect(event.toStatus, isNot(DepositStatus.unknown),
            reason: 'every wire status must parse');
      }

      // ── listing ──────────────────────────────────────────────────
      final mine = await client.deposits.list(userId: userId);
      expect(mine.map((s) => s.id), contains(session.id));
      final credit = mine.firstWhere((s) => s.id == session.id);
      expect(credit.status, DepositStatus.credited);
    });

    test('failure shapes: unsupported_asset / not_found / quote_required',
        () async {
      // 422 unsupported_asset.
      await expectLater(
        client.deposits.createSession(
          userId: 'sdk_live_err',
          sourceNetwork: 'base',
          sourceAssetId: 'base:0x000000000000000000000000000000000000dead',
          sourceWalletAddress: '0x2222222222222222222222222222222222222222',
          sourceAmountMinor: 5000000,
        ),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 422)
            .having((e) => e.code, 'code', 'unsupported_asset')),
      );

      // 404 deposit_not_found.
      await expectLater(
        client.deposits.retrieve('dep_00000000000000000000000000000000'),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 404)
            .having((e) => e.code, 'code', 'deposit_not_found')),
      );

      // 409 quote_required (prepare before quoting).
      final runTag = DateTime.now().millisecondsSinceEpoch;
      final bare = await client.deposits.createSession(
        userId: 'sdk_live_noq_$runTag',
        sourceNetwork: 'base',
        sourceAssetId: 'base:0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913',
        sourceWalletAddress: '0x2222222222222222222222222222222222222222',
        sourceAmountMinor: 2000000 + (runTag % 1000000),
      );
      await expectLater(
        client.deposits.prepare(bare.id),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 409)
            .having((e) => e.code, 'code', 'quote_required')),
      );
    });
  },
      skip: liveUrl.isEmpty ? _kSkipReason : false,
      timeout: const Timeout(Duration(minutes: 2)));
}
