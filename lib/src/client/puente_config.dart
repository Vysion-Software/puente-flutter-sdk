enum PuenteEnvironment {
  sandbox,
  production,
}

class PuenteConfig {
  final String apiKey;
  final PuenteEnvironment environment;
  final Duration timeout;

  const PuenteConfig({
    required this.apiKey,
    this.environment = PuenteEnvironment.production,
    this.timeout = const Duration(seconds: 30),
  });

  String get baseUrl {
    switch (environment) {
      case PuenteEnvironment.sandbox:
        return 'https://sandbox.api.puenterailway.com/v1';
      case PuenteEnvironment.production:
        return 'https://api.puenterailway.com/v1';
    }
  }
}
