-- ai.lua: makes AI cars obey race control. CSP API (see API_NOTES.md).
local R = require("rules")

local M = {}
local cars = {}   -- [i] = { limited=bool, entry=kmh, lastLevel=0, pitRequested=bool, parked=bool }

local function get(i)
  local c = cars[i]
  if not c then c = { limited = false, entry = 0, lastLevel = 0 }; cars[i] = c end
  return c
end

local function release(i, c)
  physics.setAITopSpeed(i, math.huge)
  physics.setAIThrottleLimit(i, 1)
  physics.setAICaution(i, 1)
  c.limited = false
end

-- ctx = { level = 0|1|2, hazardAheadM = number|nil, aheadGapM = number|nil, aheadKmh = number|nil,
--         giveBackKmh = number|nil (speed of the car it must let back past) }
function M.apply(i, car, ctx)
  local c = get(i)
  if c.parked then return end
  local A = R.aiYellow
  local cap = math.huge

  if ctx.level > 0 then
    if c.lastLevel == 0 then c.entry = math.max(car.speedKmh, 60) end
    if ctx.level == 1 then
      cap = math.max(A.singleMinKmh, c.entry * A.singleFactor)
    else
      cap = math.min(A.doubleMaxKmh, math.max(A.doubleMinKmh, c.entry * A.doubleFactor))
      if ctx.hazardAheadM and ctx.hazardAheadM < A.nearIncidentM then cap = math.min(cap, A.nearIncidentKmh) end
    end
    -- NCR App.8 1.7 e/f: no overtaking. Don't close on the car ahead inside the zone.
    -- Match (never undercut) its speed, or a queue slows a little more at every car.
    if ctx.aheadGapM and ctx.aheadGapM < A.followGapM and ctx.aheadKmh then
      cap = math.min(cap, math.max(ctx.aheadKmh, 20))
    end
  end
  c.lastLevel = ctx.level

  if ctx.giveBackKmh then
    cap = math.min(cap, math.max(ctx.giveBackKmh * A.giveBackFactor, 30))
  end

  c.cap = cap
  if cap < math.huge then
    physics.setAITopSpeed(i, cap)
    if ctx.level > 0 then physics.setAICaution(i, A.caution) end
    c.limited = true
  elseif c.limited then
    release(i, c)
  end
end

-- Current cap for the trace file (nil = not limited).
function M.capOf(i)
  local c = cars[i]
  return c and c.limited and c.cap or nil
end

-- Drive-through / stop-go / black / black-orange: send the AI to the pits.
function M.requestPit(i)
  local c = get(i)
  if not c.pitRequested then
    physics.setAIPitStopRequest(i, true)
    c.pitRequested = true
  end
end

function M.pitDone(i)
  local c = get(i)
  c.pitRequested = false
  physics.setAIPitStopRequest(i, false)   -- v0.1.1 bug: left on, so the car kept pitting
end

-- Pit guard (race only). BRSCC sprint races have no scheduled stops, so an AI car pits only when
-- race control sends it (penalty / black flag). Anything else is logged with the likely cause and
-- cancelled. ctx = { lapsLeft = n, rcWantsPit = bool, now = s }
-- Returns a diagnostic string the first time a car tries an unscheduled stop, else nil.
local function diag(car)
  local wear = 0
  pcall(function() for w = 0, 3 do wear = math.max(wear, car.wheels[w].tyreWear or 0) end end)
  local dmg = 0
  pcall(function() for z = 0, 3 do dmg = math.max(dmg, car.damage[z] or 0) end end)
  return ("fuel %.1f L (%.2f L/lap), engine life %.0f/1000, gearbox dmg %.2f, body dmg %.0f, tyre wear %.0f%%"):format(
    car.fuel or -1, car.fuelPerLap or -1, car.engineLifeLeft or -1, car.gearboxDamage or -1, dmg, wear * 100)
end
M.diag = diag

function M.pitGuard(i, car, ctx)
  local c = get(i)
  if ctx.rcWantsPit or c.parked then c.guardActive = false; return nil end
  local msg = nil
  -- Fuel: a real car starts with enough for the race. Only top up if AC under-fuelled the AI.
  local fpl = car.fuelPerLap or 0
  if fpl > 0 and car.maxFuel and car.maxFuel > 0 and ctx.lapsLeft then
    local need = fpl * (ctx.lapsLeft + 1.5)
    if car.fuel < need and (not c.fuelT or ctx.now - c.fuelT > 10) then
      c.fuelT = ctx.now
      physics.setCarFuel(i, math.min(car.maxFuel, need + fpl))
      if not c.fuelNoted then c.fuelNoted = true; msg = "under-fuelled by AC, topped up: " .. diag(car) end
    end
  end
  if car.isRequestingPitStop or (car.isInPitlane and not car.isInPit and not c.guardActive) then
    physics.setAIPitStopRequest(i, false)
    if not c.guardActive then
      c.guardActive = true
      msg = "unscheduled pit attempt cancelled: " .. diag(car)
    end
  elseif not car.isInPitlane then
    c.guardActive = false
  end
  -- Sitting in its box with no reason: ask it to leave.
  if car.isInPit and car.speedKmh < 1 then
    c.boxT = (c.boxT or 0) + (ctx.dt or 0)
    if c.boxT > 15 and not c.releaseTried then
      c.releaseTried = true
      physics.setAIPitStopRequest(i, false)
      physics.awakeCar(i)
      msg = "stuck in its pit box with no race-control reason - released: " .. diag(car)
    end
  else
    c.boxT, c.releaseTried = 0, false
  end
  return msg
end

-- Black flag (DSQ): once in its pit box, park it.
function M.parkIfInBox(i, car)
  local c = get(i)
  if c.parked then return true end
  if car.isInPit or (car.isInPitlane and car.speedKmh < 5) then   -- in its box, or stopped in the lane
    physics.setAINoInput(i, true, false)
    c.parked = true
    return true
  end
  M.requestPit(i)
  return false
end

-- Give every car back to AC (session change / app unload).
function M.releaseAll()
  for i, c in pairs(cars) do
    if c.limited then release(i, c) end
    if c.parked then physics.setAINoInput(i, false, false) end
  end
  cars = {}
end

return M
