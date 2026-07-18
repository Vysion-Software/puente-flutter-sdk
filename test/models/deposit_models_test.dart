import 'package:puente_railway/puente_railway.dart';
import 'package:test/test.dart';

void main() {
  group('DepositStatus', () {
    test('parses every wire value', () {
      const wires = <String, DepositStatus>{
        'created': DepositStatus.created,
        'quoted': DepositStatus.quoted,
        'prepared': DepositStatus.prepared,
        'submitted': DepositStatus.submitted,
        'routing': DepositStatus.routing,
        'destination_detected': DepositStatus.destinationDetected,
        'compliance_hold': DepositStatus.complianceHold,
        'credited': DepositStatus.credited,
        'sweep_pending': DepositStatus.sweepPending,
        'sweeping': DepositStatus.sweeping,
        'swept': DepositStatus.swept,
        'reconciled': DepositStatus.reconciled,
        'cancelled': DepositStatus.cancelled,
        'quote_expired': DepositStatus.quoteExpired,
        'user_rejected': DepositStatus.userRejected,
        'source_failed': DepositStatus.sourceFailed,
        'route_failed': DepositStatus.routeFailed,
        'wrong_asset': DepositStatus.wrongAsset,
        'wrong_destination': DepositStatus.wrongDestination,
        'amount_mismatch': DepositStatus.amountMismatch,
        'compliance_rejected': DepositStatus.complianceRejected,
        'manual_review': DepositStatus.manualReview,
      };
      wires.forEach((wire, status) {
        expect(DepositStatus.fromWire(wire), status);
        expect(status.wire, wire);
      });
    });

    test('unknown wire values degrade to unknown, never crash', () {
      expect(DepositStatus.fromWire('brand_new_status'), DepositStatus.unknown);
      expect(DepositStatus.fromWire(null), DepositStatus.unknown);
      expect(DepositStatus.unknown.isTerminal, isFalse);
      expect(DepositStatus.unknown.isSettled, isFalse);
      expect(DepositStatus.unknown.isFailure, isFalse);
    });

    test('settled = credited plus post-credit sweep states', () {
      expect(DepositStatus.credited.isSettled, isTrue);
      expect(DepositStatus.sweepPending.isSettled, isTrue);
      expect(DepositStatus.sweeping.isSettled, isTrue);
      expect(DepositStatus.swept.isSettled, isTrue);
      expect(DepositStatus.reconciled.isSettled, isTrue);
      expect(DepositStatus.destinationDetected.isSettled, isFalse);
      expect(DepositStatus.complianceHold.isSettled, isFalse);
    });

    test('terminal partitions: settled + failures + manual_review', () {
      // Settled states stop a watch loop.
      expect(DepositStatus.credited.isTerminal, isTrue);
      expect(DepositStatus.swept.isTerminal, isTrue);
      expect(DepositStatus.reconciled.isTerminal, isTrue);
      // Failure terminals.
      for (final s in const [
        DepositStatus.cancelled,
        DepositStatus.quoteExpired,
        DepositStatus.userRejected,
        DepositStatus.sourceFailed,
        DepositStatus.routeFailed,
        DepositStatus.wrongAsset,
        DepositStatus.wrongDestination,
        DepositStatus.amountMismatch,
        DepositStatus.complianceRejected,
      ]) {
        expect(s.isFailure, isTrue, reason: s.wire);
        expect(s.isTerminal, isTrue, reason: s.wire);
        expect(s.isSettled, isFalse, reason: s.wire);
      }
      // manual_review is terminal for polling but neither settled nor failed.
      expect(DepositStatus.manualReview.isTerminal, isTrue);
      expect(DepositStatus.manualReview.isFailure, isFalse);
      // In-flight states are not terminal — compliance_hold releases.
      for (final s in const [
        DepositStatus.created,
        DepositStatus.quoted,
        DepositStatus.prepared,
        DepositStatus.submitted,
        DepositStatus.routing,
        DepositStatus.destinationDetected,
        DepositStatus.complianceHold,
      ]) {
        expect(s.isTerminal, isFalse, reason: s.wire);
      }
    });
  });

  group('SupportedDepositAsset', () {
    final json = <String, dynamic>{
      'id': 'base:0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913',
      'network': 'base',
      'chain_id': '8453',
      'symbol': 'USDC',
      'name': 'USD Coin',
      'decimals': 6,
      'min_amount_minor': 1000000,
      'max_amount_minor': 10000000000,
      'enabled': true,
    };

    test('round-trips through JSON', () {
      final asset = SupportedDepositAsset.fromJson(json);
      expect(asset.id, 'base:0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913');
      expect(asset.network, 'base');
      expect(asset.chainId, '8453');
      expect(asset.decimals, 6);
      expect(asset.minAmountMinor, 1000000);
      expect(asset.maxAmountMinor, 10000000000);
      expect(asset.enabled, isTrue);
      expect(SupportedDepositAsset.fromJson(asset.toJson()), asset);
    });
  });

  group('PuenteSigningRequest union', () {
    test('dispatches evm_transaction', () {
      final r = PuenteSigningRequest.fromJson(<String, dynamic>{
        'type': 'evm_transaction',
        'chain_id': 8453,
        'from': '0xaaa',
        'to': '0xbbb',
        'data': '0x38ed1739',
        'value': '0',
        'gas_limit': null,
        'max_fee_per_gas': null,
        'max_priority_fee_per_gas': null,
      });
      expect(r, isA<EvmTransactionSigningRequest>());
      final tx = r as EvmTransactionSigningRequest;
      expect(tx.chainId, 8453);
      expect(tx.value, '0');
      expect(tx.gasLimit, isNull);
      expect(PuenteSigningRequest.fromJson(tx.toJson()), tx);
    });

    test('dispatches evm_erc20_approval (string amounts pass through)', () {
      final r = PuenteSigningRequest.fromJson(<String, dynamic>{
        'type': 'evm_erc20_approval',
        'chain_id': '8453',
        'token': '0xtoken',
        'spender': '0xspender',
        'amount_minor': '123456789012345678901234567890',
        'from': '0xaaa',
        'to': '0xtoken',
        'data': '0x095ea7b3',
        'value': '0',
      });
      expect(r, isA<EvmErc20ApprovalSigningRequest>());
      final approval = r as EvmErc20ApprovalSigningRequest;
      // Tolerates chain ids as strings.
      expect(approval.chainId, 8453);
      // Amount exceeds 2^63 — verbatim string passthrough, no int parse.
      expect(approval.amountMinor, '123456789012345678901234567890');
      expect(PuenteSigningRequest.fromJson(approval.toJson()), approval);
    });

    test('dispatches solana_transaction', () {
      final r = PuenteSigningRequest.fromJson(<String, dynamic>{
        'type': 'solana_transaction',
        'network': 'mainnet-beta',
        'encoding': 'base64',
        'serialized_transaction': 'AAAA',
        'required_signers': ['SignerPubkey111'],
      });
      expect(r, isA<SolanaTransactionSigningRequest>());
      final sol = r as SolanaTransactionSigningRequest;
      expect(sol.network, 'mainnet-beta');
      expect(sol.requiredSigners, ['SignerPubkey111']);
      expect(PuenteSigningRequest.fromJson(sol.toJson()), sol);
    });

    test('unknown type never throws and preserves the payload', () {
      final json = <String, dynamic>{
        'type': 'bitcoin_psbt',
        'psbt': 'cHNidP8B',
      };
      final r = PuenteSigningRequest.fromJson(json);
      expect(r, isA<UnknownSigningRequest>());
      final unknown = r as UnknownSigningRequest;
      expect(unknown.type, 'bitcoin_psbt');
      expect(unknown.payload['psbt'], 'cHNidP8B');
      expect(unknown.toJson(), json);
      // Missing type entirely also survives.
      expect(
        PuenteSigningRequest.fromJson(<String, dynamic>{'x': 1}),
        isA<UnknownSigningRequest>(),
      );
    });

    test('sealed switch is exhaustive over all variants', () {
      String describe(PuenteSigningRequest r) => switch (r) {
            EvmTransactionSigningRequest() => 'evm',
            EvmErc20ApprovalSigningRequest() => 'approval',
            SolanaTransactionSigningRequest() => 'solana',
            UnknownSigningRequest() => 'unknown',
          };
      expect(
        describe(const UnknownSigningRequest(
            type: 'x', payload: <String, dynamic>{})),
        'unknown',
      );
      expect(
        describe(const SolanaTransactionSigningRequest(
          network: 'devnet',
          encoding: 'base64',
          serializedTransaction: '',
          requiredSigners: [],
        )),
        'solana',
      );
    });
  });

  group('DepositQuote', () {
    final json = <String, dynamic>{
      'source_amount_minor': 100000000,
      'expected_destination_minor': 99650000,
      'minimum_destination_minor': 98653500,
      'fees': [
        {
          'kind': 'gas',
          'amount_minor': 100000,
          'amount_usd': '0.10',
          'label': 'Gas receiver fee',
        },
        {'kind': 'service', 'amount_usd': '0.25'},
      ],
      'total_fees_usd': '0.35',
      'expires_at': '2026-07-17T12:02:00.000Z',
      'display': {
        'currency': 'MXN',
        'estimated_credit': '1966.10',
        'fx_rate': '19.73',
        'fx_type': 'indicative',
      },
    };

    test('round-trips with fees and display estimate', () {
      final quote = DepositQuote.fromJson(json);
      expect(quote.sourceAmountMinor, 100000000);
      expect(quote.expectedDestinationMinor, 99650000);
      expect(quote.minimumDestinationMinor, 98653500);
      expect(quote.fees, hasLength(2));
      expect(quote.fees.first.amountMinor, 100000);
      expect(quote.fees.last.amountMinor, isNull);
      expect(quote.totalFeesUsd, '0.35');
      expect(quote.display!.currency, 'MXN');
      expect(quote.display!.fxRate, '19.73');
      expect(quote.display!.fxType, 'indicative');
      expect(DepositQuote.fromJson(quote.toJson()), quote);
    });

    test('isExpired is relative to the caller clock', () {
      final quote = DepositQuote.fromJson(json);
      expect(quote.isExpired(DateTime.utc(2026, 7, 17, 12, 1)), isFalse);
      expect(quote.isExpired(DateTime.utc(2026, 7, 17, 12, 2)), isTrue);
      expect(quote.isExpired(DateTime.utc(2026, 7, 17, 13)), isTrue);
    });

    test('missing amounts throw a typed FormatException', () {
      final bad = Map<String, dynamic>.from(json)
        ..remove('expected_destination_minor');
      expect(() => DepositQuote.fromJson(bad), throwsFormatException);
    });
  });

  group('DepositDisplayEstimate', () {
    test('tolerates numeric estimated_credit and missing fx fields', () {
      final estimate = DepositDisplayEstimate.fromJson(<String, dynamic>{
        'currency': 'USD',
        'estimated_credit': 99.65,
      });
      expect(estimate.estimatedCredit, '99.65');
      expect(estimate.fxRate, isNull);
      expect(estimate.fxType, 'indicative');
    });
  });

  group('DepositSession', () {
    final fullJson = <String, dynamic>{
      'id': 'dep_0123456789abcdef',
      'user_id': 'usr_42',
      'status': 'credited',
      'source_network': 'base',
      'source_asset_id': 'base:0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913',
      'source_token': '0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913',
      'source_token_decimals': 6,
      'source_wallet_address': '0xUserWallet',
      'source_amount_minor': 100000000,
      'destination_network': 'solana',
      'destination_mint': 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v',
      'destination_address': 'DepositAddr1111111111111111111111111111111',
      'expected_destination_minor': 99650000,
      'minimum_destination_minor': 98653500,
      'actual_destination_minor': 99650000,
      'quote': {
        'source_amount_minor': 100000000,
        'expected_destination_minor': 99650000,
        'minimum_destination_minor': 98653500,
        'fees': [
          {'kind': 'service', 'amount_usd': '0.35', 'label': 'Service fee'},
        ],
        'total_fees_usd': '0.35',
        'expires_at': '2026-07-17T12:02:00.000Z',
      },
      'provider_route_id': 'rt_abc123',
      'spender': '0x1111111111111111111111111111111111111111',
      'approval': {
        'type': 'evm_erc20_approval',
        'chain_id': 8453,
        'token': '0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913',
        'spender': '0x1111111111111111111111111111111111111111',
        'amount_minor': '100000000',
        'from': '0xUserWallet',
        'to': '0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913',
        'data': '0x095ea7b3',
        'value': '0',
      },
      'transaction': {
        'type': 'evm_transaction',
        'chain_id': 8453,
        'from': '0xUserWallet',
        'to': '0x1111111111111111111111111111111111111111',
        'data': '0x38ed1739',
        'value': '0',
        'gas_limit': null,
        'max_fee_per_gas': null,
        'max_priority_fee_per_gas': null,
      },
      'source_tx_hash': '0xdeadbeef',
      'destination_tx_signature': 'mockSig123',
      'failure_code': null,
      'failure_details': null,
      'display_currency': 'MXN',
      'display_estimate': {
        'currency': 'MXN',
        'estimated_credit': '1966.10',
        'fx_rate': '19.73',
        'fx_type': 'indicative',
      },
      'created_at': '2026-07-17T12:00:00.000Z',
      'updated_at': '2026-07-17T12:05:00.000Z',
      'submitted_at': '2026-07-17T12:01:00.000Z',
      'detected_at': '2026-07-17T12:03:00.000Z',
      'confirmed_at': '2026-07-17T12:04:00.000Z',
      'credited_at': '2026-07-17T12:05:00.000Z',
      'swept_at': null,
      'reconciled_at': null,
    };

    test('parses every wire field and round-trips', () {
      final session = DepositSession.fromJson(fullJson);
      expect(session.id, 'dep_0123456789abcdef');
      expect(session.userId, 'usr_42');
      expect(session.status, DepositStatus.credited);
      expect(session.sourceNetwork, 'base');
      expect(session.sourceTokenDecimals, 6);
      expect(session.sourceAmountMinor, 100000000);
      expect(session.destinationNetwork, 'solana');
      expect(session.destinationMint,
          'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v');
      expect(session.expectedDestinationMinor, 99650000);
      expect(session.actualDestinationMinor, 99650000);
      expect(session.quote, isNotNull);
      expect(session.quote!.totalFeesUsd, '0.35');
      expect(session.providerRouteId, 'rt_abc123');
      expect(session.spender, '0x1111111111111111111111111111111111111111');
      expect(session.approval, isA<EvmErc20ApprovalSigningRequest>());
      expect(session.transaction, isA<EvmTransactionSigningRequest>());
      expect(session.sourceTxHash, '0xdeadbeef');
      expect(session.destinationTxSignature, 'mockSig123');
      expect(session.displayEstimate!.fxType, 'indicative');
      expect(session.createdAt, DateTime.utc(2026, 7, 17, 12));
      expect(session.creditedAt, DateTime.utc(2026, 7, 17, 12, 5));
      expect(session.sweptAt, isNull);
      expect(DepositSession.fromJson(session.toJson()), session);
    });

    test('parses a minimal created session', () {
      final session = DepositSession.fromJson(<String, dynamic>{
        'id': 'dep_min',
        'status': 'created',
        'source_amount_minor': 5000000,
        'created_at': '2026-07-17T12:00:00.000Z',
      });
      expect(session.status, DepositStatus.created);
      expect(session.quote, isNull);
      expect(session.approval, isNull);
      expect(session.failureCode, isNull);
    });

    test('carries failure_code on failure terminals', () {
      final session = DepositSession.fromJson(<String, dynamic>{
        'id': 'dep_fail',
        'status': 'route_failed',
        'source_amount_minor': 5000000,
        'failure_code': 'route_failed',
        'failure_details': 'provider route failed',
        'created_at': '2026-07-17T12:00:00.000Z',
      });
      expect(session.status, DepositStatus.routeFailed);
      expect(session.status.isFailure, isTrue);
      expect(session.failureCode, 'route_failed');
    });

    test('malformed payloads throw typed FormatException', () {
      expect(
        () => DepositSession.fromJson(<String, dynamic>{'unexpected': true}),
        throwsFormatException,
      );
      expect(
        () => DepositSession.fromJson(<String, dynamic>{
          'id': 'dep_x',
          'status': 'created',
          'source_amount_minor': 1,
        }),
        throwsFormatException, // missing created_at
      );
      expect(
        () => DepositSession.fromJson(<String, dynamic>{
          'id': 'dep_x',
          'status': 'created',
          'source_amount_minor': '1', // string, not int
          'created_at': '2026-07-17T12:00:00.000Z',
        }),
        throwsFormatException,
      );
    });

    test('unknown status on the wire degrades to unknown', () {
      final session = DepositSession.fromJson(<String, dynamic>{
        'id': 'dep_new',
        'status': 'quantum_settled',
        'source_amount_minor': 1,
        'created_at': '2026-07-17T12:00:00.000Z',
      });
      expect(session.status, DepositStatus.unknown);
    });
  });

  group('PreparedDeposit', () {
    test('exposes typed approval, transaction, and spender', () {
      final prepared = PreparedDeposit.fromJson(<String, dynamic>{
        'id': 'dep_prep',
        'status': 'prepared',
        'source_amount_minor': 100000000,
        'created_at': '2026-07-17T12:00:00.000Z',
        'provider_route_id': 'rt_1',
        'spender': '0x1111111111111111111111111111111111111111',
        'approval': {
          'type': 'evm_erc20_approval',
          'chain_id': 8453,
          'token': '0xt',
          'spender': '0x1111111111111111111111111111111111111111',
          'amount_minor': '100000000',
          'from': '0xu',
          'to': '0xt',
          'data': '0x095ea7b3',
          'value': '0',
        },
        'transaction': {
          'type': 'evm_transaction',
          'chain_id': 8453,
          'from': '0xu',
          'to': '0x1111111111111111111111111111111111111111',
          'data': '0x38ed1739',
          'value': '0',
        },
      });
      expect(prepared.session.status, DepositStatus.prepared);
      expect(prepared.approval, isA<EvmErc20ApprovalSigningRequest>());
      expect(prepared.transaction, isA<EvmTransactionSigningRequest>());
      expect(prepared.spender, '0x1111111111111111111111111111111111111111');
      expect(prepared.providerRouteId, 'rt_1');
    });

    test('approval is optional (allowance already sufficient)', () {
      final prepared = PreparedDeposit.fromJson(<String, dynamic>{
        'id': 'dep_prep2',
        'status': 'prepared',
        'source_amount_minor': 100000000,
        'created_at': '2026-07-17T12:00:00.000Z',
        'transaction': {
          'type': 'evm_transaction',
          'chain_id': 8453,
          'from': '0xu',
          'to': '0xr',
          'data': '0x38ed1739',
          'value': '0',
        },
      });
      expect(prepared.approval, isNull);
    });

    test('missing transaction throws FormatException', () {
      expect(
        () => PreparedDeposit.fromJson(<String, dynamic>{
          'id': 'dep_prep3',
          'status': 'prepared',
          'source_amount_minor': 100000000,
          'created_at': '2026-07-17T12:00:00.000Z',
        }),
        throwsFormatException,
      );
    });
  });

  group('DepositEvent', () {
    test('round-trips, including null from_status on the creation event', () {
      final creation = DepositEvent.fromJson(<String, dynamic>{
        'from_status': null,
        'to_status': 'created',
        'actor': 'client',
        'detail': null,
        'created_at': '2026-07-17T12:00:00.000Z',
      });
      expect(creation.fromStatus, isNull);
      expect(creation.toStatus, DepositStatus.created);
      expect(DepositEvent.fromJson(creation.toJson()), creation);

      final transition = DepositEvent.fromJson(<String, dynamic>{
        'from_status': 'routing',
        'to_status': 'destination_detected',
        'actor': 'worker',
        'detail': {'commitment': 'confirmed'},
        'created_at': '2026-07-17T12:03:00.000Z',
      });
      expect(transition.fromStatus, DepositStatus.routing);
      expect(transition.detail, {'commitment': 'confirmed'});
      expect(DepositEvent.fromJson(transition.toJson()), transition);
    });
  });
}
