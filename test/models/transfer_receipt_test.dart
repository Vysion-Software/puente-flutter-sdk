import 'package:puente_railway/puente_railway.dart';
import 'package:test/test.dart';

void main() {
  group('TransferReceipt', () {
    final fullReceiptJson = <String, dynamic>{
      'transaction_id': 'b1c2d3e4-0000-4000-8000-000000000042',
      'status': 'settled',
      'transfer_type': 'cross_border',
      'currency_leg': 'CETES',
      'source_amount': {'amount': 10000, 'currency': 'USD'},
      'target_amount': {'amount': 197300, 'currency': 'MXN'},
      'fx_rate': '19.73',
      'fee_breakdown': {
        'flat_fee_minor': 100,
        'fx_spread_fee_minor': 0,
        'vendor_fee_minor': 0,
        'total_fee_minor': 100,
        'currency': 'USD',
      },
      'vendor_costs': {
        'etherfuse_minor': 12,
        'network_minor': 3,
        'other_minor': 0,
        'currency': 'USD',
      },
      'reference': 'SPEI-AB12CD',
      'memo': 'Para la familia',
      'receiver_name': 'María García López',
      'created_at': '2026-07-01T12:00:00Z',
      'settled_at': '2026-07-01T12:00:42Z',
      'cnft': {
        'folio': 'PES-000042',
        'asset_id': null,
        'metadata_uri': 'https://receipts.pesito.app/000042.json',
        'mint_signature': null,
      },
    };

    test('fromJson parses the full backend receipt', () {
      final r = TransferReceipt.fromJson(fullReceiptJson);
      expect(r.transactionId, 'b1c2d3e4-0000-4000-8000-000000000042');
      expect(r.status, TransferStatus.settled);
      expect(r.transferType, 'cross_border');
      expect(r.currencyLeg, CurrencyLeg.cetes);
      expect(r.sourceAmount, const Money.fromMinor(10000, Currency.usd));
      expect(r.targetAmount, const Money.fromMinor(197300, Currency.mxn));
      expect(r.fxRate, '19.73');
      expect(
          r.feeBreakdown!.totalFee, const Money.fromMinor(100, Currency.usd));
      expect(r.vendorCosts!.etherfuse, const Money.fromMinor(12, Currency.usd));
      expect(r.vendorCosts!.network, const Money.fromMinor(3, Currency.usd));
      expect(r.reference, 'SPEI-AB12CD');
      expect(r.memo, 'Para la familia');
      expect(r.receiverName, 'María García López');
      expect(r.createdAt, DateTime.utc(2026, 7, 1, 12));
      expect(r.settledAt, DateTime.utc(2026, 7, 1, 12, 0, 42));
      expect(r.cnft!.folio, 'PES-000042');
      expect(r.cnft!.assetId, isNull);
      expect(r.cnft!.metadataUri, 'https://receipts.pesito.app/000042.json');
      expect(r.cnft!.mintSignature, isNull);
    });

    test('fxRate stays a string — display only, never a double', () {
      final r = TransferReceipt.fromJson(fullReceiptJson);
      expect(r.fxRate, isA<String>());
    });

    test('tolerates absent optional blocks', () {
      final r = TransferReceipt.fromJson(<String, dynamic>{
        'transaction_id': 'tx_min',
        'status': 'settled',
        'transfer_type': 'p2p_same_region',
        'currency_leg': 'USDC',
        'source_amount': {'amount': 5000, 'currency': 'USD'},
        'target_amount': {'amount': 5000, 'currency': 'USD'},
        'fx_rate': '1',
        'reference': null,
        'created_at': '2026-07-01T12:00:00Z',
        'settled_at': '2026-07-01T12:00:01Z',
        'cnft': null,
      });
      expect(r.feeBreakdown, isNull);
      expect(r.vendorCosts, isNull);
      expect(r.reference, isNull);
      expect(r.memo, isNull);
      expect(r.receiverName, isNull);
      expect(r.cnft, isNull);
      expect(r.currencyLeg, CurrencyLeg.usdc);
    });

    test('unknown currency_leg degrades to CurrencyLeg.unknown', () {
      final json = Map<String, dynamic>.from(fullReceiptJson);
      json['currency_leg'] = 'FUTURE_LEG';
      expect(TransferReceipt.fromJson(json).currencyLeg, CurrencyLeg.unknown);
    });
  });

  group('ReceiptMetadata', () {
    test('fromJson parses a fully minted cNFT block', () {
      final m = ReceiptMetadata.fromJson({
        'folio': 'PES-A1B2C3',
        'asset_id': 'asset_abc',
        'metadata_uri': 'https://receipts.pesito.app/a1b2c3.json',
        'mint_signature': '5KtP…sig',
      });
      expect(m.folio, 'PES-A1B2C3');
      expect(m.assetId, 'asset_abc');
      expect(m.metadataUri, 'https://receipts.pesito.app/a1b2c3.json');
      expect(m.mintSignature, '5KtP…sig');
    });
  });
}
