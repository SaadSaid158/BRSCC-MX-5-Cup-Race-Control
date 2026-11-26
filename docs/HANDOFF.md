# Handoff: BRSCC MX-5 Cup Race Control (written 2026-11-26)

For a new Claude Code session on the user's Windows laptop, with desktop control. Read `CLAUDE.md` (the standing rules) and this file before doing anything.

---

## 1. Where things stand
- **Repo:** `SaadSaid158/brscc-mx-5-cup-race-control` (private). `main` holds **v0.2.1**; CI is green.
- **Done:**
  - **v0.1:** marshal sectors, yellow/double yellow, AI yellow compliance, overtaking under yellow with give-back, the NCR track-limits ladder, drive-through and black flag, reports.
  - **v0.2:** the Practice HUD (approved mock-ups in `docs/mockups/`), a basic Race HUD, the Settings and Race Control windows, automatic marshal posts, gap timing, the AI pit guard, and the compat layer for older CSP versions.
- **Tests:** 112 unit tests (`tests/run.lua`) and 26 end-to-end checks (`tests/sim.lua`, against a fake CSP API; `OLD_CSP=1` makes missing fields throw).
  - `HUD_SNAPSHOTS=<dir> luajit tests/sim.lua` writes what the HUD draws as SVGs. Render them with Playwright or a browser to check the layout.
