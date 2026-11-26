-- redflag.lua: REGS 2.6 / NCR Ch.12 App.6 Art.9. Pure logic, no CSP API.
local R = require("rules")

local M = {}

-- leaderLaps: laps the leader had completed when the red was FIRST shown.
-- progress:   fraction of scheduled distance/duration done (0..1). For a timed race, elapsed / duration.
-- Returns "A" | "B" | "C".
function M.case(leaderLaps, progress)
  if leaderLaps < R.redFlag.caseALeaderLapsBelow then return "A" end   -- REGS 2.6.2: no contest, original grid
  if progress >= R.redFlag.caseCFraction then return "C" end           -- REGS 2.6.4: result, no restart
  return "B"                                                           -- REGS 2.6.3: part 1, restart
end

-- Order of crossing the line at lap L = leaderLaps - 1 (REGS 2.6.3 / NCR App.6 9.1 b,c,e).
-- crossings[id] = { [lap] = timeCrossed, ... }  (lap n complete when crossed for the n-th time)
-- running[id]   = true if the car was moving under its own power at the red (NCR App.8 1.7 j)
-- Returns an array of ids. Cars on lap L first, by crossing time; then cars short of L, by laps
-- desc then by their last crossing time. Non-running cars are left out (not classified).
function M.order(crossings, leaderLaps, running)
  local L = math.max(leaderLaps - 1, 0)
  local rows = {}
  for id, laps in pairs(crossings) do
    if running[id] then
      local n = 0
      for lap in pairs(laps) do if lap <= L and lap > n then n = lap end end
      rows[#rows + 1] = { id = id, laps = n, t = laps[n] or math.huge }
    end
  end
  table.sort(rows, function(a, b)
    if a.laps ~= b.laps then return a.laps > b.laps end
    if a.t ~= b.t then return a.t < b.t end
    return tostring(a.id) < tostring(b.id)
  end)
  local out = {}
  for i, r in ipairs(rows) do out[i] = r.id end
  return out, L
end

-- Who is on the restart grid, and who goes to the pit lane (NCR App.6 Art.9.2).
-- order: from M.order (or the original grid for Case A)
-- state[id] = { repaired = bool, inPitAtRed = bool }
-- Returns gridIds, pitLaneIds (pit-lane cars start after all others).
function M.restartGrid(order, state)
  local grid, pit = {}, {}
  for _, id in ipairs(order) do
    local s = state[id] or {}
    if s.repaired or s.inPitAtRed then            -- 9.2: repaired cars can't return to the grid;
      pit[#pit + 1] = id                          -- REGS 2.6.1: pit-lane cars restart from pit exit
    else
      grid[#grid + 1] = id
    end
  end
  return grid, pit
end

-- Case A: "Gaps on the grid should not be closed up" (REGS 2.6.2).
-- originalGrid: array of ids by slot. available[id] = can restart.
-- Returns slot -> id (nil for an empty slot).
function M.caseAGrid(originalGrid, available)
  local slots = {}
  for slot, id in ipairs(originalGrid) do
    if available[id] then slots[slot] = id end
  end
  return slots
end

-- NCR App.6 9.3(b): if the restart is shortened, the new duration is used for the 75% test.
function M.adjustedProgress(doneLapsOrTime, newTotal)
  return doneLapsOrTime / newTotal
end

return M
