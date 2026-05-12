// Drop-in route for landing-worker/worker.js — serves the candle-flame logo
// at https://plaincandle.dev/flame.svg so the CF Access org-level branding
// can reference it directly. Once this is live and CF Access points at the
// new URL, the dormant plaincandle-home Pages project can be deleted.
//
// How to install:
//   1) Run, on your Windows box, with the existing Pages site still live:
//        curl -fsS https://plaincandle-home.pages.dev/flame.svg > flame.svg
//      Paste the contents into the backticks below (replacing the placeholder
//      comment). It's fine to keep the SVG on multiple lines — backticks
//      preserve whitespace and an SVG renderer doesn't care.
//
//   2) In landing-worker/worker.js, add the FLAME_SVG constant near the top
//      and the early-return block at the very start of the fetch handler,
//      before any CF Access identity logic runs. /flame.svg must be reachable
//      unauthenticated, because the CF Access login page itself fetches it
//      before the user has signed in.
//
//   3) Make sure the landing Access app's policy allows /flame.svg through
//      without auth. Easiest way: add a Bypass policy to the landing Access
//      app for the path /flame.svg (Action: Bypass, Include: Everyone). If
//      the path-level bypass is too fiddly, the alternative is to host the
//      SVG on a separate Worker that isn't fronted by Access at all.
//
//   4) Deploy with the same pattern documented in AIonNas.md:
//        source /c/Users/Shane-PC/plaincandle/.env
//        cd /c/Users/Shane-PC/plaincandle/landing-worker
//        curl -s -X PUT \
//          "https://api.cloudflare.com/client/v4/accounts/$ACCT/workers/scripts/plaincandle-landing" \
//          -H "Authorization: Bearer $TOKEN" \
//          -F "metadata=@C:/Users/Shane-PC/AppData/Local/Temp/landing-meta.json;type=application/json" \
//          -F "worker.js=@worker.js;type=application/javascript+module"
//
//   5) Verify: curl -I https://plaincandle.dev/flame.svg → 200, content-type
//      image/svg+xml. Open in a browser and confirm the flame renders.
//
//   6) In Zero Trust → Settings → Custom Pages (org-level login design),
//      change the logo URL from
//        https://plaincandle-home.pages.dev/flame.svg
//      to
//        https://plaincandle.dev/flame.svg
//      Save, then trigger a sign-out + sign-in to confirm the flame still
//      appears above the white card.
//
//   7) Only after the new URL is confirmed working in the login page, delete
//      the plaincandle-home Pages project from the Cloudflare dashboard.

const FLAME_SVG = `<!-- paste the contents of flame.svg here, between the backticks -->`;

// Add at the top of the fetch handler:
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

// Example wiring inside the existing default export:
//
//   export default {
//     async fetch(request, env, ctx) {
//       const svg = maybeServeFlame(request);
//       if (svg) return svg;
//       // ...existing auth + routing logic...
//     }
//   };

export { FLAME_SVG, maybeServeFlame };
