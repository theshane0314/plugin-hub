#!/usr/bin/env bash
# Task #2 from AIonNas.md — fix the "OI" loading flash on ai.plaincandle.dev
# (and apply the same flags to the other three Access apps for consistency).
#
# Strategy: for each Cloudflare Access app, GET the full app object, merge in
# `auto_redirect_to_identity: true` and `skip_interstitial: true`, and PUT the
# full body back. The earlier attempt failed because PUT requires the entire
# app body, not just the changed fields.
#
# Usage:
#   source /c/Users/Shane-PC/plaincandle/.env   # exports TOKEN, ACCT
#   bash aionnas/fix-oi-flash.sh
#
# Requires: bash, curl, jq.

set -euo pipefail

: "${TOKEN:?TOKEN env var required (source .env first)}"
: "${ACCT:?ACCT env var required (source .env first)}"

declare -A APPS=(
  [plaincandle.dev]=a89735bc-9085-4b3f-87be-045e0e376bc3
  [admin.plaincandle.dev]=408e0631-435d-4ace-9634-5e846074cc32
  [ai.plaincandle.dev]=923cdebf-9787-4c81-9524-5dc301bedd42
  [seerr.plaincandle.dev]=286ec55a-98fa-4eda-bb85-101deac6ef8d
)

API="https://api.cloudflare.com/client/v4/accounts/$ACCT/access/apps"

for name in "${!APPS[@]}"; do
  id="${APPS[$name]}"
  echo "==> $name ($id)"

  current=$(curl -fsS \
    -H "Authorization: Bearer $TOKEN" \
    "$API/$id")

  if [[ "$(jq -r '.success' <<<"$current")" != "true" ]]; then
    echo "    GET failed:" >&2
    jq '.errors' <<<"$current" >&2
    exit 1
  fi

  body=$(jq '.result
    | .auto_redirect_to_identity = true
    | .skip_interstitial = true' <<<"$current")

  resp=$(curl -fsS -X PUT \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    --data "$body" \
    "$API/$id")

  if [[ "$(jq -r '.success' <<<"$resp")" != "true" ]]; then
    echo "    PUT failed:" >&2
    jq '.errors' <<<"$resp" >&2
    exit 1
  fi

  jq -r '"    ok  auto_redirect_to_identity=\(.result.auto_redirect_to_identity)  skip_interstitial=\(.result.skip_interstitial)"' <<<"$resp"
done

echo
echo "Done. Verify by visiting https://ai.plaincandle.dev/ in a private window"
echo "while signed out — the 'OI' flash should be gone (CF Access intercepts"
echo "immediately instead of letting the Open WebUI shell render first)."
