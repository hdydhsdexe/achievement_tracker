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
local SCREEN_MARGIN = 8
local MIN_HUD_WIDTH = 120
local MIN_FONT_PIXELS = 8
local MAX_FONT_PIXELS = 32

local function progressText(value, target)
  local ratio = target > 0 and math.min(1, value / target) or 0
  local segments = 10
  local filled = math.floor(ratio * segments + 0.5)
  return "[" .. string.rep("#", filled) .. string.rep("-", segments - filled) .. "]"
end

local function formatTime(seconds)
  local value = math.max(0, seconds or 0)
  return string.format("%02d:%02d", math.floor(value / 60), value % 60)
end

local function buildRows(state, pixelSize, x, screenWidth)
  local settings = state.settings
  local language = Text.resolveLanguage(settings.language)
  local labels = Text.labels(language)
  local rows = {}
  local maxWidth = math.max(1, screenWidth - SCREEN_MARGIN - x)
  local routeContext = state.routeContext or Routes.context(Game(), state.run)
  local function addWrapped(value, indent, color, factor)
    local rowPixels = math.max(MIN_FONT_PIXELS,
      Text.pixel(pixelSize * (factor or 1)))
    local actualScale = Text.scaleForPixels(rowPixels)
    for _, line in ipairs(Text.wrap(value, maxWidth - indent, actualScale)) do
      table.insert(rows, { text=line, indent=indent, color=color, scale=actualScale,
        height=math.max(8, Text.pixel(12 * actualScale)) })
    end
  end
  addWrapped(labels.title, 0, HUD_TITLE, 1)
  local trackedIds = state.tracker.ids
  local challengeId = Isaac.GetChallenge()
  if challengeId ~= 0 then
    local challengeGoal = Catalog.challengeGoal(challengeId)
    trackedIds = challengeGoal and { challengeGoal.id } or {}
  end
  for _, id in ipairs(trackedIds) do
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
        addWrapped("- " .. text.name .. markProgress, 0, routeColor, 1)
        local currentPrefix = language == "zh" and "当前：" or "NOW: "
        local nextPrefix = language == "zh" and "下一步：" or "NEXT: "
        addWrapped(currentPrefix .. route.current, 8, routeColor, 0.9)
        if route.next then addWrapped(nextPrefix .. route.next, 8, HUD_MUTED, 0.85) end
      else
        -- Non-route goals retain the original compact completion-condition HUD.
        addWrapped("- " .. text.detail .. suffix, 0, color, 1)
      end
      if progress and not route then
        addWrapped(progressText(progress, target), 8, color, 0.8)
      end
    end
  end
  addWrapped(labels.controls, 0, HUD_MUTED, 0.8)
  return rows, language
end

local function fitLayout(state)
  local screenWidth, screenHeight = Isaac.GetScreenWidth(), Isaac.GetScreenHeight()
  local preferredX = tonumber(state.settings.hud.x) or SCREEN_MARGIN
  local maximumX = math.max(SCREEN_MARGIN,
    screenWidth - SCREEN_MARGIN - MIN_HUD_WIDTH)
  local x = math.max(SCREEN_MARGIN, math.min(maximumX, preferredX))
  local requestedPixels = math.max(MIN_FONT_PIXELS, math.min(MAX_FONT_PIXELS,
    Text.pixel((tonumber(state.settings.hud.fontScale) or 1) * 16)))
  local chosenRows, language, totalHeight
  for pixelSize = requestedPixels, MIN_FONT_PIXELS, -1 do
    local rows
    rows, language = buildRows(state, pixelSize, x, screenWidth)
    local height = 0
    for _, row in ipairs(rows) do height = height + row.height end
    chosenRows, totalHeight = rows, height
    if totalHeight <= screenHeight - SCREEN_MARGIN * 2 then break end
  end
  local preferredY = tonumber(state.settings.hud.y) or SCREEN_MARGIN
  local y = math.max(SCREEN_MARGIN, math.min(preferredY,
    screenHeight - SCREEN_MARGIN - totalHeight))
  return { x=Text.pixel(x), y=Text.pixel(y), rows=chosenRows,
    language=language, totalHeight=totalHeight }
end

function Hud.render(state)
  if not state.settings.hud.visible or state.menu.open then return end
  local layout = fitLayout(state)
  local y = layout.y
  for _, row in ipairs(layout.rows) do
    Text.draw(row.text, layout.x + row.indent, y, row.scale,
      row.color, layout.language)
    y = y + row.height
  end
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
  local screenWidth, screenHeight = Isaac.GetScreenWidth(), Isaac.GetScreenHeight()
  local maxWidth = screenWidth - SCREEN_MARGIN * 2
  local requestedPixels = math.max(MIN_FONT_PIXELS, math.min(MAX_FONT_PIXELS,
    Text.pixel((tonumber(state.settings.hud.fontScale) or 1) * 16)))
  local lines, scale, lineHeight
  for pixelSize = requestedPixels, MIN_FONT_PIXELS, -1 do
    scale = Text.scaleForPixels(pixelSize)
    lineHeight = math.max(8, Text.pixel(12 * scale))
    lines = Text.wrap(message, maxWidth, scale)
    if #lines * lineHeight <= screenHeight - SCREEN_MARGIN * 2 then break end
  end
  local y = math.max(SCREEN_MARGIN,
    Text.pixel((screenHeight - #lines * lineHeight) / 2))
  for _, line in ipairs(lines) do
    Text.draw(line, SCREEN_MARGIN, y, scale, HUD_FAILED, language, maxWidth, true)
    y = y + lineHeight
  end
end

return Hud
