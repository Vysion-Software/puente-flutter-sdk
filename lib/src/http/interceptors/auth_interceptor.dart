import 'package:http/http.dart' as http;

class AuthInterceptor extends http.BaseClient {
  final http.Client _inner;
  final String _apiKey;
  final String _sdkVersion = '0.1.0';

  AuthInterceptor(this._inner, this._apiKey);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = 'Bearer $_apiKey';
    request.headers['Content-Type'] = 'application/json';
    request.headers['Accept'] = 'application/json';
    request.headers['X-SDK-Version'] = _sdkVersion;
    return _inner.send(request);
  }
}
