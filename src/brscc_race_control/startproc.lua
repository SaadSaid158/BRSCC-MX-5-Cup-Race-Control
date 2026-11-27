-- startproc.lua: the standing-start sequence (REGS 2.5, NCR Ch.12 App.6). Pure logic, no CSP API.
--
--   1-minute board (start engines, clear the grid) -> 30 s board -> green-flag lap -> cars back on their
--   grid slots -> 5 s board (grid complete) -> board withdrawn -> red lights on 5 s later ->
--   lights out 2-7 s after that = the start.
-- The caller feeds it time and two facts it can only get from the sim: when the green-flag lap is under
-- way, and when the grid is complete again. It returns what to show and whether the race has started.
local R = require("rules")

local M = {}

-- rng: optional function(min, max) -> number, for the lights-out delay (tests pass a fixed one)
function M.new(rng)
  return { phase = "one_minute", t = 0, rng = rng or function(a, b) return a + math.random() * (b - a) end }
end

local function go(st, phase) st.phase, st.t = phase, 0 end

-- ev: { greenLapStarted = bool, gridComplete = bool }
-- returns view: { board = "1 MIN" | "30 SEC" | "5 SEC" | nil, lights = "off" | "red" | "out",
--                 greenLap = bool (no overtaking, pole sets the pace: NCR App.6 6.12), started = bool }
function M.update(st, dt, ev)
  ev = ev or {}
  local S = R.start
  st.t = st.t + dt
  if st.phase == "one_minute" and st.t >= S.oneMinuteS then go(st, "thirty")
  elseif st.phase == "thirty" and (st.t >= S.thirtySecS or ev.greenLapStarted) then go(st, "green_lap")
  elseif st.phase == "green_lap" and ev.gridComplete then go(st, "five")
  elseif st.phase == "five" and st.t >= S.fiveSecBoardS then go(st, "withdrawn")
  elseif st.phase == "withdrawn" and st.t >= S.redLightsAfterBoardS then
    go(st, "red"); st.outAfter = st.rng(S.lightsOutMinS, S.lightsOutMaxS)
  elseif st.phase == "red" and st.t >= st.outAfter then go(st, "racing")
  end
  local p = st.phase
  return {
    board = (p == "one_minute" and "1 MIN") or (p == "thirty" and "30 SEC") or (p == "five" and "5 SEC") or nil,
    lights = (p == "red" and "red") or (p == "racing" and "out") or "off",
    greenLap = p == "green_lap",
    started = p == "racing",
  }
end

-- Jump start (NCR App.6 Art.7-8): from the 5 s board until lights out, a car that has moved more than
-- R.start.jumpMoveM from its grid slot has jumped. movedM: distance from its slot, in metres.
function M.isJump(st, movedM)
  local p = st.phase
  return (p == "five" or p == "withdrawn" or p == "red") and movedM > R.start.jumpMoveM
end

-- REGS 2.5.4: a car that couldn't hold its grid position on the green-flag lap (every other car ahead
-- of it) starts from the back of the last row. order: grid order (names); laggards: set of names.
function M.regrid(order, laggards)
  local front, back = {}, {}
  for _, n in ipairs(order) do
    if laggards[n] then back[#back + 1] = n else front[#front + 1] = n end
  end
  for _, n in ipairs(back) do front[#front + 1] = n end
  return front
end

return M
