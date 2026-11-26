-- hud.lua: on-screen flag panel + race control messages. Drawn from the IN_GAME UI callback.
local M = {}

local C = {
  yellow = rgbm(1, 0.85, 0, 1), green = rgbm(0.1, 0.75, 0.25, 1), black = rgbm(0, 0, 0, 1),
  white = rgbm(1, 1, 1, 1), panel = rgbm(0, 0, 0, 0.55), grey = rgbm(0.8, 0.8, 0.8, 1),
  orange = rgbm(1, 0.5, 0, 1), red = rgbm(0.85, 0.1, 0.1, 1),
}

local function flagBox(x, y, w, h, col)
  ui.drawRectFilled(vec2(x, y), vec2(x + w, y + h), col, 3)
end

local function blackWhite(x, y, w, h)
  ui.drawRectFilled(vec2(x, y), vec2(x + w, y + h), C.white, 3)
  -- lower-left triangle black: approximate with stacked strips
  local n = 12
  for k = 0, n - 1 do
    local yy = y + h * k / n
    ui.drawRectFilled(vec2(x, yy), vec2(x + w * (k + 1) / n, yy + h / n + 0.5), C.black, 0)
  end
end

-- view = { level=0|1|2, green=bool, postName=, carFlag=nil|"black_white"|"drive_through"|"black",
--          carNumber=, trackLimits=n, timePenaltyS=n, pending=n, messages={ {t=, text=} } }
function M.draw(view)
  local sim = ac.getSim()
  local W = sim.windowWidth / sim.uiScale
  local fw, fh, gap = 90, 60, 10
  local cx, y = W / 2, 70

  local title, flags = nil, {}
  if view.carFlag == "black" then
    title, flags = "BLACK FLAG - PIT AND REPORT TO CLERK OF THE COURSE", { "black" }
  elseif view.level == 2 then
    title, flags = "DOUBLE YELLOW - SLOW DOWN, BE PREPARED TO STOP, NO OVERTAKING", { "yellow", "yellow" }
  elseif view.level == 1 then
    title, flags = "YELLOW - SLOW DOWN, NO OVERTAKING", { "yellow" }
  elseif view.green then
    title, flags = "GREEN - TRACK CLEAR", { "green" }
  end
  if view.carFlag == "black_white" then
    flags[#flags + 1] = "bw"
    title = (title and (title .. "  |  ") or "") .. "BLACK/WHITE: TRACK LIMITS WARNING #" .. (view.carNumber or "")
  elseif view.carFlag == "drive_through" then
    flags[#flags + 1] = "black"
    title = (title and (title .. "  |  ") or "") .. "DRIVE-THROUGH PENALTY: ENTER PIT LANE WITHIN 3 LAPS"
  end

  if #flags > 0 then
    local total = #flags * fw + (#flags - 1) * gap
    local x = cx - total / 2
    ui.drawRectFilled(vec2(x - 12, y - 10), vec2(x + total + 12, y + fh + 40), C.panel, 6)
    for _, f in ipairs(flags) do
      if f == "bw" then blackWhite(x, y, fw, fh)
      else flagBox(x, y, fw, fh, C[f] or C.white) end
      x = x + fw + gap
    end
    local ts = 15
    local tw = #title * ts * 0.52
    ui.dwriteDrawText(title, ts, vec2(cx - tw / 2, y + fh + 10), C.white)
    if view.postName and view.level > 0 then
      ui.dwriteDrawText(view.postName, 12, vec2(cx - #view.postName * 3.2, y - 26), C.grey)
    end
  end

  -- Status strip for the player's own record
  local status = ("Track limits: %d   Time pen: +%ds%s"):format(view.trackLimits or 0, view.timePenaltyS or 0,
    (view.pending or 0) > 0 and "   DRIVE-THROUGH PENDING" or "")
  ui.dwriteDrawText(status, 12, vec2(cx - #status * 3.2, y + fh + 50), C.grey)

  -- Race control messages, newest first
  local mx, my = W - 440, 120
  local msgs = view.messages or {}
  if #msgs > 0 then
    local n = math.min(#msgs, 6)
    ui.drawRectFilled(vec2(mx - 10, my - 30), vec2(W - 20, my + n * 22 + 6), C.panel, 6)
    ui.dwriteDrawText("RACE CONTROL", 13, vec2(mx, my - 24), C.yellow)
    for k = 1, n do
      local m = msgs[#msgs - k + 1]
      ui.dwriteDrawText(m.text, 12, vec2(mx, my + (k - 1) * 22), k == 1 and C.white or C.grey)
    end
  end
end

return M
