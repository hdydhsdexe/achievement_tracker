local Catalog = require("scripts.data.goals")
local CompletionMarks = require("scripts.core.completion_marks")
local Routes = require("scripts.core.routes")
local Text = require("scripts.ui.text")
local Sensors = require("scripts.core.sensors")
local LongTermProgress = require("scripts.core.long_term_progress")
local RouteRecommendations = require("scripts.core.route_recommendations")
local Tracker = require("scripts.core.tracker")
local Hud = {}

local HUD_TITLE = KColor(1.00, 0.94, 0.78, 1)
local HUD_BODY = KColor(0.96, 0.86, 0.68, 1)
local HUD_MUTED = KColor(0.72, 0.65, 0.56, 1)
local HUD_COMPLETED = KColor(0.60, 1.00, 0.65, 1)
local HUD_WARNING = KColor(1.00, 0.84, 0.28, 1)
local HUD_OPPORTUNITY = KColor(1.00, 0.88, 0.54, 1)
local HUD_FAILED = KColor(1.00, 0.38, 0.34, 1)
local SCREEN_MARGIN = 8
local MIN_HUD_WIDTH = 120
local HUD_FONT_PIXELS = { 11, 22, 33 }
local PAGE_ROTATION_FRAMES = 150
local currentLayoutSignature = nil
local pageStartedFrame = 0

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

local function wrappedRows(value, indent, color, maxWidth, fontPixels)
  local rows = {}
  for _, line in ipairs(Text.wrapPixels(value, math.max(1, maxWidth - indent), fontPixels)) do
    table.insert(rows, { text=line, indent=indent, color=color })
  end
  return rows
end

local function appendRows(target, source)
  for _, row in ipairs(source) do table.insert(target, row) end
end

local function lineAdvance(fontPixels, lineSpacingPixels)
  return Text.lineHeightPixels(fontPixels) + lineSpacingPixels
end

local function contentHeight(lines, fontPixels, lineSpacingPixels)
  if lines <= 0 then return 0 end
  return lines * Text.lineHeightPixels(fontPixels)
    + (lines - 1) * lineSpacingPixels
end

local function maximumLineCount(availableHeight, fontPixels, lineSpacingPixels)
  return math.max(1, math.floor((availableHeight + lineSpacingPixels)
    / lineAdvance(fontPixels, lineSpacingPixels)))
end

local function opportunityBlock(state, language, maxWidth, fontPixels)
  local opportunity = state.sceneOpportunities and state.sceneOpportunities[1]
  if opportunity and not opportunity.message then
    for _, candidate in ipairs(state.sceneOpportunities) do
      if candidate.message then opportunity = candidate; break end
    end
  end
  if not opportunity or not opportunity.message then return nil end
  local value = opportunity.message[language] or opportunity.message.en
  if type(value) ~= "string" or value == "" then return nil end
  return wrappedRows("! " .. value, 0,
    opportunity.danger and HUD_FAILED or HUD_OPPORTUNITY, maxWidth, fontPixels)
end

local function completionNoticeBlocks(state, language, maxWidth, fontPixels)
  local blocks = {}
  local labels = Text.labels(language)
  for _, id in ipairs(state.completionNotices or {}) do
    local goal = Catalog.get(id)
    if goal then
      blocks[#blocks + 1] = wrappedRows(string.format(labels.goalCompleted, Catalog.text(goal,
        language).name), 0, HUD_COMPLETED, maxWidth, fontPixels)
    end
  end
  return blocks
end

local function routeDetailsHeld()
  return Input and Keyboard and Input.IsButtonPressed
    and Input.IsButtonPressed(Keyboard.KEY_TAB, 0)
end

local function appendCompactActions(rows, actions, color, maxWidth, fontPixels)
  for _, action in ipairs(actions or {}) do
    appendRows(rows, wrappedRows(action.text, 0,
      action.available and color or HUD_MUTED, maxWidth, fontPixels))
  end
end

