#!/usr/bin/env bash
# SRS FR-9 — no-secrets client audit for the puente_railway SDK.
#
# Policy: this package is a typed API client. It must never contain secrets,
# credentials, fee/FX math, or direct vendor calls. This script enforces the
# *secrets* half of that boundary in two layers:
#
#   1. Appendix-A term PRESENCE is reported for auditability but never fails
#      the build — the SDK legitimately mentions vendor names in doc comments
#      and has a webhook-verifier parameter named `secret`.
#   2. VALUE-SHAPED secrets (things that look like real keys, tokens,
#      connection strings, PEM blocks, or seed phrases) hard-fail with exit 1.
#
# Allowlisted false positives (filters use the exact *quoted* literal so a
# longer real key sharing the prefix is NOT masked):
#   - 'whsec_test_secret'  deterministic HMAC fixture in
#                          test/webhooks/webhook_verifier_test.dart; a
#                          documented test literal, not a credential.
#   - 'sk_live_x'          one-char placeholder in
#                          test/client/puente_config_test.dart asserting that
#                          PuenteConfig plumbs apiKey through; real keys are
#                          far longer and would still be caught.
# Known benign term presence (informational layer only, never fails):
#   - `secret` param in lib/src/webhooks/webhook_verifier.dart — the HMAC
#     verifier's *input name*; callers supply the value at runtime.
#   - COLUMN — the Flutter `Column` widget in example/.
#   - ETHERFUSE / BRALE / etc. — vendor names in doc comments and model
#     docs; no URLs or credentials.
set -euo pipefail

cd "$(cd "$(dirname "$0")/.." && pwd)"

# Skip VCS/build dirs and binaries. The scanner also excludes itself: its own
# pattern definitions and term list would inflate the presence counts (this
# file is code-reviewed like any other).
EXCLUDES="--exclude-dir=.git --exclude-dir=.dart_tool --exclude-dir=build \
  --exclude-dir=coverage --exclude=no_secrets_audit.sh"

scan() { # scan <extra-grep-flags-or-empty> <ERE> -> file:line hits, exits 0
  # shellcheck disable=SC2086  # EXCLUDES/$1 are intentionally word-split
  grep -rEIn $1 $EXCLUDES -e "$2" . 2>/dev/null || true
}

TERMS="API_KEY PRIVATE_KEY MNEMONIC SECRET TURNKEY COLUMN BRALE ETHERFUSE \
  PAYNEARME POMELO DATABASE_URL SOLANA_RPC"

echo "== SRS Appendix-A term presence (informational — does NOT fail CI) =="
printf '%-14s %s\n' "TERM" "HITS"
for term in $TERMS; do
  # shellcheck disable=SC2086
  count=$( (grep -roEIi $EXCLUDES -e "$term" . 2>/dev/null || true) \
    | wc -l | tr -d ' ')
  printf '%-14s %s\n' "$term" "$count"
done
echo

FAILURES=0

check() { # check <label> <extra-grep-flags-or-empty> <ERE> [allow-literal...]
  local label="$1" flags="$2" regex="$3" hits allow
  shift 3
  hits=$(scan "$flags" "$regex")
  # Mask allowlisted literals IN PLACE and re-grep the residue — dropping
  # whole lines would let a real secret hide next to a fixture on the
  # same line.
  if [ "$#" -gt 0 ] && [ -n "$hits" ]; then
    for allow in "$@"; do
      hits=$(printf '%s\n' "$hits" | sed "s|${allow}|ALLOWLISTED|g")
    done
    # shellcheck disable=SC2086
    hits=$(printf '%s\n' "$hits" | grep -EI $flags -- "$regex" || true)
  fi
  hits=$(printf '%s\n' "$hits" | sed '/^$/d')
  if [ -n "$hits" ]; then
    FAILURES=$((FAILURES + 1))
    echo "FAIL [$label]"
    printf '%s\n' "$hits" | sed 's/^/    /'
  else
    echo "ok   [$label]"
  fi
}

echo "== Value-shaped secret checks (any hit fails the build) =="

check "stripe-style live key sk_live_*" "" \
  'sk_live_[A-Za-z0-9]+' "'sk_live_x'"
# {2,} (not {2}) so this repo's own sk_testnet_<random> format is caught too.
check "sk_<env>_<16+ chars> API key" "" \
  'sk_[a-z]{2,}_[A-Za-z0-9]{16,}'
# Underscore included in the class so real whsec_ values (and the fixture)
# match; the fixture is then allowlisted by its exact quoted literal.
check "webhook signing secret whsec_*" "" \
  'whsec_[A-Za-z0-9_]{8,}' "'whsec_test_secret'"
check "AWS access key id" "" \
  'AKIA[0-9A-Z]{16}'
check "PEM private key block" "" \
  '-----BEGIN( RSA| EC)? PRIVATE KEY-----'
check "Google API key" "" \
  'AIza[0-9A-Za-z_-]{35}'
check "Slack token" "" \
  'xox[baprs]-'
check "postgres connection string" "" \
  'postgres(ql)?://'
# 12+ lowercase 3-8 letter words inside one quoted string ~= a BIP39 seed
# phrase; quoting keeps ordinary prose in docs from tripping this.
check "mnemonic-looking quoted phrase" "" \
  "['\"]([a-z]{3,8} ){11,}[a-z]{3,8}['\"]"
# Any Appendix-A term assigned a non-trivial quoted literal value.
check "Appendix-A term with assigned literal" "-i" \
  "(API_KEY|PRIVATE_KEY|MNEMONIC|SECRET|TURNKEY|COLUMN|BRALE|ETHERFUSE|PAYNEARME|POMELO|DATABASE_URL|SOLANA_RPC)[[:space:]]*[:=][[:space:]]*['\"][A-Za-z0-9_-]{16,}" \
  "'whsec_test_secret'"

echo
if [ "$FAILURES" -gt 0 ]; then
  echo "no_secrets_audit: FAILED — $FAILURES check(s) found value-shaped secrets."
  exit 1
fi
echo "no_secrets_audit: PASS — no value-shaped secrets detected."
