-- sectors.lua: marshal sector map. Pure logic, no CSP API.
-- A map is an array of { from = spline 0..1, name = "Post 3 / Copse" }, sorted by `from`.
-- Sector k runs from map[k].from to map[k+1].from (the last one wraps to the first).
local R = require("rules")

local M = {}

function M.even(n)
  n = n or R.yellow.sectorsDefault
  local map = {}
  for k = 1, n do map[k] = { from = (k - 1) / n, name = "Post " .. k } end
  return map
end

-- Validate and sort a loaded map; fall back to an even split if it's unusable.
function M.normalise(map)
  if type(map) ~= "table" or #map < 3 then return M.even() end
  local out = {}
  for k, s in ipairs(map) do
    local f = tonumber(s.from)
    if not f or f < 0 or f >= 1 then return M.even() end
    out[#out + 1] = { from = f, name = s.name or ("Post " .. k) }
  end
  table.sort(out, function(a, b) return a.from < b.from end)
  return out
end

-- Sector index containing spline position s (0..1).
function M.at(map, s)
  s = s % 1
  local idx = #map                      -- before the first boundary = still in the last sector (wrap)
  for k = 1, #map do
    if map[k].from <= s then idx = k else break end
  end
  return idx
end

function M.next(map, k) return k % #map + 1 end
function M.prev(map, k) return (k - 2) % #map + 1 end

-- Forward distance along the lap from spline a to spline b, in metres.
function M.ahead(a, b, lengthM)
  return ((b - a) % 1) * lengthM
end

return M
