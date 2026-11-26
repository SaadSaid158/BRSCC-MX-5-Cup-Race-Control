-- yellowpass.lua: overtaking under yellow (NCR Ch.12 App.8 Art.1.7 e/f, 1.10) and give-back.
-- Pure logic, no CSP API. Works on physical track position, so passing a lapped car counts too.
local R = require("rules")

local M = {}

function M.new()
  return { prevD = {}, open = {} }   -- open[passer] = { victim=, lap=, time= }
end

-- Signed on-track distance from b to a in metres: > 0 means a is physically ahead of b.
local function delta(sa, sb, L)
  local d = (sa - sb) % 1
  if d > 0.5 then d = d - 1 end
  return d * L
end
M.delta = delta

-- cars[id] = { spline=, lap=, inPit=bool, hazard=bool, level=0|1|2 }  (level = flag where the car is)
-- Returns events: { type="pass", passer=, victim= } | { type="given_back", passer=, victim= }
--                 | { type="void", passer= } | { type="expired", passer=, victim= }
function M.update(st, cars, L, now)
  local ev = {}
  local ids = {}
  for id in pairs(cars) do ids[#ids + 1] = id end
  table.sort(ids)
  local W = R.yellow.passWindowM

  for i = 1, #ids do
    for j = i + 1, #ids do
      local a, b = ids[i], ids[j]
      local ca, cb = cars[a], cars[b]
      local key = a .. ":" .. b
      local d = delta(ca.spline, cb.spline, L)
      local p = st.prevD[key]
      st.prevD[key] = d
      if p and math.abs(d) < W and math.abs(p) < W and not ca.inPit and not cb.inPit then
        local passer, victim
        if p < 0 and d >= 0 then passer, victim = a, b
        elseif p > 0 and d <= 0 then passer, victim = b, a end
        if passer then
          local cp, cv = cars[passer], cars[victim]
          local underYellow = math.max(cp.level, cv.level) > 0
          local legit = cv.hazard or cp.hazard          -- passing the stricken car itself is allowed
          if st.open[victim] and st.open[victim].victim == passer then
            -- the wronged car got its place back: that's the give-back, not a new offence
            ev[#ev + 1] = { type = "given_back", passer = victim, victim = passer }
            st.open[victim] = nil
          elseif underYellow and not legit and not st.open[passer] then
            st.open[passer] = { victim = victim, lap = cp.lap, time = now }
            ev[#ev + 1] = { type = "pass", passer = passer, victim = victim }
          end
        end
      end
    end
  end

  for passer, o in pairs(st.open) do
    local cp, cv = cars[passer], cars[o.victim]
    if not cp or not cv or cv.inPit or cv.hazard then
      st.open[passer] = nil
      ev[#ev + 1] = { type = "void", passer = passer }
    elseif delta(cv.spline, cp.spline, L) > 0 and delta(cv.spline, cp.spline, L) < W then
      st.open[passer] = nil                               -- victim is back ahead
      ev[#ev + 1] = { type = "given_back", passer = passer, victim = o.victim }
    elseif cp.lap >= o.lap + R.yellow.giveBackLaps and now - o.time >= 20 then  -- OURS: >= 1 lap and >= 20 s
      st.open[passer] = nil
      ev[#ev + 1] = { type = "expired", passer = passer, victim = o.victim }
    end
  end
  return ev
end

return M
