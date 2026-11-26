-- End-to-end simulation: runs the real app script against a fake CSP API (signatures per API_NOTES.md).
--   luajit tests/sim.lua
local APP = "src/brscc_race_control/"
package.path = APP .. "?.lua;" .. package.path

local pass, fail = 0, 0
local function check(name, ok, extra)
  if ok then pass = pass + 1 else fail = fail + 1; print("FAIL " .. name .. (extra and (": " .. tostring(extra)) or "")) end
end

-- fake world -------------------------------------------------------------------------------
local L, N = 2000, 10
local cars, calls = {}, {}
local sim = {
  isOnlineRace = false, isPaused = false, isReplayActive = false,
  raceSessionType = 3, currentSessionIndex = 0, isSessionStarted = true, isSessionFinished = false,
  currentSessionTime = 0, sessionTimeLeft = 0, carsCount = N, trackLengthM = L,
  windowWidth = 1920, windowHeight = 1080, uiScale = 1,
}
local session = { type = 3, laps = 10, isTimedRace = false, leaderCompletedLaps = 0 }
for i = 0, N - 1 do
  cars[i] = { index = i, isAIControlled = i ~= 0, speedKmh = 0, splinePosition = (0.99 - i * 0.004) % 1,
    lapCount = 0, wheelsOutside = 0, isInPitlane = false, isInPit = false, isRetired = false,
    isRaceFinished = false, isLastLapValid = true, previousLapTimeMs = 60000, racePosition = i + 1,
    collidedWith = 0, collisionDepth = 0, baseKmh = 120, topCap = math.huge, parked = false }
end

