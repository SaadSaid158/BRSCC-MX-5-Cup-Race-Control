-- BRSCC Race Control: offline race control for the BRSCC Mazda MX-5 Championship (2026 regs + MSUK NCR).
-- Slice 1+2+3+4: marshal sectors, yellow / double yellow, AI compliance, overtaking under yellow
-- with give-back, track limits ladder, drive-through / black flag, provisional report.
-- Every rule lives in rules.lua with its reference. API usage is documented in API_NOTES.md.

local R = require("rules")
local S = require("sectors")
local F = require("flags")
local D = require("detect")
local YP = require("yellowpass")
local ST = require("stewards")
local AI = require("ai")
local HUD = require("hud")
local P = require("points")

local VERSION = "0.1.2"
local sim = ac.getSim()
local G = nil

-- helpers ------------------------------------------------------------------------
local function fmtTime(ms)
  if not ms or ms < 0 then return "--:--" end
  local s = math.floor(ms / 1000)
  return string.format("%02d:%02d", math.floor(s / 60), s % 60)
end

local function fmtLap(ms)
  if not ms or ms <= 0 then return "-" end
  return string.format("%d:%06.3f", math.floor(ms / 60000), (ms % 60000) / 1000)
end

local function name(i) return ac.getDriverName(i) or ("Car " .. (i + 1)) end

