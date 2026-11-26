-- detect.lua: hazard (stopped / off-track car) and track-limit detection. Pure logic, no CSP API.
-- Input per car each frame: { spline=, speed=kmh, wheelsOut=0..4, inPit=bool, retired=bool }
local R = require("rules")

local M = {}

function M.new() return { cars = {} } end

local car
-- Race start: every car on the grid gets a grid-stall clock. A car that gets away arms normally
-- (armedAboveKmh); one still crawling after gridStallS is armed there, so a stalled car is a hazard.
function M.raceStarted(st, cars)
  for id, s in pairs(cars) do
    local c = car(st, id)
    if not s.inPit then c.gridT = 0 end
  end
end

car = function(st, id)
  local c = st.cars[id]
  if not c then
    c = { armed = false, slowT = 0, okT = 0, hazard = 0, tlArmed = true, tlOkT = 0 }
    st.cars[id] = c
  end
  return c
end

-- Returns hazards (array of { id=, spline=, severity= }) and newHazards (ids that just became one).
function M.hazards(st, cars, dt)
  local Y = R.yellow
  local list, fresh = {}, {}
  for id, s in pairs(cars) do
    local c = car(st, id)
    if s.speed > Y.armedAboveKmh and not s.inPit then c.armed = true end
    if c.gridT and not c.armed then
      if s.speed > Y.stoppedKmh or s.inPit then c.gridT = nil
      else
        c.gridT = c.gridT + dt
        if c.gridT >= Y.gridStallS then c.armed, c.gridT = true, nil end
      end
    end
    local sev = 0
    if c.armed and not s.inPit and not s.retired then
      local off = s.wheelsOut >= Y.offTrackWheels
      if s.speed < Y.stoppedKmh then
        c.slowT = c.slowT + dt
        if c.slowT >= Y.stoppedForS then
          sev = off and 1 or 2         -- stopped ON track = double; stopped off it = single (App.8 1.8)
        end
      else
        c.slowT = 0
        if off and s.speed < Y.offTrackSlowKmh then sev = 1 end   -- slow / spinning off track
      end
    else
      c.slowT = 0
    end

    if sev > 0 then
      if c.hazard == 0 then fresh[#fresh + 1] = id end
      c.hazard = math.max(c.hazard, sev)
      c.okT = 0
    elseif c.hazard > 0 then
      -- clear once it's driving normally again, or it's reached the pits / retired
      if s.inPit or s.retired then
        c.hazard = 0
      elseif s.speed > Y.clearAboveKmh and s.wheelsOut < Y.offTrackWheels then
        c.okT = c.okT + dt
        if c.okT >= Y.clearForS then c.hazard, c.okT = 0, 0 end
      else
        c.okT = 0
      end
    end
    if c.hazard > 0 then list[#list + 1] = { id = id, spline = s.spline, severity = c.hazard } end
  end
  return list, fresh
end

function M.isHazard(st, id) return st.cars[id] ~= nil and st.cars[id].hazard > 0 end

-- Track limits (NCR Ch.12 App.7 Art.1.6b): one breach per excursion.
-- Returns true on the frame a new breach starts.
function M.trackLimit(st, id, s, dt)
  local c = car(st, id)
  if s.inPit or s.speed < R.trackLimitMinKmh or c.hazard > 0 then
    c.tlOkT = 0
    return false
  end
  local beyond = s.beyond or s.wheelsOut      -- per-wheel surface count when available
  if beyond >= R.trackLimitWheels then
    c.tlOkT = 0
    c.tlOutT = (c.tlOutT or 0) + dt
    if c.tlArmed and c.tlOutT >= R.trackLimitMinS then
      c.tlArmed = false
      return true
    end
  else
    c.tlOutT = 0
    c.tlOkT = c.tlOkT + dt
    if c.tlOkT >= R.trackLimitRearmS then c.tlArmed = true end
  end
  return false
end

return M
