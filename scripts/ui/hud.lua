local Catalog = require("scripts.data.goals")
local Text = require("scripts.ui.text")
local Hud = {}

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
      -- The persistent HUD intentionally shows the completion condition, not the achievement name.
      Text.draw("- " .. text.detail .. suffix, x, y, scale, KColor(1, 1, 1, 1), language)
      y = y + lineHeight
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
