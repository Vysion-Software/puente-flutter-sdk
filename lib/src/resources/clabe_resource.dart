import '../http/puente_http_client.dart';
import '../models/clabe_info.dart';

class ClabeResource {
  final PuenteHttpClient _client;

  ClabeResource(this._client);

  Future<ClabeInfo> lookup(String clabe) async {
    final response = await _client.get('/clabe/$clabe');
    return ClabeInfo.fromJson(response);
  }
}