local function routeBlock(state, language, maxWidth, fontPixels)
  local route = state.tracker.route
  local recommended = false
  if not route and state.run.startRoomPrompt then
    route = state.run.routeRecommendation
    recommended = route ~= nil
  end
  if not route then return nil end
  local labels = Text.labels(language)
  local evaluationContext = state.routeContext or Routes.context(Game(), state.run)
  local evaluation = RouteRecommendations.combinedEvaluation(route, {
    getGoal=Catalog.get,
    context=evaluationContext,
    completionStore=state.settings.completionMarks,
    language=language,
    tracked=not recommended
  })
  local completed = 0
  for _, id in ipairs(route.memberIds or {}) do
    local goal = Catalog.get(id)
    if goal and ((state.profileCompleted and state.profileCompleted[id])
      or (state.run.completedGoals and state.run.completedGoals[id])
      or CompletionMarks.isSatisfied(goal, state.settings.completionMarks)) then
      completed = completed + 1
    end
  end
  local color = evaluation.severity == "failed" and HUD_FAILED
    or evaluation.severity == "warning" and HUD_WARNING
    or evaluation.severity == "completed" and HUD_COMPLETED
    or HUD_BODY
  local rows = {}
  local expanded = routeDetailsHeld()
  local compactActions = evaluation.severity ~= "failed"
    and evaluation.severity ~= "completed"
    and Routes.compactActions(evaluationContext, language) or nil
  if expanded then
    local heading = recommended and labels.routeRecommendation or labels.trackedRoute
    local routeProgress = string.format(labels.routeProgress, completed, #route.memberIds)
    appendRows(rows, wrappedRows("- " .. heading .. "："
      .. RouteRecommendations.label(route, language) .. "  " .. routeProgress,
      0, color, maxWidth, fontPixels))
    local memberNames = {}
    for _, id in ipairs(route.memberIds or {}) do
      local goal = Catalog.get(id)
      if goal then memberNames[#memberNames + 1] = Catalog.text(goal, language).name end
    end
    appendRows(rows, wrappedRows(labels.routeMembers .. "：" .. table.concat(memberNames, "、"),
      8, HUD_MUTED, maxWidth, fontPixels))
  end
  if not expanded and compactActions then
    appendCompactActions(rows, compactActions, color, maxWidth, fontPixels)
  elseif #evaluation.current > 0 then
    appendRows(rows, wrappedRows((language == "zh" and "当前：" or "NOW: ")
      .. table.concat(evaluation.current, " / "), expanded and 8 or 0,
      color, maxWidth, fontPixels))
  end
  if expanded and #evaluation.next > 0 then
    appendRows(rows, wrappedRows((language == "zh" and "下一步：" or "NEXT: ")
      .. table.concat(evaluation.next, " / "), 8, HUD_MUTED, maxWidth, fontPixels))
  end
  if recommended then
    appendRows(rows, wrappedRows(labels.trackRecommendedRoute,
      8, HUD_OPPORTUNITY, maxWidth, fontPixels))
  end
  for _, warning in ipairs(evaluation.departureWarnings or {}) do
    appendRows(rows, wrappedRows("! " .. warning, 0, HUD_WARNING, maxWidth, fontPixels))
  end
  for _, hint in ipairs(evaluation.contextHints or {}) do
    appendRows(rows, wrappedRows("> " .. hint, 0, HUD_OPPORTUNITY, maxWidth, fontPixels))
  end
  return rows
end

local function quickNoticeBlock(state, language, maxWidth, fontPixels)
  local notice = state.quickTrackNotice
  if not notice or notice.untilFrame < Isaac.GetFrameCount() then return nil end
  local value = Text.labels(language)[notice.key]
  return value and wrappedRows("! " .. value, 0, HUD_FAILED, maxWidth, fontPixels) or nil
end

local function buildBlocks(state, fontPixels, x, screenWidth)
  local settings = state.settings
  local language = Text.resolveLanguage(settings.language)
  local labels = Text.labels(language)
  local maxWidth = math.max(1, screenWidth - SCREEN_MARGIN - x)
  local headerRows = wrappedRows(labels.title, 0, HUD_TITLE, maxWidth, fontPixels)
  local blocks = {}
  for _, block in ipairs(completionNoticeBlocks(state, language, maxWidth, fontPixels)) do
    table.insert(blocks, block)
  end
  local routeContext = state.routeContext or Routes.context(Game(), state.run)
  local trackedIds = state.tracker.ids
  local challengeId = Isaac.GetChallenge()
  if challengeId ~= 0 then
    local challengeGoal = Catalog.challengeGoal(challengeId)
    trackedIds = challengeGoal and { challengeGoal.id } or {}
  end
  local combinedRoute = challengeId == 0
    and routeBlock(state, language, maxWidth, fontPixels) or nil
  if combinedRoute then table.insert(blocks, combinedRoute) end
  for _, id in ipairs(trackedIds) do
    local goal = Catalog.get(id)
    if goal and not Tracker.routeContains(state.tracker, id) then
      local block = {}
      local text = Catalog.text(goal, language)
      local route = Routes.evaluate(goal, routeContext, settings.completionMarks, language)
      local suffix = goal.deadline and ("  < " .. formatTime(goal.deadline)) or ""
      local progress, target = Sensors.progress(goal, state.run)
      if progress then suffix = suffix .. string.format("  (%d/%d)", progress, target) end
      local longTerm = LongTermProgress.format(goal, state, language)
      if longTerm then suffix = suffix .. longTerm end
      local failed = state.run.failedGoals and state.run.failedGoals[goal.id]
      local completed = (state.profileCompleted and state.profileCompleted[goal.id])
        or (state.run.completedGoals and state.run.completedGoals[goal.id])
        or CompletionMarks.isSatisfied(goal, settings.completionMarks)
      local color = failed and HUD_FAILED
        or completed and HUD_COMPLETED
        or HUD_BODY
      local routeConflict = not completed and state.tracker.route
        and RouteRecommendations.conflicts(goal,
        state.tracker.route, {
          difficulty=CompletionMarks.difficultyValue(Game()),
          completionStore=settings.completionMarks,
          currentPlayers=routeContext.players
        })
      if routeConflict then
        color = HUD_FAILED
        suffix = suffix .. "  · " .. labels.routeConflict
      end
      if route then
        local expanded = routeDetailsHeld()
        local routeColor = routeConflict and HUD_FAILED
          or route.severity == "failed" and HUD_FAILED
          or route.severity == "warning" and HUD_WARNING
          or route.severity == "completed" and HUD_COMPLETED
          or color
        local markProgress = route.required > 1
          and string.format("  [%d/%d]", route.known, route.required) or ""
        local currentPrefix = language == "zh" and "当前：" or "NOW: "
        local nextPrefix = language == "zh" and "下一步：" or "NEXT: "
        if route and not expanded then
          local compactActions = route.severity ~= "failed"
            and route.severity ~= "completed"
            and Routes.compactActions(routeContext, language) or nil
          if compactActions then
            appendCompactActions(block, compactActions, routeColor, maxWidth, fontPixels)
          else
            appendRows(block, wrappedRows(currentPrefix .. route.current,
              0, routeColor, maxWidth, fontPixels))
          end
        else
          appendRows(block, wrappedRows("- " .. text.name .. markProgress,
            0, routeColor, maxWidth, fontPixels))
          appendRows(block, wrappedRows(currentPrefix .. route.current,
            8, routeColor, maxWidth, fontPixels))
        end
        if expanded and route.next then
          appendRows(block, wrappedRows(nextPrefix .. route.next,
            8, HUD_MUTED, maxWidth, fontPixels))
        end
        local guidance = RouteRecommendations.goalGuidance(goal, route, {
          context=routeContext, completionStore=settings.completionMarks,
          language=language
        })
        for _, warning in ipairs(guidance.departureWarnings or {}) do
          appendRows(block, wrappedRows("! " .. warning,
            0, HUD_WARNING, maxWidth, fontPixels))
        end
      else
        appendRows(block, wrappedRows("- " .. text.detail .. suffix,
          0, color, maxWidth, fontPixels))
        if progress then
          appendRows(block, wrappedRows(progressText(progress, target),
            8, color, maxWidth, fontPixels))
        end
      end
      table.insert(blocks, block)
    end
  end
  local opportunity = opportunityBlock(state, language, maxWidth, fontPixels)
  if opportunity then table.insert(blocks, opportunity) end
  local notice = quickNoticeBlock(state, language, maxWidth, fontPixels)
  if notice then table.insert(blocks, notice) end
  return {
    headerRows=headerRows, blocks=blocks, controls=labels.controls,
    language=language, maxWidth=maxWidth, fontPixels=fontPixels
  }
end

local function footerRows(content, page, pages)
  local label = content.controls .. string.format("  [%d/%d]", page, pages)
  return wrappedRows(label, 0, HUD_MUTED, content.maxWidth, content.fontPixels)
end

local function allBlockRows(blocks)
  local rows = {}
  for _, block in ipairs(blocks) do appendRows(rows, block) end
  return rows
end

local function pageLineCount(content, rows, page, pages)
  return #content.headerRows + #rows + #footerRows(content, page, pages)
end

local function staticLayout(state, fontPixels, x, screenWidth, lineSpacingPixels)
  local content = buildBlocks(state, fontPixels, x, screenWidth)
  local rows = allBlockRows(content.blocks)
  local lines = pageLineCount(content, rows, 1, 1)
  return { content=content, pages={ rows }, lines=lines,
    totalHeight=contentHeight(lines, fontPixels, lineSpacingPixels),
    x=x, fontPixels=fontPixels, lineSpacingPixels=lineSpacingPixels }
end

local function paginateBlocks(content, availableLines)
  local fixedLines = #content.headerRows + #footerRows(content, 99, 99)
  local capacity = math.max(1, availableLines - fixedLines)
  local pages, page, split = {}, {}, false
  local function flush()
    if #page > 0 then table.insert(pages, page) end
    page = {}
  end
  for _, block in ipairs(content.blocks) do
    if #block > capacity then
      flush()
      split = true
      local offset = 1
      while offset <= #block do
        local chunk = {}
        for index = offset, math.min(#block, offset + capacity - 1) do
          table.insert(chunk, block[index])
        end
        table.insert(pages, chunk)
        offset = offset + capacity
      end
    else
      if #page + #block > capacity then flush() end
      appendRows(page, block)
    end
  end
  flush()
  if #pages == 0 then table.insert(pages, {}) end
  return pages, split
end

local function pagedLayout(state, x, screenWidth, availableHeight, lineSpacingPixels)
  local fontPixels = 11
  local content = buildBlocks(state, fontPixels, x, screenWidth)
  local availableLines = maximumLineCount(availableHeight,
    fontPixels, lineSpacingPixels)
  local pages, split = paginateBlocks(content, availableLines)
  local maximumLines = 1
  for page, rows in ipairs(pages) do
    maximumLines = math.max(maximumLines,
      pageLineCount(content, rows, page, #pages))
  end
  return { content=content, pages=pages, split=split, lines=maximumLines,
    totalHeight=contentHeight(maximumLines, fontPixels, lineSpacingPixels),
    x=x, fontPixels=fontPixels, lineSpacingPixels=lineSpacingPixels }
end

local function requestedTierIndex(fontPixels)
  for index, pixels in ipairs(HUD_FONT_PIXELS) do
    if pixels == fontPixels then return index end
  end
  return 1
end

local function placeVertically(layout, preferredY, screenHeight)
  local totalHeight = layout.totalHeight
  layout.y = math.max(SCREEN_MARGIN, math.min(preferredY,
    screenHeight - SCREEN_MARGIN - totalHeight))
  return layout
end

local function fitLayout(state)
  local screenWidth, screenHeight = Isaac.GetScreenWidth(), Isaac.GetScreenHeight()
  local preferredX = tonumber(state.settings.hud.x) or SCREEN_MARGIN
  local maximumX = math.max(SCREEN_MARGIN,
    screenWidth - SCREEN_MARGIN - MIN_HUD_WIDTH)
  local x = math.max(SCREEN_MARGIN, math.min(maximumX, preferredX))
  local preferredY = tonumber(state.settings.hud.y) or SCREEN_MARGIN
  local availableHeight = screenHeight - SCREEN_MARGIN * 2
  local requestedPixels = state.settings.hud.fontPixels or 11
  local lineSpacingPixels = state.settings.hud.lineSpacingPixels or 0
  local requestedIndex = requestedTierIndex(requestedPixels)
  for tierIndex = requestedIndex, 1, -1 do
    local layout = staticLayout(state, HUD_FONT_PIXELS[tierIndex], x,
      screenWidth, lineSpacingPixels)
    if layout.totalHeight <= availableHeight then
      return placeVertically(layout, preferredY, screenHeight)
    end
  end
  for candidateX = x - 1, SCREEN_MARGIN, -1 do
    local layout = staticLayout(state, 11, candidateX,
      screenWidth, lineSpacingPixels)
    if layout.totalHeight <= availableHeight then
      return placeVertically(layout, preferredY, screenHeight)
    end
  end
  local fallback = pagedLayout(state, SCREEN_MARGIN, screenWidth,
    availableHeight, lineSpacingPixels)
  return placeVertically(fallback, preferredY, screenHeight)
end

local function layoutSignature(layout)
  local parts = { layout.content.language, tostring(layout.x), tostring(layout.y),
    tostring(layout.fontPixels), tostring(layout.lineSpacingPixels),
    tostring(#layout.pages) }
  for _, page in ipairs(layout.pages) do
    for _, row in ipairs(page) do table.insert(parts, row.text) end
    table.insert(parts, "|")
  end
  return table.concat(parts, "\31")
end

local function activePage(layout)
  local signature = layoutSignature(layout)
  local now = Isaac.GetFrameCount()
  if signature ~= currentLayoutSignature then
    currentLayoutSignature = signature
    pageStartedFrame = now
  end
  return math.floor((now - pageStartedFrame) / PAGE_ROTATION_FRAMES)
    % #layout.pages + 1
end

function Hud.render(state)
  if not state.settings.hud.visible or state.menu.open then return end
  local layout = fitLayout(state)
  local page = activePage(layout)
  local rows = {}
  appendRows(rows, layout.content.headerRows)
  appendRows(rows, layout.pages[page])
  appendRows(rows, footerRows(layout.content, page, #layout.pages))
  local y = layout.y
  local advance = lineAdvance(layout.fontPixels, layout.lineSpacingPixels)
  for _, row in ipairs(rows) do
    Text.drawPixels(row.text, layout.x + row.indent, y, layout.fontPixels,
      row.color, layout.content.language)
    y = y + advance
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
  local maximumHeight = screenHeight - SCREEN_MARGIN * 2
  local requestedIndex = requestedTierIndex(state.settings.hud.fontPixels or 11)
  local lineSpacingPixels = state.settings.hud.lineSpacingPixels or 0
  local lines, fontPixels, warningHeight
  for tierIndex = requestedIndex, 1, -1 do
    fontPixels = HUD_FONT_PIXELS[tierIndex]
    lines = Text.wrapPixels(message, maxWidth, fontPixels)
    warningHeight = contentHeight(#lines, fontPixels, lineSpacingPixels)
    if warningHeight <= maximumHeight then break end
  end
  local y = math.max(SCREEN_MARGIN,
    Text.pixel((screenHeight - warningHeight) / 2))
  local advance = lineAdvance(fontPixels, lineSpacingPixels)
  for _, line in ipairs(lines) do
    Text.drawPixels(line, SCREEN_MARGIN, y, fontPixels,
      HUD_FAILED, language, maxWidth, true)
    y = y + advance
  end
end

return Hud
