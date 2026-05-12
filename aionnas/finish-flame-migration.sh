#!/usr/bin/env bash
# Task #4 — finish the flame.svg migration off the dormant plaincandle-home
# Pages project. Run on the Windows box (bash) with the existing .env sourced.
#
# Two-phase by design:
#   phase 1 (default):  bash aionnas/finish-flame-migration.sh
#       Fetches flame.svg, generates landing-worker/worker.patched.js, prints a
#       diff hint. NOTHING is deployed or mutated in Cloudflare. Inspect the
#       result, then re-run with --commit.
#   phase 2:            bash aionnas/finish-flame-migration.sh --commit
#       Replaces worker.js with the patched version (backup kept), deploys,
#       adds a path-scoped sibling Access app for /flame.svg with a
#       Bypass=Everyone policy, updates the org-level login logo, verifies
#       the new URL, and deletes the plaincandle-home Pages project.
#
# Required env (source plaincandle/.env):
#   TOKEN   Cloudflare API token (must have Pages:Edit as of task #5)
#   ACCT    Cloudflare account id
#
# Optional env:
#   LANDING_DIR    default /c/Users/Shane-PC/plaincandle/landing-worker
#   META_FILE      worker upload metadata json (default: temp file we generate)

set -euo pipefail

COMMIT=false
[[ "${1:-}" == "--commit" ]] && COMMIT=true

: "${TOKEN:?TOKEN env var required (source plaincandle/.env)}"
: "${ACCT:?ACCT env var required}"

LANDING_DIR="${LANDING_DIR:-/c/Users/Shane-PC/plaincandle/landing-worker}"
WORKER_JS="$LANDING_DIR/worker.js"
PATCHED_JS="$LANDING_DIR/worker.patched.js"
LANDING_APP_ID="a89735bc-9085-4b3f-87be-045e0e376bc3"
ZONE_ID="70626f5bc46960e98445116cd2d753a4"
OLD_LOGO="https://plaincandle-home.pages.dev/flame.svg"
NEW_LOGO="https://plaincandle.dev/flame.svg"

if [[ ! -f "$WORKER_JS" ]]; then
  echo "ERROR: $WORKER_JS not found. Set LANDING_DIR." >&2
  exit 1
fi

log()  { printf '==> %s\n' "$*"; }
sub()  { printf '    %s\n' "$*"; }
warn() { printf '!!  %s\n' "$*" >&2; }

# -------------------------------------------------------------------------
# Phase 1: fetch SVG, generate patched worker.js
# -------------------------------------------------------------------------

log "fetching $OLD_LOGO"
SVG_RAW=$(curl -fsS "$OLD_LOGO")
sub "${#SVG_RAW} bytes"

# Escape backticks and ${} for safe inclusion in a JS template literal.
SVG_ESCAPED=$(printf '%s' "$SVG_RAW" | sed -e 's/\\/\\\\/g' -e 's/`/\\`/g' -e 's/\${/\\${/g')

log "generating $PATCHED_JS"
SHAPE=""
if grep -qE 'async[[:space:]]+fetch[[:space:]]*\(' "$WORKER_JS"; then
  SHAPE="module"
  sub "detected module-worker shape (async fetch(...))"
elif grep -qE "addEventListener\(\s*['\"]fetch['\"]" "$WORKER_JS"; then
  SHAPE="sw"
  sub "detected service-worker shape (addEventListener('fetch', ...))"
else
  warn "could not detect worker shape. Aborting before any changes."
  warn "Inspect $WORKER_JS and either add the maybeServeFlame call manually,"
  warn "or update this script to recognize your handler."
  exit 1
fi

if grep -q 'maybeServeFlame' "$WORKER_JS"; then
  warn "$WORKER_JS already contains maybeServeFlame — nothing to patch."
  warn "If you want to re-run, restore from the .before-flame backup first."
  exit 1
fi

