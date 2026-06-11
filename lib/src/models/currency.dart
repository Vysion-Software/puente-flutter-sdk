/// Currencies the Puente Railway ledger tracks.
///
/// Mirrors `puente_core::Currency` in the Rust workspace. Values are wired
/// as UPPERCASE strings (`"USD"`, `"MXN"`, `"USDC"`, `"CETES"`, `"SOL"`) on
/// the JSON boundary so the Dart SDK and Rust server stay in sync without a
/// schema translation layer.
///
/// **Minor units.** Every monetary amount in this SDK is an integer count of
/// minor units. The number of decimal places per currency lives on the enum
/// itself ([decimals]) so a `Money` value is always self-describing — no
/// outside table required to format it.
enum Currency {
  /// US dollars. 2 decimals (cents).
  usd('USD', 2),

  /// Mexican pesos. 2 decimals (centavos).
  mxn('MXN', 2),

  /// SPL USDC on Solana. 6 decimals.
  usdc('USDC', 6),

  /// Etherfuse-issued CETES stablebond on Solana. 6 decimals, yield-bearing.
  cetes('CETES', 6),

  /// Native SOL. 9 decimals (lamports).
  sol('SOL', 9);

  /// Wire-format ISO/ticker string sent over the JSON boundary.
  final String code;

  /// Number of decimal places used by the **minor unit** the ledger stores.
  final int decimals;

  const Currency(this.code, this.decimals);

  /// Parse a wire-format currency code into the enum. Case-insensitive.
  ///
  /// Throws [ArgumentError] if the code is not recognized. Callers that
  /// need a soft-fail path should catch and map to their own fallback.
  static Currency fromCode(String code) {
    final upper = code.toUpperCase();
    for (final c in Currency.values) {
      if (c.code == upper) return c;
    }
    throw ArgumentError.value(code, 'code', 'unknown currency');
  }

  /// Parse a wire-format currency code, returning `null` on miss.
  static Currency? tryFromCode(String? code) {
    if (code == null) return null;
    try {
      return Currency.fromCode(code);
    } on ArgumentError {
      return null;
    }
  }

  /// 10^[decimals] — the scale factor between minor and major units.
  ///
  /// Returned as `int` (safe for all five currencies — max is 10^9 which
  /// fits comfortably in a signed 64-bit int).
  int get scale {
    var s = 1;
    for (var i = 0; i < decimals; i++) {
      s *= 10;
    }
    return s;
  }
}