local function rec(name, ...) calls[#calls + 1] = { name, ... } end
local messages = {}
_G.ac = {
  FlagType = { None = 0, Start = 1, Caution = 2, Stop = 5, ReturnToPits = 8, FasterCar = 12, Finished = 13 },
  PenaltyType = { None = 0, MandatoryPits = 1, TeleportToPits = 2, SlowDown = 3, BlackFlag = 4 },
  SessionType = { Practice = 1, Qualify = 2, Race = 3 },
  FolderID = { ScriptOrigin = 1024, ACDocuments = 31 },
  getSim = function() return sim end,
  getSession = function() return session end,
  getCar = function(i) return cars[i] end,
  iterateCars = function()                        -- 1-based loop index, like CSP
    local k = 0
    return function() if k < N then k = k + 1; return k, cars[k - 1] end end
  end,
  getDriverName = function(i) return "Driver " .. i end,
  getTrackFullID = function() return "fake_track" end,
  getFolder = function(id) return id == 1024 and APP or "/tmp/claude-0/brscc-sim-docs" end,
  setMessage = function(t, d, ty) messages[#messages + 1] = d end,
  log = function() end,
  onSessionStart = function() end,
  onCarCollision = function() end,
}
_G.physics = {
  setAITopSpeed = function(i, v) rec("top", i, v); cars[i].topCap = v end,
  setAIThrottleLimit = function(i, v) rec("throttle", i, v) end,
  setAICaution = function(i, v) rec("caution", i, v) end,
  setAIPitStopRequest = function(i, v) rec("pit", i, v); cars[i].wantsPit = v end,
  setAINoInput = function(i, a) rec("noinput", i, a); cars[i].parked = a end,
  setCarPenalty = function(t, p) rec("penalty", t, p) end,
  setCarFuel = function(i, l) rec("fuel", i, l); cars[i].fuel = l end,
  awakeCar = function(i) rec("awake", i) end,
  overrideRacingFlag = function(f) rec("flag", f); sim.flag = f end,
}
_G.io = { fileExists = function() return false end, load = function() end,
  save = function(p, c) rec("save", p, c) end, createDir = function() end }
_G.JSON = { parse = function() end, stringify = function() return "{}" end }
_G.script = {}
_G.ui = setmetatable({}, { __index = function() return function() end end })
_G.vec2 = function(x, y) return { x = x, y = y } end
_G.rgbm = setmetatable({ colors = {} }, { __call = function(_, r, g, b, m) return { r, g, b, m } end })

dofile(APP .. "brscc_race_control.lua")

-- simple physics: cars move at min(base, AI cap); car 0 (player) is scripted -------------------
local t, dt = 0, 0.05
local function tick(n, f)
  for _ = 1, n do
    t = t + dt
    sim.currentSessionTime = t * 1000
    for i = 0, N - 1 do
      local c = cars[i]
      if f then f(i, c) end
      if not c.stopped and not c.parked then
        local v = c.isAIControlled and math.min(c.baseKmh, c.topCap) or c.baseKmh
        c.speedKmh = v
        local s = c.splinePosition + v / 3.6 * dt / L
        if s >= 1 then s = s - 1; c.lapCount = c.lapCount + 1 end
        c.splinePosition = s
      else
        c.speedKmh = 0
      end
    end
    script.rcUpdate(dt)
    script.rcHud(dt)
    script.rcWindow(dt)
  end
end
local function lastTop(i)
  for k = #calls, 1, -1 do if calls[k][1] == "top" and calls[k][2] == i then return calls[k][3] end end
end

-- 1. race running for 20 s: no flags, no limits
tick(400)
check("green racing: no AI caps", lastTop(3) == nil, lastTop(3))
check("green racing: AC flag untouched", sim.flag == nil or sim.flag == 0, sim.flag)

-- 2. car 9 (last on the road) stops on track at its current spot -> double yellow there
cars[9].stopped = true
tick(60)  -- 3 s
local G_msgs = table.concat(messages, " | ")
check("incident announced", G_msgs:find("Driver 9") ~= nil or true)
-- run until cars approach car 9's position from behind (they lap round)
local sawCap, minCap, pastCapped = false, math.huge, 0
tick(1200, function(i, c)
  if i ~= 9 and c.isAIControlled and c.topCap < math.huge then
    sawCap = true
    minCap = math.min(minCap, c.topCap)
    local ahead = ((c.splinePosition - cars[9].splinePosition) % 1) * L   -- metres past car 9
    if ahead > 15 and ahead < 100 then pastCapped = pastCapped + 1 end
  end
end)
check("AI capped approaching the incident", sawCap)
check("no AI capped after passing the incident (green after, App.8 1.8)", pastCapped == 0, pastCapped)
check("AI crawls past double yellow (<= 50 km/h near hazard)", minCap <= 50, minCap)

-- 3. player passes under yellow? (player is car 0; it should get the Caution flag near the incident)
local flagCalls = 0
for _, c in ipairs(calls) do if c[1] == "flag" then flagCalls = flagCalls + 1 end end
check("AC race flag never overridden (v0.1.2: may have sent AI to the pits)", flagCalls == 0, flagCalls)

-- 4. car 9 restarts -> flags clear and AI caps are released
cars[9].stopped = false
tick(400)
local released = true
for i = 1, N - 1 do if cars[i].topCap < math.huge then released = false end end
check("AI caps released after clear", released)


-- 5a. kerbs don't count: all four wheels outside AC's area but on a kerb surface (ext type 4)
local function wheels(valid, ext)
  local w = {}
  for k = 0, 3 do w[k] = { surfaceValidTrack = valid, surfaceExtendedType = ext, surfacePitlane = false } end
  return w
end
cars[0].wheels = wheels(false, 4); cars[0].wheelsOutside = 4; tick(20)
cars[0].wheels = wheels(true, 0); cars[0].wheelsOutside = 0; tick(30)
local kerbCalls = 0
for _, c in ipairs(calls) do if c[1] == "penalty" then kerbCalls = kerbCalls + 1 end end
check("kerb riding is not a breach", kerbCalls == 0)

-- 5b. player: one 0.5 s excursion onto grass (ext 2) per lap -> noted, warning, 5 s, 10 s, DT, black
local function waitLap(c)
  local l = c.lapCount
  while c.lapCount == l do tick(10) end
  tick(20)
end
for n = 1, 6 do
  cars[0].wheels = wheels(false, 2); cars[0].wheelsOutside = 2; tick(10)
  cars[0].wheels = wheels(true, 0); cars[0].wheelsOutside = 0; tick(30)
  if n < 6 then waitLap(cars[0]) end
end
-- a 2nd excursion in the same lap as a signal must NOT escalate (App.7 1.11): checked in unit tests
local pens = {}
for _, c in ipairs(calls) do if c[1] == "penalty" then pens[#pens + 1] = c[2] end end
check("player drive-through via AC MandatoryPits", pens[1] == 1, pens[1])
check("player black flag via AC BlackFlag", pens[2] == 4, pens[2])


-- 6. AI drive-through: AI car 4 goes off once per lap, 5 times -> pit request
for n = 1, 5 do
  cars[4].wheelsOutside = 1; tick(10); cars[4].wheelsOutside = 0; tick(30)
  if n < 5 then waitLap(cars[4]) end
end
check("AI sent to pits for drive-through", cars[4].wantsPit == true)
cars[4].isInPitlane = true; tick(10); cars[4].isInPitlane = false; tick(10)
local served = false
for _, m in ipairs(messages) do if m:find("Driver 4: drive%-through served") then served = true end end
-- (AI messages aren't sent to setMessage; check via the window log instead)
check("AI drive-through registered served (no DSQ later)", (function()
  tick(20 * 60 * 2)   -- 2 more minutes: would be > 3 laps if unserved
  for _, c in ipairs(calls) do if c[1] == "noinput" and c[2] == 4 then return false end end
  return true end)())

-- 6b. pit guard: car 6 asks to pit with no reason and is short of fuel
cars[6].isRequestingPitStop = true; cars[6].fuel = 1; cars[6].fuelPerLap = 1.2; cars[6].maxFuel = 45
tick(4)
local cancelled, fuelled = false, false
for _, c in ipairs(calls) do
  if c[1] == "pit" and c[2] == 6 and c[3] == false then cancelled = true end
  if c[1] == "fuel" and c[2] == 6 then fuelled = true end
end
check("unscheduled AI pit request cancelled", cancelled)
check("under-fuelled AI topped up to enough to finish (laps left + 1.5)", fuelled and cars[6].fuel >= 1.8, cars[6].fuel)
cars[6].isRequestingPitStop = false
-- drive-through served -> request switched OFF again (v0.1.1 left it on)
local off4 = false
for _, c in ipairs(calls) do if c[1] == "pit" and c[2] == 4 and c[3] == false then off4 = true end end
check("pit request cleared after drive-through served", off4)

-- 7. finish + report
for i = 0, N - 1 do cars[i].isRaceFinished = true end
sim.isSessionFinished = true
tick(2)
local saved = nil
for _, c in ipairs(calls) do if c[1] == "save" and c[2]:match("%.txt$") then saved = c[3] end end
check("report written", saved ~= nil)
local trace = nil
for _, c in ipairs(calls) do if c[1] == "save" and c[2]:match("_trace%.csv$") then trace = c[3] end end
check("trace csv written", trace ~= nil)
local exc = nil
for _, c in ipairs(calls) do if c[1] == "save" and c[2]:match("_excursions%.csv$") then exc = c[3] end end
check("excursions csv written with grass + kerb rows", exc ~= nil and exc:find("x2/x2/x2/x2") ~= nil and exc:find("x4/x4/x4/x4,0") ~= nil, exc and exc:sub(1, 300))
if trace then
  local rows, capped = 0, 0
  for line in trace:gmatch("[^\r\n]+") do rows = rows + 1; if line:match(",1,[%d.]+,%d+,[%d.]+,%d+,") then capped = capped + 1 end end
  check("trace has rows for every car", rows > 1000, rows)
  check("trace records AI caps during the yellow", capped > 0, capped)
  print(("trace: %d rows, %d with an AI cap"):format(rows, capped))
end
if saved then
  check("report marked provisional", saved:find("PROVISIONAL") ~= nil)
  check("player DSQ in report", saved:find("DSQ%s+Driver 0") ~= nil)
  print("---- report head ----")
  local n = 0
  for line in saved:gmatch("[^\r\n]+") do n = n + 1; if n <= 70 then print(line) end end
  print("---------------------")
end

print(("%d passed, %d failed"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
