-- blueflags.lua: blue flags for a car about to be lapped (NCR Ch.12 App.8 1.7 b/c, App.7 1.5). Pure logic.
-- The BRSCC regs say nothing on blue flags, so the NCR applies: stationary blue = a faster car is close
-- behind; waved blue = it's trying to pass, let it by at the first opportunity.
local R = require("rules")

local M = {}

function M.new() return { cars = {} } end

-- gapS: seconds the lapping car is behind this car (nil = no lapping car near).
-- Returns "stationary", "waved" or nil.
function M.signal(gapS)
  if not gapS then return nil end
  if gapS <= R.blue.wavedGapS then return "waved" end
  if gapS <= R.blue.stationaryGapS then return "stationary" end
  return nil
end

-- Track one lapped car. Call when it passes a marshal post (post index). sig: what that post shows.
-- Returns true once, when a waved blue has been shown at R.blue.ignoredPosts posts in a row without
-- the car letting the lapping car by (for the stewards to look at).
function M.atPost(st, id, post, sig)
  local c = st.cars[id]
  if not c then c = { waved = 0, reported = false, lastPost = nil }; st.cars[id] = c end
  if post == c.lastPost then return false end
  c.lastPost = post
  if sig == "waved" then c.waved = c.waved + 1 else c.waved = 0; c.reported = false end
  if c.waved >= R.blue.ignoredPosts and not c.reported then c.reported = true; return true end
  return false
end

return M
