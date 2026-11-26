-- points.lua: championship points (REGS 1.6, 4.2.4). Pure logic, no CSP API.
local R = require("rules")

local M = {}

-- Points for a finishing position among classified, non-DSQ finishers.
function M.forPosition(pos)
  return math.max(R.points.floor, R.points.first - R.points.step * (pos - 1))
end

-- result: ordered array of { id=, classified=bool, dsq=bool }  (final results order)
-- fastest: { id=, valid=bool } -- valid=false if the lap breached NCR Ch.12 App.7 Art.1.6
-- Returns map id -> points for this race.
function M.race(result, fastest)
  local out, pos = {}, 0
  for _, e in ipairs(result) do
    if e.classified and not e.dsq then
      pos = pos + 1
      out[e.id] = M.forPosition(pos)
    else
      out[e.id] = 0
    end
  end
  -- REGS 1.6.1: fastest lap point, only for a valid lap. OURS: holder must also score (classified, not DSQ)
  if fastest and fastest.valid and out[fastest.id] and out[fastest.id] > 0 then
    out[fastest.id] = out[fastest.id] + R.points.fastestLap
  end
  return out
end

-- rounds: array of { points=, dsq=bool, finalEvent=bool }, one per championship round HELD
--   (rounds a driver missed are included with points = 0)
-- tookPartInFinal: bool. REGS 1.6.2: without it, final-event rounds can't be dropped.
-- penaltyPoints: total NCR penalty points this season. REGS 4.2.4: x3 deducted, can go negative.
-- Returns total, droppedIndices.
function M.season(rounds, tookPartInFinal, penaltyPoints)
  local candidates = {}
  for i, r in ipairs(rounds) do
    local droppable = not r.dsq                                  -- REGS 1.6.2: DSQ rounds can't be dropped
      and not (r.finalEvent and not tookPartInFinal)
    if droppable then candidates[#candidates + 1] = i end
  end
  table.sort(candidates, function(a, b)
    if rounds[a].points ~= rounds[b].points then return rounds[a].points < rounds[b].points end
    return a < b
  end)
  local dropped = {}
  for k = 1, math.min(R.points.dropLowest, #candidates) do dropped[candidates[k]] = true end

  local total = 0
  for i, r in ipairs(rounds) do
    if not dropped[i] then total = total + r.points end
  end
  total = total - R.points.penaltyPointMultiplier * (penaltyPoints or 0)
  return total, dropped
end

return M
