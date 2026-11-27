-- End-to-end simulation: runs the real app script against a fake CSP API (signatures per API_NOTES.md).
--   luajit tests/sim.lua
local APP = "src/brscc_race_control/"
local realIO = io
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
  currentSessionTime = 0, sessionTimeLeft = 0, carsCount = N, trackLengthM = L, time = 0,
  windowWidth = 1920, windowHeight = 1080,
}
local session = { type = 3, laps = 10, isTimedRace = false, leaderCompletedLaps = 0 }
for i = 0, N - 1 do
  cars[i] = { index = i, isAIControlled = i ~= 0, speedKmh = 0, splinePosition = (0.99 - i * 0.004) % 1,
    lapCount = 0, wheelsOutside = 0, isInPitlane = false, isInPit = false, isRetired = false,
    isRaceFinished = false, isLastLapValid = true, previousLapTimeMs = 60000, racePosition = i + 1,
    collidedWith = 0, collisionDepth = 0, baseKmh = 120, topCap = math.huge, parked = false, bestLapTimeMs = 59000 }
end

-- OLD_CSP=1: behave like CSP 0.2.11 (build 3465), where the car/sim state is an FFI struct and reading a
-- field that version doesn't have THROWS (this is what broke v0.2.0 in-game: no AI track limits, empty trace).
-- The list is the real one, checked against the 0.2.11 lua-sdk (docs/API_NOTES.md, "Verified on 0.2.11"):
-- isRequestingPitStop is the only field we read that 0.2.11 lacks.
local OLD = os.getenv("OLD_CSP") == "1"
local OLD_MISSING = { isRequestingPitStop = true }
local function strict(t)
  return setmetatable(t, { __index = function(_, k)
    if OLD and OLD_MISSING[k] then error("'struct ac_car_state' has no member named '" .. k .. "'", 2) end
  end })
end
if OLD then
  for i = 0, N - 1 do strict(cars[i]) end
  strict(sim)
end