-- pad to n display characters (names like "Hołowczyc" are multi-byte UTF-8)
local function pad(str, n)
  local _, extra = str:gsub("[\128-\191]", "")
  return str .. string.rep(" ", math.max(0, n - (#str - extra)))
end

-- NCR App.7 1.6b via CSP per-wheel surface data: a wheel is beyond the track limit if it's on a
-- non-track surface that isn't a kerb and isn't pit lane. Returns count and a surface code string
-- ("T"/"x" = valid track or not, then the ac.SurfaceExtendedType number), or nil if unavailable.
local KERB = (ac.SurfaceExtendedType and ac.SurfaceExtendedType.Kerb) or 4
local function wheelsBeyond(car)
  local n, codes = 0, {}
  local ok = pcall(function()
    for w = 0, 3 do
      local wh = car.wheels[w]
      if not wh.surfacePitlane and not wh.surfaceValidTrack and wh.surfaceExtendedType ~= KERB then n = n + 1 end
      codes[w + 1] = (wh.surfaceValidTrack and "T" or "x") .. tostring(wh.surfaceExtendedType)
    end
  end)
  if not ok then return nil, "n/a" end
  return n, table.concat(codes, "/")
end

local function sessionKind()
  local t = sim.raceSessionType
  if t == ac.SessionType.Practice then return "practice" end
  if t == ac.SessionType.Qualify then return "qualifying" end
  if t == ac.SessionType.Race then return "race" end
  return nil
end

local function say(text, toPlayer, illegal)
  G.messages[#G.messages + 1] = { t = sim.currentSessionTime, text = text }
  if #G.messages > 60 then table.remove(G.messages, 1) end
  G.log[#G.log + 1] = "[" .. fmtTime(sim.currentSessionTime) .. "] " .. text
  ac.log("BRSCC RC: " .. text)
  if toPlayer then ac.setMessage("Race Control", text, illegal and "illegal" or nil, 7) end
end

local function loadMap()
  local id = ac.getTrackFullID("_")
  local path = ac.getFolder(ac.FolderID.ScriptOrigin) .. "/data/tracks/" .. id .. ".json"
  if io.fileExists(path) then
    local ok, data = pcall(JSON.parse, io.load(path))
    if ok and type(data) == "table" and data.sectors then return S.normalise(data.sectors), id, true end
  end
  return S.even(), id, false
end

-- session lifecycle ---------------------------------------------------------------
local function init()
  if G then
    AI.releaseAll()
    physics.overrideRacingFlag(ac.FlagType.None)
  end
  local map, trackId, fromFile = loadMap()
  G = {
    kind = sessionKind(), map = map, trackId = trackId,
    flags = F.new(map), det = D.new(), yp = YP.new(),
    drivers = {}, prev = {}, black = {}, bwUntil = {}, tlLaps = {}, doubleLap = {}, exc = {},
    excursions = { "t_s,car,ai,spline,duration_s,max_wheels_outside,max_wheels_beyond,surfaces_fl_fr_rl_rr,counted" },
    laps = {}, finished = {}, contacts = {},
    messages = {}, log = {}, lastFlag = nil, reportWritten = false,
    trace = { "t_s,car,ai,spline,lap,kmh,ai_cap_kmh,flag_level,hazard,wheels_out,in_pit,in_box,req_pit,fuel_l,fuel_per_lap,engine_life,gearbox_dmg" }, traceT = 0,
  }
  for i = 0, sim.carsCount - 1 do
    G.drivers[i] = ST.newDriver(i)
    G.laps[i], G.tlLaps[i] = {}, {}
  end
  if G.kind then
    say(("Briefing (%s): pit limit %d km/h. Yellow = slow, no overtaking until the green. " ..
      "Track limits per NCR App.7 1.11. Marshal posts: %s.")
      :format(G.kind, R.pitLimitKmh, fromFile and (#map .. " from track file") or (#map .. " evenly spaced")), true)
  end
end

local function ctxFor(car)
  local sess = ac.getSession(sim.currentSessionIndex)
  local timed = sess and sess.isTimedRace
  return {
    session = G.kind, lap = car.lapCount, time = sim.currentSessionTime,
    leaderLap = sess and sess.leaderCompletedLaps or nil,
    lapsTotal = (sess and not timed) and sess.laps or nil,
    minutesLeft = (timed or G.kind ~= "race") and (sim.sessionTimeLeft / 60000) or nil,
  }
end

-- act on a stewards' decision ----------------------------------------------------------
local function apply(i, car, dec, label)
  if not dec then return end
  local me = not car.isAIControlled
  local who, k = name(i), dec.kind
  if k == "time" then
    say(("%s: +%ds time penalty - %s%s"):format(who, dec.seconds, label,
      dec.convertedFrom and " (drive-through converted, NCR App.10 2.1l)" or ""), me, true)
  elseif k == "drive_through" or k == "stop_go" then
    say(("%s: DRIVE-THROUGH - %s. Enter the pit lane within %d laps."):format(who, label, R.serveWithinLaps), me, true)
    if me then physics.setCarPenalty(ac.PenaltyType.MandatoryPits, R.serveWithinLaps) else AI.requestPit(i) end
  elseif k == "dsq_session" then
    say(("%s: BLACK FLAG - disqualified - %s"):format(who, label), me, true)
    G.black[i] = true
    G.drivers[i].pending = {}   -- a disqualified car has nothing left to serve
    if me then physics.setCarPenalty(ac.PenaltyType.BlackFlag, -1) end
  elseif k == "warning" then
    say(("%s: warning - %s"):format(who, label), me, false)
  elseif k == "reprimand" then
    say(("%s: reprimand - %s"):format(who, label), me, true)
  elseif k == "lap_deleted" then
    say(("%s: lap %d deleted - %s"):format(who, (dec.lap or 0) + 1, label), me, true)
  elseif k == "grid" then
    say(("%s: %d-place grid penalty - %s"):format(who, dec.places or 0, label), me, true)
  end
end

-- yellow-pass events ------------------------------------------------------------------
local function onPassEvent(ev, cars)
  local i = ev.passer
  local car = ac.getCar(i)
  if not car then return end
  local d, ctx = G.drivers[i], ctxFor(car)
  if ev.type == "pass" then
    local post = G.map[S.at(G.map, car.splinePosition)].name
    if G.kind == "race" then
      say(("%s passed %s under yellow (%s) - give the place back"):format(name(i), name(ev.victim), post), not car.isAIControlled, true)
    elseif G.kind == "qualifying" then
      d.deletedLaps[car.lapCount] = true
      G.yp.open[i] = nil
      apply(i, car, { kind = "lap_deleted", lap = car.lapCount }, "overtaking under yellow (" .. post .. ")")
    else
      G.yp.open[i] = nil
      apply(i, car, ST.penalise(d, "reprimand", ctx, { reason = "overtaking under yellow" }), "overtaking under yellow (" .. post .. ")")
    end
  elseif ev.type == "given_back" then
    say(("%s gave the place back to %s - no further action"):format(name(i), name(ev.victim)), not car.isAIControlled)
  elseif ev.type == "expired" and G.kind == "race" then
    local pen = R.yellow.passPenalty
    apply(i, car, ST.penalise(d, pen.kind, ctx, { seconds = pen.seconds, reason = "overtaking under yellow",
      ref = "NCR Ch.12 App.8 1.10" }), "overtaking under yellow, place not given back")
  end
end

-- report ---------------------------------------------------------------------------------
local function writeReport(force)
  if (G.reportWritten and not force) or not G.kind then return end
  G.reportWritten = true
  local out = {}
  local function w(s) out[#out + 1] = s end
  w(("BRSCC MAZDA MX-5 CHAMPIONSHIP - RACE CONTROL REPORT (PROVISIONAL)  v%s"):format(VERSION))
  w(("Track: %s   Session: %s   Written: %s"):format(G.trackId, G.kind, os.date("%Y-%m-%d %H:%M:%S")))
  w("Results are provisional (REGS 2.9). Penalties applied per rules.lua references.")
  w("")

  local rows = {}
  for i = 0, sim.carsCount - 1 do
    local car = ac.getCar(i)
    if car then
      local d = G.drivers[i]
      local best = nil
      for _, l in ipairs(G.laps[i]) do if l.valid and (not best or l.ms < best) then best = l.ms end end
      rows[#rows + 1] = { i = i, car = car, d = d, best = best,
        fin = G.finished[i] and (G.finished[i] + d.timePenaltyS * 1000) or nil }
    end
  end

  if G.kind == "race" then
    table.sort(rows, function(a, b)
      if a.d.dsq ~= b.d.dsq then return not a.d.dsq end
      if a.car.lapCount ~= b.car.lapCount then return a.car.lapCount > b.car.lapCount end
      if a.fin and b.fin then return a.fin < b.fin end
      if a.fin or b.fin then return a.fin ~= nil end
      return a.car.racePosition < b.car.racePosition
    end)
    -- fastest valid lap (REGS 1.6.1: not if set while breaching App.7 1.6)
    local fl
    for _, r in ipairs(rows) do if r.best and not r.d.dsq and (not fl or r.best < fl.ms) then fl = { id = r.i, ms = r.best } end end
    local res = {}
    for _, r in ipairs(rows) do res[#res + 1] = { id = r.i, classified = r.fin ~= nil, dsq = r.d.dsq } end
    local pts = P.race(res, fl and { id = fl.id, valid = true } or nil)
    w("POS  DRIVER                      LAPS  FINISH(+PEN)   PEN   TL  PP  POINTS")
    for pos, r in ipairs(rows) do
      w(("%-4s %s %4d  %-12s %4ds %3d %3d  %d"):format(r.d.dsq and "DSQ" or tostring(pos), pad(name(r.i), 27),
        r.car.lapCount, r.fin and fmtTime(r.fin) or (r.d.dsq and "-" or "NC"), r.d.timePenaltyS,
        r.d.trackLimits, r.d.penaltyPoints, pts[r.i] or 0))
    end
    if fl then w(("Fastest valid lap: %s %s (+1 point)"):format(name(fl.id), fmtLap(fl.ms))) end
  else
    table.sort(rows, function(a, b)
      if (a.best ~= nil) ~= (b.best ~= nil) then return a.best ~= nil end
      return (a.best or 0) < (b.best or 0)
    end)
    w("POS  DRIVER                      BEST VALID   LAPS  DELETED  NOTE")
    for pos, r in ipairs(rows) do
      local del = 0
      for _ in pairs(r.d.deletedLaps) do del = del + 1 end
      local note = ""
      if G.kind == "qualifying" and #G.laps[r.i] < R.minQualifyingLaps then
        note = "fewer than 3 laps (REGS 2.3.2): start from the back"
      end
      w(("%-4d %s %-12s %4d  %7d  %s"):format(pos, pad(name(r.i), 27), fmtLap(r.best), #G.laps[r.i], del, note))
    end
  end

  w("")
  w("RACE CONTROL LOG")
  for _, l in ipairs(G.log) do w("  " .. l) end
  w("")
  w("CONTACTS (evidence, REGS 2.13 equivalent)")
  for _, c in ipairs(G.contacts) do w("  " .. c) end

  local dir = ac.getFolder(ac.FolderID.ACDocuments) .. "/brscc-race-control"
  io.createDir(dir)
  io.createDir(dir .. "/reports")
  local base = dir .. "/reports/" .. os.date("%Y-%m-%d_%H%M%S") .. "_" .. G.trackId .. "_" .. G.kind
  io.save(base .. ".txt", table.concat(out, "\r\n"))
  io.save(base .. "_trace.csv", table.concat(G.trace, "\r\n"))
  io.save(base .. "_excursions.csv", table.concat(G.excursions, "\r\n"))
  local ledger = {}
  for i, d in pairs(G.drivers) do
    ledger[#ledger + 1] = { car = i, driver = name(i), penaltyPoints = d.penaltyPoints, timePenaltyS = d.timePenaltyS,
      trackLimits = d.trackLimits, dsq = d.dsq, gridDrop = d.gridDrop, log = d.log }
  end
  io.save(base .. ".json", JSON.stringify({ version = VERSION, track = G.trackId, session = G.kind, drivers = ledger }))
  say("Provisional report written: Documents/Assetto Corsa/brscc-race-control/reports", true)
end

-- main tick -----------------------------------------------------------------------------
function script.rcUpdate(dt)
  if sim.isOnlineRace or sim.isPaused or sim.isReplayActive then return end
  if not G then init() end
  if not G.kind then return end
  local L = sim.trackLengthM
  local running = sim.isSessionStarted and sim.currentSessionTime > 0

  -- 1. snapshot
  local snap = {}
  for _, car in ac.iterateCars() do
    local i = car.index
    local beyond, codes = wheelsBeyond(car)
    snap[i] = { spline = car.splinePosition, speed = car.speedKmh, wheelsOut = car.wheelsOutside,
      inPit = car.isInPitlane, retired = car.isRetired, lap = car.lapCount, beyond = beyond, codes = codes }
    -- excursion log (every time any wheel leaves AC's allowed area): for tuning track limits
    local out = (beyond or 0) > 0 or car.wheelsOutside > 0
    local e = G.exc[i]
    if out and not car.isInPitlane and car.speedKmh > 30 then
      if not e then e = { t0 = sim.currentSessionTime, spline = car.splinePosition, wo = 0, by = 0 }; G.exc[i] = e end
      e.wo = math.max(e.wo, car.wheelsOutside)
      if (beyond or 0) >= e.by then e.by, e.codes = beyond or 0, codes end
    elseif e then
      if #G.excursions < 20000 then
        G.excursions[#G.excursions + 1] = ("%.1f,%d,%d,%.4f,%.2f,%d,%d,%s,%d"):format(e.t0 / 1000, i,
          car.isAIControlled and 1 or 0, e.spline, (sim.currentSessionTime - e.t0) / 1000, e.wo, e.by,
          e.codes or "", e.counted and 1 or 0)
      end
      G.exc[i] = nil
    end
  end

  -- 2. hazards -> sector flags
  local hazards, fresh = D.hazards(G.det, snap, dt)
  local changed = F.update(G.flags, hazards, dt)
  for _, id in ipairs(fresh) do
    local h = snap[id]
    local post = G.map[S.at(G.map, h.spline)].name
    say(("Incident: %s stopped/off at %s - yellow flags"):format(name(id), post))
  end
  if changed and not F.any(G.flags) then say("All sectors clear - green") end

  -- 3. per-car flag level, yellow passes
  local ycars = {}
  for i, s in pairs(snap) do
    local lvl, k = F.levelFor(G.flags, s.spline, L)
    -- NCR App.8 1.8: waved green immediately AFTER the incident. A car that has passed every
    -- hazard in its own sector is racing again (only the next post's flag can still apply).
    local hzIn, allBehind = false, true
    for _, h in ipairs(hazards) do
      if h.id ~= i and S.at(G.map, h.spline) == k then
        hzIn = true
        if YP.delta(s.spline, h.spline, L) <= 0 then allBehind = false end
      end
    end
    s.pastHazard = hzIn and allBehind
    if s.pastHazard then
      local nk = S.next(G.map, k)
      lvl = (S.ahead(s.spline, G.map[nk].from, L) <= R.yellow.lookAheadM) and G.flags.level[nk] or 0
    end
    s.level = lvl
    if i == 0 then G.playerLevel, G.playerGreen = lvl, s.pastHazard or G.flags.green[k] == 1 end
    if G.kind == "qualifying" and lvl == 2 then G.doubleLap[i] = true end
    if not G.finished[i] and not G.black[i] then
      ycars[i] = { spline = s.spline, lap = s.lap, inPit = s.inPit, hazard = D.isHazard(G.det, i), level = lvl }
    end
  end
  if running then
    for _, ev in ipairs(YP.update(G.yp, ycars, L, sim.currentSessionTime / 1000)) do onPassEvent(ev, snap) end
  end

  -- 4. per car: track limits, laps, pit lane, finish, AI
  for _, car in ac.iterateCars() do
    local i = car.index
    local s, d, pv = snap[i], G.drivers[i], G.prev[i]
    if not d then d = ST.newDriver(i); G.drivers[i] = d; G.laps[i] = {}; G.tlLaps[i] = {} end
    local ctx = ctxFor(car)

    if running and not G.black[i] and not G.finished[i] and D.trackLimit(G.det, i, s, dt) then
      G.tlLaps[i][car.lapCount] = true
      if G.exc[i] then G.exc[i].counted = true end
      local out = ST.trackLimits(d, ctx)
      if out.action == "held" then
        G.log[#G.log + 1] = "[" .. fmtTime(sim.currentSessionTime) .. "] " .. name(i) ..
          ": track limits breach noted - not escalated, previous signal not yet shown (App.7 1.11)"
      end
      if out.action == "warning" then G.bwUntil[i] = sim.currentSessionTime + 15000 end
      if out.action ~= "none" and out.action ~= "held" then
        apply(i, car, out.decision, ("track limits #%d (NCR App.7 1.11)"):format(out.count or 0))
      end
      if G.kind == "race" and out.action == "none" then
        say(("%s: track limits #1 - noted"):format(name(i)), not car.isAIControlled)
      end
    end

    if pv then
      if car.lapCount > pv.lap then                        -- lap completed
        local lapIdx = pv.lap
        local deleted = d.deletedLaps[lapIdx]
        if G.kind == "qualifying" and G.doubleLap[i] and not deleted then
          d.deletedLaps[lapIdx], deleted = true, true
          apply(i, car, { kind = "lap_deleted", lap = lapIdx }, "lap set through double yellow")
        end
        G.doubleLap[i] = nil
        G.laps[i][#G.laps[i] + 1] = { lap = lapIdx, ms = car.previousLapTimeMs,
          valid = car.isLastLapValid and not deleted and not G.tlLaps[i][lapIdx] }
        apply(i, car, ST.onLap(d, ctx), "drive-through not served within 3 laps (NCR App.10 2.1)")
      end
      if pv.inPit and not car.isInPitlane and #d.pending > 0 and not G.black[i] then   -- left the pit lane
        local p = ST.served(d, d.pending[1].kind)
        if p then
          say(("%s: %s served"):format(name(i), p.kind == "stop_go" and "stop-go" or "drive-through"), not car.isAIControlled)
          if car.isAIControlled then AI.pitDone(i) end
        end
      end
    end

    if G.kind == "race" and car.isRaceFinished and not G.finished[i] then
      G.finished[i] = sim.currentSessionTime
      ST.onFinish(d, ctx)
    end

    if car.isAIControlled then
      if G.black[i] then
        AI.parkIfInBox(i, car)
      else
        -- nearest car physically ahead, nearest hazard ahead
        local gap, aheadKmh, hz = nil, nil, nil
        for j, o in pairs(snap) do
          if j ~= i and not o.inPit then
            local dist = S.ahead(s.spline, o.spline, L)
            if dist > 0 and dist < 200 and (not gap or dist < gap) then gap, aheadKmh = dist, o.speed end
          end
        end
        for _, h in ipairs(hazards) do
          local dist = S.ahead(s.spline, h.spline, L)
          if h.id ~= i and (not hz or dist < hz) then hz = dist end
        end
        local gb = nil
        local o = G.yp.open[i]
        if o and G.kind == "race" and snap[o.victim] then gb = snap[o.victim].speed end
        if #d.pending > 0 then AI.requestPit(i) end
        if G.kind == "race" and R.aiPitGuard and not G.finished[i] then
          local sess = ac.getSession(sim.currentSessionIndex)
          local lapsLeft
          if sess and not sess.isTimedRace and (sess.laps or 0) > 0 then
            lapsLeft = math.max(0, sess.laps - car.lapCount)
          else
            lapsLeft = math.ceil((sim.sessionTimeLeft or 0) / 1000 / math.max(60, (car.bestLapTimeMs or 0) / 1000)) + 1
          end
          local msg = AI.pitGuard(i, car, { lapsLeft = lapsLeft, rcWantsPit = #d.pending > 0,
            now = sim.currentSessionTime / 1000, dt = dt })
          if msg then say(("%s: %s"):format(name(i), msg)) end
        end
        AI.apply(i, car, { level = (G.finished[i] or s.inPit or D.isHazard(G.det, i)) and 0 or s.level, hazardAheadM = hz,
          aheadGapM = gap, aheadKmh = aheadKmh, giveBackKmh = gb })
      end
    end

    G.prev[i] = { lap = car.lapCount, inPit = car.isInPitlane }
  end

  -- trace (2 Hz) for tuning: data/trace.csv next to the report
  G.traceT = G.traceT + dt
  if G.traceT >= 0.5 and #G.trace < 200000 then
    G.traceT = 0
    for i, s in pairs(snap) do
      local c = ac.getCar(i)
      G.trace[#G.trace + 1] = ("%.1f,%d,%d,%.4f,%d,%.1f,%s,%d,%d,%d,%d,%d,%d,%.2f,%.3f,%.0f,%.3f"):format(
        sim.currentSessionTime / 1000, i, c.isAIControlled and 1 or 0, s.spline, s.lap, s.speed,
        AI.capOf(i) and ("%.0f"):format(AI.capOf(i)) or "", s.level or 0, D.isHazard(G.det, i) and 1 or 0,
        s.wheelsOut, s.inPit and 1 or 0, c.isInPit and 1 or 0, c.isRequestingPitStop and 1 or 0,
        c.fuel or -1, c.fuelPerLap or -1, c.engineLifeLeft or -1, c.gearboxDamage or -1)
    end
  end

  -- 5. player's HUD flag (AC can show Caution / Stop / ReturnToPits natively)
  local me = snap[0]
  if me and R.useACFlagOverride then
    local flag = ac.FlagType.None
    if G.black[0] then flag = ac.FlagType.Stop
    elseif me.level > 0 then flag = ac.FlagType.Caution
    elseif #G.drivers[0].pending > 0 then flag = ac.FlagType.ReturnToPits end
    if flag ~= G.lastFlag then
      physics.overrideRacingFlag(flag)
      G.lastFlag = flag
    end
  end

  -- 6. end of session
  if sim.isSessionFinished or (G.kind == "race" and G.finished[0] and sim.currentSessionTime - G.finished[0] > 60000) then
    writeReport()
  end
end

-- HUD -----------------------------------------------------------------------------------
function script.rcHud(dt)
  if not G or not G.kind or sim.isOnlineRace then return end
  local me = ac.getCar(0)
  if not me then return end
  local lvl, k = F.levelFor(G.flags, me.splinePosition, sim.trackLengthM)
  if G.playerLevel ~= nil then lvl = G.playerLevel end
  local d = G.drivers[0]
  local carFlag = nil
  if G.black[0] then carFlag = "black"
  elseif d and #d.pending > 0 then carFlag = "drive_through"
  elseif G.bwUntil[0] and sim.currentSessionTime < G.bwUntil[0] then carFlag = "black_white" end
  HUD.draw({
    level = lvl, green = (G.playerGreen and lvl == 0) or false, postName = G.map[k].name, carFlag = carFlag,
    carNumber = "", trackLimits = d and d.trackLimits or 0, timePenaltyS = d and d.timePenaltyS or 0,
    pending = d and #d.pending or 0, messages = G.messages,
  })
end

-- Window: marshal posts + stewards' ledger ---------------------------------------------------
function script.rcWindow(dt)
  if sim.isOnlineRace then ui.text("BRSCC Race Control is offline-only."); return end
  if not G then ui.text("Waiting for session..."); return end
  ui.text(("BRSCC Race Control v%s  |  %s  |  %s"):format(VERSION, G.trackId, G.kind or "unsupported session"))
  if ui.button("Write report now") then writeReport(true) end
  ui.text(" ")

  -- Marshal map builder: drive a slow lap, press the button level with each real marshal post.
  G.edit = G.edit or { posts = {}, name = "" }
  ui.text("MARSHAL MAP BUILDER  (drive a slow lap; mark each post as you pass it)")
  local me = ac.getCar(0)
  if me then
    local newName = ui.inputText("Post name (e.g. Post 3 / Copse)", G.edit.name)
    if newName then G.edit.name = newName end
    if ui.button("Mark post at my car") then
      local nm = (G.edit.name ~= "" and G.edit.name) or ("Post " .. (#G.edit.posts + 1))
      G.edit.posts[#G.edit.posts + 1] = { from = math.floor(me.splinePosition * 10000) / 10000, name = nm }
      G.edit.name = ""
    end
    ui.sameLine()
    if ui.button("Undo") then table.remove(G.edit.posts) end
    ui.sameLine()
    if ui.button("Save map") and #G.edit.posts >= 3 then
      local dir = ac.getFolder(ac.FolderID.ScriptOrigin) .. "/data/tracks"
      io.createDir(dir)
      io.save(dir .. "/" .. G.trackId .. ".json", JSON.stringify({ track = G.trackId, sectors = G.edit.posts }))
      G.map = S.normalise(G.edit.posts)
      G.flags = F.new(G.map)
      say(("Marshal map saved: %d posts for %s"):format(#G.map, G.trackId), true)
    end
    ui.text(("  %d marked, you are at spline %.4f (need 3+ to save)"):format(#G.edit.posts, me.splinePosition))
  end
  ui.text(" ")
  ui.text("MARSHAL POSTS")
  for k, sct in ipairs(G.map) do
    local l = G.flags.level[k]
    local txt = ("  %2d  %-22s %s"):format(k, sct.name, l == 2 and "DOUBLE YELLOW" or l == 1 and "YELLOW" or "-")
    if l > 0 then ui.textColored(txt, rgbm(1, 0.85, 0, 1)) else ui.text(txt) end
  end
  ui.text(" ")
  ui.text("STEWARDS")
  for i = 0, sim.carsCount - 1 do
    local d = G.drivers[i]
    if d and (d.trackLimits > 0 or d.timePenaltyS > 0 or d.penaltyPoints > 0 or d.dsq or #d.pending > 0) then
      ui.text(("  %-24s TL %d  +%ds  PP %d%s%s"):format(name(i), d.trackLimits, d.timePenaltyS, d.penaltyPoints,
        #d.pending > 0 and "  DT pending" or "", d.dsq and "  DSQ" or ""))
    end
  end
  ui.text(" ")
  ui.text("LOG")
  for n = #G.log, math.max(1, #G.log - 25), -1 do ui.text("  " .. G.log[n]) end
end

-- events --------------------------------------------------------------------------------------
ac.onSessionStart(function() init() end)

ac.onCarCollision(-1, function(i)
  if not G or not G.kind then return end
  local car = ac.getCar(i)
  if not car then return end
  local with = car.collidedWith
  G.contacts[#G.contacts + 1] = ("[%s] %s contact with %s at %.3f spline, %.0f km/h, depth %.2f m"):format(
    fmtTime(sim.currentSessionTime), name(i), with == 0 and "track/wall" or name(with - 1),
    car.splinePosition, car.speedKmh, car.collisionDepth)
end)

init()
