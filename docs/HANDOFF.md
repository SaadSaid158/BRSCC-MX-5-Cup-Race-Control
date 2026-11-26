# Handoff: BRSCC MX-5 Cup Race Control

**Written:** 2026-11-26, at the end of the cloud development session (v0.1 → v0.2.1).
**For:** a Claude Code session on the user's Windows laptop, with `windows-mcp` (desktop control) and `telemetrist` MCPs, started with `claude remote-control` so the user can steer it from their phone.

**Read this first:** `CLAUDE.md` (the standing rules), then **§1–§4** of this file (about 10 minutes). After that, go straight to **§5, your first jobs**. The rest is reference: open it when the task needs it.

---

## 1. What we're building, and why
- **The app:** a **CSP Lua app** for Assetto Corsa that runs offline races as realistic **BRSCC Mazda MX-5 Championship** rounds:
  - marshal posts and flags;
  - stewards and penalties;
  - AI that obeys race control;
  - full meetings and championships.
- **The user:** they're preparing to race the real championship and will use this to train on a G29 with a shifter. **Realism outranks convenience in every design decision.**
- **Sources of truth:**
  - the **2026 BRSCC Mazda MX-5 Championship Sporting & Technical Regulations** ("REGS");
  - the **Motorsport UK National Competition Rules 2026** ("NCR").

  Every rule value is in `src/brscc_race_control/rules.lua`, with its article. Values the rules leave open are marked `OURS`.
- **Same consequences for every driver.** The player gets no special treatment. If the player would be disqualified, they are.
- **No third-party race-control apps.** The user disabled Nuzzy's FIA race control and similar apps; they fight our app over the AI and the flags. If AI behaviour looks wrong, check first that nothing else is running.
- **The README says the project is vibe coded:** the user directs and tests, Claude writes the code. Keep that section.

## 2. Status
| Item | State |
|---|---|
| Version on `main` | **v0.2.1** (CI green) |
| Repo | `SaadSaid158/brscc-mx-5-cup-race-control` (private) |
| Milestones on GitHub | M1–M6. **M1 is open**, issues #2–#6 |
| Last in-game test | v0.2.0 on CSP 0.2.11, Silverstone International (see §7) |
| v0.2.1 in-game | **not yet tested** |
| Releases | Pushing a tag `vX.Y.Z` makes Actions publish a release with the zip. The cloud session couldn't push tags or create releases (blocked by its policy); a local session probably can |

**Commit history (newest first):**
- handoff and CLAUDE.md;
- README and roadmap;
- v0.2.1 compat;
- v0.2.0 HUD, settings and auto posts;
- CI releases;
- v0.1.2 initial import.

## 3. The user's machine and setup
- **OS:** Windows. The repo is cloned in the user's home folder (`BRSCC-MX-5-Cup-Race-Control`).
- **AC install:** ask the user, or find the folder containing `acs.exe`. The path contains spaces, so always quote it.
- **CSP:** **0.2.11**. The lua-sdk under `<AC>/extension/internal/lua-sdk` is **the source of truth for that version**. Grep it before using any API function or field. Avoid CSP 0.2.12-preview1: it breaks `setAITopSpeed` and `setAIThrottleLimit`.
- **The app installs to** `<AC>/apps/lua/brscc_race_control/`: copy `src/brscc_race_control/` there, or unzip the install zip into `<AC>`.
- **Reports** go to `Documents/Assetto Corsa/brscc-race-control/reports/`. Each session produces:
  - `.txt`: results, log, COMPATIBILITY section, contacts;
  - `.json`: the stewards' ledger;
  - `_trace.csv`: 2 Hz, every car (spline, speed, AI cap, flag level, hazard, wheels out, pits, fuel, …);
  - `_excursions.csv`: every off-track moment, with the per-wheel surface codes.
