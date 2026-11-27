-- raceini.lua: read and write AC's race.ini (Documents/Assetto Corsa/cfg/race.ini). Pure logic.
--
-- What we rely on (docs/API_NOTES.md, "race.ini"):
--   * [CAR_0] is the player (MODEL=- means [RACE] MODEL); [CAR_1]..[CAR_n] are the AI, each with its
--     own DRIVER_NAME, SKIN, AI_LEVEL and AI_AGGRESSION. Sections can appear in any order in the file.
--   * [SESSION_0] STARTING_POSITION is the player's grid slot (1-based).
--   * CM picks new random AI names at every launch, so a meeting stores its entry list and writes it
--     back on each relaunch.
-- ac.restartAssettoCorsa(raceIni) MERGES the text we give it into race.ini, so we always write every
-- key of every section we touch.
local M = {}

-- text -> { sections = { NAME = { key = value } }, order = { "NAME", ... } }
function M.parse(text)
  local ini = { sections = {}, order = {} }
  local cur
  for line in (text or ""):gmatch("[^\r\n]+") do
    local sec = line:match("^%s*%[([^%]]+)%]%s*$")
    if sec then
      cur = ini.sections[sec]
      if not cur then cur = {}; ini.sections[sec] = cur; ini.order[#ini.order + 1] = sec end
    elseif cur and not line:match("^%s*[;#]") then
      local k, v = line:match("^%s*([^=]-)%s*=%s*(.-)%s*$")
      if k and k ~= "" then cur[k] = v end
    end
  end
  return ini
end

-- sections: ordered array of { name, { {key, value}, ... } } -> INI text (CRLF, like CM writes)
function M.serialise(sections)
  local out = {}
  for _, s in ipairs(sections) do
    out[#out + 1] = "[" .. s[1] .. "]"
    for _, kv in ipairs(s[2]) do out[#out + 1] = kv[1] .. "=" .. tostring(kv[2]) end
    out[#out + 1] = ""
  end
  return table.concat(out, "\r\n")
end

local CAR_KEYS = { "MODEL", "MODEL_CONFIG", "SKIN", "SETUP", "DRIVER_NAME", "NATIONALITY", "NATION_CODE",
  "BALLAST", "RESTRICTOR", "AI_LEVEL", "AI_AGGRESSION" }

-- The entry list as CM wrote it: { { name=, isPlayer=, keys = {KEY = value} }, ... } in CAR_n order.
function M.entries(ini)
  local list = {}
  local n = tonumber(ini.sections.RACE and ini.sections.RACE.CARS) or 0
  for i = 0, n - 1 do
    local s = ini.sections["CAR_" .. i]
    if s then
      local keys = {}
      for _, k in ipairs(CAR_KEYS) do if s[k] ~= nil then keys[k] = s[k] end end
      list[#list + 1] = { name = s.DRIVER_NAME or ("Car " .. i), isPlayer = i == 0, keys = keys }
    end
  end
  return list
end

-- One session's race.ini to merge on restart.
-- entries: the meeting's entry list (player first, as from M.entries).
-- grid: array of entry names in grid order (P1 first); entries not in it go to the back in list order.
-- session: { name=, type = 1 practice | 2 qualify | 3 race, laps=, minutes=, raceLaps= }
-- extra: optional { {section, { {key, value} } } } appended (e.g. our meeting marker).
-- The player keeps CAR_0 and gets STARTING_POSITION; the AI fill the other slots in CAR_n order.
function M.forSession(entries, grid, session, extra)
  local order, seen = {}, {}
  for _, nm in ipairs(grid or {}) do
    for _, e in ipairs(entries) do
      if e.name == nm and not seen[nm] then seen[nm] = true; order[#order + 1] = e end
    end
  end
  for _, e in ipairs(entries) do if not seen[e.name] then seen[e.name] = true; order[#order + 1] = e end end

  local playerSlot, ai = 1, {}
  for slot, e in ipairs(order) do
    if e.isPlayer then playerSlot = slot else ai[#ai + 1] = e end
  end

  local sections = {}
  local function car(idx, e)
    local kv = {}
    for _, k in ipairs(CAR_KEYS) do if e.keys[k] ~= nil then kv[#kv + 1] = { k, e.keys[k] } end end
    sections[#sections + 1] = { "CAR_" .. idx, kv }
  end
  for _, e in ipairs(entries) do if e.isPlayer then car(0, e) end end
  for i, e in ipairs(ai) do car(i, e) end

  local race = { { "CARS", #order } }
  if session.raceLaps then race[#race + 1] = { "RACE_LAPS", session.raceLaps } end
  table.insert(sections, 1, { "RACE", race })
  sections[#sections + 1] = { "SESSION_0", {
    { "NAME", session.name }, { "TYPE", session.type }, { "LAPS", session.laps or 0 },
    { "DURATION_MINUTES", session.minutes or 0 }, { "SPAWN_SET", session.type == 3 and "START" or "PIT" },
    { "STARTING_POSITION", playerSlot },
  } }
  for _, x in ipairs(extra or {}) do sections[#sections + 1] = x end
  return M.serialise(sections), playerSlot
end

return M
