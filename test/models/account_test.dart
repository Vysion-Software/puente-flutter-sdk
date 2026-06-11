import 'package:puente_railway/puente_railway.dart';
import 'package:test/test.dart';

void main() {
  group('KycTier', () {
    test('wire round-trip', () {
      for (final t in KycTier.values) {
        expect(KycTier.fromWire(t.wire), t);
      }
    });

    test('unknown wire value defaults to none', () {
      expect(KycTier.fromWire('vip'), KycTier.none);
      expect(KycTier.fromWire(null), KycTier.none);
    });
  });

  group('Account', () {
    test('fromJson parses a full doc + displayName helper', () {
      final a = Account.fromJson({
        'id': 'acct_1',
        'first_name': 'Maria',
        'last_name': 'Garcia',
        'email': 'maria@example.com',
        'phone': '+525555555555',
        'kyc_tier': 'tier1',
        'created_at': '2026-01-01T00:00:00Z',
      });
      expect(a.id, 'acct_1');
      expect(a.displayName, 'Maria Garcia');
      expect(a.kycTier, KycTier.tier1);
      expect(a.createdAt.isUtc, isTrue);
    });

    test('fromJson tolerates missing created_at + kyc_tier', () {
      final a = Account.fromJson({
        'id': 'acct_2',
        'first_name': 'X',
        'last_name': 'Y',
        'email': 'x@y',
        'phone': '+1',
      });
      expect(a.kycTier, KycTier.none);
      expect(a.createdAt.millisecondsSinceEpoch, 0);
    });
  });

  group('ClabeInfo', () {
    test('fromJson + props', () {
      final c = ClabeInfo.fromJson({
        'clabe': '012180012345678901',
        'bank_name': 'BBVA México',
        'bank_code': '012',
        'valid': true,
      });
      expect(c.bankCode, '012');
      expect(c.valid, isTrue);
    });

    test('valid defaults to false', () {
      final c = ClabeInfo.fromJson({
        'clabe': '000180012345678901',
        'bank_name': 'Unknown Bank',
        'bank_code': '000',
      });
      expect(c.valid, isFalse);
    });
  });
}
