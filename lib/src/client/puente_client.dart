import 'package:http/http.dart' as http;
import '../http/interceptors/auth_interceptor.dart';
import '../http/interceptors/retry_interceptor.dart';
import '../http/puente_http_client.dart';
import '../resources/accounts_resource.dart';
import '../resources/clabe_resource.dart';
import '../resources/quotes_resource.dart';
import '../resources/transfers_resource.dart';
import 'puente_config.dart';

class PuenteClient {
  final PuenteConfig config;
  late final PuenteHttpClient _httpClient;
  late final QuotesResource quotes;
  late final TransfersResource transfers;
  late final AccountsResource accounts;
  late final ClabeResource clabe;

  PuenteClient({
    required String apiKey,
    PuenteEnvironment environment = PuenteEnvironment.production,
    Duration timeout = const Duration(seconds: 30),
    http.Client? innerClient,
  }) : config = PuenteConfig(
          apiKey: apiKey,
          environment: environment,
          timeout: timeout,
        ) {
    final baseClient = innerClient ?? http.Client();
    final authClient = AuthInterceptor(baseClient, config.apiKey);
    final retryClient = RetryInterceptor(authClient);
    
    _httpClient = PuenteHttpClient(
      client: retryClient,
      baseUrl: config.baseUrl,
      timeout: config.timeout,
    );

    quotes = QuotesResource(_httpClient);
    transfers = TransfersResource(_httpClient);
    accounts = AccountsResource(_httpClient);
    clabe = ClabeResource(_httpClient);
  }

  void close() {
    _httpClient.close();
  }
}
