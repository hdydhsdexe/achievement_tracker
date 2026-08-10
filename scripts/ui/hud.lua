local Catalog = require("scripts.data.goals")
local Text = require("scripts.ui.text")
local Sensors = require("scripts.core.sensors")
local Hud = {}

local function drawProgress(x, y, scale, value, target, color, language)
  local ratio = target > 0 and math.min(1, value / target) or 0
  local segments = 10
  local filled = math.floor(ratio * segments + 0.5)
  local bar = "[" .. string.rep("#", filled) .. string.rep("-", segments - filled) .. "]"
  Text.draw(bar, x, y, scale, color, language)
end

local function formatTime(seconds)
  local value = math.max(0, seconds or 0)
  return string.format("%02d:%02d", math.floor(value / 60), value % 60)
end

function Hud.render(state)
  if not state.settings.hud.visible or state.menu.open then return end
  local settings = state.settings
  local language = Text.resolveLanguage(settings.language)
  local labels = Text.labels(language)
  local scale = settings.hud.fontScale
  local x, y = settings.hud.x, settings.hud.y
  local lineHeight = math.max(9, math.floor(12 * scale))
  Text.draw(labels.title, x, y, scale, KColor(1, 0.85, 0.25, 1), language)
  y = y + lineHeight
  for _, id in ipairs(state.tracker.ids) do
    local goal = Catalog.get(id)
    if goal then
      local text = Catalog.text(goal, language)
      local suffix = goal.deadline and ("  < " .. formatTime(goal.deadline)) or ""
      local progress, target = Sensors.progress(goal, state.run)
      if progress then suffix = suffix .. string.format("  (%d/%d)", progress, target) end
      local failed = state.run.failedGoals and state.run.failedGoals[goal.id]
      local completed = (state.profileCompleted and state.profileCompleted[goal.id])
        or (state.run.completedGoals and state.run.completedGoals[goal.id])
      local color = failed and KColor(1, 0.25, 0.25, 1)
        or completed and KColor(0.25, 1, 0.35, 1)
        or KColor(1, 1, 1, 1)
      -- The persistent HUD intentionally shows the completion condition, not the achievement name.
      Text.draw("- " .. text.detail .. suffix, x, y, scale, color, language)
      y = y + lineHeight
      if progress then
        drawProgress(x + 8, y - 2, scale * 0.8, progress, target, color, language)
        y = y + math.max(6, math.floor(8 * scale))
      end
    end
  end
  Text.draw(labels.controls, x, y + 2, scale * 0.8, KColor(0.65, 0.65, 0.65, 1), language)
end

function Hud.renderWarning(state)
  local warning = state.activeWarning
  if not warning or warning.untilFrame < Isaac.GetFrameCount() then return end
  local goal = Catalog.get(warning.goalId)
  if not goal then return end
  local language = Text.resolveLanguage(state.settings.language)
  local labels = Text.labels(language)
  local detail = Catalog.text(goal, language).detail
  local message = warning.kind == "deadline"
    and (detail .. "：" .. formatTime(warning.remaining) .. " " .. labels.remaining)
    or (detail .. "：" .. labels.failed .. " (" .. tostring(warning.reason or warning.kind) .. ")")
  Text.draw(message, 12, 42, state.settings.hud.fontScale, KColor(1, 0.35, 0.25, 1), language, Isaac.GetScreenWidth() - 24, true)
end

return Hud
