# Project memory

This repo is `theshane0314/plugin-hub` — a fork of the RuneLite plugin-hub.

The branch `claude/start-aionnas-docs-3TDDe` is **dual-purpose**: in addition to any plugin work, it tracks an unrelated workstream called **AIonNAS** (self-hosted services on TrueNAS `LilNasX` @ `192.168.0.3`, fronted by Cloudflare Tunnel + Cloudflare Access + Workers at `plaincandle.dev`).

## If you've been pulled in to continue AIonNAS work

1. Read `AIonNas.md` end-to-end first — it's the source of truth for the AIonNAS infrastructure state, IDs, decisions, gotchas, and pending work. The "Handoff for the next Claude Code session" section at the top is the fastest catch-up.
2. Committed AIonNAS scripts and snippets live under `aionnas/`. Don't put AIonNAS work anywhere else in the repo.
3. The previous session ran in a Linux sandbox with no network path to `192.168.0.3`, no mount of the Windows filesystem, no Cloudflare API token, and no browser MCP. If you have any of those, you can do strictly more — especially:
   - **Read `C:\Users\Shane-PC\plaincandle\landing-worker\worker.js`** to inspect the actual worker source.
   - **Reach Cloudflare API** with the `plaincandle-admin` token (`Workers + Access + KV + DNS + Pages:Edit` as of 2026-05-12).
   - **Drive the Cloudflare dashboard** if you have a browser MCP.
4. The TrueNAS API key is **redacted** from `AIonNas.md`. The real one is in `C:\Users\Shane-PC\plaincandle\.env`. Do not commit it.
5. When you finish a task, mark it DONE in `AIonNas.md` with today's date (same format as the existing DONE entries), commit, and push to the same branch.

## If you're doing plugin-hub work (not AIonNAS)

`AIonNas.md` and `aionnas/` are unrelated — leave them alone. Refer to the upstream RuneLite plugin-hub README and `templateplugin/CLAUDE.md`.
