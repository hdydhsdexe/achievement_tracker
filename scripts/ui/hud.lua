local Catalog = require("scripts.data.goals")
local CompletionMarks = require("scripts.core.completion_marks")
local Routes = require("scripts.core.routes")
local Text = require("scripts.ui.text")
local Sensors = require("scripts.core.sensors")
local Hud = {}

local HUD_TITLE = KColor(1.00, 0.94, 0.78, 1)
local HUD_BODY = KColor(0.96, 0.86, 0.68, 1)
local HUD_MUTED = KColor(0.72, 0.65, 0.56, 1)
local HUD_COMPLETED = KColor(0.60, 1.00, 0.65, 1)
local HUD_WARNING = KColor(1.00, 0.84, 0.28, 1)
local HUD_FAILED = KColor(1.00, 0.38, 0.34, 1)

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
  local maxWidth = math.max(120, Isaac.GetScreenWidth() - x - 12)
  local routeContext = state.routeContext or Routes.context(Game(), state.run)
  local function drawWrapped(value, indent, color, textScale)
    local actualScale = textScale or scale
    for _, line in ipairs(Text.wrap(value, maxWidth - indent, actualScale)) do
      Text.draw(line, x + indent, y, actualScale, color, language)
      y = y + math.max(8, math.floor(12 * actualScale))
    end
  end
  Text.draw(labels.title, x, y, scale, HUD_TITLE, language)
  y = y + lineHeight
  for _, id in ipairs(state.tracker.ids) do
    local goal = Catalog.get(id)
    if goal then
      local text = Catalog.text(goal, language)
      local route = Routes.evaluate(goal, routeContext, settings.completionMarks, language)
      local suffix = goal.deadline and ("  < " .. formatTime(goal.deadline)) or ""
      local progress, target = Sensors.progress(goal, state.run)
      if progress then suffix = suffix .. string.format("  (%d/%d)", progress, target) end
      local failed = state.run.failedGoals and state.run.failedGoals[goal.id]
      local completed = (state.profileCompleted and state.profileCompleted[goal.id])
        or (state.run.completedGoals and state.run.completedGoals[goal.id])
        or CompletionMarks.isSatisfied(goal, settings.completionMarks)
      local color = failed and HUD_FAILED
        or completed and HUD_COMPLETED
        or HUD_BODY
      if route then
        local routeColor = route.severity == "failed" and HUD_FAILED
          or route.severity == "warning" and HUD_WARNING
          or route.severity == "completed" and HUD_COMPLETED
          or color
        local markProgress = route.required > 1
          and string.format("  [%d/%d]", route.known, route.required) or ""
        drawWrapped("- " .. text.name .. markProgress, 0, routeColor, scale)
        local currentPrefix = language == "zh" and "当前：" or "NOW: "
        local nextPrefix = language == "zh" and "下一步：" or "NEXT: "
        drawWrapped(currentPrefix .. route.current, 8, routeColor, scale * 0.9)
        if route.next then drawWrapped(nextPrefix .. route.next, 8, HUD_MUTED, scale * 0.85) end
      else
        -- Non-route goals retain the original compact completion-condition HUD.
        drawWrapped("- " .. text.detail .. suffix, 0, color, scale)
      end
      if progress and not route then
        drawProgress(x + 8, y - 2, scale * 0.8, progress, target, color, language)
        y = y + math.max(6, math.floor(8 * scale))
      end
    end
  end
  Text.draw(labels.controls, x, y + 2, scale * 0.8, HUD_MUTED, language)
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
  Text.draw(message, 12, 42, state.settings.hud.fontScale, HUD_FAILED, language,
    Isaac.GetScreenWidth() - 24, true)
end

return Hud
