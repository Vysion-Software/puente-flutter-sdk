/// Lifecycle states of an external-wallet deposit session — the
/// `deposit_intents.status` state machine in Puente
/// (`docs/deposits-external-wallet-design.md`):
///
/// ```
/// created → quoted → prepared → submitted → routing → destination_detected
///         → compliance_hold? → credited → sweep_pending → sweeping → swept
///         → reconciled
/// ```
///
/// Wire format is snake_case strings. Unknown values map to
/// [DepositStatus.unknown] so a server-side status extension never crashes
/// an older client.
enum DepositStatus {
  /// Session created; deposit address assigned; no quote yet.
  created('created'),

  /// A route quote is attached. Re-quoting (`quoted → quoted`) is legal
  /// until the session is prepared.
  quoted('quoted'),

  /// Signing requests were built; the route is locked to a provider.
  prepared('prepared'),

  /// The user's wallet broadcast the source transaction (client-reported
  /// hash; the server verifies independently).
  submitted('submitted'),

  /// The routing provider is bridging/swapping toward Solana USDC.
  routing('routing'),

  /// USDC arrived at the user's Puente deposit address (detected at
  /// `confirmed` commitment; credit waits for `finalized`).
  destinationDetected('destination_detected'),

  /// Compliance review is holding the credit. Not terminal — the hold can
  /// be released (→ [credited]) or rejected (→ [complianceRejected]).
  complianceHold('compliance_hold'),

  /// The customer's ledger balance was credited. Terminal for the
  /// customer — everything after this is internal treasury movement.
  credited('credited'),

  /// Post-credit: sweep to the pooled treasury is queued. Internal.
  sweepPending('sweep_pending'),

  /// Post-credit: sweep transaction is in flight. Internal.
  sweeping('sweeping'),

  /// Post-credit: funds swept into the pooled treasury. Internal.
  swept('swept'),

  /// Post-credit: reconciliation confirmed the books match. Internal.
  reconciled('reconciled'),

  /// Terminal: the user (or an operator) cancelled before submission.
  cancelled('cancelled'),

  /// Terminal: the quote lapsed before the route was prepared/funded.
  quoteExpired('quote_expired'),

  /// Terminal: the user declined to sign in their wallet.
  userRejected('user_rejected'),

  /// Terminal: the source-chain transaction failed or reverted.
  sourceFailed('source_failed'),

  /// Terminal: the routing provider failed the route (refund to source
  /// initiated when funds had moved).
  routeFailed('route_failed'),

  /// Terminal: a different asset than expected arrived at the deposit
  /// address. Routed to manual handling.
  wrongAsset('wrong_asset'),

  /// Terminal: funds landed somewhere other than the assigned address.
  wrongDestination('wrong_destination'),

  /// Terminal: settled amount doesn't match the quote (under/over) —
  /// manual handling.
  amountMismatch('amount_mismatch'),

  /// Terminal: compliance rejected the deposit.
  complianceRejected('compliance_rejected'),

  /// Terminal for polling: an operator must act before anything changes.
  manualReview('manual_review'),

  /// Wire value not recognized by this SDK build.
  unknown('unknown');

  /// JSON wire value.
  final String wire;

  const DepositStatus(this.wire);

  /// Parse a wire value into the enum, defaulting to [unknown] on miss —
  /// a new backend status must never crash a deployed app.
  static DepositStatus fromWire(String? value) {
    if (value == null) return DepositStatus.unknown;
    for (final s in DepositStatus.values) {
      if (s.wire == value) return s;
    }
    return DepositStatus.unknown;
  }

  /// True once the customer's balance has been credited. The sweep states
  /// ([sweepPending], [sweeping], [swept], [reconciled]) are post-credit
  /// internal treasury movements — from the customer's point of view the
  /// deposit settled at [credited] and never regresses.
  bool get isSettled =>
      this == DepositStatus.credited ||
      this == DepositStatus.sweepPending ||
      this == DepositStatus.sweeping ||
      this == DepositStatus.swept ||
      this == DepositStatus.reconciled;

  /// True for the failure terminals — the deposit will not credit.
  bool get isFailure =>
      this == DepositStatus.cancelled ||
      this == DepositStatus.quoteExpired ||
      this == DepositStatus.userRejected ||
      this == DepositStatus.sourceFailed ||
      this == DepositStatus.routeFailed ||
      this == DepositStatus.wrongAsset ||
      this == DepositStatus.wrongDestination ||
      this == DepositStatus.amountMismatch ||
      this == DepositStatus.complianceRejected;

  /// Terminal for a customer-facing poll loop (`DepositsResource.watch`):
  /// settled states ([isSettled]), failure states ([isFailure]), and
  /// [manualReview] (an operator must act — polling won't observe
  /// progress). [complianceHold] is NOT terminal: holds release.
  bool get isTerminal => isSettled || isFailure || this == manualReview;
}
