-- hud_panels.lua: the HUD, one function per movable CSP window. Each draws from (0, 0) and
-- returns its size (or nothing when it has nothing to show). The view table comes from
-- buildView() in brscc_race_control.lua.
--
-- Modes: "practice" shows everything (for learning); "race" is what a real BRSCC driver gets:
-- the flag at the post, boards at the line, a pit board once a lap. No live timing, no overview.
-- `arrange` draws every panel with sample content so the driver can place them.
local H = require("hud_common")
local C, F = H.C, H.F

local M = {}

-- sample content for arrange mode
local DEMO = {
  flag = { lamps = { "yellow", "yellow" }, title = "DOUBLE YELLOW", line1 = "Slow · be ready to stop · NO OVERTAKING",
    line2 = "Post 4 · incident 180 m ahead", post = 4 },
  ticker = { text = "Car 7 passed car 3 under yellow (Post 4) - give the place back" },
  race = { pos = 4, total = 10, lapText = "LAP 7 / 10", subText = "4 laps to go", aheadName = "ANEMA",
    ahead = { value = 0.84 }, behindName = "KOLDERS", behind = { value = 1.2 }, last = "1:15.402", best = "1:15.118" },
  record = { tl = 2, tlText = "2 of 6 · next: +5 s", timePen = 0 },
  pit = { "P4", "-0.8", "L3" },
  results = { title = "RACE 1", sub = "PROVISIONAL · 10 LAPS",
    rows = {
      { pos = "1", name = "VINCENT ANEMA", laps = 10, time = "14:26.118", pen = "", pts = "100" },
      { pos = "2", name = "BRUCE DAHLGREN", laps = 10, time = "+1.904", pen = "", pts = "99" },
      { pos = "3", name = "SAAD SAID", laps = 10, time = "+6.233", pen = "+5 s", pts = "96" },
      { pos = "NC", name = "MAURO ROCCA", laps = 7, time = "-", pen = "", pts = "0", muted = true },
    },
    note = "FASTEST VALID LAP · DAHLGREN 1:25.380 (+1)",
    standings = { { "V. ANEMA", 198 }, { "S. SAID", 194 }, { "B. DAHLGREN", 193 } }, standingsNote = "AFTER RACE 2 OF 3" },
}

-- ── flags ─────────────────────────────────────────────────────────────────────────────────
function M.flags(v, arrange)
  local f
  if v.mode == "race" then f = v.postFlag or v.lineBoard else f = v.flag end
  if not f and arrange then f = DEMO.flag end
  if not f then return end
  local w, h = H.flagStation(f, v.scale, v.t)
  if f == DEMO.flag then H.sample(w) end
  return w, h
end

