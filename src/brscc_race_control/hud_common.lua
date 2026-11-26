-- hud_common.lua: drawing helpers + colours shared by the Practice and Race HUDs (CSP ui API).
local M = {}

M.C = {
  yellow = rgbm(1, 0.83, 0, 1), yellowDark = rgbm(0.79, 0.66, 0, 1), green = rgbm(0.1, 0.71, 0.29, 1),
  black = rgbm(0, 0, 0, 1), white = rgbm(1, 1, 1, 1), purple = rgbm(0.48, 0.18, 0.75, 1),
  panel = rgbm(0.03, 0.04, 0.055, 0.8), border = rgbm(1, 1, 1, 0.12), dim = rgbm(0.6, 0.64, 0.68, 1),
  text = rgbm(0.92, 0.92, 0.92, 1), amber = rgbm(1, 0.69, 0.13, 1), red = rgbm(1, 0.29, 0.29, 1),
  up = rgbm(0.28, 0.82, 0.44, 1), seg = rgbm(0.18, 0.23, 0.18, 1), pipOff = rgbm(1, 1, 1, 0.13),
  car = rgbm(0.81, 0.84, 0.86, 1),
}

local fontBold, fontReg = "Segoe UI;Weight=Bold", "Segoe UI"

function M.rect(x, y, w, h, col, r) ui.drawRectFilled(vec2(x, y), vec2(x + w, y + h), col, r or 0) end
function M.frame(x, y, w, h, col, r, t) ui.drawRect(vec2(x, y), vec2(x + w, y + h), col, r or 0, nil, t or 1) end

function M.measure(text, size, bold)
  ui.pushDWriteFont(bold and fontBold or fontReg)
  local v = ui.measureDWriteText(text, size)
  ui.popDWriteFont()
  return v.x, v.y
end

-- align: 0 = left, 0.5 = centre, 1 = right (x is the anchor)
function M.text(text, size, x, y, col, bold, align)
  ui.pushDWriteFont(bold and fontBold or fontReg)
  if align and align > 0 then
    local w = ui.measureDWriteText(text, size).x
    x = x - w * align
  end
  ui.dwriteDrawText(text, size, vec2(x, y), col or M.C.white)
  ui.popDWriteFont()
end

-- A flag "lamp" (one marshal flag / light panel block).
function M.lamp(kind, x, y, w, h, number)
  local C = M.C
  if kind == "yellow" then M.rect(x, y, w, h, C.yellow, 6)
  elseif kind == "green" then M.rect(x, y, w, h, C.green, 6)
  elseif kind == "purple" then M.rect(x, y, w, h, C.purple, 6)
    M.text("60", h * 0.5, x + w / 2, y + h * 0.2, C.white, true, 0.5)
  elseif kind == "sc" then
    M.rect(x, y, w, h, C.yellow, 6); M.frame(x + 2, y + 2, w - 4, h - 4, C.black, 6, 4)
    M.text("SC", h * 0.55, x + w / 2, y + h * 0.17, C.black, true, 0.5)
  elseif kind == "bw" then
    M.rect(x, y, w, h, C.white, 6)
    ui.drawTriangleFilled(vec2(x, y), vec2(x + w, y), vec2(x, y + h), C.black)
  elseif kind == "black" or kind == "number" then
    M.rect(x, y, w, h, C.black, 6); M.frame(x, y, w, h, C.white, 6, 3)
    if number then M.text(tostring(number), h * 0.55, x + w / 2, y + h * 0.17, C.white, true, 0.5) end
  elseif kind == "chequered" then
    local n = 6
    for i = 0, n - 1 do for j = 0, 3 do
      M.rect(x + i * w / n, y + j * h / 4, w / n, h / 4, ((i + j) % 2 == 0) and C.white or C.black, 0)
    end end
  end
end

-- Flag panel (top centre). f = { lamps = { kinds... }, title=, line1=, line2=, number= }
function M.flagPanel(f, cx, y, s)
  local C = M.C
  local lw, lh, gap, pad = 150 * s, 96 * s, 8 * s, 12 * s
  local tw1 = M.measure(f.title, 40 * s, true)
  local tw2 = f.line1 and M.measure(f.line1, 20 * s) or 0
  local tw3 = f.line2 and M.measure(f.line2, 16 * s) or 0
  local textW = math.max(tw1, tw2, tw3)
  local lampsW = #f.lamps * lw + (#f.lamps - 1) * gap
  local w = pad + lampsW + 18 * s + textW + 22 * s
  local x = cx - w / 2
  M.rect(x, y, w, lh + 2 * pad, C.panel, 12 * s)
  M.frame(x, y, w, lh + 2 * pad, C.border, 12 * s, 2)
  local lx = x + pad
  for _, k in ipairs(f.lamps) do M.lamp(k, lx, y + pad, lw, lh, f.number); lx = lx + lw + gap end
  local tx = x + pad + lampsW + 18 * s
  M.text(f.title, 40 * s, tx, y + pad, C.white, true)
  if f.line1 then M.text(f.line1, 20 * s, tx, y + pad + 50 * s, C.text) end
  if f.line2 then M.text(f.line2, 16 * s, tx, y + pad + 76 * s, C.dim) end
  return y + lh + 2 * pad
end

return M
