-- hud_common.lua: the HUD's drawing kit. Two languages, one palette:
--   * information reads like a club timing monitor: flat black, square edges, condensed type,
--     colour only where it means something;
--   * flags and boards are drawn as the physical kit a driver sees: cloth flags on a pole with the
--     post's number board, the magnetic-number pit board.
-- Every panel draws from its own window's origin (0, 0), so CSP can move each one.
local M = {}

M.C = {
  ground = rgbm(0.035, 0.038, 0.042, 0.94),   -- monitor black (solid panels)
  glass = rgbm(0.04, 0.05, 0.07, 0.42),       -- glass tint: light, with a text shadow doing the rest
  sheen = rgbm(1, 1, 1, 0.09), edge = rgbm(1, 1, 1, 0.14),
  inset = rgbm(1, 1, 1, 0.06),                -- rounded rows/chips inside a glass panel
  shadow = rgbm(0, 0, 0, 0.55),
  plate = rgbm(1, 1, 1, 0.045),               -- a row lifted off the ground
  rule = rgbm(1, 1, 1, 0.13),
  ink = rgbm(0.95, 0.95, 0.93, 1),
  mute = rgbm(0.6, 0.62, 0.65, 1),
  timing = rgbm(1, 0.82, 0, 1),               -- timing-screen yellow: position, live values
  amber = rgbm(1, 0.62, 0.1, 1),
  red = rgbm(0.95, 0.2, 0.18, 1),
  -- the flags themselves (Motorsport UK colours, as cloth)
  yellow = rgbm(1, 0.84, 0, 1), green = rgbm(0, 0.6, 0.27, 1), black = rgbm(0.02, 0.02, 0.02, 1),
  white = rgbm(0.97, 0.97, 0.95, 1), purple = rgbm(0.45, 0.2, 0.72, 1),
  pole = rgbm(0.55, 0.57, 0.6, 1), alu = rgbm(0.66, 0.68, 0.7, 1),
  seg = rgbm(1, 1, 1, 0.1), car = rgbm(0.8, 0.82, 0.84, 1),
}
local C = M.C

-- Barlow Condensed (SIL OFL, bundled in fonts/): a DIN-like condensed face, the type of
-- British circuit signage and timing screens.
M.F = {
  num = "Barlow Condensed:fonts;Weight=Bold",
  label = "Barlow Condensed:fonts;Weight=SemiBold",
  body = "Barlow Condensed:fonts;Weight=Medium",
}

function M.rect(x, y, w, h, col, r, corners) ui.drawRectFilled(vec2(x, y), vec2(x + w, y + h), col, r or 0, corners) end
function M.frame(x, y, w, h, col, t) ui.drawRect(vec2(x, y), vec2(x + w, y + h), col, 0, nil, t or 1) end
function M.hline(x, y, w, col) M.rect(x, y, w, 1, col or C.rule) end

function M.measure(text, size, font)
  ui.pushDWriteFont(font or M.F.body)
  local v = ui.measureDWriteText(text, size)
  ui.popDWriteFont()
  return v.x, v.y
end

-- align: 0 = left, 0.5 = centre, 1 = right (x is the anchor)
function M.text(text, size, x, y, col, font, align)
  ui.pushDWriteFont(font or M.F.body)
  if align and align > 0 then x = x - ui.measureDWriteText(text, size).x * align end
  if M.ctx and M.ctx.glass then           -- thin glass: a soft shadow keeps text legible over sky
    local o = math.max(1, size * 0.06)
    ui.dwriteDrawText(text, size, vec2(x + o * 0.5, y + o), C.shadow)
  end
  ui.dwriteDrawText(text, size, vec2(x, y), col or C.ink)
  ui.popDWriteFont()
end

-- M.ctx is the current view (set by the window runner): scale, screen size, glass on/off.
M.ctx = nil
M.R = 14            -- glass corner radius (scaled)

-- An information panel. Glass: the patch of scene behind the window, blurred (dynamic::screen,
-- needs CSP's Graphics Adjustments; when it isn't there the tint alone still reads), a dark tint
-- strong enough for white text over bright sky, a sheen across the top and a hairline edge.
-- Solid: the timing-monitor ground.
function M.panel(w, h)
  local v = M.ctx
  if v and v.glass then
    local r = M.R * v.scale
    pcall(function()
      local wp = ui.windowPos()
      ui.beginBlurring()
      ui.drawImageRounded("dynamic::screen", vec2(0, 0), vec2(w, h), rgbm(1, 1, 1, 1),
        vec2(wp.x / v.W, wp.y / v.H), vec2((wp.x + w) / v.W, (wp.y + h) / v.H), r)
      ui.endBlurring(0.12)
    end)
    M.rect(0, 0, w, h, C.glass, r)
    ui.drawRectFilledMultiColor(vec2(r * 0.5, 1), vec2(w - r * 0.5, h * 0.42),
      C.sheen, C.sheen, rgbm(1, 1, 1, 0), rgbm(1, 1, 1, 0))
    ui.drawRect(vec2(0, 0), vec2(w, h), C.edge, r, nil, 1)
  else
    M.rect(0, 0, w, h, C.ground)
    M.frame(0, 0, w, h, C.rule)
  end
end
-- radius for small inner shapes (segments, pips, rows): rounded on glass, square on solid
function M.inner(px) local v = M.ctx; return (v and v.glass) and px * v.scale or 0 end
-- corner radius of the current panel, for anything drawn flush with its edge
function M.radius() local v = M.ctx; return (v and v.glass) and M.R * v.scale or 0 end

