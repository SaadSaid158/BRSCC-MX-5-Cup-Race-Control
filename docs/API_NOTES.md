# CSP Lua API notes (verified 2026-11-26)

**Sources:**
- `ac-custom-shaders-patch/acc-lua-sdk` (public; commit of 2026-08-17): the enums.
- The generated `ac_apps` definitions vendored in `dreasgrech/AssettoCorsaRealisticTrackday` (`lib/ac_apps/lib.lua`): function signatures and the state fields.

**Re-check against your local copy:** `extension/internal/lua-sdk` (CSP 0.2.11). Anything marked ⚠ is known to vary by CSP version.

## Host: Lua app (`apps/lua/brscc_race_control/`)
- `ac_apps` loads `ac_physics` + `ac_physics_ai` with `withPhysics = true`, so `physics.*` works from an app.
  - Proven offline by two open-source apps: Realistic Trackday and RaceFlow/ApexFlow.
- Both of them refuse to run when `ac.getSim().isOnlineRace` is true. We do the same.
- **Manifest hooks:**
  - `[SIM_CALLBACKS] UPDATE = fn`: called after every sim update. Our main logic lives here.
  - `[UI_CALLBACKS] IN_GAME = fn`: full-screen overlay drawn every frame. This is our flag panel.
  - `[CORE] LAZY = NONE`: the app loads with the session, even if its window is never opened.
- Main script = `<folder name>.lua`; `require("module")` resolves from the app folder.
- ⚠ **Realistic Trackday reports:** `setAIThrottleLimit` and `setAITopSpeed` were broken in **CSP 0.2.12-preview1**. 0.2.11 is fine.

## Functions (signature: notes)
- `physics.setAITopSpeed(car, kmh)`: use `math.huge` to remove the limit.
- `physics.setAIThrottleLimit(car, 0..1)`: 1 = no limit.
- `physics.setAICaution(car, 0..16)`: default 1; higher = bigger gap to the car in front. Experimental.
- `physics.setAIAggression(car, 0..1)`: CM's value is ×0.95.
- `physics.setAILevel(car, 0..2)`
- `physics.setAISplineOffset(car, -1..1, overrideAwareness?)`
- `physics.setAIPitStopRequest(car, bool)`: since 0.3.0-p147, `false` also blocks pitting briefly.
- `physics.setAIStopCounter(car, seconds)`: forced braking; 0 releases it.
- `physics.setGentleStop(car, bool)`
- `physics.setAINoInput(car, active, stall)`: parks the AI car.
- `physics.setCarPenalty(ac.PenaltyType, param)`: **player car only**; invalidates the lap.
- `physics.teleportCarTo(car, ac.SpawnSet)`: Start / Pits / HotlapStart / TimeAttack. Invalidates the lap.
- `physics.overrideRacingFlag(ac.FlagType)`: call with `None` to give control back to AC.
- `physics.awakeCar(car)`
- `physics.disableCarCollisions(...)`: replaces the deprecated `setCarCollisions`.
- `ac.onCarCollision(car | -1, fn(carIndex))`: fires once when contact starts. Then use `collidedWith` (0 = track, otherwise a car) and `collisionDepth`.
- `ac.onSessionStart(fn(sessionIndex, restarted))`: **not called for the first session.** Do your initialisation at load time as well.
- `ac.setMessage(title, desc, nil|'illegal', seconds)`
- `ac.getCar(i)`, `ac.iterateCars()` (yields `i, car`), `ac.getSim()`, `ac.getSession(i)`
- `ac.getTrackID()`, `ac.getTrackLayout()`, `ac.getTrackFullID(sep)`, `ac.getDriverName(i)`
- `io.load / io.save / io.createDir / io.fileExists`, `JSON.parse / JSON.stringify`
- `ac.getFolder(ac.FolderID.ACDocuments)`
- **Not found:** `restartSession`. Red-flag restarts will need `teleportCarTo` plus our own procedure.