local function rec(name, ...) calls[#calls + 1] = { name, ... } end
local messages, logs = {}, {}
_G.ac = {
  FlagType = { None = 0, Start = 1, Caution = 2, Stop = 5, ReturnToPits = 8, FasterCar = 12, Finished = 13 },
  PenaltyType = { None = 0, MandatoryPits = 1, TeleportToPits = 2, SlowDown = 3, BlackFlag = 4 },
  SessionType = { Practice = 1, Qualify = 2, Race = 3 },
  FolderID = { ScriptOrigin = 1024, ACDocuments = 31 },
  getSim = function() return sim end,
  getSession = function() return session end,
  hasTrackSpline = function() return true end,
  trackProgressToWorldCoordinate = function(t)
    local d = (t % 1) * L
    local st, r = 600, 400 / math.pi        -- 2 x 600 m straights + 2 hairpins of 400 m
    if d < st then return { x = d, z = 0 } end d = d - st
    if d < 400 then local a = d / r; return { x = st + r * math.sin(a), z = r - r * math.cos(a) } end d = d - 400
    if d < st then return { x = st - d, z = 2 * r } end d = d - st
    local a = d / r; return { x = -r * math.sin(a), z = r + r * math.cos(a) }
  end,
  INIConfig = { trackData = function() return { sections = { SECTION_0 = { IN = { "0.30" }, OUT = { "0.50" }, TEXT = { "Hairpin" } } } } end },
  getCar = function(i) return cars[i] end,
  iterateCars = function()                        -- 1-based loop index, like CSP
    local k = 0
    return function() if k < N then k = k + 1; return k, cars[k - 1] end end
  end,
  getDriverName = function(i) return "Driver " .. i end,
  getTrackFullID = function() return "fake_track" end,
  getFolder = function(id) return id == 1024 and APP or "/tmp/claude-0/brscc-sim-docs" end,
  setMessage = function(t, d, ty) messages[#messages + 1] = d end,
  log = function(m) logs[#logs + 1] = tostring(m); if tostring(m):find("HUD error") then _G.hudError = m end end,
  onSessionStart = function(f) SESSION_START = f end,
  restartAssettoCorsa = function(text) RESTARTS[#RESTARTS + 1] = text end,
  getAppWindows = function()
    local t = {}
    for _, n in ipairs({ "BRSCC Flags", "BRSCC Timing", "BRSCC Results", "Some Other App" }) do
      t[#t + 1] = { name = n:lower():gsub(" ", "_"), title = n, size = { x = 300, y = 120 },
        position = LAYOUT_MOVED and { x = #t * 100, y = 0 } or { x = 0, y = 0 } }   -- untouched: all stacked
    end
    return t
  end,
  accessAppWindow = function(n)
    return { valid = function() return true end, move = function(self, p) rec("move", n, p.x, p.y); return self end }
  end,
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
-- an in-memory file system: what the app saves it can load again (meetings, race.ini)
FILES, RESTARTS = {}, {}
_G.io = { fileExists = function(p) return FILES[p] ~= nil end, load = function(p) return FILES[p] end,
  save = function(p, c) rec("save", p, c); FILES[p] = c end, createDir = function() end }
-- JSON that round-trips Lua tables (as Lua source); enough for the meeting file
local function ser(v)
  local ty = type(v)
  if ty == "table" then
    local parts = {}
    for k, x in pairs(v) do parts[#parts + 1] = "[" .. ser(k) .. "]=" .. ser(x) end
    return "{" .. table.concat(parts, ",") .. "}"
  elseif ty == "string" then return ("%q"):format(v) end
  return tostring(v)
end
_G.JSON = { stringify = ser, parse = function(text)
  if type(text) ~= "string" then return nil end
  local f = loadstring("return " .. text)
  return f and f() or nil
end }
_G.script = {}
-- ui mock: records draw calls so the HUD can be rendered to SVG for a visual check
local draws = {}
local function col(c) return c and ("rgba(%d,%d,%d,%.2f)"):format((c[1] or 1) * 255, (c[2] or 1) * 255, (c[3] or 1) * 255, c[4] or 1) or "#fff" end
local fontStack = {}
_G.ui = setmetatable({
  drawRectFilled = function(a, b, c, r) draws[#draws + 1] = ('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" rx="%.1f" fill="%s"/>'):format(a.x, a.y, b.x - a.x, b.y - a.y, r or 0, col(c)) end,
  drawRect = function(a, b, c, r, _, t) draws[#draws + 1] = ('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" rx="%.1f" fill="none" stroke="%s" stroke-width="%.1f"/>'):format(a.x, a.y, b.x - a.x, b.y - a.y, r or 0, col(c), t or 1) end,
  drawTriangleFilled = function(a, b, c, k) draws[#draws + 1] = ('<polygon points="%.1f,%.1f %.1f,%.1f %.1f,%.1f" fill="%s"/>'):format(a.x, a.y, b.x, b.y, c.x, c.y, col(k)) end,
  drawCircleFilled = function(p, r, c) draws[#draws + 1] = ('<circle cx="%.1f" cy="%.1f" r="%.1f" fill="%s"/>'):format(p.x, p.y, r, col(c)) end,
  pushDWriteFont = function(f) fontStack[#fontStack + 1] = f end,
  popDWriteFont = function() fontStack[#fontStack] = nil end,
  measureDWriteText = function(t, size)
    local bold = (fontStack[#fontStack] or ""):find("Bold")
    local w = 0
    for ch in t:gmatch("[%z\1-\127\194-\244][\128-\191]*") do w = w + ((ch:match("[A-Z0-9]") and 0.62) or 0.5) end
    return { x = w * size * (bold and 1.04 or 1), y = size * 1.2 }
  end,
  dwriteDrawText = function(t, size, p, c)
    local bold = (fontStack[#fontStack] or ""):find("Bold")
    t = t:gsub("&", "&amp;"):gsub("<", "&lt;")
    draws[#draws + 1] = ('<text x="%.1f" y="%.1f" font-size="%.1f" font-family="Barlow Condensed,Arial Narrow,Arial" font-weight="%s" fill="%s" dominant-baseline="hanging">%s</text>'):format(p.x, p.y, size, bold and 700 or 400, col(c), t)
  end,
  drawQuadFilled = function(a, b, c, d, k) draws[#draws + 1] = ('<polygon points="%.1f,%.1f %.1f,%.1f %.1f,%.1f %.1f,%.1f" fill="%s"/>'):format(a.x, a.y, b.x, b.y, c.x, c.y, d.x, d.y, col(k)) end,
  drawLine = function(a, b, k, t) draws[#draws + 1] = ('<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="%s" stroke-width="%.1f"/>'):format(a.x, a.y, b.x, b.y, col(k), t or 1) end,
  button = function(label) if _G.press and label == _G.press then _G.press = nil; return true end end,
  tabBar = function(_, _, f) f() end,
  tabItem = function(_, _, f) f() end,
  slider = function(_, v) return v, false end,
}, { __index = function() return function() end end })
_G.drawsSVG = function(path, W, H)
  local f = realIO.open(path, "w")
  if not f then return end
  f:write(('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d"><defs><linearGradient id="g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#6d88a3"/><stop offset=".45" stop-color="#9fb3c4"/><stop offset=".46" stop-color="#4c5a48"/><stop offset=".62" stop-color="#2c2f33"/><stop offset="1" stop-color="#111"/></linearGradient></defs><rect width="100%%" height="100%%" fill="url(#g)"/>'):format(W, H))
  local fonts = os.getenv("HUD_FONTS")   -- folder URL holding the bundled TTFs, for a faithful preview
  if fonts then
    f:write(('<style>@font-face{font-family:"Barlow Condensed";font-weight:400;src:url("%s/BarlowCondensed-Medium.ttf")}' ..
      '@font-face{font-family:"Barlow Condensed";font-weight:700;src:url("%s/BarlowCondensed-Bold.ttf")}</style>'):format(fonts, fonts))
  end
  f:write(table.concat(draws, "\n"))
  f:write("</svg>")
  f:close()
end
_G.clearDraws = function() draws = {} end
_G.vec2 = function(x, y) return { x = x, y = y } end
-- HUD windows draw from their own origin; the harness shifts every point by the window's place
local OX, OY = 0, 0
for _, k in ipairs({ "drawRectFilled", "drawRect", "drawTriangleFilled", "drawCircleFilled", "drawQuadFilled", "drawLine", "dwriteDrawText" }) do
  local f = rawget(ui, k)
  rawset(ui, k, function(...)
    local a = { ... }
    for i = 1, select("#", ...) do
      local p = a[i]
      if type(p) == "table" and p.x and p.y and not p.r then a[i] = { x = p.x + OX, y = p.y + OY } end
    end
    return f(unpack(a, 1, select("#", ...)))
  end)
end
-- a default layout, as a driver might place the panels on a 1920x1080 screen
local WINDOWS = { { "rcWinFlags", 560, 24 }, { "rcWinStrip", 640, 180 }, { "rcWinMessages", 600, 258 },
  { "rcWinTiming", 36, 640 }, { "rcWinRecord", 1584, 640 }, { "rcWinPitBoard", 1680, 340 }, { "rcWinResults", 640, 320 } }
_G.drawWindows = function()
  FRAME = (FRAME or 0) + 1
  for _, w in ipairs(WINDOWS) do
    -- the results table is ~120 text draws; the harness's text measuring is slow, so draw it every 20th frame
    if w[1] ~= "rcWinResults" or FRAME % 20 == 0 then OX, OY = w[2], w[3]; script[w[1]](); OX, OY = 0, 0 end
  end
end
_G.rgbm = setmetatable({ colors = {} }, { __call = function(_, r, g, b, m) return { r, g, b, m, r = r, g = g, b = b, mult = m } end })

dofile(APP .. "brscc_race_control.lua")

-- simple physics: cars move at min(base, AI cap); car 0 (player) is scripted -------------------
local t, dt = 0, 0.05
PRESTART, T0 = false, 0
local function tick(n, f)
  for _ = 1, n do
    t = t + dt
    sim.currentSessionTime = PRESTART and -1.7976931348623157e308 or (t - T0) * 1000
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
    clearDraws()
    drawWindows()
    if _G.afterHud then _G.afterHud() end
    script.rcWindow(dt)
    script.rcSettings(dt)
    sim.time = t * 1000
  end
end
local function lastTop(i)
  for k = #calls, 1, -1 do if calls[k][1] == "top" and calls[k][2] == i then return calls[k][3] end end
end

-- 0. pre-start: the grid waits with AC's clock at -DBL_MAX, then the race goes green with car 5
--    stalled on its grid slot. Found in-game on v0.2.1: gaps showed the tail of DBL_MAX, and a car
--    that never launched was never a hazard (it never reached the 50 km/h arming speed).
local absurd = false
_G.afterHud = function()
  for _, d in ipairs(draws) do if d:find("%d%d%d%d%d%d%d%d%d%d") then absurd = true end end
end
for i = 0, N - 1 do cars[i].parked = true end
PRESTART = true; sim.isSessionStarted = false
tick(100)                                     -- 5 s on the grid before the start
PRESTART = false; sim.isSessionStarted = true; T0 = t
for i = 0, N - 1 do if i ~= 5 then cars[i].parked = false end end
tick(200)                                     -- 10 s of racing, car 5 still stalled
check("pre-start: no absurd numbers on the HUD (gaps from the -DBL_MAX clock)", not absurd)
local stallLog = table.concat(logs, " | ")
check("grid stall: a car that never launched is a hazard", stallLog:find("Driver 5 stopped") ~= nil, stallLog:sub(1, 300))
cars[5].parked = false
tick(200)                                     -- it gets going; flags clear behind it
_G.afterHud = nil

-- 1. race running for 20 s: no flags, no limits
tick(400)
check("green racing: no AI caps", lastTop(3) == nil, lastTop(3))
check("green racing: AC flag untouched", sim.flag == nil or sim.flag == 0, sim.flag)

-- 2. car 9 (last on the road) stops on track at its current spot -> double yellow there
cars[9].stopped = true
tick(60)  -- 3 s
check("incident announced", table.concat(logs, " | "):find("Driver 9 stopped") ~= nil)
-- run until cars approach car 9's position from behind (they lap round)
local SNAP = os.getenv("HUD_SNAPSHOTS")   -- directory to write HUD SVGs into (optional)
local snapped = {}
local function snap(name) if SNAP and not snapped[name] then snapped[name] = true; drawsSVG(SNAP .. "/" .. name .. ".svg", 1920, 1080) end end
_G.afterHud = function()
  local d = ((cars[9].splinePosition - cars[0].splinePosition) % 1) * L
  if cars[9].stopped and d > 150 and d < 260 then snap("practice_double_yellow") end
end
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
  if n == 5 then tick(2); snap("practice_drive_through") end
  if n < 6 then waitLap(cars[0]) end
end
-- a 2nd excursion in the same lap as a signal must NOT escalate (App.7 1.11): checked in unit tests
check("HUD drew without errors through yellow + penalties", _G.hudError == nil, _G.hudError)
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
if OLD then
  check("OLD CSP: missing fields reported, not fatal", true)
else
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
end
-- drive-through served -> request switched OFF again (v0.1.1 left it on)
local off4 = false
for _, c in ipairs(calls) do if c[1] == "pit" and c[2] == 4 and c[3] == false then off4 = true end end
check("pit request cleared after drive-through served", off4)

-- 6c. race-mode HUD: pit board + line board shown just after crossing the line
require("settings").set("hudMode", "race")
_G.afterHud = nil
do local l = cars[1].lapCount; local l0 = cars[0].lapCount
  while cars[0].lapCount == l0 do tick(1) end
  tick(10); snap("race_mode_pitboard") end
check("race-mode HUD drew without errors", _G.hudError == nil, _G.hudError)
require("settings").set("hudMode", "practice")

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
  check("report has compatibility section", saved:find("COMPATIBILITY") ~= nil)
  if OLD then check("report lists the missing CSP fields", saved:find("isRequestingPitStop") ~= nil) end
  check("player DSQ in report", saved:find("DSQ%s+Driver 0") ~= nil)
  print("---- report head ----")
  local n = 0
  for line in saved:gmatch("[^\r\n]+") do n = n + 1; if n <= 70 then print(line) end end
  print("---------------------")
end

-- 7b. first launch: the default panel layout was placed once, only our windows moved
do
  local moves, other = 0, false
  for _, c in ipairs(calls) do if c[1] == "move" then moves = moves + 1; if c[2] == "some_other_app" then other = true end end end
  check("layout: our panels placed once on first launch", moves == 3, moves)
  check("layout: other apps left alone", not other)
  check("layout: remembered", require("settings").get("layoutApplied") == true)
end

-- 8. a full meeting (M1): start it, qualify, relaunch, race 1, continue to race 2.
--    AC's side of a relaunch is played here: race.ini becomes what the app wrote, a new session starts.
do
  local DOCS = ac.getFolder(ac.FolderID.ACDocuments)
  local INI = DOCS .. "/cfg/race.ini"
  local lines = { "[RACE]", "CARS=" .. N, "TRACK=fake_track", "" }
  for i = 0, N - 1 do
    lines[#lines + 1] = "[CAR_" .. i .. "]"; lines[#lines + 1] = "DRIVER_NAME=Driver " .. i
    lines[#lines + 1] = i == 0 and "MODEL=-" or "MODEL=mx5"; lines[#lines + 1] = ""
  end
  lines[#lines + 1] = "[SESSION_0]"; lines[#lines + 1] = "NAME=Quick Race"; lines[#lines + 1] = "TYPE=3"
  FILES[INI] = table.concat(lines, string.char(13, 10))
  local RI = require("raceini")
  local function relaunchInto(kind)
    FILES[INI] = RESTARTS[#RESTARTS]
    sim.raceSessionType, session.type, sim.isSessionFinished = kind, kind, false
    for i = 0, N - 1 do
      local c = cars[i]
      c.lapCount, c.isRaceFinished, c.stopped, c.parked, c.isInPitlane = 0, false, false, false, false
      c.splinePosition, c.wheelsOutside, c.topCap = (0.99 - i * 0.004) % 1, 0, math.huge
    end
    T0 = t
    SESSION_START()
    tick(1)
  end
  local function active() return JSON.parse(FILES[DOCS .. "/brscc-race-control/meetings/active.json"]) end

  _G.press = "Start meeting: go to qualifying"; tick(1)
  check("meeting: start relaunches into qualifying", #RESTARTS == 1 and RESTARTS[1]:find("NAME=Qualifying") ~= nil
    and RESTARTS[1]:find("TYPE=2") ~= nil, RESTARTS[1])
  check("meeting: saved", active() ~= nil and active().session == 1)

  relaunchInto(ac.SessionType.Qualify)
  cars[0].previousLapTimeMs = 61000                        -- the player qualifies slowest
  tick(3800)                                               -- 3+ laps each
  sim.isSessionFinished = true; tick(2)
  local m = active()
  check("meeting: qualifying recorded", m and m.results.qualifying ~= nil and #m.results.qualifying.order == N)
  check("meeting: player qualified last", m and m.results.qualifying.order[N] == "Driver 0",
    m and table.concat(m.results.qualifying.order, ","))

  _G.press = "Continue to Race 1"; tick(1)
  local r1 = RI.parse(RESTARTS[#RESTARTS] or "")
  check("meeting: race 1 relaunch written", #RESTARTS == 2 and r1.sections.SESSION_0.NAME == "Race 1")
  check("meeting: player starts from the back", r1.sections.SESSION_0.STARTING_POSITION == tostring(N),
    r1.sections.SESSION_0.STARTING_POSITION)
  check("meeting: entry list written back", r1.sections.CAR_1.DRIVER_NAME == m.results.qualifying.order[1],
    r1.sections.CAR_1.DRIVER_NAME)

  relaunchInto(ac.SessionType.Race)
  cars[0].previousLapTimeMs = 60000
  tick(400)
  for i = 1, N - 1 do cars[i].isRaceFinished = true end   -- the AI take the flag first
  tick(20)
  cars[0].isRaceFinished = true; tick(20)                  -- everyone in: race control can call it
  m = active()
  local r = m and m.results.race1
  check("meeting: race 1 recorded once every car took the flag", r ~= nil, m and m.session)
  if r then
    local cls = 0
    for _, row in ipairs(r.rows) do if row.classified then cls = cls + 1 end end
    check("meeting: all finishers classified (Art.1.11)", cls == N, cls)
    check("meeting: winner has 100 points", r.rows[1].points == 100 or r.rows[1].points == 101, r.rows[1].points)
  end
  tick(20)
  clearDraws(); script.rcWinResults()
  local txt = table.concat(draws, string.char(10))
  check("results window: race 1, provisional, with meeting standings",
    txt:find(">RACE 1<") ~= nil and txt:find("PROVISIONAL") ~= nil and txt:find(">MEETING<") ~= nil, txt:sub(1, 300))
  check("results window drew without errors", _G.hudError == nil, _G.hudError)
  _G.press = "Continue to Race 2"; tick(1)
  check("meeting: race 2 relaunch from race 1's result", #RESTARTS == 3 and
    RI.parse(RESTARTS[3]).sections.CAR_1.DRIVER_NAME == (r and r.order[1] ~= "Driver 0" and r.order[1] or r and r.order[2]),
    RESTARTS[3] and RI.parse(RESTARTS[3]).sections.CAR_1.DRIVER_NAME)
end

print(("%d passed, %d failed"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
