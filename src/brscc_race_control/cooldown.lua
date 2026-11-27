-- cooldown.lua: after the chequered flag (REGS 2.8). Pure logic.
-- Drivers must slow progressively, stay behind any competitor ahead of them, and return to the pit lane.
-- This tracks the order cars took the flag in and reports anyone who passes a finished car ahead.
local M = {}

function M.new() return { order = {}, at = {}, reported = {} } end

-- A car took the chequered flag: it joins the cool-down queue in that order.
function M.finished(st, id)
  if st.at[id] then return end
  st.order[#st.order + 1] = id
  st.at[id] = #st.order
end

-- progress: id -> absolute track progress (laps completed + lap fraction). Leave out (nil) a car that
-- has entered the pit lane: passing a car going into the pits is not an offence.
-- Returns { {passer=, passed=} } for new passes of a car that finished ahead (REGS 2.8 II), each once.
function M.check(st, progress)
  local out = {}
  for i = 1, #st.order do
    for j = i + 1, #st.order do
      local ahead, behind = st.order[i], st.order[j]
      local pa, pb = progress[ahead], progress[behind]
      local key = tostring(behind) .. ">" .. tostring(ahead)
      if pa and pb and pb > pa and not st.reported[key] then
        st.reported[key] = true
        out[#out + 1] = { passer = behind, passed = ahead }
      end
    end
  end
  return out
end

return M
