# BRSCC MX-5 Cup Race Control

A Lua app for Assetto Corsa (Custom Shaders Patch) that runs offline races as realistic
**BRSCC Mazda MX-5 Championship** rounds:
- marshal flags;
- stewards and penalties;
- AI that obeys race control.

Every rule is traced to the **2026 BRSCC Mazda MX-5 Championship Sporting & Technical Regulations** and the **Motorsport UK National Competition Rules (NCR) 2026**.

> Status: **v0.1.2, early development.** Tested in-game at Silverstone International.
> See [Roadmap](#roadmap).

## Requirements
- Assetto Corsa + Content Manager
- **Custom Shaders Patch 0.2.11**. Avoid 0.2.12-preview1: it breaks the AI speed limits.
- **Offline only.** The app switches itself off in online sessions.

## Install
1. Download the install zip from **Releases**, or build it with `scripts/package.sh`.
2. Unzip it into your Assetto Corsa root folder (the one containing `acs.exe`), so that you end up with `apps/lua/brscc_race_control/manifest.ini`.
3. Start any offline Practice, Qualifying or Race session. The app loads automatically.
   - Its window (marshal posts, stewards' ledger, log, marshal-map builder) is in the in-game apps bar.

Reports are written to `Documents/Assetto Corsa/brscc-race-control/reports/`. Each session produces four files:
- `.txt`: provisional results and the race-control log;
- `.json`: the stewards' ledger;
- `_trace.csv`: telemetry for tuning;
- `_excursions.csv`: track-limits evidence.

## What it does (v0.1.2)
| Area | Behaviour | Source |
|---|---|---|
| Marshal posts | 12 evenly spaced, or record the real posts with the in-app map builder | NCR Ch.12 App.8 1.8 |
| Yellow flags | A stopped car on track brings a double yellow, plus a single yellow at the post before; a car off track brings a single yellow; green after the incident | App.8 1.7 e/f, 1.8 |
| AI under yellow | Slows down, crawls past the hazard, no overtaking, back to racing once past | App.8 1.7, 1.10 |
| Overtaking under yellow | Race: give the place back or take 10 s. Qualifying: lap deleted. Practice: reprimand | App.8 1.10 |
| Track limits | Checked per wheel against the surface underneath (kerbs are legal). Ladder: noted → black/white warning → 5 s → +10 s → drive-through → black flag. At most one step per lap | App.7 1.6, 1.11 |
| Drive-through | Serve within 3 laps, or disqualified. In the last 5 laps it becomes a 30 s penalty | App.10 2.1 |
| Points | 100, 98, 96 … for positions, +1 for the fastest valid lap. Penalty points per App.12; ×3 deducted from the championship total (REGS 4.2.4) | REGS 1.6, NCR Ch.2 App.12 |
| Red flag | Case A/B/C classification logic (in-race procedure not built yet) | REGS 2.6, App.6 Art.9 |
| AI pit guard | In a race, AI pit only when race control sends them in; anything else is cancelled and logged with its cause | sprint format |
| Same rules for everyone | The player and the AI face identical consequences | — |

## Repository layout
```
src/brscc_race_control/   the app (copy into <AC>/apps/lua/)
  rules.lua               every constant, with its regs/NCR reference
  stewards.lua            penalties, ladders, ledger          (pure logic)
  points.lua              championship points                 (pure logic)
  redflag.lua             red-flag cases A/B/C                (pure logic)
  sectors.lua, flags.lua  marshal posts and flag states       (pure logic)
  detect.lua              hazard and track-limit detection    (pure logic)
  yellowpass.lua          overtaking under yellow, give-back  (pure logic)
  ai.lua                  AI compliance and pit guard         (CSP API)
  hud.lua                 on-screen overlay                   (CSP API)
  brscc_race_control.lua  main script: ties it together       (CSP API)
tests/run.lua             unit tests for the pure-logic modules
tests/sim.lua             end-to-end: runs the real app against a fake CSP API
docs/                     regulation research, API notes, test plans, HUD mock-ups
scripts/package.sh        builds the install zip into dist/
```

## Development
These run with LuaJIT 2.1, which is the same runtime CSP uses:
```bash
luajit tests/run.lua
```
```bash
luajit tests/sim.lua
```
```bash
scripts/package.sh
```
CI runs both test suites on every push.

**Rules of the codebase:**
- Every rule value lives in `rules.lua`, with its regs/NCR reference. Where the regs leave something open, the value is marked `OURS`.
- Every CSP API call is checked against the SDK definitions (`docs/API_NOTES.md`).
- The rules logic is kept pure (no CSP calls) so it can be unit-tested.

## Roadmap
1. **HUD v2**, from the approved mock-ups (`docs/mockups/`): a Race mode (realistic: flags at the posts, boards at the line) and a Practice mode (full information).
2. **Meeting flow:** qualifying, then races 1–3. Grids are set by the app (race 2 from the race 1 result, race 3 from race 2).
3. **Race procedures:**
   - standing start with jump-start detection;
   - blue flags;
   - **Safety Car** (NCR App.8 Art.2);
   - Code 60 as a per-event option;
   - red flag;
   - contact judgements.
4. **Championship:**
   - final results;
   - standings with the 3 worst rounds dropped;
   - penalty points;
   - Driving Standards Yellow/Red Warnings, applied equally to every driver.
5. **The 2026 calendar tracks**, each with its marshal-post map.

## Disclaimer
This is an unofficial fan project, not affiliated with or endorsed by the BRSCC, Mazda or Motorsport UK. The regulation references are for simulation only.
