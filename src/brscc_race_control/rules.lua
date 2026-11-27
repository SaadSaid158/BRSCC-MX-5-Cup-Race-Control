-- rules.lua: every number the race control uses, with its source.
-- "REGS" = 2026 BRSCC Mazda MX-5 Championship Sporting & Technical Regulations (27 Mar 2026).
-- "NCR"  = Motorsport UK National Competition Rules 2026.
-- "OURS" = our own design choice where the rules leave it open (approved, or flagged for review).
-- Pure data: no CSP API calls in this file.

local R = {}

-- Scoring --------------------------------------------------------------------
R.points = {
  first = 100,              -- REGS 1.6.1: P1 = 100
  step = 2,                 -- REGS 1.6.1: decreasing by 2 per place
  floor = 0,                -- OURS: never award negative race points (P51+ in theory)
  fastestLap = 1,           -- REGS 1.6.1: +1, not if set while breaching NCR Ch.12 App.7 Art.1.6
  dropLowest = 3,           -- REGS 1.6.2: best totals less 3 lowest scores
  penaltyPointMultiplier = 3, -- REGS 4.2.4: 3 champ points per penalty point, may go negative
}

-- Penalty points per penalty type: NCR Ch.2 App.12 Art.1.5 (Art.1.4 for SG/DT)
R.penaltyPoints = {
  verbal_warning = 0,
  reprimand = 2,
  time = 3, grid = 3, place = 3, fine = 3,
  drive_through = 0, stop_go = 0,           -- Art.1.4: no points, no appeal (incl. when converted to time)
  dsq_session = 4,                          -- DSQ from practice / heat / race
  dsq_event = 6,
}
R.penaltyPointsBanThreshold = 12            -- NCR Ch.2 App.12 Art.1.6: 12 pts in 12 months -> National Court
                                            -- OURS: maps to "excluded from next round" in-game

-- Penalty limits ---------------------------------------------------------------
R.maxTimePenaltyS = 60                      -- NCR Ch.2 Annexe A Art.1.3a: up to 1 minute
R.maxPlacePenalty = 10                      -- NCR Ch.2 Annexe A Art.1.3a / REGS 4.2.2 (grid, quali)
R.serveWithinLaps = 3                       -- NCR Ch.12 App.10 Art.2.1: <= 3 complete laps after the board
R.lateConversion = {                        -- NCR Ch.12 App.10 Art.2.1(l)
  lastLaps = 5,                             -- imposed in the last 5 laps ...
  lastMinutes = 10,                         -- ... or the last 10 min of a timed race ...
  timeS = 30,                               -- ... becomes 30-60 s added to elapsed time. OURS: 30 s
}
R.unservedPenalty = "dsq_session"           -- OURS: NCR only says "further penalties incl. DSQ"

-- Our penalty values (NCR Annexe A gives no table, only the 60 s / 10 place cap) ----
-- NCR Ch.12 App.7 Art.1.11 (races). Replaces the handoff's 3-warnings ladder.
-- A breach = any part of any tyre contact patch beyond the kerb's outer edge (Art.1.6b).
-- The driver must have been shown the previous step's signal before the next step applies.
R.trackLimitsLadder = {
  [1] = { action = "none" },
  [2] = { action = "warning", flag = "black_white" },
  [3] = { action = "time", seconds = 5 },
  [4] = { action = "time", seconds = 10 },        -- "a further 10 s" (cumulative: 15 s total)
  [5] = { action = "drive_through" },             -- in addition to the time penalties
  [6] = { action = "black" },                     -- DSQ via black flag
}
R.trackLimitsQualifying = "delete_lap"            -- NCR Ch.12 App.7 Art.1.11(a)
-- NCR Ch.12 App.6 Art.9.1(f): breaches on laps discounted by a red-flag roll-back don't count.
R.contactLadder = { "warning", "time5", "drive_through", "dsq_session" }  -- OURS (handoff 5.2)
R.jumpStart = { action = "time", seconds = 10, penaltyPoints = 0 }  -- NCR Ch.12 App.6 Art.7-8
R.code60OvertakeTimeS = 60                  -- NCR Ch.12 App.8 Art.3.9: "1 minute or more"

-- Speeds / procedures ------------------------------------------------------------
R.pitLimitKmh = 60                          -- REGS 2.7.4 (NCR Ch.12 App.11 Art.3.6.a)
R.code60Kmh = 60                            -- NCR Ch.12 App.8 Art.3.5
R.fcyKmh = 80                               -- NCR Ch.12 App.8 Art.4.5
R.scMaxGapCarLengths = 5                    -- NCR Ch.12 App.8 Art.2.6
R.scLightsOffLapFraction = function(trackLengthM)  -- NCR Ch.12 App.8 Art.2.10
  return (trackLengthM >= 3218.7) and 0.25 or 0.5 -- 2 miles
end
R.minQualifyingLaps = 3                     -- REGS 2.3.2

-- Race classification, NCR Ch.12 App.9 Art.1.11: at least 80% of the winner's laps (decimals
-- disregarded), crossing the finish line (not in the pit lane) under own power within 4 minutes of the winner.
R.classification = { minFraction = 0.8, afterWinnerS = 240 }

