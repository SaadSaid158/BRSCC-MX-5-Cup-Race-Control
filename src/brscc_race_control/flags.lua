-- flags.lua: per-sector yellow state from the current hazards. Pure logic, no CSP API.
-- Levels: 0 = green (racing), 1 = single waved yellow, 2 = double waved yellow.
local R = require("rules")
local S = require("sectors")

local M = {}

function M.new(map)
  local st = { map = map, level = {}, hold = {}, green = {} }
  for k = 1, #map do st.level[k], st.hold[k], st.green[k] = 0, 0, 0 end
  return st
end

-- hazards: array of { spline = 0..1, severity = 1|2 }
-- Returns true if any sector's level changed (for logging / messages).
function M.update(st, hazards, dt)
  local map, n = st.map, #st.map
  local want = {}
  for k = 1, n do want[k] = 0 end
  for _, h in ipairs(hazards) do
    local k = S.at(map, h.spline)
    want[k] = math.max(want[k], h.severity)
    if h.severity >= 2 then                       -- NCR App.8 1.8: waved yellow at the post before
      local p = S.prev(map, k)
      want[p] = math.max(want[p], R.yellow.postBeforeDouble)
    end
  end

  local changed = false
  for k = 1, n do
    local cur = st.level[k]
    if want[k] >= cur then
      if want[k] > cur then changed = true end
      st.level[k] = want[k]
      st.hold[k] = R.yellow.clearHoldS
    else
      st.hold[k] = st.hold[k] - dt
      if st.hold[k] <= 0 then
        st.level[k] = want[k]
        changed = true
      end
    end
  end

  -- Green after a yellow sector (NCR App.8 1.8 "waved green immediately after"): informational.
  for k = 1, n do
    local prevYellow = st.level[S.prev(map, k)] > 0
    st.green[k] = (st.level[k] == 0 and prevYellow) and 1 or 0
  end
  return changed
end

-- Effective level for a car at spline s: the flag at its own post, or at the next post if
-- it's within lookAheadM of it (that post's flag is already visible).
function M.levelFor(st, s, lengthM)
  local map = st.map
  local k = S.at(map, s)
  local lvl = st.level[k]
  local nk = S.next(map, k)
  if S.ahead(s, map[nk].from, lengthM) <= R.yellow.lookAheadM then
    lvl = math.max(lvl, st.level[nk])
  end
  return lvl, k
end

function M.any(st)
  for k = 1, #st.map do if st.level[k] > 0 then return true end end
  return false
end

return M
