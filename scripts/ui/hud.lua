local Catalog = require("scripts.data.goals")
local Hud = {}

local function formatTime(seconds)
  local value = math.max(0, seconds or 0)
  return string.format("%02d:%02d", math.floor(value / 60), value % 60)
end

function Hud.render(state)
  if not state.settings.hud.visible or state.menu.open then return end
  local x, y = state.settings.hud.x, state.settings.hud.y
  Isaac.RenderText("ACHIEVEMENT TRACKER", x, y, 1, 0.85, 0.25, 1)
  y = y + 12
  for _, id in ipairs(state.tracker.ids) do
    local goal = Catalog.get(id)
    if goal then
      local text = Catalog.text(goal, state.settings.language)
      local suffix = ""
      if goal.deadline then suffix = "  < " .. formatTime(goal.deadline) end
      Isaac.RenderText("- " .. text.name .. suffix, x, y, 1, 1, 1, 1)
      y = y + 11
    end
  end
  Isaac.RenderText("F3: goals  |  F4: hide", x, y + 2, 0.65, 0.65, 0.65, 1)
end

function Hud.renderWarning(state)
  local warning = state.activeWarning
  if not warning or warning.untilFrame < Isaac.GetFrameCount() then return end
  local goal = Catalog.get(warning.goalId)
  if not goal then return end
  local text = Catalog.text(goal, state.settings.language)
  local message = warning.kind == "deadline"
    and (text.name .. ": " .. formatTime(warning.remaining) .. " remaining")
    or (text.name .. ": condition lost (" .. tostring(warning.reason or warning.kind) .. ")")
  local width = Isaac.GetScreenWidth()
  Isaac.RenderText(message, math.max(12, width / 2 - #message * 3), 42, 1, 0.35, 0.25, 1)
end

return Hud
