-- compat.lua: CSP version differences and error containment.
--
-- CSP exposes car/sim state as FFI structs: reading a field that doesn't exist in the installed
-- CSP version THROWS instead of returning nil. v0.2.0 read newer fields (isRequestingPitStop,
-- fuelPerLap, ...) on CSP 0.2.11, which aborted the update loop at the first AI car every frame:
-- no AI track limits, no trace. Everything newer than the v0.1.0 field set goes through get().
local M = { missing = {}, errors = {}, errorOrder = {} }

-- Safe field read. Remembers missing fields so the pcall cost is paid once per field name.
function M.get(obj, key, default)
  if M.missing[key] then return default end
  local ok, v = pcall(function() return obj[key] end)
  if not ok then M.missing[key] = true; return default end
  if v == nil then return default end
  return v
end

-- Run fn(...) and contain any error under `where` (logged once per distinct message).
function M.guard(where, fn, ...)
  local ok, err = pcall(fn, ...)
  if not ok then
    local key = where .. ": " .. tostring(err)
    if not M.errors[key] then
      M.errors[key] = 0
      M.errorOrder[#M.errorOrder + 1] = key
      if ac and ac.log then ac.log("BRSCC RC error - " .. key) end
    end
    M.errors[key] = M.errors[key] + 1
  end
  return ok
end

function M.cspVersion()
  local v = "unknown"
  pcall(function() v = tostring(ac.getPatchVersion()) .. " (" .. tostring(ac.getPatchVersionCode()) .. ")" end)
  return v
end

function M.missingList()
  local t = {}
  for k in pairs(M.missing) do t[#t + 1] = k end
  table.sort(t)
  return t
end

return M
