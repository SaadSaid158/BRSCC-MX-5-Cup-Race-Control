-- meeting.lua: a BRSCC race meeting across sessions. Pure logic, no CSP API; the main script saves
-- it as JSON and relaunches AC between sessions (raceini.lua).
--
-- REGS 2.3.3: qualifying, then races 1, 2 and 3. Race 1's grid is the qualifying order, race 2's is
-- race 1's result and race 3's is race 2's result.
-- Drivers are identified by name: CM renames the AI at every launch, so the meeting owns the entry
-- list and writes it back each time.
local R = require("rules")
local P = require("points")

local M = {}

M.SESSIONS = {
  { key = "qualifying", name = "Qualifying", type = 2 },
  { key = "race1", name = "Race 1", type = 3 },
  { key = "race2", name = "Race 2", type = 3 },
  { key = "race3", name = "Race 3", type = 3 },
}

-- entries: from raceini.entries (player first). opts: { qualiMinutes=, raceLaps= } (OURS: the
-- regulations set race length per event in the Final Instructions; the driver picks them here).
function M.new(id, track, entries, opts)
  local m = { id = id, track = track, entries = entries, session = 1, results = {}, grids = {},
    opts = { qualiMinutes = opts and opts.qualiMinutes or 15, raceLaps = opts and opts.raceLaps or 10 },
    drivers = {} }
  for _, e in ipairs(entries) do m.drivers[e.name] = { points = 0, penaltyPoints = 0, gridDrop = 0 } end
  return m
end

function M.current(m) return M.SESSIONS[m.session] end
function M.finished(m) return m.session > #M.SESSIONS end

-- the session to write into race.ini
function M.spec(m)
  local s = M.current(m)
  if not s then return nil end
  if s.type == 2 then return { name = s.name, type = 2, minutes = m.opts.qualiMinutes } end
  return { name = s.name, type = 3, laps = m.opts.raceLaps, raceLaps = m.opts.raceLaps }
end

-- Grid drops (REGS 4.2.2 / NCR Ch.2 Annexe A 1.3a, at most R.maxPlacePenalty places). A drop that
-- runs past the back of the grid puts the driver last. OURS: penalties are applied front to back.
function M.applyGridDrops(order, drops)
  local grid = {}
  for i, n in ipairs(order) do grid[i] = n end
  for _, n in ipairs(order) do
    local drop = math.min(drops[n] or 0, R.maxPlacePenalty)
    if drop > 0 then
      local at
      for i, x in ipairs(grid) do if x == n then at = i end end
      table.remove(grid, at)
      table.insert(grid, math.min(at + drop, #grid + 1), n)
    end
  end
  return grid
end

-- Qualifying. rows: { name=, bestMs= (best valid lap or nil), laps= (laps completed) }
-- REGS 2.3.2: fewer than R.minQualifyingLaps laps -> start from the back (in best-time order).
function M.recordQualifying(m, rows)
  local ok, short = {}, {}
  for _, r in ipairs(rows) do
    if (r.laps or 0) >= R.minQualifyingLaps then ok[#ok + 1] = r else short[#short + 1] = r end
  end
  local function byBest(a, b)
    if (a.bestMs ~= nil) ~= (b.bestMs ~= nil) then return a.bestMs ~= nil end
    if a.bestMs and a.bestMs ~= b.bestMs then return a.bestMs < b.bestMs end
    return a.name < b.name
  end
  table.sort(ok, byBest); table.sort(short, byBest)
  local order = {}
  for _, r in ipairs(ok) do order[#order + 1] = r.name end
  for _, r in ipairs(short) do order[#order + 1] = r.name end
  m.results.qualifying = { order = order, rows = rows }
  return order
end

-- Race classification, NCR Ch.12 App.9 Art.1.11: classified if the car covered at least 80% of the
-- winner's laps (decimals disregarded) and crossed the finish line, not in the pit lane, under its own
-- power within four minutes of the winner.
-- rows: { name=, laps=, finishMs= (session time it took the flag; nil if it didn't), penaltyS=,
--         dsq=, bestMs= (best valid lap) }
-- Returns ordered rows with .classified and .points; also stores them in the meeting.
function M.classifyRace(rows)
  local out = {}
  for _, r in ipairs(rows) do out[#out + 1] = r end
  local function key(r) return r.finishMs and (r.finishMs + (r.penaltyS or 0) * 1000) or nil end
  table.sort(out, function(a, b)
    if (a.dsq or false) ~= (b.dsq or false) then return not a.dsq end
    if a.laps ~= b.laps then return a.laps > b.laps end
    local ka, kb = key(a), key(b)
    if ka and kb and ka ~= kb then return ka < kb end
    if (ka ~= nil) ~= (kb ~= nil) then return ka ~= nil end
    return a.name < b.name
  end)
  local winner
  for _, r in ipairs(out) do if not r.dsq and r.finishMs then winner = r; break end end
  local minLaps = winner and math.floor(winner.laps * R.classification.minFraction) or math.huge
  for _, r in ipairs(out) do
    r.classified = winner ~= nil and not r.dsq and r.finishMs ~= nil and r.laps >= minLaps
      and r.finishMs - winner.finishMs <= R.classification.afterWinnerS * 1000
  end
  local fastest
  for _, r in ipairs(out) do
    if r.bestMs and not r.dsq and (not fastest or r.bestMs < fastest.bestMs) then fastest = r end
  end
  local res = {}
  for _, r in ipairs(out) do res[#res + 1] = { id = r.name, classified = r.classified, dsq = r.dsq } end
  local pts = P.race(res, fastest and { id = fastest.name, valid = true } or nil)
  for _, r in ipairs(out) do r.points = pts[r.name] or 0 end
  return out, fastest and fastest.name or nil
end

-- Record the current race: classification, points, and the order the next grid comes from.
function M.recordRace(m, rows)
  local s = M.current(m)
  local out, fastest = M.classifyRace(rows)
  local order = {}
  for _, r in ipairs(out) do
    order[#order + 1] = r.name
    local d = m.drivers[r.name]
    if d then d.points = d.points + r.points end
  end
  m.results[s.key] = { order = order, rows = out, fastest = fastest }
  return out
end

-- Carry this session's stewards' ledger: penalty points accumulate; grid drops wait for the next race.
function M.carryLedger(m, ledger)
  for name, l in pairs(ledger or {}) do
    local d = m.drivers[name]
    if d then
      d.penaltyPoints = d.penaltyPoints + (l.penaltyPoints or 0)
      d.gridDrop = d.gridDrop + (l.gridDrop or 0)
    end
  end
end

-- Move to the next session and work out its grid (nil for qualifying: cars leave the pits).
function M.advance(m)
  local prev = M.current(m)
  m.session = m.session + 1
  local s = M.current(m)
  if not s or s.type ~= 3 then return nil end
  local from = m.results[prev.key]
  local order = from and from.order or {}
  local drops = {}
  for name, d in pairs(m.drivers) do drops[name] = d.gridDrop; d.gridDrop = 0 end
  local grid = M.applyGridDrops(order, drops)
  m.grids[s.key] = grid
  return grid
end

-- Meeting standings: points across the races so far, highest first.
function M.standings(m)
  local t = {}
  for name, d in pairs(m.drivers) do t[#t + 1] = { name = name, points = d.points, penaltyPoints = d.penaltyPoints } end
  table.sort(t, function(a, b)
    if a.points ~= b.points then return a.points > b.points end
    return a.name < b.name
  end)
  return t
end

return M
