import 'package:flutter_test/flutter_test.dart';
import 'package:puente_railway/puente_railway.dart';

void main() {
  test('TransferStatus enum deserialization', () {
    final jsonPending = {"id": "txn_1", "status": "pending", "created_at": "2024-01-01T00:00:00Z"};
    final jsonProcessing = {"id": "txn_2", "status": "processing", "created_at": "2024-01-01T00:00:00Z"};
    final jsonSettled = {"id": "txn_3", "status": "settled", "created_at": "2024-01-01T00:00:00Z"};
    final jsonUnknown = {"id": "txn_x", "status": "some_new_status", "created_at": "2024-01-01T00:00:00Z"};

    expect(Transfer.fromJson(jsonPending).status, TransferStatus.pending);
    expect(Transfer.fromJson(jsonProcessing).status, TransferStatus.processing);
    expect(Transfer.fromJson(jsonSettled).status, TransferStatus.settled);
    expect(Transfer.fromJson(jsonUnknown).status, TransferStatus.unknown);
  });
}
