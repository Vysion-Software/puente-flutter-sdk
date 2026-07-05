/// The settlement leg the Puente treasury routed a movement through.
///
/// Reported by the backend on quotes and receipts (`"currency_leg"`) so the
/// client can *display* which rail carried the funds. The SDK never chooses
/// or computes a leg — routing is a backend treasury decision.
///
/// Wire format is the UPPERCASE ticker. Unknown values map to
/// [CurrencyLeg.unknown] so a server-side extension doesn't crash older
/// clients (same convention as `TransferStatus`).
enum CurrencyLeg {
  /// SPL USDC leg (same-region and USD-denominated hops).
  usdc('USDC'),

  /// Ondo US Dollar Yield leg (yield-bearing USD treasury hold).
  ousd('OUSD'),

  /// Etherfuse CETES stablebond leg (MXN-denominated settlement).
  cetes('CETES'),

  /// Wire format not recognized by this SDK build.
  unknown('unknown');

  /// JSON wire value.
  final String wire;

  const CurrencyLeg(this.wire);

  /// Parse a wire value into the enum, defaulting to [unknown] on miss.
  /// Forward-compatible: new backend legs never throw on old clients.
  static CurrencyLeg fromWire(String? value) {
    if (value == null) return CurrencyLeg.unknown;
    for (final leg in CurrencyLeg.values) {
      if (leg.wire == value) return leg;
    }
    return CurrencyLeg.unknown;
  }
}