- **race.ini:** `Documents/Assetto Corsa/cfg/race.ini`. Content Manager writes it at every launch.
- **Settings storage:** `ac.storage` under `Documents/Assetto Corsa/cfg/extension/state/lua/…`.
- **Car:** `content/cars/brscc_mazda_mx5_na_2026`. Its `data.acd` is encrypted, so the AI can only be steered through the API.
  - Physics notes: 960 kg with driver, 5-speed H-pattern with no autoblip, no ABS or TC, Kumho HS52 195/50R15 tyres.
- **Tracks in the install:**
  - `ks_silverstone` (the International layout is the 2026 final round, and the **testbed**);
  - `ks_brands_hatch` (not on the 2026 calendar);
  - `js_thruxton` and other Silverstone variants.
  - **Missing calendar tracks:** Snetterton 300, Oulton Park International, Donington National, Croft, Cadwell Park, Anglesey International. Ask the user for the mods when needed.
- **MCPs:**
  - `windows-mcp` (`uvx windows-mcp serve`): screenshots, mouse and keyboard.
  - `telemetrist` (a local Python server): the user's telemetry tool. **Inspect its tools before relying on it.** It may give lap and input telemetry, which would be useful for tuning the AI.
  - `playwright`.
  - Use the `gh` CLI for GitHub (it's logged in). The GitHub MCP plugin is broken; ignore it.
- **Standard test setup in CM:**
  - Car: BRSCC MX-5 NA for every car.
  - Track: Silverstone International.
  - Conditions: Clear, 20 °C, 14:00, time ×1, Optimum track, no wind.
  - AI: 9 cars, strength 95 %, aggression 50 %.
  - Damage 0 %, fuel and tyres ×1, tyre blankets on.
  - Penalties ON, jump start OFF (until M2 implements ours).

## 4. Ground rules for this session
- **Desktop control (`windows-mcp`):** only inside Assetto Corsa, Content Manager, the terminal, the repo, and the AC and Documents/Assetto Corsa folders.
  - Don't open or touch the user's other apps, browser accounts, email or files.
  - Ask before changing CM or AC settings outside the standard test setup above.
- **Never delete** anything outside the repo and our own app or report folders.
- **The user steers from their phone.**
  - Work in **whole milestones**, and give a **short status** after each step: what's done, what's next, anything blocked.
  - Don't ask for permission on routine work.
  - Do ask on product decisions (the rules and realism trade-offs listed in each milestone).
- **Keep context lean.** Read files in slices, grep instead of dumping, and don't paste large outputs into the conversation. The user has had a lot of trouble with compaction.
- **Before every push:** all three test suites pass, the version is bumped in both places, the package is built. See CLAUDE.md.
- **Commit trailers:** use the co-author and session lines the harness gives you. Never put model names in code or docs.
- **Privacy:** don't commit the user's Windows username, absolute personal paths, age or account details. The cloud session's push was blocked once for exactly that.

## 5. Your first jobs, in order
1. **Verify the environment (about 15 minutes):**
   - Find `<AC>` and read the CSP version: CM, or `extension/config/` and `extension/` version files.
   - **Grep the local lua-sdk** and record the answers in `docs/API_NOTES.md`, under a "Verified on 0.2.11" section. Check whether these exist on 0.2.11:
     - `physics.setCarAutopilot`, `physics.setCarPosition`, `physics.setAISplineOffset`, `physics.setGentleStop`, `physics.lockUserControlsFor`, `physics.forceUserBrakesFor`, `ac.overrideCarControls`;
     - `ac.restartAssettoCorsa`, `ac.tryToRestartSession`;
     - `ac.hasTrackSpline`, `ac.trackProgressToWorldCoordinate`, `ac.INIConfig.trackData`;
     - the `ac.StateCar` fields `position`, `look`, `isRequestingPitStop`, `fuel`, `fuelPerLap`, `maxFuel`, `engineLifeLeft`, `gearboxDamage`, `bestLapTimeMs`, `wheels[].surfaceExtendedType`, `wheels[].surfaceValidTrack`;
     - `ac.StateSim.time`, `windowWidth` and `uiScale`.
   - **Update `compat.lua` and the `OLD_CSP` list in `tests/sim.lua`** to match reality. The current list is a guess.
   - Read `Documents/Assetto Corsa/cfg/race.ini` and note its structure in `docs/API_NOTES.md`: car order, sessions, grid, AI level fields. M1 needs it.
2. **Install v0.2.1 and do one sanity run yourself:**
   1. Copy the app into `<AC>/apps/lua/`.
   2. Launch a short race through CM using desktop control: standard setup, 5 laps.
   3. Let the AI drive the player car.
   4. Read the report's **COMPATIBILITY** section, and check the trace now has rows and AI track limits are being judged.
   5. Fix anything that's broken before building on it.
3. **Build the test-driver mode (§8).** After that, almost all in-game testing can be automated.
4. **Run the outstanding in-game checks with the test driver (§7, "Not yet observed").**
5. **Start M1 (§9).**

## 6. Architecture
```
src/brscc_race_control/
  manifest.ini            two windows (Settings, Race Control); SIM_CALLBACKS UPDATE=rcUpdate; UI_CALLBACKS IN_GAME=rcHud
  brscc_race_control.lua  main: session state G, per-frame update, stewards' actions, report, view model, windows
  rules.lua               every rule constant + reference (pure data)
  settings.lua            ac.storage settings, applied onto rules.lua values (OURS values only)
  compat.lua              compat.get (safe FFI field read), compat.guard (error containment), CSP version
  sectors.lua             marshal map helpers: even(), normalise(), at(spline), next/prev, ahead()   (pure)
  autoposts.lua           posts from the AI line's curvature + sections.ini names                    (pure)
  flags.lua               per-post flag state from hazards; levelFor(car) incl. look-ahead            (pure)
  detect.lua              hazards (stopped / off-track car), track-limit excursions                  (pure)
  yellowpass.lua          overtaking under yellow, give-back, expiry                                 (pure)
  stewards.lua            penalty ladder, track-limits ladder (one step per lap), DT serve/convert,
                          jump start, ledger                                                         (pure)
  points.lua              race points, season total with drops, x3 penalty deduction                 (pure)
  redflag.lua             case A/B/C, roll-back order, restart grid                                  (pure, not wired yet)
  gaps.lua                interval timing, 200 checkpoints per lap                                   (pure)
  ai.lua                  AI caps under yellow, give-back, pit request, DSQ parking, pit guard       (CSP)
  hud_common.lua          drawing helpers, flag lamps, flag panel                                    (CSP ui)
  hud_practice.lua        full-info HUD                                                              (CSP ui)
  hud_race.lua            realistic HUD (basic)                                                      (CSP ui)
tests/run.lua             112 unit tests (pure modules)
tests/sim.lua             26 end-to-end checks: the real app against a fake CSP API; HUD_SNAPSHOTS=<dir>; OLD_CSP=1
scripts/package.sh        builds dist/BRSCC-Race-Control-v<ver>-install.zip
.github/workflows/tests.yml   unit + sim + OLD_CSP sim + package; on tag vX.Y.Z publishes a release
```

**The per-frame update (`update(dt)` in the main script), in order:**
1. **Snapshot every car:** spline, speed, wheels outside, per-wheel *beyond* (a non-track surface that isn't kerb or pit lane), pit lane, lap. Also: gaps checkpoints, line crossing, and the excursion log.
2. **Hazards → sector flags:** a stopped car on track gives a double yellow plus a single yellow at the post before; a slow or stopped car off track gives a single yellow; the post after shows green.
3. **Per-car flag level.** A car that has passed every hazard in its sector is back to green. Then the yellow-pass detection runs.
4. **Per car, inside `compat.guard`:**
   - track limits through the stewards;
   - lap completion (qualifying lap deletion, lap validity, drive-through countdown);
   - pit-lane exit (drive-through served);
   - finish;
   - **AI:** yellow caps, give-back, pit request for penalties, DSQ parking, pit guard.
5. **The 2 Hz trace.**
6. **End of session:** the report.

**HUD:** `buildView()` makes one view table, and `hud_practice` or `hud_race` draws it. Any HUD error is caught and shown in red in the Settings window.

## 7. What in-game testing has proven so far
- **v0.1.0** (Silverstone International, 2 races):
  - **Track limits:** `wheelsOutside ≥ 1` flagged kerb-riding, so all 9 AI were penalised within 40 s. Fix: per-wheel surfaces, with kerbs legal.
  - **AI after the incident:** they stayed slowed after passing it. Fix: a car past the hazard is back to green.
  - **Escalation:** a drive-through went to a black flag in 3 s. Fix: NCR App.7 1.11, where the signal must be shown at the line before the next step.
  - **AI mass-pitting:** every AI car pitted and never came out. Causes:
    - other race-control apps (the user confirmed);
    - our global `overrideRacingFlag(Caution)`;
    - the pit request never being cleared after a drive-through.

    All are fixed or removed, and a pit guard was added.
- **v0.2.0** (CSP 0.2.11):
  - **Per-wheel surfaces work at Silverstone:** kerb `T4` (valid, type 4), grass `x2` (invalid, type 2).
  - **Automatic posts** produced 11 posts.
  - **The AI didn't pit.**
  - **But** the update threw at the first AI car every frame, on newer car fields that 0.2.11 lacks. So there were no AI track-limit decisions and the trace was empty. Fixed in v0.2.1 with `compat.lua` and per-car guards. **v0.2.1 is unverified in-game.**
  - The AI genuinely put 2 wheels on the grass about 13 times in 14 minutes across 9 cars (≥ 0.3 s). Under the strict NCR reading those are breaches, which is realistic.
- **Not yet observed:**
  1. The AI **approaching a car stopped on track** (slowing early, crawling past, no overtaking, then racing again). Needs the player on pole, stopping on lap 2.
  2. The **full track-limits ladder on the player**, including serving a drive-through.
  3. v0.2.1's COMPATIBILITY lines and a non-empty trace.
  4. Where the **automatic posts sit** at Silverstone International (the user hasn't sent the list).
  5. HUD readability. Only the user can judge that.

## 8. Test-driver mode (job 3)
The goal is to automate in-game tests so the user is only needed for feel.
- **A Settings tab "Test driver"** (off by default), plus `data/scenarios/*.json`.
- **Player-car control.** Verify each function against the 0.2.11 SDK first.
  - `physics.setCarAutopilot(true)`: the player car is driven by the AI.
  - `physics.setAISplineOffset(0, ±1, true)`, **for a short time**: a scripted excursion wide onto the grass.
  - `physics.setGentleStop(0, true)` / `physics.setAIStopCounter(0, s)`: stop on track. Release afterwards.
  - Pit lane: `physics.setAIPitStopRequest(0, true)`, for serving a drive-through.
  - Fallback if autopilot isn't available: `ac.overrideCarControls`.
- **Scenario format:**
  ```json
  { "name": "yellow_and_ladder", "session": "race", "laps": 12,
    "steps": [
      { "lap": 2, "at": 0.30, "do": "stop_on_track", "for_s": 60 },
      { "lap": 4, "at": 0.86, "do": "wide", "side": "right", "for_s": 1.2 },
      { "lap": 5, "at": 0.86, "do": "wide", "side": "right", "for_s": 1.2 },
      { "lap": 9, "do": "serve_drive_through" } ],
    "expect": [
      { "type": "flag_seen", "level": 2, "by": "ai", "near_s": 0.30 },
      { "type": "no_ai_overtake_under_yellow" },
      { "type": "player_tl_count", "value": 2 } ] }
  ```
- **Output:** the normal report, plus a **TEST RESULT** section (pass or fail for each expectation) and the trace.
- **Loop:**
  1. Build, then copy the app into `<AC>`.
  2. Launch the scenario's session through CM with `windows-mcp`, or write `race.ini` and start `acs.exe`. Find out which works reliably.
  3. Wait for the report, read the TEST RESULT section, and fix anything that failed.
  4. Commit.
- **Keep scenarios in the repo.** They become the in-game regression suite.

## 9. M1 · v0.3: Race meeting (GitHub milestone 1)
**The format:** qualifying, then races 1, 2 and 3 (REGS 2.3.3; Oulton Park has 2 races).
- Race 1's grid comes from qualifying, race 2's from race 1's result, and race 3's from race 2's result.
- The user chose: **the app sets the grids**, as realistically as possible.

**Proposed flow** (confirm with the user before building; it's a UX decision):
- The app drives the meeting. After each session, the Race Control window shows "Continue to Race N →".
- The app writes `race.ini` (grid order, session) and relaunches with `ac.restartAssettoCorsa(raceIni)`, if 0.2.11 has it.
- **Fallback:** the user starts each session in CM, and the app records the grid slots at load (each car's `position` and `look` before the start). It then moves cars to their correct slots with `physics.setCarPosition` before the lights.

**Issues:**
- **#2 Meeting file.** `Documents/Assetto Corsa/brscc-race-control/meetings/<date>_<track>.json`, holding:
  - the track and round numbers (REGS 1.5.1 calendar);
  - each session's results;
  - each driver's ledger (time penalties, penalty points, grid drops, deleted laps, Driving Standards notes);
  - the meeting state (next session).
- **#3 Qualifying rules:**
  - at least 3 laps to qualify, else start from the back (REGS 2.3.2);
  - laps deleted for track limits (NCR App.7 1.11a) and for laps through a double yellow;
  - 2.3.4: a car recovered by mechanical means can't rejoin, and its later laps aren't timed;
  - 2.3.5: cross the line once after the chequered flag;
  - grid penalties up to 10 places (REGS 4.2.2, NCR Annexe A 1.7). If a driver can't serve the full penalty, they start last.
- **#4 Grids:** as above. Also cars removed after the 1-minute board, or that pit on the green flag lap, start from the pit lane (REGS 2.5.3). That really belongs to M2's start procedure but needs the grid model now.
- **#5 Classification and points:**
  - time penalties applied;
  - classified vs not classified (look up the NCR classification rule; don't invent it);
  - PROVISIONAL → FINAL once the stewards' decisions are applied (REGS 2.9);
  - points 100/98/96 … minus 2 per place, +1 for the fastest **valid** lap (not if set while breaching App.7 1.6) (REGS 1.6.1);
  - penalty points ×3 deducted (REGS 4.2.4);
  - shortened races still count full points (1.6.4).
- **#6 Results window:** session results, meeting results and each driver's ledger. Use the HUD's design language (dark panels, white type, yellow accents).
- **Definition of done:**
  - all three test suites pass, with new unit tests for qualifying, grids and classification, and sim scenarios for a full meeting;
  - one automated in-game meeting run through the test driver;
  - the user's sign-off.

## 10. Later milestones (summary; the full list is in `docs/ROADMAP.md`)
- **M2, race procedures:**
  - **The standing start (REGS 2.5.2):** the 1-minute board (start engines, clear the grid) → the 30-second board → the green flag lap, with the pole car setting the pace and no overtaking or practice starts → back to the grid slots → the 5-second board → red lights about 5 s after the board is withdrawn → lights out 2–7 s later (NCR App.6 6.13).
  - **Jump start:** +10 s and 0 penalty points (NCR App.6 Art.7–8).
  - **Blue flags:** stationary = a car close behind; waved = it's trying to pass (App.8 1.7 b/c). Lapped AI yield using the spline offset.
  - **Chequered flag:** the cool-down lap, no overtaking, into the pit lane, parc fermé (REGS 2.8, 2.14).
  - **Pit lane:** 60 km/h limit (REGS 2.7.4). The NCR penalty for speeding still needs looking up.
- **M3, neutralisations:**
  - **The Safety Car (NCR App.8 Art.2):**
    - waved yellow and the SC board at every post;
    - the field queues at **no more than 5 car lengths**, with no overtaking;
    - lapped cars are waved past only if the Clerk of the Course orders it;
    - the pit lane stays open; rejoining cars go to the back of the queue;
    - the SC turns its lights off **at least 50 % of a lap** before coming in (circuits under 2 miles; 25 % over 2 miles);
    - the leader sets the pace, and green shows at the line;
    - no overtaking until the green at the control line;
    - SC laps count, and **a race run entirely behind the SC is null and void**.
  - **No FCY:** it needs GPS tracking and radio that club MX-5 races don't have.
  - **Code 60:** an option per event, off by default. Requires the event's Final Instructions.
  - **The red flag:** wire up the existing `redflag.lua` (REGS 2.6, NCR App.6 Art.9).
    - **Case A** (fewer than 2 laps): a no-contest, restart from the original grid, gaps not closed.
    - **Case B:** the restart grid is the order one lap before the leader's laps at the red flag, and the result is the finishing order of the restarted race.
    - **Case C** (75 % or more): results declared one lap before. Track-limit breaches on the discounted laps don't count.
    - Cars may be repaired in the pits, but then start from the pit lane.
    - Exactly 2 laps counts as Case B (OURS).
- **M4, stewarding:**
  - contact judgements: NFA, Noted or a penalty, with the evidence logged;
  - penalty points per NCR Ch.2 App.12: reprimand 2, time/grid 3, DSQ 4, event DSQ 6, drive-through/stop-go 0. 12 points in 12 months is a ban;
  - BRSCC Driving Standards Yellow/Red Warnings, the same for every driver.
- **M5, championship:** the season file, the 2026 calendar, the best totals with the 3 lowest dropped (DSQ rounds can't be dropped; final-event rule in 1.6.2), Masters and Rookie trophies.
- **M6:** the full realistic Race HUD (light panels, board sequence, real race numbers from the skins' `ui_skin.json`) and a UI design pass.

## 11. Decisions log (all approved by the user unless marked OURS)
| Decision | Reference |
|---|---|
| Track-limits ladder: noted → black/white warning → +5 s → +10 s → drive-through → black flag. One step per lap, after the signal at the line | NCR App.7 1.11 |
| Track limits = any part of any tyre beyond the kerb's outer edge. Kerbs legal. Excursion must last ≥ 0.3 s (OURS) | NCR App.7 1.6b |
| Qualifying track limits: lap deleted | App.7 1.11a |
| Drive-through: serve within 3 laps. In the last 5 laps / last 10 min it becomes 30 s. Unserved → DSQ (OURS) | NCR App.10 2.1 |
| Jump start: +10 s, 0 penalty points | NCR App.6 Art.7–8 |
| Lights out 2–7 s after the red lights | NCR App.6 6.13 |
| Overtaking under yellow: give the place back within a lap and 20 s, or +10 s (OURS). Qualifying: lap deleted. Practice: reprimand | App.8 1.10 |
| Contact ladder: warning → 5 s → drive-through → DSQ (OURS; replaced in M4) | — |
| In a race, AI pit only when race control sends them in (OURS) | sprint format |
| Never override AC's race flag; our HUD draws all flags | — |
| Practice HUD is the default during development; Race mode is the realistic one | — |
| Safety Car standard; Code 60 an option per event; no FCY | REGS 2.12, NCR App.8 Art.2–4 |
| Multi-race meetings: the app sets the grids (option b) | REGS 2.3.3 |
| Same consequences for every driver | — |

## 12. Open questions for the user
- **M1 flow:** app-driven relaunch, or CM-driven with an in-session grid?
- **Driving Standards Red Warning for the player:** exclusion from the next round? The user said everyone faces the same consequences, so the answer is probably yes; confirm the details at M4.
- **Calendar track mods:** when they become available.
- **The real event Final Instructions:** once the user enters a real round, use them for Code 60 and track-specific rules.