-- One cloth flag on a pole, waving when `waved`. (x, y) is the top of the pole.
-- kind: yellow | green | purple | black | bw | chequered | white
local function cloth(kind, x, y, w, h, t, waved)
  local poleW = math.max(2, w * 0.045)
  M.rect(x, y, poleW, h * 1.5, C.pole)
  local n = 14
  local fx = x + poleW
  local amp = waved and h * 0.09 or h * 0.025
  local speed = waved and 9 or 1.5
  local function off(k) return math.sin(k / n * 3.2 - t * speed) * amp * (k / n) end
  local function shade(k) return 0.82 + 0.18 * math.cos(k / n * 3.2 - t * speed) end
  for k = 0, n - 1 do
    local x0, x1 = fx + w * k / n, fx + w * (k + 1) / n
    local o0, o1, sh = off(k), off(k + 1), shade(k)
    local function q(col, a, b)   -- vertical band a..b (0..1) of this strip
      local c = rgbm(col.r * sh, col.g * sh, col.b * sh, 1)
      ui.drawQuadFilled(vec2(x0, y + o0 + h * a), vec2(x1, y + o1 + h * a),
        vec2(x1, y + o1 + h * b), vec2(x0, y + o0 + h * b), c)
    end
    if kind == "chequered" then
      for j = 0, 3 do q(((math.floor(k / 2) + j) % 2 == 0) and C.white or C.black, j / 4, (j + 1) / 4) end
    elseif kind == "bw" then                    -- diagonal halves, black over white
      local d = k / n
      q(C.black, 0, math.max(0, 1 - d)); q(C.white, math.max(0, 1 - d), 1)
    else
      q(C[kind] or C.white, 0, 1)
    end
  end
end

-- The post's number board, hung under the flags: white board, black numerals.
local function postBoard(num, x, y, s)
  local w, h = 40 * s, 30 * s
  M.rect(x, y, w, h, C.white)
  M.text(tostring(num), 24 * s, x + w / 2, y + 1 * s, C.black, M.F.num, 0.5)
  return w
end

-- A car-number board (shown with the black flag, drive-through or black/white).
local function numberBoard(num, x, y, s)
  local w, h = 64 * s, 64 * s
  M.rect(x, y, w, h, C.black)
  M.frame(x, y, w, h, C.white, 3 * s)
  M.text(tostring(num), 40 * s, x + w / 2, y + 8 * s, C.white, M.F.num, 0.5)
  return w
end

-- The flag station. f = { lamps = {kinds}, title, line1, line2, number, post } -> w, h
-- Course flags are waved; personal boards are held still.
function M.flagStation(f, s, t)
  local fw, fh, gap, pad = 92 * s, 60 * s, 14 * s, 16 * s
  local textX = pad
  local h = 128 * s
  -- measure the text block first so the panel fits it
  local tw = math.max(M.measure(f.title, 36 * s, M.F.num),
    f.line1 and M.measure(f.line1, 18 * s) or 0, f.line2 and M.measure(f.line2, 15 * s) or 0)
  local kitW = 0
  for _, k in ipairs(f.lamps) do kitW = kitW + ((k == "number") and (64 * s) or fw + 6 * s) + gap end
  local w = pad + kitW + 6 * s + tw + pad
  M.panel(w, h)
  local x = pad
  for _, k in ipairs(f.lamps) do
    if k == "number" then x = x + numberBoard(f.number or "?", x, pad + 10 * s, s) + gap
    else
      local waved = (k == "yellow" or k == "green")
      cloth(k == "sc" and "yellow" or k, x, pad, fw, fh, t, waved)
      if k == "black" and f.number then numberBoard(f.number, x + fw * 0.2, pad + fh + 6 * s, s * 0.55) end
      x = x + fw + 6 * s + gap
    end
  end
  if f.post then postBoard(f.post, pad, pad + fh * 1.5 + 4 * s, s) end
  textX = x + 6 * s
  M.text(f.title, 36 * s, textX, pad - 4 * s, C.ink, M.F.num)
  if f.line1 then M.text(f.line1, 18 * s, textX, pad + 44 * s, C.ink) end
  if f.line2 then M.text(f.line2, 15 * s, textX, pad + 70 * s, C.mute) end
  return w, h
end

-- The pit board: aluminium frame, black face, magnetic numerals each on its own tile.
function M.pitBoard(lines, s)
  local tileW, tileH, gap, pad, frame = 30 * s, 50 * s, 4 * s, 12 * s, 6 * s
  local maxChars = 0
  for _, l in ipairs(lines) do maxChars = math.max(maxChars, #l) end
  local w = 2 * frame + 2 * pad + maxChars * (tileW + gap) - gap
  local h = 2 * frame + 2 * pad + #lines * (tileH + 10 * s) - 10 * s
  M.rect(0, 0, w, h, C.alu)
  M.rect(frame, frame, w - 2 * frame, h - 2 * frame, C.black)
  local y = frame + pad
  for k, l in ipairs(lines) do
    local x = frame + pad
    for ch in l:gmatch(".") do
      if ch ~= " " then
        M.rect(x, y, tileW, tileH, rgbm(1, 1, 1, 0.07))
        M.text(ch, 44 * s, x + tileW / 2, y + 1 * s, k == 1 and C.timing or C.white, M.F.num, 0.5)
      end
      x = x + tileW + gap
    end
    y = y + tileH + 10 * s
  end
  return w, h
end

return M
