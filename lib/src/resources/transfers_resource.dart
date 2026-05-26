import '../http/puente_http_client.dart';
import '../models/transfer.dart';

class TransfersResource {
  final PuenteHttpClient _client;

  TransfersResource(this._client);

  Future<Transfer> create({
    required String quoteId,
    required String senderAccountId,
    required String receiverClabe,
    required String receiverName,
    String? memo,
  }) async {
    final response = await _client.post(
      '/transfers',
      body: {
        'quote_id': quoteId,
        'sender_account_id': senderAccountId,
        'receiver_clabe': receiverClabe,
        'receiver_name': receiverName,
        if (memo != null) 'memo': memo,
      },
    );
    return Transfer.fromJson(response);
  }

  Future<Transfer> retrieve(String id) async {
    final response = await _client.get('/transfers/$id');
    return Transfer.fromJson(response);
  }

  Future<List<Transfer>> list({int limit = 20, String? startingAfter}) async {
    final queryParams = {
      'limit': limit.toString(),
      if (startingAfter != null) 'starting_after': startingAfter,
    };
    final response = await _client.get('/transfers', query: queryParams);
    final data = response['data'] as List;
    return data.map((e) => Transfer.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> cancel(String id) async {
    await _client.post('/transfers/$id/cancel');
  }
}
