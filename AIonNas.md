# AIonNAS — Session resume state

Last touched: 2026-05-12. Active project: self-hosted services on TrueNAS (`LilNasX` @ `192.168.0.3`) fronted by Cloudflare Tunnel + Cloudflare Access + Workers at `plaincandle.dev`.

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

### 4. Old `plaincandle-home` Pages project cleanup — IN PROGRESS
- Dormant in dashboard, custom domain detached, DNS points to Worker now. User can delete from CF UI when convenient.
- The deployed Pages project hosts `flame.svg` at `https://plaincandle-home.pages.dev/flame.svg` — currently referenced as the org-level logo path on the CF Access login page. **Don't delete until the logo is moved to the Worker or another host.**
- Migration drop-in is at `aionnas/flame-svg-route.js`. Remaining manual steps (all documented inline in that file):
  1. `curl https://plaincandle-home.pages.dev/flame.svg` and paste the body into the `FLAME_SVG` backticks.
  2. Splice `maybeServeFlame` into `landing-worker/worker.js` as the first line of the fetch handler.
  3. Add a path-level Bypass policy to the landing Access app for `/flame.svg` so it's reachable without auth (the CF Access login page itself fetches it pre-auth).
  4. Redeploy landing-worker.
  5. Update org-level CF Access logo URL to `https://plaincandle.dev/flame.svg`.
  6. Verify sign-out → sign-in renders the flame, then delete the Pages project.

### 5. API token Pages permission missing
- Token has Workers + Access + KV + DNS. Lacks `Pages:Edit`. Wasn't needed for the build, but if future tasks need to mutate Pages, re-issue the token with that scope added.

### 6. Phone push notifications
- This session is running via API key auth — `/login` is hidden, session doesn't appear in the Claude Code mobile app's session list. To get phone push, user has to restart Claude Code without `ANTHROPIC_API_KEY` set in env, do OAuth login, then re-pair on phone. Context will reset on restart (memory files persist).

## What I'd verify first next session
1. `https://plaincandle.dev/` returns 200 after a real sign-in
2. `https://admin.plaincandle.dev/` shows the admin panel
3. KV still has just `theshane0314@gmail.com`
4. cloudflared tunnel on TrueNAS is RUNNING