## Enums
- **`ac.FlagType`** (in CSP's own words, "works" means AC's HUD shows it):
  - **work:** None 0, Start 1, Caution 2 (yellow), Stop 5 (black), ReturnToPits 8 (penalty), FasterCar 12 (blue), Finished 13 (chequered), OneLapLeft 14 (white = **last lap**, *not* slow vehicle);
  - **don't work yet:** Slippery 3, PitLaneClosed 4, SlowVehicle 6, Ambulance 7, MechanicalFailure 9, Unsportsmanlike 10, StopCancel 11, SessionSuspended 15, Code60 16.

  So our HUD panel has to draw: double yellow, oil, white (slow vehicle), black/orange, black/white, SC, Code 60, red.
- **`ac.PenaltyType`:**
  - None 0;
  - MandatoryPits 1 (param = laps left to pit, so a drive-through within N laps);
  - TeleportToPits 2 (param = seconds held in the pits);
  - SlowDown 3 (param = seconds of gas cut);
  - BlackFlag 4;
  - ReleaseBlackFlag 5.
- **`ac.SessionType`:** Undefined 0, Practice 1, Qualify 2, Race 3, Hotlap 4, TimeAttack 5, Drift 6, Drag 7.

## State fields we use
**`ac.StateCar`:**
- `index`, `isAIControlled`, `speedKmh`, `splinePosition` (0..1)
- `lapCount`, `drivenInRace` (metres; in P/Q it resets every lap)
- `racePosition`
- `wheelsOutside` (number of wheels outside the allowed area), `lapCutsCount`, `isLapValid`
- `isInPitlane`, `isInPit` (parked in its box), `isRetired`, `isRaceFinished`
- `collidedWith`, `collisionDepth`
- `bestLapTimeMs`, `previousLapTimeMs`, `lapTimeMs`
- `aiLevel`, `aiAggression`

**`ac.StateSim`:**
- `isOnlineRace`, `isPaused`, `isReplayActive`
- `raceSessionType`, `currentSessionIndex`, `isSessionStarted`, `isSessionFinished`
- `currentSessionTime` (ms; negative before the start), `sessionTimeLeft`, `timeToSessionStart`
- `carsCount`, `trackLengthM`, `leaderCompletedLaps`, `focusedCar`
- `raceFlagType`, `raceFlagCause`
- `windowWidth`, `windowHeight`, `uiScale`

**`ac.StateSession`:** `type`, `laps`, `durationMinutes`, `isTimedRace`, `hasAdditionalLap`, `leaderCompletedLaps`, `isOver`.

## Added in v0.2.0 (verified against the same definitions)
- `ac.hasTrackSpline()`, `ac.trackProgressToWorldCoordinate(t, linear?) -> vec3`: the AI line in world space; used for automatic marshal posts.
- `ac.INIConfig.trackData("sections.ini")`: `.sections[name][key] = { values }`. AC sections use `IN`, `OUT` and `TEXT`.
- `ac.storage(defaultsTable, keyPrefix)`: a table that persists on write, saved under `Documents/Assetto Corsa/cfg/extension/state/lua`.
- **UI:**
  - `ui.tabBar(id, flags, fn)` / `ui.tabItem(label, flags, fn)`
  - `ui.radioButton(label, checked) -> clicked`
  - `ui.checkbox(label, checked) -> clicked`
  - `ui.slider(label, value, min, max, fmt, power|true=int) -> value, changed`
  - `ui.header`, `ui.textWrapped`
- **Drawing:**
  - `ui.drawRectFilled(p1, p2, col, rounding)`
  - `ui.drawRect(p1, p2, col, rounding, flags, thickness)`
  - `ui.drawTriangleFilled(p1, p2, p3, col)`
  - `ui.drawCircleFilled(p, r, col, segments)`
  - `ui.pushDWriteFont('Segoe UI;Weight=Bold')` (the form CSP's own scripts use)
  - `ui.measureDWriteText(text, size) -> vec2`
  - `ui.dwriteDrawText(text, size, pos, col)`
- `ac.StateSim.time` (ms since AC start): used for HUD timers, not `os.clock` (which is CPU time).
