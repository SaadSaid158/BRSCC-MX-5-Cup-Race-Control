-- stewards.lua: penalty decisions and the per-driver ledger. Pure logic, no CSP API.
-- The caller (main.lua) detects events and acts on the decisions this returns:
-- showing flags, sending the AI to the pits, writing results.
local R = require("rules")

local M = {}

function M.newDriver(id)
  return {
    id = id,
    trackLimits = 0,        -- breaches this race (R.trackLimitsLadder index)
    contactStep = 0,        -- position on R.contactLadder this race
    timePenaltyS = 0,       -- added to elapsed time at the end
    gridDrop = 0,           -- carried to the next race (REGS 4.2.2 / NCR Annexe A 1.7)
    pending = {},           -- unserved drive-through / stop-go: { kind=, notifiedLap= }
    deletedLaps = {},       -- qualifying: lap number -> true
    penaltyPoints = 0,      -- this event; the caller adds it to the season ledger
    dsq = false,
    log = {},               -- evidence trail (REGS 2.13 equivalent)
  }
end

local function record(d, entry)
  d.log[#d.log + 1] = entry
  return entry
end

-- ctx: { session = "practice"|"qualifying"|"race", lap = n, lapsTotal = n|nil,
--        minutesLeft = n|nil, time = t }
local function isLate(ctx)
  local lap = ctx.leaderLap or ctx.lap   -- "last five laps" of the race = the leader's
  if ctx.lapsTotal and ctx.lapsTotal > 0 and (ctx.lapsTotal - lap) < R.lateConversion.lastLaps then return true end
  if ctx.minutesLeft and ctx.minutesLeft < R.lateConversion.lastMinutes then return true end
  return false
end

-- Apply one penalty. kind: "reprimand" | "time" | "drive_through" | "stop_go" | "grid" | "dsq_session"
-- Returns the decision record.
function M.penalise(d, kind, ctx, opts)
  opts = opts or {}
  local dec = { kind = kind, reason = opts.reason, lap = ctx.lap, time = ctx.time, ref = opts.ref }

  if (kind == "drive_through" or kind == "stop_go") and (ctx.session ~= "race" or isLate(ctx)) then
    -- NCR Ch.12 App.10 Art.2.1(l): late or unservable -> time penalty; still 0 penalty points (App.12 1.4)
    dec.convertedFrom = kind
    kind, dec.kind = "time", "time"
    dec.seconds = R.lateConversion.timeS
    dec.pointsKind = dec.convertedFrom
  end

  if kind == "time" then
    dec.seconds = math.min(dec.seconds or opts.seconds or 0, R.maxTimePenaltyS)
    d.timePenaltyS = d.timePenaltyS + dec.seconds
  elseif kind == "drive_through" or kind == "stop_go" then
    d.pending[#d.pending + 1] = { kind = kind, notifiedLap = ctx.lap, seconds = opts.seconds }
  elseif kind == "grid" then
    dec.places = math.min(opts.places or 0, R.maxPlacePenalty)
    d.gridDrop = d.gridDrop + dec.places
  elseif kind == "dsq_session" then
    d.dsq = true
  end

  local pk = dec.pointsKind or kind
  local pts = opts.penaltyPoints
  if pts == nil then pts = R.penaltyPoints[pk] or 0 end
  dec.penaltyPoints = pts
  d.penaltyPoints = d.penaltyPoints + pts
  return record(d, dec)
end

-- Track-limits breach (NCR Ch.12 App.7 Art.1.6 / 1.11).
-- Returns { action=, flag=, decision= } for the caller to act on.
function M.trackLimits(d, ctx)
  if ctx.session == "qualifying" then
    d.deletedLaps[ctx.lap] = true                    -- App.7 1.11(a)
    return { action = "delete_lap", decision = record(d, { kind = "lap_deleted", lap = ctx.lap, time = ctx.time, reason = "track limits" }) }
  elseif ctx.session == "practice" then
    return { action = "none", decision = record(d, { kind = "noted", lap = ctx.lap, time = ctx.time, reason = "track limits" }) }
  end

  -- App.7 1.11: "signals must have been displayed to the driver before moving up the scale".
  -- Signals/boards are shown at the control line, so after a step is issued the car must cross
  -- the line before a further breach can move it up. Breaches in between are logged only.
  if d.tlHoldUntilLap and ctx.lap < d.tlHoldUntilLap then
    d.tlHeld = (d.tlHeld or 0) + 1
    return { action = "held", count = d.trackLimits, decision = record(d, { kind = "noted", lap = ctx.lap,
      time = ctx.time, reason = "track limits (previous signal not yet shown)", ref = "NCR Ch.12 App.7 Art.1.11" }) }
  end

  d.trackLimits = d.trackLimits + 1
  local step = R.trackLimitsLadder[math.min(d.trackLimits, #R.trackLimitsLadder)]
  if step.action ~= "none" then d.tlHoldUntilLap = ctx.lap + 1 end
  local out = { action = step.action, flag = step.flag, count = d.trackLimits }
  local why = { reason = "track limits #" .. d.trackLimits, ref = "NCR Ch.12 App.7 Art.1.11" }

  if step.action == "time" then
    why.seconds = step.seconds
    out.decision = M.penalise(d, "time", ctx, why)
  elseif step.action == "drive_through" then
    out.decision = M.penalise(d, "drive_through", ctx, why)
  elseif step.action == "black" then
    out.decision = M.penalise(d, "dsq_session", ctx, why)
  else
    out.decision = record(d, { kind = step.action, lap = ctx.lap, time = ctx.time, reason = why.reason, ref = why.ref })
  end
  return out
end

-- Contact / driving-standards verdict. verdict: "nfa" | "noted" | "penalty"
function M.contact(d, verdict, ctx, opts)
  opts = opts or {}
  if verdict ~= "penalty" then
    return record(d, { kind = verdict, lap = ctx.lap, time = ctx.time, reason = opts.reason })
  end
  if ctx.session == "practice" then
    return M.penalise(d, "reprimand", ctx, opts)       -- OURS (approved): practice = reprimands only
  end
  if ctx.session == "qualifying" then                   -- REGS 4.2.2: grid penalty up to 10
    opts.places = opts.places or 3
    return M.penalise(d, "grid", ctx, opts)
  end
  d.contactStep = math.min(d.contactStep + 1, #R.contactLadder)
  local step = R.contactLadder[d.contactStep]
  if step == "warning" then
    return record(d, { kind = "warning", lap = ctx.lap, time = ctx.time, reason = opts.reason })
  elseif step == "time5" then
    opts.seconds = 5
    return M.penalise(d, "time", ctx, opts)
  else
    return M.penalise(d, step, ctx, opts)
  end
end

function M.jumpStart(d, ctx)                           -- NCR Ch.12 App.6 Art.7-8
  return M.penalise(d, "time", ctx, { seconds = R.jumpStart.seconds,
    penaltyPoints = R.jumpStart.penaltyPoints, reason = "false start", ref = "NCR Ch.12 App.6 Art.7" })
end

-- Call when the car passes through the pit lane. Returns the served penalty or nil.
function M.served(d, kind)
  for i, p in ipairs(d.pending) do
    if p.kind == kind then
      table.remove(d.pending, i)
      record(d, { kind = "served", what = kind })
      return p
    end
  end
end

-- Call on every lap the car completes. Unserved after R.serveWithinLaps -> R.unservedPenalty.
-- lapsUnderSC still count (NCR Ch.12 App.10 Art.2.1).
function M.onLap(d, ctx)
  for i = #d.pending, 1, -1 do
    local p = d.pending[i]
    if ctx.lap - p.notifiedLap > R.serveWithinLaps then
      table.remove(d.pending, i)
      return M.penalise(d, R.unservedPenalty, ctx, { reason = p.kind .. " not served", ref = "NCR Ch.12 App.10 Art.2.1" })
    end
  end
end

-- Chequered flag with a penalty still pending -> convert to time (App.10 Art.2.1(l), "after the race").
function M.onFinish(d, ctx)
  for i = #d.pending, 1, -1 do
    local p = table.remove(d.pending, i)
    d.timePenaltyS = d.timePenaltyS + R.lateConversion.timeS
    record(d, { kind = "time", seconds = R.lateConversion.timeS, convertedFrom = p.kind, penaltyPoints = 0 })
  end
end

return M