-- ── the lap as a strip of marshal sectors ────────────────────────────────────────────────
function M.strip(v, arrange)
  if v.mode == "race" and not arrange then return end
  local s, st = v.scale, v.strip
  local w, pad = 640 * s, 12 * s
  local h = 64 * s
  H.panel(w, h)
  local bx, bw, by, bh = pad, w - 2 * pad, 26 * s, 10 * s
  if st.postName then H.text(st.postName:upper(), 14 * s, pad, 6 * s, C.mute, F.label) end
  H.text("S/F", 13 * s, w - pad, 6 * s, C.mute, F.label, 1)
  local posts = st.posts
  local function segCol(seg)
    if seg.level > 0 then return C.yellow elseif seg.green then return C.green end
    return v.glass and C.segGlass or C.seg      -- frosted glass swallows a 10% segment
  end
  for k = 1, #posts do
    local a = posts[k].from
    local b = (k < #posts) and posts[k + 1].from or 1
    local seg = st.segs[k]
    local x0, x1 = bx + a * bw + 1 * s, bx + b * bw - 1 * s
    H.rect(x0, by, x1 - x0, bh, segCol(seg), H.inner(3))
    if seg.level == 2 then                        -- double yellow: cut with black hatching
      local xx = x0
      while xx < x1 do H.rect(xx, by, math.min(3 * s, x1 - xx), bh, C.black); xx = xx + 8 * s end
    end
  end
  if posts[1] and posts[1].from > 0 then          -- the last sector wraps over the line
    H.rect(bx, by, posts[1].from * bw - 1 * s, bh, segCol(st.segs[#posts]), H.inner(3))
  end
  for _, c in ipairs(st.cars) do                  -- every other car: a tick under the bar
    H.rect(bx + c.s * bw - 1 * s, by + bh + 4 * s, 2 * s, 8 * s, c.hazard and C.red or C.car, H.inner(1))
  end
  local mx = bx + st.me * bw                      -- you: a marker above the bar
  ui.drawTriangleFilled(vec2(mx - 6 * s, by - 9 * s), vec2(mx + 6 * s, by - 9 * s), vec2(mx, by - 1 * s), C.timing)
  return w, h
end

-- ── race control messages ────────────────────────────────────────────────────────────────
function M.messages(v, arrange)
  if v.mode == "race" and not arrange then return end
  local tk = v.ticker or (arrange and DEMO.ticker)
  if not tk then return end
  local s = v.scale
  local tag, size, pad = "RACE CONTROL", 17 * s, 12 * s
  local tagW = H.measure(tag, 15 * s, F.label) + 2 * pad
  local tw = H.measure(tk.text, size)
  local inset = 6 * s
  local w, h = inset + tagW + pad + tw + pad, 38 * s
  H.panel(w, h)
  H.rect(inset, inset, tagW, h - 2 * inset, tk.col or C.timing, H.inner(8))
  H.text(tag, 15 * s, inset + pad, 10 * s, C.black, F.label)
  H.text(tk.text, size, inset + tagW + pad, 8 * s, C.ink)
  if tk == DEMO.ticker then H.sample(w) end
  return w, h
end

-- ── position and gaps, timing-screen style ───────────────────────────────────────────────
local function gapText(g, sign)
  if not g then return "" end
  if g.lapsDown then return ("%d LAP%s"):format(g.lapsDown, g.lapsDown > 1 and "S" or "") end
  return sign .. ("%.2f"):format(g.value)
end

function M.timing(v, arrange)
  if v.mode == "race" and not arrange then return end
  local r = (arrange and not v.race) and DEMO.race or v.race
  if not r then return end
  local s = v.scale
  local w, pad, rowH = 300 * s, 14 * s, 30 * s
  local headH = 62 * s
  local rows = {
    r.leader and { "AHEAD", "LEADER", "" } or { "AHEAD", (r.aheadName or ""):upper(), gapText(r.ahead, "-") },
    { "BEHIND", (r.behindName or ""):upper(), gapText(r.behind, "+") },
    { "LAST", "", r.last or "-" },
    { "BEST", "", r.best or "-" },
  }
  local h = headH + #rows * rowH + 8 * s
  H.panel(w, h)
  if r.pos then
    local pw = H.measure("P" .. r.pos, 48 * s, F.num)
    H.text("P" .. r.pos, 48 * s, pad, 2 * s, C.timing, F.num)
    H.text("/" .. (r.total or "-"), 20 * s, pad + pw + 3 * s, 26 * s, C.mute, F.label)
  end
  H.text(r.lapText or "", 24 * s, w - pad, 8 * s, C.ink, F.num, 1)
  if r.subText then H.text(r.subText:upper(), 13 * s, w - pad, 36 * s, C.mute, F.label, 1) end
  local y = headH
  for k, row in ipairs(rows) do
    if k % 2 == 1 then
      if v.glass then H.rect(6 * s, y + 1 * s, w - 12 * s, rowH - 2 * s, C.inset, H.inner(7))
      else H.rect(1, y, w - 2, rowH, C.plate) end
    end
    H.text(row[1], 13 * s, pad, y + 8 * s, C.mute, F.label)
    H.text(row[2], 17 * s, pad + 58 * s, y + 5 * s, C.ink)
    H.text(row[3], 20 * s, w - pad, y + 3 * s, C.ink, F.num, 1)
    y = y + rowH
  end
  if r == DEMO.race then H.sample(w) end
  return w, h
end

-- ── the driver's record: track limits and penalties ──────────────────────────────────────
function M.record(v, arrange)
  if v.mode == "race" and not arrange then return end
  local rc = (arrange and (v.record.tl or 0) == 0 and (v.record.timePen or 0) == 0) and DEMO.record or v.record
  local s = v.scale
  local w, pad = 300 * s, 14 * s
  local lines = {}
  if (rc.timePen or 0) > 0 then lines[#lines + 1] = { ("+%d S TIME PENALTY"):format(rc.timePen), C.amber } end
  if rc.dtLapsLeft then
    lines[#lines + 1] = { ("DRIVE-THROUGH · %d LAP%s TO SERVE"):format(rc.dtLapsLeft, rc.dtLapsLeft == 1 and "" or "S"), C.red }
  end
  if rc.dsq then lines[#lines + 1] = { "DISQUALIFIED", C.red } end
  if #lines == 0 then lines[1] = { "NONE", C.mute } end
  local h = (96 + 24 * #lines) * s
  H.panel(w, h)
  H.text("TRACK LIMITS", 13 * s, pad, 10 * s, C.mute, F.label)
  local pipW = (w - 2 * pad - 5 * 4 * s) / 6
  for k = 1, 6 do
    local col = v.glass and C.segGlass or C.seg
    if k <= (rc.tl or 0) then col = (k >= 5) and C.red or C.amber end
    H.rect(pad + (k - 1) * (pipW + 4 * s), 30 * s, pipW, 6 * s, col, H.inner(3))
  end
  H.text(rc.tlText or "", 16 * s, pad, 42 * s, rc.tlSevere and C.red or ((rc.tl or 0) > 0 and C.amber or C.ink))
  H.hline(pad, 68 * s, w - 2 * pad)
  H.text("PENALTIES", 13 * s, pad, 74 * s, C.mute, F.label)
  local y = 92 * s
  for _, l in ipairs(lines) do H.text(l[1], 17 * s, pad, y, l[2], F.label); y = y + 24 * s end
  if rc == DEMO.record then H.sample(w) end
  return w, h
end

-- ── pit board, once a lap on the main straight (race mode) ───────────────────────────────
function M.pitBoard(v, arrange)
  local pb = v.mode == "race" and v.pitBoard
  local lines
  if pb then lines = {} for _, l in ipairs({ pb.l1, pb.l2, pb.l3 }) do if l then lines[#lines + 1] = l end end
  elseif arrange then lines = DEMO.pit end
  if not lines then return end
  local w, h = H.pitBoard(lines, v.scale)
  if lines == DEMO.pit then H.sample(w, C.black) end
  return w, h
end

-- ── results: the session's classification, and the meeting standings beside it ──────────
function M.results(v, arrange)
  local rs = v.results or (arrange and DEMO.results)
  if not rs then return end
  local s = v.scale
  local pad, rowH = 14 * s, 22 * s
  local cols = { { "POS", 34 }, { "DRIVER", 170 }, { "LAPS", 40, 1 }, { "TIME / GAP", 92, 1 }, { "PEN", 52, 1 }, { "PTS", 40, 1 } }
  local tableW = 0
  for _, c in ipairs(cols) do tableW = tableW + c[2] * s end
  local standW = rs.standings and 190 * s or 0
  local w = pad + tableW + (rs.standings and (18 * s + standW) or 0) + pad
  local nRows = math.max(#rs.rows, rs.standings and #rs.standings or 0)
  local h = 40 * s + (nRows + 1) * rowH + (rs.note and 24 * s or 8 * s) + 8 * s
  H.panel(w, h)
  H.text(rs.title, 22 * s, pad, 6 * s, C.ink, F.num)
  if rs.sub then H.text(rs.sub, 12 * s, pad + tableW, 14 * s, C.mute, F.label, 1) end
  local y = 40 * s
  local x = pad
  for _, c in ipairs(cols) do
    H.text(c[1], 11 * s, c[3] and (x + c[2] * s - 6 * s) or (x + 6 * s), y + 5 * s, C.mute, F.label, c[3] and 1 or 0)
    x = x + c[2] * s
  end
  y = y + rowH
  for k, r in ipairs(rs.rows) do
    if k % 2 == 1 then H.rect(pad, y, tableW, rowH, v.glass and C.inset or C.plate, H.inner(7)) end
    local vals = { r.pos, r.name, tostring(r.laps), r.time, r.pen, r.pts }
    x = pad
    for i, c in ipairs(cols) do
      local col = r.muted and C.mute or C.ink
      if i == 1 and r.dsq then col = C.red end
      if i == 5 and r.pen ~= "" then col = r.dsq and C.red or C.amber end
      local font = (i == 1 or i == 4 or i == 6) and F.num or F.body
      H.text(vals[i] or "", 15 * s, c[3] and (x + c[2] * s - 6 * s) or (x + 6 * s), y + 2 * s, col, font, c[3] and 1 or 0)
      x = x + c[2] * s
    end
    y = y + rowH
  end
  if rs.note then H.text(rs.note, 11 * s, pad, y + 8 * s, C.mute, F.label) end
  if rs.standings then
    local sx = pad + tableW + 18 * s
    H.rect(sx - 9 * s, 10 * s, 1, h - 20 * s, C.rule)
    H.text("MEETING", 22 * s, sx, 6 * s, C.ink, F.num)
    local sy = 40 * s + rowH
    H.text("PTS", 11 * s, sx + standW - 6 * s, 40 * s + 5 * s, C.mute, F.label, 1)
    for k, st in ipairs(rs.standings) do
      if k % 2 == 1 then H.rect(sx, sy, standW, rowH, v.glass and C.inset or C.plate, H.inner(7)) end
      H.text(tostring(k), 15 * s, sx + 6 * s, sy + 2 * s, C.ink, F.num)
      H.text(st[1], 15 * s, sx + 28 * s, sy + 2 * s, C.ink)
      H.text(tostring(st[2]), 15 * s, sx + standW - 6 * s, sy + 2 * s, C.ink, F.num, 1)
      sy = sy + rowH
    end
    if rs.standingsNote then H.text(rs.standingsNote, 11 * s, sx, h - 24 * s, C.mute, F.label) end
  end
  if rs == DEMO.results then H.sample(w) end
  return w, h
end

return M