-- Blue flags, NCR Ch.12 App.8 1.7 b/c and App.7 1.5 (the BRSCC regs are silent).
R.blue = {
  stationaryGapS = 2.0,     -- OURS: a lapping car within this (seconds behind) -> stationary blue ("close behind")
  wavedGapS = 0.8,          -- OURS: within this -> waved blue ("trying to pass")
  ignoredPosts = 3,         -- OURS: a waved blue shown at this many posts without letting the car by -> reported
}
R.start = {                                 -- REGS 2.5.2
  oneMinuteS = 60, thirtySecS = 30, fiveSecBoardS = 5,
  redLightsAfterBoardS = 5,
  lightsOutMinS = 2, lightsOutMaxS = 7,     -- NCR Ch.12 App.6 Art.6.13: lights out 2-7 s after on
  jumpMoveM = 0.5,                          -- OURS: moved this far from the grid slot before lights out = jump start
}

-- Yellow flags (NCR Ch.12 App.8 Art.1.7 e/f, 1.8, 1.10) -------------------------------
R.yellow = {
  -- 1.8: waved yellow at the post before, double waved immediately before the incident,
  -- waved green immediately after. A car well off track: single yellow, then green.
  postBeforeDouble = 1,       -- sector before a double-yellow sector shows a single yellow
  sectorsDefault = 12,        -- OURS: even split when there's no marshal map for the track
  clearHoldS = 4,             -- OURS: flags stay out this long after the hazard clears
  lookAheadM = 120,           -- OURS: a car sees the next post's flag this far before the sector
  -- Hazard detection (OURS)
  stoppedKmh = 15,            -- slower than this ...
  stoppedForS = 1.5,          -- ... for this long = stopped car
  armedAboveKmh = 50,         -- a car only counts once it's done this speed (ignores grid / pit exit)
  gridStallS = 5,             -- OURS: at a race start, a car still under stoppedKmh this long after the
                              -- green is stalled on the grid and becomes a hazard (it never arms otherwise)
  offTrackWheels = 4,         -- all 4 wheels outside = car off track
  offTrackSlowKmh = 60,       -- off track and this slow = hazard (single yellow)
  clearAboveKmh = 40,         -- hazard clears once the car is back on track above this ...
  clearForS = 2,              -- ... for this long
  -- 1.10: overtaking under yellow is an offence until the green is passed.
  giveBackLaps = 1,           -- OURS: passer has this long to give the place back
  passPenalty = { kind = "time", seconds = 10 },  -- OURS, within Annexe A 1.3 (60 s cap); 3 pen. pts
  passWindowM = 60,           -- OURS: two cars closer than this are "racing" for the pass check
}
-- AI compliance (OURS, tuned in-game)
R.aiYellow = {
  singleFactor = 0.85,        -- single yellow: cap at 85% of the speed it entered the zone at
  singleMinKmh = 70,
  doubleFactor = 0.6,         -- double yellow: 60% of entry speed ...
  doubleMaxKmh = 100,         -- ... but never more than this
  doubleMinKmh = 40,
  nearIncidentM = 150,        -- within this of the hazard under double yellow ...
  nearIncidentKmh = 50,       -- ... crawl past
  caution = 4,                -- extra following distance (setAICaution, default 1)
  followGapM = 30,            -- don't close on the car ahead inside a yellow zone
  giveBackFactor = 0.8,       -- passer slows to 80% of the passed car's speed until it's back behind
}
-- AI pitting (OURS). BRSCC MX-5 races are sprints with no scheduled stops; AC/mod AI pitting
-- (fuel estimate, other apps) emptied the field in the v0.1.0 test. In races, AI pit only for RC.
R.aiPitGuard = true
-- v0.1.1 overrode AC's race flag (Caution) for the player's HUD. 4 of 6 unexplained AI pit stops
-- started under that override, so it's off until proven player-only. Our HUD shows the flags.
R.useACFlagOverride = false

-- Track-limit detection (NCR Ch.12 App.7 Art.1.6b: any part of any tyre beyond the kerb edge).
-- v0.1.1: a wheel is "beyond" only if it's on a non-track surface that ISN'T a kerb (per-wheel
-- surface data). v0.1.0 used AC's wheelsOutside and flagged kerb-riding AI ~40 times in 80 s.
R.trackLimitWheels = 1        -- wheels beyond >= this = breach (NCR: any part of any tyre)
R.trackLimitMinS = 0.3        -- OURS: excursion must last this long (judge of fact can see it, App.7 1.10)
R.trackLimitRearmS = 1.0      -- all wheels back on for this long before the next breach can count
R.trackLimitMinKmh = 30

-- Red flag (REGS 2.6, NCR Ch.12 App.6 Art.9) ---------------------------------------------
R.redFlag = {
  caseALeaderLapsBelow = 2,                 -- REGS 2.6.2 "less than two race laps"
  caseCFraction = 0.75,                     -- REGS 2.6.4 "more than 75%"
  -- REGS 2.6.3 says "more than two laps" and 2.6.2 says "less than two": exactly 2 laps is not
  -- covered by either. OURS: exactly 2 laps = Case B.
}

return R
