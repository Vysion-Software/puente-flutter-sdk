/// Which Puente Railway deployment the SDK should talk to.
///
/// * [mock] — no network. All requests are served by an in-memory
///   [MockTransport]. Use for unit tests and offline demos.
/// * [testnet] — Puente devnet target. The on-chain leg hits Solana devnet
///   via Helius; fiat off-ramp hits Etherfuse sandbox.
/// * [sandbox] — staging environment, hosted somewhere stable (no real
///   funds, but a real database + real Etherfuse sandbox).
/// * [production] — real money, real CETES, real SPEI.
enum PuenteEnvironment {
  /// In-memory mock. No HTTP traffic. Default for `PuenteClient.mock()`.
  mock,

  /// Puente devnet (`https://api-testnet.puenterailway.com/v1`).
  testnet,

  /// Sandbox (`https://api-sandbox.puenterailway.com/v1`).
  sandbox,

  /// Production (`https://api.puenterailway.com/v1`).
  production,
}

/// Immutable configuration for a [PuenteClient].
///
/// Construct via [PuenteConfig.new] when you want to set every option, or
/// the [PuenteConfig.testnet] / [PuenteConfig.sandbox] / [PuenteConfig.production]
/// helpers for the common cases.
class PuenteConfig {
  /// API key Puente issued to this merchant. Sent as
  /// `Authorization: Bearer <key>` on every authenticated request.
  ///
  /// May be empty in [PuenteEnvironment.mock]; required everywhere else.
  final String apiKey;

  /// Optional merchant identifier. When set, sent as
  /// `X-Puente-Merchant-Id` so the server can scope rate limits and
  /// audit logs per merchant.
  final String? merchantId;

  /// Which deployment to target. Drives [baseUrl].
  final PuenteEnvironment environment;

  /// Override the resolved base URL. Useful for pointing at a local
  /// `puente-api` during development (`http://127.0.0.1:8080/v1`).
  ///
  /// When `null`, the URL is derived from [environment].
  final Uri? baseUrlOverride;

  /// Per-request timeout. Applied to the entire request — connect +
  /// send + receive.
  final Duration timeout;

  /// Maximum retry attempts on a transport error or `429` / `5xx`
  /// response. `0` disables retries. Defaults to 3.
  final int maxRetries;

  /// Base delay for exponential backoff between retries. Actual delay is
  /// `baseRetryDelay * 2^(attempt - 1) ± jitter`.
  final Duration baseRetryDelay;

  /// Maximum delay between retries (caps the exponential growth).
  final Duration maxRetryDelay;

  /// SDK identifier echoed in the `User-Agent` and `X-SDK-Version`
  /// headers. Defaults to the package version.
  final String userAgent;

  /// Build a [PuenteConfig] with explicit values.
  const PuenteConfig({
    required this.apiKey,
    required this.environment,
    this.merchantId,
    this.baseUrlOverride,
    this.timeout = const Duration(seconds: 30),
    this.maxRetries = 3,
    this.baseRetryDelay = const Duration(milliseconds: 500),
    this.maxRetryDelay = const Duration(seconds: 10),
    this.userAgent = 'puente_railway/$packageVersion',
  });

  /// Convenience for an in-memory mock client.
  factory PuenteConfig.mock({
    String apiKey = 'sk_mock',
    String? merchantId,
  }) =>
      PuenteConfig(
        apiKey: apiKey,
        merchantId: merchantId,
        environment: PuenteEnvironment.mock,
      );

  /// Convenience for the Puente devnet (testnet).
  factory PuenteConfig.testnet({
    required String apiKey,
    String? merchantId,
    Uri? baseUrlOverride,
  }) =>
      PuenteConfig(
        apiKey: apiKey,
        merchantId: merchantId,
        environment: PuenteEnvironment.testnet,
        baseUrlOverride: baseUrlOverride,
      );

  /// Convenience for the sandbox environment.
  factory PuenteConfig.sandbox({
    required String apiKey,
    String? merchantId,
  }) =>
      PuenteConfig(
        apiKey: apiKey,
        merchantId: merchantId,
        environment: PuenteEnvironment.sandbox,
      );

  /// Convenience for the production environment.
  factory PuenteConfig.production({
    required String apiKey,
    String? merchantId,
  }) =>
      PuenteConfig(
        apiKey: apiKey,
        merchantId: merchantId,
        environment: PuenteEnvironment.production,
      );

  /// Effective base URL the HTTP transport should hit.
  ///
  /// Order of resolution: [baseUrlOverride] wins if set; otherwise we
  /// derive from [environment]. [PuenteEnvironment.mock] returns a
  /// sentinel value that the [HttpTransport] never uses (the mock
  /// transport doesn't hit the network).
  Uri get baseUrl {
    if (baseUrlOverride != null) return baseUrlOverride!;
    switch (environment) {
      case PuenteEnvironment.mock:
        return Uri.parse('mock://puente');
      case PuenteEnvironment.testnet:
        return Uri.parse('https://api-testnet.puenterailway.com/v1');
      case PuenteEnvironment.sandbox:
        return Uri.parse('https://api-sandbox.puenterailway.com/v1');
      case PuenteEnvironment.production:
        return Uri.parse('https://api.puenterailway.com/v1');
    }
  }
}

/// Current SDK package version, mirrored from pubspec.yaml. Bump on
/// release; CI checks the two are in sync.
const String packageVersion = '0.2.0';
