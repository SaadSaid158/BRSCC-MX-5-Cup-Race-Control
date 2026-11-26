# CLAUDE.md: standing rules for this repo

Read `docs/HANDOFF.md` first; it has the full project state. Then read `docs/ROADMAP.md`.

## The project
A CSP Lua app for Assetto Corsa that runs offline races as realistic **BRSCC Mazda MX-5 Championship** rounds. The user is training for the real championship, so **realism is the top priority**.
- Every rule value lives in `src/brscc_race_control/rules.lua`, with its 2026 regs / Motorsport UK NCR reference.
- Values we chose ourselves are marked `OURS`.
- Never invent a rule. If the regs and the NCR are silent, mark the value OURS and say so.

## Working style
- The user is aiming for MX-5 Cup. Talk casually, in British English, as an equal co-worker.
- Challenge bad ideas.
- **Keep context lean:** read files in slices and avoid dumping big tool output. The user hates sessions that fill their context with junk.
- Work in **milestones** (`docs/ROADMAP.md`, GitHub milestones M1–M6). Ship complete features, not drip-fed patches.
- Every milestone has to pass the simulator tests before it goes to an in-game test.
- **The same consequences apply to every driver**, the player included. There are no special rules for AI or player.

## Code rules (learned the hard way)
- **CSP car/sim state are FFI structs.** Reading a field that the installed CSP lacks **throws**. Any field newer than the v0.1.0 set goes through `compat.get(obj, key, default)`. The user runs **CSP 0.2.11**; the SDK definitions we verified against are newer.
- `ac.iterateCars()` yields a **1-based** loop index. Always use `car.index` (0-based) for `physics.*` and `ac.getCar`.
- `car.collidedWith` is **the other car's index + 1** (0 means the track or a wall).
- **Never use `physics.overrideRacingFlag`.** It's global, and it probably sent AI cars into the pits. Flags are drawn by our own HUD.
- Use the session clock `G.clock` for timers, not `os.clock` (that's CPU time) or `sim.time` (it may not exist).
- Every CSP API call must match the SDK definitions (`docs/API_NOTES.md`). The local SDK is at `<AC>/extension/internal/lua-sdk`.
- Keep the rules logic pure (no CSP calls) so it can be unit-tested. CSP-facing code goes in `brscc_race_control.lua`, `ai.lua` and the `hud_*` files.

## Before every push
```bash
luajit tests/run.lua
```
```bash
luajit tests/sim.lua
```
```bash
OLD_CSP=1 luajit tests/sim.lua
```
- All three must pass.
- Bump `VERSION` in both `manifest.ini` and `brscc_race_control.lua`.
- Run `scripts/package.sh` to build `dist/*-install.zip`.
- CI runs the same checks. Pushing a tag `vX.Y.Z` makes Actions publish a release with the zip attached.

## Commits
End every commit message with the co-author / session lines the harness gives you. Don't put model names anywhere in the code.
