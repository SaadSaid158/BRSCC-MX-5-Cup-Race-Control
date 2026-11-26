-- gaps.lua: interval timing between cars, like timing loops around the lap. Pure logic.
-- Each car records the time it passes each of K checkpoints. The gap from car A (ahead) to car B
-- is: time B reached its latest checkpoint minus the time A reached that same checkpoint.
local M = {}
M.K = 200                           -- checkpoints per lap

function M.new() return { cars = {} } end

-- Call every frame per car. lap = completed laps, spline = 0..1, t = seconds.
function M.update(st, id, lap, spline, t)
  local c = st.cars[id]
  if not c then c = { times = {}, last = nil, cp = nil }; st.cars[id] = c end
  local prog = lap + spline
  if c.last and prog < c.last - 0.5 then prog = prog + 1 end   -- spline wrapped before lap counter
  if c.last and prog > c.last + 0.5 then prog = c.last end      -- lap counter ahead of spline: wait
  c.last = math.max(c.last or prog, prog)
  local cp = math.floor(c.last * M.K)
  if not c.cp then c.cp = cp; c.times[cp] = t; return end
  if cp > c.cp then
    for k = c.cp + 1, cp do c.times[k] = t end
    c.times[cp - 3 * M.K] = nil                                  -- keep ~3 laps
    c.cp = cp
  end
end

-- Interval from `ahead` to `behind` in seconds (positive), or nil. lapsDown if more than a lap apart.
function M.interval(st, ahead, behind)
  local a, b = st.cars[ahead], st.cars[behind]
  if not a or not b or not b.cp then return nil end
  local tb = b.times[b.cp]
  local ta = a.times[b.cp]
  if ta and tb then return tb - ta, 0 end
  -- ahead car is more than one lap ahead at this checkpoint?
  if a.cp and a.cp - b.cp >= M.K then return nil, math.floor((a.cp - b.cp) / M.K) end
  return nil
end

function M.progress(st, id) local c = st.cars[id]; return c and c.last end

return M