- **Next:** **M1 · v0.3: Race meeting** (GitHub milestone 1, issues #2–#6). See §5.

## 2. The user's machine
| Item | Value |
|---|---|
| OS | Windows |
| AC install | ask the user, or find the folder containing `acs.exe` (the path may contain spaces: quote it) |
| CSP | **0.2.11**. Avoid 0.2.12-preview1 (it breaks the AI speed caps) |
| App install path | `<AC>/apps/lua/brscc_race_control/` (unzip the install zip into `<AC>`) |
| Reports | `Documents/Assetto Corsa/brscc-race-control/reports/` (`.txt`, `.json`, `_trace.csv`, `_excursions.csv` per session) |
| race.ini | `Documents/Assetto Corsa/cfg/race.ini` (CM writes it on every launch) |
| CSP Lua SDK | `<AC>/extension/internal/lua-sdk`: **the source of truth for 0.2.11**, so grep it before using any field |
| Car | `content/cars/brscc_mazda_mx5_na_2026` (data.acd encrypted) |
| Test track | **Silverstone International** (`ks_silverstone`, layout `international`); it's the 2026 final round |
| Other apps | **Disable all other race-control and AI apps** (for example Nuzzy's FIA race control). They caused the AI mass-pitting |

**Standard test settings:**
- the BRSCC MX-5 NA for every car;
- Clear, 20 °C, 14:00, Optimum track;
- 9 AI at 95 % strength and 50 % aggression;
- damage 0 %, Penalties ON, jump start off.

## 3. What in-game testing has shown
- **v0.1.0:**
  - Track limits were over-sensitive, because kerb-riding was counted.
  - AI stayed slowed after passing the incident.
  - Escalation was too fast.
  - The AI pitted en masse and never came out.
  - Contributing causes: our `overrideRacingFlag`, the pit request never being cleared after a drive-through, and other race-control apps. All three are fixed or removed.
- **v0.2.0:**
  - The per-wheel surface data works at Silverstone: kerb = `T4` (valid track, kerb type 4), grass = `x2` (invalid, grass type 2).
  - Automatic posts produced 11 posts.
  - The AI didn't pit.
  - **But** the update loop threw at the first AI car every frame. The cause was newer car fields missing in 0.2.11, so there were no AI track-limit decisions and the trace was empty. Fixed in v0.2.1 with `compat.lua` and per-car guards.
- **Not yet observed in-game:**
  - the AI approaching a car stopped on track (needs a pole start and a stop on lap 2);
  - the full track-limits ladder on the player;
  - the v0.2.1 COMPATIBILITY report lines;
  - the automatic post positions at Silverstone.

## 4. First job for a session with desktop control: a test-driver mode
Rather than pressing keys from screenshots, add a **test-driver mode** to the app. It's in the Settings window, off by default.
- **Driving the player car:**
  - `physics.setCarAutopilot(active)` puts the user car on AI.
  - `physics.setAISplineOffset(0, offset, true)` pushes it wide, for scripted track-limit excursions.
  - `physics.setGentleStop(0, true)` stops it on track.
  - `ac.overrideCarControls` is another option.
  - Verify every one of these in the **local** SDK first (CSP 0.2.11).
- **Scenario script:** a JSON list of steps, for example:
  - `{lap:2, at:0.30, do:"stop", for_s:60}`
  - `{lap:4, at:0.86, do:"wide", offset:1.0, for_s:1.5}`
  - `{do:"serve_drive_through"}`
- **Output:** the normal reports, plus an assertions section ("expected double yellow at post X: yes/no").
- **The automation loop:**
  1. Build, then copy `src/brscc_race_control` into `<AC>/apps/lua/`.
  2. Launch the race through CM using desktop control, or write `race.ini` and start `acs.exe` directly.
  3. Wait for the report, read it, and fix what's wrong.

  Only the user's subjective feel tests need the user.

**Ground rules for desktop control:** stay inside AC, Content Manager, the terminal and this repo. Don't touch the user's other apps, accounts or files. Ask before changing CM or AC settings that the user didn't ask for.

## 5. M1 · v0.3: Race meeting (in detail)
A BRSCC meeting is **qualifying, then races 1, 2 and 3** (REGS 2.3.3; Oulton Park has 2 races).

The user chose **option (b) from our earlier discussion**: the app sets the grids, as realistically as possible.

**Preferred flow (to confirm with the user):** the app drives the meeting. After each session, the Race Control window offers "Continue to Race N →". The app then writes `race.ini` and relaunches AC with `ac.restartAssettoCorsa(raceIni)` (verify that exists in 0.2.11). As a fallback, the app records the grid slots when a race loads (each car's `position` and `look` before the start) and moves cars into the right slots with `physics.setCarPosition(car, pos, dir)` before the lights.

**Issues:**
- **#2 Meeting file:** a JSON file under `Documents/Assetto Corsa/brscc-race-control/` holding the track, session order, results, penalties, points and grid drops.
- **#3 Qualifying rules:**
  - at least 3 laps to qualify, else start from the back (REGS 2.3.2);
  - laps deleted for track limits (NCR App.7 1.11a) and for laps through a double yellow;
  - grid penalties carried to the race (REGS 4.2.2, up to 10 places).
- **#4 Grids:** race 1 from qualifying, race 2 from race 1's result, race 3 from race 2's result.
- **#5 Classification and points:**
  - time penalties applied;
  - classified vs not classified;
  - PROVISIONAL, then FINAL;
  - points 100/98/96… plus 1 for the fastest valid lap (REGS 1.6.1);
  - penalty points ×3 deducted (REGS 4.2.4).
- **#6 Results window:** session and meeting results, in the same design language as the HUD.

**What M1 needs from the machine:**
- a real `race.ini` (to learn CM's format: car order, sessions, grid);
- the 0.2.11 SDK, to verify `restartAssettoCorsa`, `setCarPosition`, `setCarAutopilot` and the car `position`/`look` fields.

## 6. Later milestones
See `docs/ROADMAP.md`:
- **M2:** the standing start with green flag lap and boards, jump starts (+10 s), blue flags, cool-down lap, pit speeding.
- **M3:** the Safety Car (NCR App.8 Art.2; there's **no FCY**, because the NCR requires GPS and radio that club MX-5 races don't have), red flag A/B/C, Code 60 as a per-event option.
- **M4:** contact judgements, penalty points, Driving Standards warnings.
- **M5:** the championship.
- **M6:** the full Race HUD and polish.

## 7. Research you can rely on
- `docs/NCR_RESEARCH.md`: SC, Code 60, FCY, flags, App.7 track limits, App.6 starts and red flag, App.10 drive-through, App.12 penalty points, the 2026 calendar, points.
- `docs/API_NOTES.md`: verified CSP API, flags that work natively, penalty types, state fields.
- **Key decisions:**
  - The track-limits ladder follows NCR App.7 1.11 (one step per lap, after the signal at the line).
  - Kerbs are legal.
  - A jump start is +10 s with 0 penalty points.
  - Lights out comes 2–7 s after the red lights.
  - A drive-through counts 0 penalty points; a time penalty counts 3.
  - In a race, the AI pit only when race control sends them in.
  - The Practice HUD is the default during development; Race mode is realistic.

## 8. How to work with the user
- They message from their phone and want **momentum**: whole milestones, a short status after each one, and the install zip sent.
- After each milestone, run all three test suites, package, push, and send the zip. Tell them which in-game test they need to do personally, if any.
- They want realism above everything. Same consequences for all drivers.
