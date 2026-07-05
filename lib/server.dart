/// Server-side-only surface of the Puente Railway SDK.
///
/// ```dart
/// import 'package:puente_railway/server.dart';
/// ```
///
/// Exposes [WebhookVerifier], which authenticates inbound webhook
/// deliveries with an HMAC secret. **Webhook HMAC secrets must NEVER
/// ship in a mobile app** — anyone can extract a string from an app
/// bundle, and a leaked secret lets an attacker forge
/// `transfer.settled` events. Verify webhooks on your backend and relay
/// state to clients through your own authenticated API.
library;

export 'src/webhooks/webhook_verifier.dart';
