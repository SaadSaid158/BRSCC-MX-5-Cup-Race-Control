-- autoposts.lua: automatic marshal-post map from track geometry. Pure logic, no CSP API.
--
-- UK circuits place marshal posts so each one can see the approach to the next hazard: one
-- before every corner, with straights covered at intervals. We approximate that from the AI
-- line: find the corners from curvature, put a post a little before each corner entry,
-- then fill long gaps and merge posts that would be too close together.
--
-- build(pos, lengthM, opts) where
--   pos(t) -> x, z     world position of the AI line at lap progress t (0..1)
--   lengthM            lap length in metres
--   opts.sections      optional { { from=, to=, name= } } corner names (sections.ini), spline 0..1
-- returns a map { { from = 0..1, name = "Post 3 · Copse" }, ... } sorted by `from`.
local M = {}

M.cfg = {
  samples = 720,          -- curvature samples around the lap
  windowM = 20,           -- heading-change window for curvature
  turnDegPerM = 0.25,     -- above this the line is "in a corner" (~230 m radius)
  minCornerDeg = 20,      -- ignore kinks smaller than this in total
  mergeCornersM = 60,     -- corners closer than this are one complex
  postBeforeM = 40,       -- post sits this far before the corner entry
  minSpacingM = 120,      -- posts closer than this merge
  maxSpacingM = 350,      -- gaps longer than this get extra posts
}

local function wrapAngle(a)
  while a > math.pi do a = a - 2 * math.pi end
  while a < -math.pi do a = a + 2 * math.pi end
  return a
end

-- Returns corners { { s0=, s1=, deg= } } (spline 0..1) found from curvature.
function M.corners(pos, lengthM, cfg)
  cfg = cfg or M.cfg
  local n = cfg.samples
  local step = lengthM / n
  local hd = {}
  for i = 0, n - 1 do
    local x0, z0 = pos(i / n)
    local x1, z1 = pos(((i + 1) % n) / n)
    hd[i] = math.atan2(z1 - z0, x1 - x0)
  end
  local w = math.max(1, math.floor(cfg.windowM / step / 2 + 0.5))
  local turn = {}                               -- deg per metre, signed
  for i = 0, n - 1 do
    local a = hd[(i - w) % n]
    local b = hd[(i + w) % n]
    turn[i] = math.deg(wrapAngle(b - a)) / (2 * w * step)
  end

  -- contiguous runs above threshold (handle wrap by starting at a straight sample)
  local start = 0
  for i = 0, n - 1 do if math.abs(turn[i]) < cfg.turnDegPerM then start = i; break end end
  local runs, cur = {}, nil
  for k = 0, n - 1 do
    local i = (start + k) % n
    local on = math.abs(turn[i]) >= cfg.turnDegPerM
    if on then
      if not cur then cur = { i0 = start + k, i1 = start + k, absDeg = 0 } end
      cur.i1 = start + k
      cur.absDeg = cur.absDeg + math.abs(turn[i]) * step   -- total turning, left or right
    elseif cur then
      runs[#runs + 1] = cur; cur = nil
    end
  end
  if cur then runs[#runs + 1] = cur end

  -- merge runs separated by short straights (complexes like Maggotts/Becketts)
  local merged = {}
  for _, r in ipairs(runs) do
    local last = merged[#merged]
    if last and (r.i0 - last.i1) * step < cfg.mergeCornersM then
      last.i1 = r.i1
      last.absDeg = last.absDeg + r.absDeg
    else
      merged[#merged + 1] = r
    end
  end
  local out = {}
  for _, r in ipairs(merged) do
    if r.absDeg >= cfg.minCornerDeg then
      out[#out + 1] = { s0 = (r.i0 % n) / n, s1 = (r.i1 % n) / n, deg = r.absDeg }
    end
  end
  return out
end

local function sectionName(sections, s)
  if not sections then return nil end
  for _, sec in ipairs(sections) do
    local a, b = sec.from, sec.to
    local inside = (a <= b) and (s >= a and s <= b) or (s >= a or s <= b)
    if inside then return sec.name end
  end
end

function M.build(pos, lengthM, opts)
  opts = opts or {}
  local cfg = opts.cfg or M.cfg
  local corners = M.corners(pos, lengthM, cfg)
  local before = cfg.postBeforeM / lengthM

  local pts = { { s = 0, name = "Start/Finish" } }           -- start-line post (lights / starter)
  for k, c in ipairs(corners) do
    local s = (c.s0 - before) % 1
    local nm = sectionName(opts.sections, (c.s0 + 0.5 * ((c.s1 - c.s0) % 1)) % 1)
    pts[#pts + 1] = { s = s, name = nm or ("Turn " .. k) }
  end
  table.sort(pts, function(a, b) return a.s < b.s end)

  -- merge posts that are too close (keep the corner one, i.e. the later of the two)
  local kept = {}
  for _, p in ipairs(pts) do
    local last = kept[#kept]
    if last and (p.s - last.s) * lengthM < cfg.minSpacingM then
      if last.name == "Start/Finish" then kept[#kept] = p else last.s, last.name = p.s, p.name end
    else
      kept[#kept + 1] = p
    end
  end
  if #kept > 1 and ((kept[1].s + 1 - kept[#kept].s) * lengthM) < cfg.minSpacingM then
    table.remove(kept)                                         -- wrap-around merge
  end

  -- fill long gaps (straights)
  local filled = {}
  for i, p in ipairs(kept) do
    filled[#filled + 1] = p
    local nx = kept[i % #kept + 1]
    local gap = ((nx.s - p.s) % 1) * lengthM
    if #kept == 1 then gap = lengthM end
    if gap > cfg.maxSpacingM then
      local extra = math.ceil(gap / cfg.maxSpacingM) - 1
      for e = 1, extra do
        filled[#filled + 1] = { s = (p.s + (gap / lengthM) * e / (extra + 1)) % 1, name = nil, after = p.name }
      end
    end
  end
  table.sort(filled, function(a, b) return a.s < b.s end)

  local map = {}
  for k, p in ipairs(filled) do
    local nm = p.name or ("after " .. (p.after or "start"))
    map[k] = { from = math.floor(p.s * 100000 + 0.5) / 100000, name = ("Post %d · %s"):format(k, nm) }
  end
  return map, corners
end

-- sections.ini (AC): [SECTION_n] IN=, OUT=, TEXT= ; `ini` = ac.INIConfig-like { sections = {...} }
function M.sectionsFromIni(ini)
  local out = {}
  if not ini or not ini.sections then return out end
  for name, sec in pairs(ini.sections) do
    if name:match("^SECTION") then
      local a = tonumber(sec.IN and sec.IN[1])
      local b = tonumber(sec.OUT and sec.OUT[1])
      local t = sec.TEXT and sec.TEXT[1]
      if a and b and t and t ~= "" then out[#out + 1] = { from = a, to = b, name = t } end
    end
  end
  table.sort(out, function(x, y) return x.from < y.from end)
  return out
end

return M
