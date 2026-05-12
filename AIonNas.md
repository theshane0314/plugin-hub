# AIonNAS — Session resume state

Last touched: 2026-05-12. Active project: self-hosted services on TrueNAS (`LilNasX` @ `192.168.0.3`) fronted by Cloudflare Tunnel + Cloudflare Access + Workers at `plaincandle.dev`.

---

## Handoff for the next Claude Code session (2026-05-12)

Tasks 2, 3, 4, 5, 6 are **done**. Task 1 (OIDC SSO) is **not started** — it's the only remaining item.

What's committed on branch `claude/start-aionnas-docs-3TDDe` of `theshane0314/plugin-hub`:
- `AIonNas.md` — this doc (TrueNAS API key redacted; check `C:\Users\Shane-PC\plaincandle\.env` for the real value).
- `aionnas/fix-oi-flash.sh` — task #2, ran and worked.
- `aionnas/flame-svg-route.js` — original drop-in snippet for task #4 (now superseded by the script below, kept for reference).
- `aionnas/finish-flame-migration.sh` — task #4, two-phase script (dry-run by default, `--commit` to execute). Details under task 4 below.

What the previous session couldn't do from its sandbox, which a new session with broader access (mounted Windows drive, browser MCP, or TrueNAS network reach) should be able to:
- Read `C:\Users\Shane-PC\plaincandle\landing-worker\worker.js` directly to confirm the handler shape before patching.
- Drive the Cloudflare dashboard (e.g., for the token edit in task #5 — already completed manually).
- Reach `plaincandle-home.pages.dev`, `*.plaincandle.dev`, and `192.168.0.3` for verification / API calls.

Pick up by reading the "Pending items" section below — start with whichever is shortest given your session's capabilities. Task #4 just needs someone to run the script. Task #1 is the big remaining piece of work.

---

## TL;DR what's live right now

- **`plaincandle.dev`** — Worker `plaincandle-landing`. Dark dashboard with cards filtered by what each user has access to. Sign-out button (top-right) → CF Access logout → returns to homepage.
- **`admin.plaincandle.dev`** — Worker `plaincandle-admin`. Admin panel for managing users (add/remove, role toggle, per-user subdomain access). Only admins (currently me) can reach it.
- **`ai.plaincandle.dev`** — Open WebUI on TrueNAS via Cloudflare Tunnel.
- **`seerr.plaincandle.dev`** — Seerr v3.2.0 on TrueNAS via Cloudflare Tunnel.
- All four behind Cloudflare Access with **MFA required** (TOTP or biometrics). Identity = email OTP (one-time PIN).

## How the user data flows
- KV namespace `plaincandle-users` (id `428b71f577fd4677bf123024e7218e76`) is source of truth.
- Schema: key = `email_lowercase` → JSON `{ role: "admin"|"basic", subdomains: ["ai","seerr","admin","plaincandle"], added, updated }`.
- Admin Worker writes KV on every change, then calls `rebuildAllPolicies()` to sync each Access app's `plaincandle-managed` policy with the right email list.
- Each app additionally keeps the original `owner-only` reusable policy (just my email) as a break-glass.

## Critical bug fixed this session
- KV originally stored my key as `Theshane0314@gmail.com` (capital T) but the Workers lowercase emails on lookup → my admin record was invisible → "account does not have access" after sign-out.
- Fixed: re-seeded under `theshane0314@gmail.com` (lowercase), deleted the capital-T entry. Architecture going forward: always store and look up emails lowercase.

## Cloudflare account, zone, app, KV IDs
- Account ID: `3287d50d1583b22223859ab5ec3262ff`
- Zone (`plaincandle.dev`): `70626f5bc46960e98445116cd2d753a4`
- KV: `428b71f577fd4677bf123024e7218e76`
- Access apps:
  - `plaincandle.dev` (landing): `a89735bc-9085-4b3f-87be-045e0e376bc3`
  - `admin.plaincandle.dev`: `408e0631-435d-4ace-9634-5e846074cc32`
  - `ai.plaincandle.dev`: `923cdebf-9787-4c81-9524-5dc301bedd42`
  - `seerr.plaincandle.dev`: `286ec55a-98fa-4eda-bb85-101deac6ef8d`
- Reusable policy `owner-only`: `440f1475-e14c-4511-a47a-ed1b5523415e`
- Token + IDs also stored at `C:\Users\Shane-PC\plaincandle\.env`.

## Worker source paths
- Admin: `C:\Users\Shane-PC\plaincandle\admin-worker\worker.js`
- Landing: `C:\Users\Shane-PC\plaincandle\landing-worker\worker.js`
- Summary doc: `C:\Users\Shane-PC\plaincandle\SUMMARY.md`

## Deploy command pattern
```
source /c/Users/Shane-PC/plaincandle/.env
cd /c/Users/Shane-PC/plaincandle/<worker>
curl -s -X PUT "https://api.cloudflare.com/client/v4/accounts/$ACCT/workers/scripts/<name>" \
  -H "Authorization: Bearer $TOKEN" \
  -F "metadata=@C:/Users/Shane-PC/AppData/Local/Temp/<meta>.json;type=application/json" \
  -F "worker.js=@worker.js;type=application/javascript+module"
```
Bash on Windows needs **Windows-style paths** (`C:/...`) for `-F @file` to read; POSIX-style fails silently with "Failed to open/read local data".

## TrueNAS state
- Now on TrueNAS SCALE 25.10.3 (rolled back off 26.0 BETA).
- REST API works again at `/api/v2.0/`.
- API key: `<REDACTED — see .env locally>` (works as of 2026-05-12).
- Apps state confirmed running last check: seerr, overseerr, open-webui, ollama, hexos, sonarr, sabnzbd, requestrr, radarr, plex, cloudflare. Stopped: portainer.
- The `cloudflare` (cloudflared tunnel) app spontaneously stopped at one point this session — caused 1033 errors on `ai`/`seerr`. Restarted via `app.start ["cloudflare"]`. If it happens again, that's the first thing to check.

## Seerr state
- Migrated from Overseerr. Old Overseerr DB had schema drift (missing `jellyfinUsername` column on `user` table) → SQLite errors → seerr container crashlooped.
- Resolved by wiping `db.sqlite3*` and `settings.json`, letting Seerr regenerate. All Overseerr data (requests, users) is lost; settings backed up as `db.sqlite3.overseerr-bak` in the seerr config dir.
- Manually flipped `main.initialized` and `public.initialized` to `true` in `settings.json` because the setup wizard hung at "Finishing...".
- Plex sign-in works. Radarr/Sonarr not yet added.

## Login customizations
- Org-level login design: dark background `#0f0f0f`, header "plaincandle.dev", footer "private infrastructure", logo = candle flame SVG hosted at `https://plaincandle-home.pages.dev/flame.svg`.
- Removed `text_color` override after it made the OTP input field invisible (white-on-white).
- The white card containing email/OTP inputs is hardcoded by Cloudflare — not customizable without building a custom IdP.

## Sign-out flow
- Hits `/cdn-cgi/access/logout?returnTo=https%3A%2F%2Fplaincandle.dev%2F` — kills CF Access session, returns user to landing page where re-auth is triggered. Sign-out itself has never required a password; the CF Access logout endpoint just invalidates the cookie.

## Mobile layout
- Landing + admin workers both have `@media (max-width: 640px)` and `(max-width: 380px)` rules. Topbar wraps, email truncates to ellipsis (hidden under 380px), table converts to stacked cards on the admin panel, font sizes drop, padding shrinks.

---

## Pending items to pick up next session

### 1. OIDC SSO between landing → Seerr (started, not done)
User asked: clicking the Seerr card on the landing should sign them straight into Seerr, no second login.

Plan (option 1 from my earlier analysis):
- Configure Cloudflare Access as an OIDC identity provider
- Configure Seerr to accept OIDC sign-in (need to confirm Seerr v3.2.0 supports OIDC — Jellyseerr fork added it, Seerr fork may have it too)
- Map CF Access email → Seerr user

If Seerr doesn't support OIDC natively, fallback is **option 3** (Worker pre-auth proxy):
- Worker on a Seerr-fronting path reads CF Access identity, calls Seerr API with admin API key to mint a session cookie, sets cookie, redirects to Seerr UI.

### 2. Fix "OI" loading flash on `ai.plaincandle.dev` when unauth'd — DONE 2026-05-12
- Resolved by `aionnas/fix-oi-flash.sh`: GETs each of the 4 Access apps, merges `auto_redirect_to_identity: true` and `skip_interstitial: true`, PUTs the full body back. Confirmed working — flash gone.
- If it ever regresses, the fallback is still: Cache Rule `Cache-Control: no-store` on `ai.plaincandle.dev`, or unregister the Open WebUI service worker.

### 3. Add Radarr/Sonarr to Seerr — DONE 2026-05-12
- Both *arr servers connected to Seerr via its settings UI.

### 4. Old `plaincandle-home` Pages project cleanup — DONE 2026-05-12
- Ran `aionnas/finish-flame-migration.sh` on the Windows box (dry-run → diff looked clean → `--commit`).
- Module-worker shape detected; patched `landing-worker/worker.js` to serve `/flame.svg` (720-byte SVG embedded as template literal). Backup at `worker.js.before-flame-migration.1778618033`.
- Worker deployed. Sibling Access app `flame-svg-public` (id `5d2816e9-fecb-4548-9e03-aa09797bee73`) created on `plaincandle.dev/flame.svg` with `bypass-everyone` policy so the SVG is reachable pre-auth.
- Org-level `login_design.logo_path` updated to `https://plaincandle.dev/flame.svg`. Verified HTTP 200, 720 bytes.
- `plaincandle-home` Pages project deleted.
- Gotchas hit (record for future scripts touching org settings):
  - `jq` was missing on the Windows bash — installed binary to `C:\Users\Shane-PC\bin\jq.exe`.
  - The PUT to `/access/organizations` requires the **full** org body merged with edits, not just the changed sub-object — minimum kept fields: `auth_domain`, `name`, `login_design`, `is_ui_read_only`, `allow_authenticate_via_warp`, `deny_unmatched_requests`, **and `mfa_config`** (omitting `mfa_config` triggers `access.api.error.mfa_authenticator_in_use` 12169 because the API treats absence as "remove authenticators" and the owner-only policy uses TOTP/biometrics).
  - The script aborted at the deploy step on the first run (jq missing); the worker was already swapped+deployed by then. Verified live worker has the `BEGIN flame.svg migration` header before continuing, then ran the remaining steps manually.
- Earlier route snippet (`aionnas/flame-svg-route.js`) and the script remain in `aionnas/` for reference.

### 5. API token Pages permission missing — DONE 2026-05-12
- `plaincandle-admin` token edited via dashboard to add `Account → Cloudflare Pages → Edit`. Now has Workers + Access + KV + DNS + Pages:Edit. Can be used to script the `plaincandle-home` Pages deletion once #4 ships.

### 6. Phone push notifications — DONE 2026-05-12
- Restarted Claude Code without `ANTHROPIC_API_KEY`, OAuth login, phone paired.

## What I'd verify first next session
1. `https://plaincandle.dev/` returns 200 after a real sign-in
2. `https://admin.plaincandle.dev/` shows the admin panel
3. KV still has just `theshane0314@gmail.com`
4. cloudflared tunnel on TrueNAS is RUNNING
