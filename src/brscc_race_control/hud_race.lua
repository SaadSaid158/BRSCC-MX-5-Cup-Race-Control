-- hud_race.lua: realistic HUD. BASIC VERSION, structure ready for the full build.
-- What a real BRSCC MX-5 driver gets:
--   * flags only from the post you're at / approaching (no track overview, no live timing)
--   * penalties as a board at the start/finish line (black flag + car number)
--   * a pit board once a lap on the main straight: position, gap, laps to go
-- TODO(race mode): light panels at panel-equipped circuits, flag waving animation, mirror-side
-- placement option, pit-board styles, start-line board sequence (1 min / 30 s / 5 s).
local H = require("hud_common")
local C = H.C

local M = {}

function M.draw(v)
  local s = v.scale
  local cx = v.W / 2
  -- 1. the flag at the post (v.postFlag is only set when the car is at / approaching that post)
  if v.postFlag then H.flagPanel(v.postFlag, cx, 26 * s, s) end
  -- 2. board at the line (penalties / black flag), shown for a few seconds after crossing it
  if v.lineBoard then H.flagPanel(v.lineBoard, cx, v.H * 0.3, s) end
  -- 3. pit board, shown on the main straight after crossing the line
  local pb = v.pitBoard
  if pb then
    local w, h = 230 * s, 200 * s
    local x, y = v.W - w - 60 * s, v.H * 0.35
    H.rect(x, y, w, h, C.black, 4 * s)
    H.frame(x, y, w, h, C.white, 4 * s, 3)
    local lines = { pb.l1, pb.l2, pb.l3 }
    for k, l in ipairs(lines) do
      if l then H.text(l, 44 * s, x + w / 2, y + (12 + (k - 1) * 62) * s, k == 1 and C.yellow or C.white, true, 0.5) end
    end
  end
end

return M
