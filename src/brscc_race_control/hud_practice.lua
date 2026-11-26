-- hud_practice.lua: full-information HUD (approved mock-ups, docs/mockups/). For development
-- and learning. View model is built in brscc_race_control.lua (buildView).
local H = require("hud_common")
local C = H.C

local M = {}

local function strip(v, cx, y, s)
  local w, pad = 760 * s, 12 * s
  local x = cx - w / 2
  local h = 72 * s
  H.rect(x, y, w, h, C.panel, 10 * s)
  local bx, bw, by, bh = x + pad, w - 2 * pad, y + 10 * s, 22 * s
  -- segments: posts as proportional blocks along the lap
  local posts = v.strip.posts
  for k = 1, #posts do
    local a = posts[k].from
    local b = (k < #posts) and posts[k + 1].from or 1
    local seg = v.strip.segs[k]
    local col = C.seg
    if seg.level == 2 then col = C.yellow elseif seg.level == 1 then col = C.yellow elseif seg.green then col = C.green end
    local x0, x1 = bx + a * bw + 1.5 * s, bx + b * bw - 1.5 * s
    H.rect(x0, by, x1 - x0, bh, col, 3 * s)
    if seg.level == 2 then                       -- double: stripe it so it reads differently
      local st = 10 * s
      local xx = x0
      while xx < x1 do H.rect(xx, by, math.min(st / 2, x1 - xx), bh, C.yellowDark, 0); xx = xx + st end
    end
    if seg.sc then H.rect(x0, by, x1 - x0, bh, C.yellow, 3 * s) end
  end
  if posts[1] and posts[1].from > 0 then          -- wrap: last sector also covers 0..first
    local seg = v.strip.segs[#posts]
    local col = seg.level > 0 and C.yellow or (seg.green and C.green or C.seg)
    H.rect(bx, by, posts[1].from * bw - 1.5 * s, bh, col, 3 * s)
  end
  -- cars
  for _, c in ipairs(v.strip.cars) do
    ui.drawCircleFilled(vec2(bx + c.s * bw, by + bh + 14 * s), 5 * s, c.hazard and C.red or C.car, 12)
  end
  local mx = bx + v.strip.me * bw
  ui.drawTriangleFilled(vec2(mx - 9 * s, by - 7 * s), vec2(mx + 9 * s, by - 7 * s), vec2(mx, by + 5 * s), C.white)
  H.text("S/F", 13 * s, bx, by + bh + 24 * s, C.dim)
  H.text("S/F", 13 * s, bx + bw, by + bh + 24 * s, C.dim, false, 1)
  if v.strip.postName then H.text(v.strip.postName, 13 * s, cx, by + bh + 24 * s, C.dim, false, 0.5) end
  return y + h
end

local function ticker(v, cx, y, s)
  if not v.ticker then return end
  local t = v.ticker.text
  local tw = H.measure("RACE CONTROL  ", 22 * s, true) + H.measure(t, 22 * s)
  local w = tw + 36 * s
  local x = cx - w / 2
  H.rect(x, y, w, 46 * s, rgbm(0, 0, 0, 0.8), 6 * s)
  H.rect(x, y, 6 * s, 46 * s, v.ticker.col or C.yellow, 0)
  local lw = H.measure("RACE CONTROL  ", 22 * s, true)
  H.text("RACE CONTROL", 22 * s, x + 20 * s, y + 9 * s, C.yellow, true)
  H.text(t, 22 * s, x + 20 * s + lw, y + 9 * s, C.white)
end

local function fmtGap(g)
  if not g then return "-" end
  if g.lapsDown then return ("%d lap%s"):format(g.lapsDown, g.lapsDown > 1 and "s" or "") end
  return ("%.2f"):format(g.value)
end

local function racePanel(v, x, yBottom, s)
  local r = v.race
  if not r then return end
  local w, h = 340 * s, 250 * s
  local y = yBottom - h
  H.rect(x, y, w, h, C.panel, 12 * s)
  local px = x + 18 * s
  if r.pos then
    H.text("P" .. r.pos, 64 * s, px, y + 8 * s, C.white, true)
    local pw = H.measure("P" .. r.pos, 64 * s, true)
    H.text("/" .. r.total, 26 * s, px + pw + 2 * s, y + 42 * s, C.dim, true)
  end
  H.text(r.lapText, 28 * s, x + w - 18 * s, y + 24 * s, C.white, true, 1)
  if r.subText then H.text(r.subText, 15 * s, x + w - 18 * s, y + 60 * s, C.dim, false, 1) end
  local rows = {
    r.leader and { "Leader", "", C.up }
      or { "Ahead" .. (r.aheadName and (" · " .. r.aheadName) or ""), r.ahead and ("-" .. fmtGap(r.ahead)) or "-", C.up },
    { "Behind" .. (r.behindName and (" · " .. r.behindName) or ""), r.behind and ("+" .. fmtGap(r.behind)) or "-", C.red },
    { "Last", r.last or "-", C.white },
    { "Best", r.best or "-", C.white },
  }
  local ry = y + 98 * s
  for _, row in ipairs(rows) do
    H.rect(px, ry - 4 * s, w - 36 * s, 1, C.border, 0)
    H.text(row[1], 21 * s, px, ry, C.dim)
    H.text(row[2], 21 * s, x + w - 18 * s, ry, row[3], true, 1)
    ry = ry + 34 * s
  end
end

local function recordPanel(v, xRight, yBottom, s)
  local rc = v.record
  local w = 360 * s
  local chips = {}
  if rc.timePen > 0 then chips[#chips + 1] = { ("+%d s"):format(rc.timePen), "time" } end
  if rc.dtLapsLeft then chips[#chips + 1] = { ("DRIVE-THROUGH · %d lap%s left"):format(rc.dtLapsLeft, rc.dtLapsLeft == 1 and "" or "s"), "dt" } end
  if rc.dsq then chips[#chips + 1] = { "DISQUALIFIED", "dt" } end
  if #chips == 0 then chips[1] = { "None", "ok" } end
  for _, ch in ipairs(chips) do w = math.max(w, H.measure(ch[1], 20 * s, true) + 24 * s + 36 * s) end
  local h = (128 + 44 * #chips) * s
  local x, y = xRight - w, yBottom - h
  H.rect(x, y, w, h, C.panel, 12 * s)
  local px = x + 18 * s
  H.text("TRACK LIMITS", 15 * s, px, y + 14 * s, C.dim, true)
  local pw, gap = (w - 36 * s - 5 * 6 * s) / 6, 6 * s
  for k = 1, 6 do
    local col = C.pipOff
    if k <= rc.tl then col = (k >= 5) and C.red or C.amber end
    H.rect(px + (k - 1) * (pw + gap), y + 40 * s, pw, 14 * s, col, 3 * s)
  end
  H.text(rc.tlText, 17 * s, px, y + 62 * s, rc.tlSevere and C.red or (rc.tl > 0 and C.amber or C.dim))
  H.text("PENALTIES", 15 * s, px, y + 94 * s, C.dim, true)
  local cy = y + 118 * s
  for _, ch in ipairs(chips) do
    local tw = H.measure(ch[1], 20 * s, true)
    if ch[2] == "time" then H.rect(px, cy, tw + 24 * s, 36 * s, C.amber, 7 * s); H.text(ch[1], 20 * s, px + 12 * s, cy + 5 * s, C.black, true)
    elseif ch[2] == "dt" then H.rect(px, cy, tw + 24 * s, 36 * s, C.black, 7 * s); H.frame(px, cy, tw + 24 * s, 36 * s, C.white, 7 * s, 2)
      H.text(ch[1], 20 * s, px + 12 * s, cy + 5 * s, C.white, true)
    else H.rect(px, cy, tw + 24 * s, 36 * s, rgbm(1, 1, 1, 0.11), 7 * s); H.text(ch[1], 20 * s, px + 12 * s, cy + 5 * s, C.text, true) end
    cy = cy + 44 * s
  end
end

function M.draw(v)
  local s = v.scale
  local cx = v.W / 2
  local y = 26 * s
  if v.flag then y = H.flagPanel(v.flag, cx, y, s) + 4 * s end
  y = strip(v, cx, math.max(y, 150 * s), s) + 6 * s
  ticker(v, cx, y, s)
  racePanel(v, 36 * s, v.H * 0.72, s)
  recordPanel(v, v.W - 36 * s, v.H * 0.72, s)
end

return M
