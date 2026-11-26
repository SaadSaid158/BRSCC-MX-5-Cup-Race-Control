-- Offline unit tests for the pure-logic modules. Run from the project root:
--   luajit tests/run.lua
package.path = "src/brscc_race_control/?.lua;" .. package.path

local points = require("points")
local stewards = require("stewards")
local redflag = require("redflag")

local pass, fail = 0, 0
local function eq(name, got, want)
  if got == want then pass = pass + 1
  else fail = fail + 1; print(("FAIL %s: got %s, want %s"):format(name, tostring(got), tostring(want))) end
end

-- points ----------------------------------------------------------------------
eq("P1", points.forPosition(1), 100)
eq("P6", points.forPosition(6), 90)
eq("P51 floor", points.forPosition(51), 0)
do
  local res = {
    { id = "a", classified = true }, { id = "b", classified = true, dsq = true },
    { id = "c", classified = true }, { id = "d", classified = false },
  }
  local p = points.race(res, { id = "c", valid = true })
  eq("race P1", p.a, 100); eq("race DSQ", p.b, 0); eq("race P2 after DSQ + FL", p.c, 99); eq("race NC", p.d, 0)
  local p2 = points.race(res, { id = "a", valid = false })
  eq("FL invalid (track limits)", p2.a, 100)
end
do
  local rounds = {}
  for i = 1, 20 do rounds[i] = { points = 50 + i, finalEvent = i >= 18 } end
  rounds[2].dsq = true; rounds[2].points = 0
  -- drops: lowest droppable = rounds 1 (51), 3 (53), 4 (54). Round 2 (DSQ) can't be dropped.
  local total = 0
  for i = 1, 20 do total = total + rounds[i].points end
  local want = total - 51 - 53 - 54 - 3 * 3   -- 3 penalty points -> -9
  local got, dropped = points.season(rounds, true, 3)
  eq("season total", got, want); eq("DSQ not dropped", dropped[2], nil)
  -- negative allowed (REGS 4.2.4)
  local neg = points.season({ { points = 0 }, { points = 0 }, { points = 0 }, { points = 5 } }, true, 4)
  eq("negative total", neg, -7)   -- keeps the 5 (3 zeros dropped), 5 - 12
  -- missed final event: final rounds can't be dropped
  local r2 = { { points = 90 }, { points = 90 }, { points = 90 }, { points = 90 },
               { points = 0, finalEvent = true }, { points = 0, finalEvent = true } }
  eq("missed final", (points.season(r2, false, 0)), 90)
end

-- stewards: track limits (NCR Ch.12 App.7 Art.1.11) ---------------------------------
do
  local d = stewards.newDriver("x")
  local acts = {}
  -- one breach per lap: each step's signal is shown at the line before the next breach
  for i = 1, 6 do acts[i] = stewards.trackLimits(d, { session = "race", lap = i, lapsTotal = 20 }).action end
  eq("TL1", acts[1], "none"); eq("TL2", acts[2], "warning"); eq("TL3", acts[3], "time")
  eq("TL4", acts[4], "time"); eq("TL5", acts[5], "drive_through"); eq("TL6", acts[6], "black")
  eq("TL time total", d.timePenaltyS, 15)
  eq("TL DSQ", d.dsq, true)
  eq("TL pen points 3+3+0+4", d.penaltyPoints, 10)
end
do
  local d = stewards.newDriver("q")
  local r = stewards.trackLimits(d, { session = "qualifying", lap = 4 })
  eq("quali delete", r.action, "delete_lap"); eq("quali lap flagged", d.deletedLaps[4], true)
  eq("quali no count", d.trackLimits, 0)
end

do -- App.7 1.11: no escalation until the car has crossed the line after the last signal
  local d = stewards.newDriver("burri")
  local ctx = { session = "race", lap = 1, lapsTotal = 20 }
  eq("hold 1 none", stewards.trackLimits(d, ctx).action, "none")
  eq("hold 2 warning", stewards.trackLimits(d, ctx).action, "warning")
  eq("hold 3 same lap held", stewards.trackLimits(d, ctx).action, "held")
  eq("hold count unchanged", d.trackLimits, 2)
  eq("hold next lap escalates", stewards.trackLimits(d, { session = "race", lap = 2, lapsTotal = 20 }).action, "time")
end

