-- racenum.lua: a car's race number, from its skin. Pure logic (the caller loads the file).
--
-- The BRSCC MX-5 skins carry the number in three places, in order of trust:
--   1. ui_skin.json "number", when it's digits and not all zeros (many skins leave "0" as a placeholder,
--      and a few hold junk such as a driver's name);
--   2. the leading digits of the skin folder ("01_max5_blue_and_white" -> "01", as painted on the car);
--   3. any other digits in the folder name ("KrabbyRacing88" -> "88", "RotterGraafRacing_76_Wilco" -> "76").
-- Nothing found -> nil; the caller decides the fallback.
local M = {}

local function usable(n) return n and n:match("^%d+$") and not n:match("^0+$") and n or nil end

function M.fromSkin(folder, uiSkinText)
  local n = uiSkinText and uiSkinText:match('"number"%s*:%s*"?%s*([^",}%s]*)')
  if usable(n) then return n end
  -- the model name is in most folder names ("00_max5-red-red"): its 5 is not a race number
  folder = (folder or ""):lower():gsub("max%-?5", ""):gsub("mx%-?5", "")
  n = folder:match("^(%d+)")
  if usable(n) then return n end
  for d in folder:gmatch("%d+") do if usable(d) then return d end end
  return nil
end

-- A number for every car in the field. found: index -> number or nil (from M.fromSkin), for indexes
-- 0..count-1. OURS: a car with no number gets the lowest number from 90 up that no other car uses,
-- so a board never points at two cars because of it. (Duplicates painted on real skins are kept.)
function M.assign(found, count)
  local used, out = {}, {}
  for i = 0, count - 1 do if found[i] then used[tonumber(found[i])] = true; out[i] = found[i] end end
  local next = 90
  for i = 0, count - 1 do
    if not out[i] then
      while used[next] do next = next + 1 end
      out[i], used[next] = tostring(next), true
    end
  end
  return out
end

return M