HEADER=$(cat <<EOF
// --- BEGIN flame.svg migration (task #4 of AIonNas.md) ---
const FLAME_SVG = \`${SVG_ESCAPED}\`;
function maybeServeFlame(request) {
  const url = new URL(request.url);
  if (url.pathname !== "/flame.svg") return null;
  return new Response(FLAME_SVG, {
    headers: {
      "content-type": "image/svg+xml; charset=utf-8",
      "cache-control": "public, max-age=86400, immutable",
    },
  });
}
// --- END flame.svg migration ---
EOF
)

# Prepend the header, then inject the early-return into the handler.
{
  printf '%s\n\n' "$HEADER"
  if [[ "$SHAPE" == "module" ]]; then
    awk '
      !done && /async[[:space:]]+fetch[[:space:]]*\(/ {
        print
        print "    { const __flame = maybeServeFlame(request); if (__flame) return __flame; }"
        done = 1
        next
      }
      { print }
    ' "$WORKER_JS"
  else
    awk '
      !done && /addEventListener\(\s*["'\'']fetch["'\'']/ {
        print
        # The handler typically takes (event) — pull request from event.
        print "  { const __flameReq = event.request; const __flame = maybeServeFlame(__flameReq); if (__flame) { event.respondWith(__flame); return; } }"
        done = 1
        next
      }
      { print }
    ' "$WORKER_JS"
  fi
} > "$PATCHED_JS"

if ! grep -q 'maybeServeFlame(' "$PATCHED_JS"; then
  warn "patched file is missing the maybeServeFlame call — bailing."
  rm -f "$PATCHED_JS"
  exit 1
fi

sub "wrote $PATCHED_JS"

if ! $COMMIT; then
  cat <<EOF

Dry-run complete. Inspect with:
  diff "$WORKER_JS" "$PATCHED_JS" | head -60

If the diff looks right, re-run with --commit:
  bash $0 --commit

EOF
  exit 0
fi

# -------------------------------------------------------------------------
# Phase 2 (--commit): replace, deploy, configure CF, verify, delete Pages
# -------------------------------------------------------------------------

log "backing up worker.js and swapping in patched"
BACKUP="$WORKER_JS.before-flame-migration.$(date +%s)"
cp "$WORKER_JS" "$BACKUP"
mv "$PATCHED_JS" "$WORKER_JS"
sub "backup: $BACKUP"

log "deploying plaincandle-landing"
TMP_META=$(mktemp --suffix=.json)
cat > "$TMP_META" <<'EOF'
{"main_module":"worker.js","compatibility_date":"2024-10-01"}
EOF
META_WIN="$(cygpath -w "$TMP_META" 2>/dev/null || echo "$TMP_META")"
WORKER_WIN="$(cygpath -w "$WORKER_JS" 2>/dev/null || echo "$WORKER_JS")"

DEPLOY_RESP=$(curl -fsS -X PUT \
  "https://api.cloudflare.com/client/v4/accounts/$ACCT/workers/scripts/plaincandle-landing" \
  -H "Authorization: Bearer $TOKEN" \
  -F "metadata=@$META_WIN;type=application/json" \
  -F "worker.js=@$WORKER_WIN;type=application/javascript+module")
jq '{success, errors}' <<<"$DEPLOY_RESP"
[[ "$(jq -r .success <<<"$DEPLOY_RESP")" == "true" ]] || { warn "deploy failed"; exit 1; }

log "creating sibling Access app for /flame.svg (Bypass=Everyone)"
# Check if a flame-svg app already exists.
EXISTING_APPS=$(curl -fsS \
  -H "Authorization: Bearer $TOKEN" \
  "https://api.cloudflare.com/client/v4/accounts/$ACCT/access/apps?per_page=100")
FLAME_APP_ID=$(jq -r '.result[] | select(.domain=="plaincandle.dev/flame.svg") | .id' <<<"$EXISTING_APPS")

if [[ -z "$FLAME_APP_ID" ]]; then
  CREATE_RESP=$(curl -fsS -X POST \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    --data '{
      "name": "flame-svg-public",
      "domain": "plaincandle.dev/flame.svg",
      "type": "self_hosted",
      "session_duration": "24h"
    }' \
    "https://api.cloudflare.com/client/v4/accounts/$ACCT/access/apps")
  FLAME_APP_ID=$(jq -r '.result.id' <<<"$CREATE_RESP")
  sub "created app $FLAME_APP_ID"
else
  sub "app already exists ($FLAME_APP_ID)"
fi

EXISTING_POLICIES=$(curl -fsS \
  -H "Authorization: Bearer $TOKEN" \
  "https://api.cloudflare.com/client/v4/accounts/$ACCT/access/apps/$FLAME_APP_ID/policies")
if jq -e '.result[] | select(.name=="bypass-everyone")' <<<"$EXISTING_POLICIES" > /dev/null; then
  sub "bypass policy already present"
else
  curl -fsS -X POST \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    --data '{
      "name": "bypass-everyone",
      "decision": "bypass",
      "include": [{"everyone": {}}],
      "precedence": 1
    }' \
    "https://api.cloudflare.com/client/v4/accounts/$ACCT/access/apps/$FLAME_APP_ID/policies" \
    | jq '{success, errors, result:{id, name, decision}}'
fi

log "updating org-level login design logo URL"
ZT_CFG=$(curl -fsS \
  -H "Authorization: Bearer $TOKEN" \
  "https://api.cloudflare.com/client/v4/accounts/$ACCT/access/organizations")
LOGIN_DESIGN=$(jq '.result.login_design' <<<"$ZT_CFG")
if [[ "$LOGIN_DESIGN" == "null" || -z "$LOGIN_DESIGN" ]]; then
  warn "no login_design block returned — set the logo URL manually under"
  warn "Zero Trust → Settings → Custom Pages, then continue."
else
  NEW_DESIGN=$(jq --arg url "$NEW_LOGO" '.logo_path = $url' <<<"$LOGIN_DESIGN")
  PUT_RESP=$(curl -fsS -X PUT \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    --data "{\"login_design\": $NEW_DESIGN}" \
    "https://api.cloudflare.com/client/v4/accounts/$ACCT/access/organizations")
  jq '{success, errors, logo:.result.login_design.logo_path}' <<<"$PUT_RESP"
fi

log "verifying $NEW_LOGO"
sleep 3
HTTP=$(curl -sS -o /tmp/flame.fetched -w '%{http_code}' "$NEW_LOGO" || true)
sub "HTTP $HTTP, $(wc -c </tmp/flame.fetched) bytes"
if [[ "$HTTP" != "200" ]]; then
  warn "expected 200 — the bypass policy may not have propagated. Wait ~30s and curl again."
  warn "NOT deleting the Pages project yet. Re-run with --commit after verifying manually."
  exit 1
fi

log "deleting plaincandle-home Pages project"
# Look up the project by name.
PAGES_LIST=$(curl -fsS \
  -H "Authorization: Bearer $TOKEN" \
  "https://api.cloudflare.com/client/v4/accounts/$ACCT/pages/projects?per_page=100")
PAGES_PROJECT_NAME=$(jq -r '.result[] | select(.name=="plaincandle-home") | .name' <<<"$PAGES_LIST")
if [[ -z "$PAGES_PROJECT_NAME" ]]; then
  sub "no plaincandle-home Pages project found — already deleted?"
else
  DEL_RESP=$(curl -fsS -X DELETE \
    -H "Authorization: Bearer $TOKEN" \
    "https://api.cloudflare.com/client/v4/accounts/$ACCT/pages/projects/plaincandle-home")
  jq '{success, errors}' <<<"$DEL_RESP"
fi

echo
log "done"
sub "verify in a private window: https://plaincandle.dev/ → sign-out → sign-in → the flame should render above the white card."