-- stewards: drive-through serving and late conversion ------------------------------
do
  local d = stewards.newDriver("dt")
  stewards.penalise(d, "drive_through", { session = "race", lap = 5, lapsTotal = 20 })
  eq("DT pending", #d.pending, 1)
  eq("DT 0 pts", d.penaltyPoints, 0)
  eq("DT lap 8 ok", stewards.onLap(d, { session = "race", lap = 8, lapsTotal = 20 }), nil)
  local dec = stewards.onLap(d, { session = "race", lap = 9, lapsTotal = 20 })
  eq("DT unserved -> DSQ", dec and dec.kind, "dsq_session"); eq("DSQ 4 pts", d.penaltyPoints, 4)
end
do
  local d = stewards.newDriver("late")
  local dec = stewards.penalise(d, "drive_through", { session = "race", lap = 17, lapsTotal = 20 })
  eq("late DT -> time", dec.kind, "time"); eq("late DT 30 s", d.timePenaltyS, 30)
  eq("late DT 0 pts", d.penaltyPoints, 0)
end
do
  local d = stewards.newDriver("served")
  stewards.penalise(d, "drive_through", { session = "race", lap = 5, lapsTotal = 20 })
  eq("served", stewards.served(d, "drive_through") ~= nil, true)
  eq("nothing pending", stewards.onLap(d, { session = "race", lap = 12, lapsTotal = 20 }), nil)
end
do
  local d = stewards.newDriver("js")
  stewards.jumpStart(d, { session = "race", lap = 0, lapsTotal = 20 })
  eq("jump start 10 s", d.timePenaltyS, 10); eq("jump start 0 pts", d.penaltyPoints, 0)
end
do
  local d = stewards.newDriver("c")
  local ctx = { session = "race", lap = 4, lapsTotal = 20 }
  eq("contact 1 warning", stewards.contact(d, "penalty", ctx).kind, "warning")
  eq("contact 2 time", stewards.contact(d, "penalty", ctx).kind, "time")
  eq("contact 2 5 s", d.timePenaltyS, 5)
  eq("contact 3 DT", stewards.contact(d, "penalty", ctx).kind, "drive_through")
  eq("contact 4 DSQ", stewards.contact(d, "penalty", ctx).kind, "dsq_session")
  eq("contact NFA", stewards.contact(stewards.newDriver("n"), "nfa", ctx).kind, "nfa")
  eq("practice reprimand", stewards.contact(stewards.newDriver("p"), "penalty", { session = "practice", lap = 1 }).kind, "reprimand")
end

-- red flag ----------------------------------------------------------------------
eq("case A", redflag.case(1, 0.1), "A")
eq("case B (exactly 2 laps)", redflag.case(2, 0.15), "B")
eq("case C", redflag.case(15, 0.75), "C")
do
  local crossings = {
    a = { [1] = 60, [2] = 120, [3] = 180, [4] = 240 },
    b = { [1] = 61, [2] = 122, [3] = 185 },          -- passed a on lap 4? no: only 3 laps
    c = { [1] = 62, [2] = 121, [3] = 181, [4] = 239 }, -- leads at lap 4 but order counted at lap 3
    d = { [1] = 70, [2] = 140 },
    e = { [1] = 59, [2] = 119, [3] = 179 },          -- stopped, not running
  }
  local running = { a = true, b = true, c = true, d = true }
  local order, L = redflag.order(crossings, 4, running)
  eq("roll-back lap", L, 3)
  eq("order 1", order[1], "a"); eq("order 2", order[2], "c"); eq("order 3", order[3], "b")
  eq("order 4 (lapped)", order[4], "d"); eq("not running excluded", order[5], nil)
  local grid, pit = redflag.restartGrid(order, { c = { repaired = true } })
  eq("grid 2 after repair", grid[2], "b"); eq("pit lane", pit[1], "c")
  local slots = redflag.caseAGrid({ "a", "b", "c" }, { a = true, c = true })
  eq("case A gap kept", slots[2], nil); eq("case A slot 3", slots[3], "c")
end


-- sectors / flags -------------------------------------------------------------------
local S = require("sectors")
local F = require("flags")
do
  local map = S.even(10)
  eq("sector at 0", S.at(map, 0), 1); eq("sector at 0.95", S.at(map, 0.95), 10); eq("sector wrap", S.at(map, 1.02), 1)
  eq("prev of 1", S.prev(map, 1), 10); eq("next of 10", S.next(map, 10), 1)
  local bad = S.normalise({ { from = 2 } }); eq("bad map -> even", #bad, 12)
  local st = F.new(map)
  F.update(st, { { spline = 0.55, severity = 2 } }, 0.016)
  eq("double at sector 6", st.level[6], 2); eq("single at post before", st.level[5], 1)
  eq("green after", st.green[7], 1); eq("sector 4 clear", st.level[4], 0)
  -- look-ahead: 2 km lap, car 100 m before sector 5 (starts at 0.4) sees its yellow
  eq("look-ahead", (F.levelFor(st, 0.4 - 100 / 2000, 2000)), 1)
  eq("too far for look-ahead", (F.levelFor(st, 0.3, 2000)), 0)
  F.update(st, {}, 1); eq("hold keeps yellow", st.level[6], 2)
  F.update(st, {}, 5); eq("clears after hold", st.level[6], 0); eq("all clear", F.any(st), false)
end

-- detect -------------------------------------------------------------------------
local D = require("detect")
do
  local st = D.new()
  local function tick(s, t) local h; for _ = 1, math.floor(t / 0.1) do h = D.hazards(st, { [3] = s }, 0.1) end; return h end
  tick({ spline = 0.2, speed = 0, wheelsOut = 0 }, 3)
  eq("not armed on grid", D.isHazard(st, 3), false)
  tick({ spline = 0.2, speed = 120, wheelsOut = 0 }, 1)
  local h = tick({ spline = 0.3, speed = 5, wheelsOut = 0 }, 2)
  eq("stopped on track = double", h[1] and h[1].severity, 2)
  tick({ spline = 0.3, speed = 80, wheelsOut = 0 }, 1)
  eq("still hazard (clearForS)", D.isHazard(st, 3), true)
  tick({ spline = 0.32, speed = 80, wheelsOut = 0 }, 2)
  eq("cleared", D.isHazard(st, 3), false)
  h = tick({ spline = 0.4, speed = 30, wheelsOut = 4 }, 0.2)
  eq("slow off track = single", h[1] and h[1].severity, 1)
  -- track limits: one breach per excursion
  local st2 = D.new()
  local s = { speed = 150, wheelsOut = 1 }
  eq("TL too brief", D.trackLimit(st2, 1, s, 0.1), false)
  eq("TL breach after 0.3 s", D.trackLimit(st2, 1, s, 0.25), true)
  eq("TL same excursion", D.trackLimit(st2, 1, s, 0.016), false)
  s.wheelsOut = 0; D.trackLimit(st2, 1, s, 0.5); eq("not rearmed yet", D.trackLimit(st2, 1, { speed = 150, wheelsOut = 1 }, 0.4), false)
  s.wheelsOut = 0; D.trackLimit(st2, 1, s, 1.1); eq("rearmed", D.trackLimit(st2, 1, { speed = 150, wheelsOut = 1 }, 0.4), true)
  eq("kerb ignored (beyond=0)", D.trackLimit(D.new(), 1, { speed = 150, wheelsOut = 2, beyond = 0 }, 1), false)
  eq("pit lane ignored", D.trackLimit(D.new(), 1, { speed = 150, wheelsOut = 4, inPit = true }, 0.016), false)
end

-- yellow passes -----------------------------------------------------------------------
local YP = require("yellowpass")
do
  local L = 2000
  local st = YP.new()
  local function step(sa, sb, lvl, now, lapA)
    return YP.update(st, {
      [1] = { spline = sa, lap = lapA or 0, level = lvl }, [2] = { spline = sb, lap = 0, level = lvl } }, L, now)
  end
  step(0.500, 0.505, 1, 0)                  -- car 1 is 10 m behind car 2, under yellow
  local ev = step(0.506, 0.505, 1, 0.1)     -- car 1 passes
  eq("pass under yellow", ev[1] and ev[1].type, "pass"); eq("passer", ev[1] and ev[1].passer, 1)
  ev = step(0.506, 0.507, 1, 0.2)           -- car 2 back ahead (it re-passed)
  eq("given back", ev[1] and ev[1].type, "given_back"); eq("no new offence", ev[2], nil)
  -- green pass is fine
  local st2 = YP.new(); st = st2
  step(0.600, 0.605, 0, 0); ev = step(0.606, 0.605, 0, 0.1); eq("green pass ok", #ev, 0)
  -- passing the stricken car is allowed
  st = YP.new()
  YP.update(st, { [1] = { spline = 0.5, lap = 0, level = 2 }, [2] = { spline = 0.505, lap = 0, level = 2, hazard = true } }, L, 0)
  ev = YP.update(st, { [1] = { spline = 0.506, lap = 0, level = 2 }, [2] = { spline = 0.505, lap = 0, level = 2, hazard = true } }, L, 0.1)
  eq("hazard car pass ok", #ev, 0)
  -- not given back -> expired after a lap and 20 s
  st = YP.new()
  step(0.500, 0.505, 1, 0); step(0.506, 0.505, 1, 0.1)
  ev = step(0.9, 0.5, 0, 30, 1)
  eq("expired", ev[1] and ev[1].type, "expired")
  -- lapping under yellow is still an overtake (positions across the lap boundary)
  st = YP.new()
  step(0.999, 0.002, 1, 0, 5); ev = step(0.004, 0.003, 1, 0.1, 6)
  eq("pass across line", ev[1] and ev[1].type, "pass")
end

print(("%d passed, %d failed"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
