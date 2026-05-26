import '../http/puente_http_client.dart';
import '../models/account.dart';

class AccountsResource {
  final PuenteHttpClient _client;

  AccountsResource(this._client);

  Future<Account> create({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required DateTime dateOfBirth,
    required String addressLine1,
    required String city,
    required String state,
    required String postalCode,
    required String country,
  }) async {
    final response = await _client.post(
      '/accounts',
      body: {
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'phone': phone,
        'date_of_birth': dateOfBirth.toIso8601String().split('T').first,
        'address_line_1': addressLine1,
        'city': city,
        'state': state,
        'postal_code': postalCode,
        'country': country,
      },
    );
    return Account.fromJson(response);
  }

  Future<Account> retrieve(String id) async {
    final response = await _client.get('/accounts/$id');
    return Account.fromJson(response);
  }

  Future<Account> update(String id, {String? phone}) async {
    final response = await _client.patch(
      '/accounts/$id',
      body: {
        if (phone != null) 'phone': phone,
      },
    );
    return Account.fromJson(response);
  }
}
