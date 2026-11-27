-- settings.lua: persistent user settings (CSP ac.storage), applied on top of rules.lua.
-- Rule values that come straight from the regs/NCR are NOT exposed here; only our own
-- tuning choices (marked OURS in rules.lua) and display preferences are.
local R = require("rules")

local M = {}

M.defaults = {
  hudMode = "practice",       -- "practice" = full information (mock-ups), "race" = realistic
  hudScale = 1.0,
  hudGlass = true,
  layoutApplied = false,      -- the default panel layout has been placed once (first launch)            -- glass panels (blurred scene behind them); false = solid monitor black
  postsSource = "auto",       -- "auto" = recorded map if one exists, else from geometry; "even"
  trackLimitWheels = 1,       -- NCR App.7 1.6b reading: any wheel beyond (1). 4 = AC's own cut rule
  trackLimitMinS = 0.3,
  aiPitGuard = true,
  aiSingleFactor = 0.85,
  aiDoubleMaxKmh = 100,
}

local store
function M.load()
  if ac and ac.storage and not M.memoryOnly then
    store = ac.storage(M.defaults, "brscc_rc_")
  else
    store = {}
    for k, v in pairs(M.defaults) do store[k] = v end
  end
  M.apply()
  return store
end

function M.get(k) return store[k] end

function M.set(k, v)
  if store[k] ~= v then
    store[k] = v
    M.apply()
    return true
  end
  return false
end

-- Push settings into the shared rules table (modules read R at call time).
function M.apply()
  R.trackLimitWheels = math.max(1, math.min(4, math.floor(store.trackLimitWheels + 0.5)))
  R.trackLimitMinS = store.trackLimitMinS
  R.aiPitGuard = store.aiPitGuard and true or false
  R.aiYellow.singleFactor = store.aiSingleFactor
  R.aiYellow.doubleMaxKmh = store.aiDoubleMaxKmh
end

return M
