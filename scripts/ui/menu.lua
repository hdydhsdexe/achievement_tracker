local Catalog = require("scripts.data.goals")
local CompletionMarks = require("scripts.core.completion_marks")
local CharacterRelevance = require("scripts.core.character_relevance")
local Routes = require("scripts.core.routes")
local Rewards = require("scripts.core.rewards")
local LongTermProgress = require("scripts.core.long_term_progress")
local Recommendations = require("scripts.data.recommendations")
local RouteRecommendations = require("scripts.core.route_recommendations")
local RewardIcons = require("scripts.ui.reward_icons")
local Text = require("scripts.ui.text")
local Tracker = require("scripts.core.tracker")
local Menu = {}
local COLUMNS = 3
local MAX_ROWS = 9
local FILTERS = { "all", "collectible", "trinket", "card",
  "character", "monster", "area", "challenge", "pickup", "world",
  "feature", "route", "other" }
local MAX_SEARCH_LENGTH = 48
local HOLD_DELAY_MS = 300
local HOLD_REPEAT_MS = 90
local PANEL_WIDTH_RATIO = 0.64
local MIN_PANEL_WIDTH = 270
local MAX_PANEL_WIDTH = 340
local BASE_PANEL_HEIGHT = 250
local SCREEN_VERTICAL_MARGIN = 6
local SCREEN_HORIZONTAL_MARGIN = 12
local DETAIL_GAP = 4
local F3_FONT_PIXELS = { 11, 22, 33 }
local detailLineCache = {}
local catalogOrder = {}
for index, goal in ipairs(Catalog.goals) do catalogOrder[goal.id] = index end
local SHOOT_KEYS = {
  [ButtonAction.ACTION_SHOOTLEFT]=Keyboard.KEY_LEFT,
  [ButtonAction.ACTION_SHOOTRIGHT]=Keyboard.KEY_RIGHT,
  [ButtonAction.ACTION_SHOOTUP]=Keyboard.KEY_UP,
  [ButtonAction.ACTION_SHOOTDOWN]=Keyboard.KEY_DOWN
}

-- Light fills retain the font atlas' black pixel outline, keeping the menu
-- readable on parchment without the muddy dark-on-dark look.
local DARK_INK = KColor(1.00, 0.94, 0.78, 1)
local INK = KColor(0.96, 0.86, 0.68, 1)
local MUTED = KColor(0.72, 0.65, 0.56, 1)
local COMPLETED_INK = KColor(0.66, 0.90, 0.64, 1)
local CURRENT_INK = KColor(0.62, 0.86, 1.00, 1)
local CONVERTIBLE_INK = KColor(1.00, 0.72, 0.30, 1)
local UNAVAILABLE_INK = KColor(1.00, 0.56, 0.56, 1)
local TRACKED_INK = KColor(1.00, 0.88, 0.54, 1)
local COMPLETED_TINT = Color(0.72, 0.82, 0.62, 1)
local CURRENT_TINT = Color(1, 1, 1, 1)
local CONVERTIBLE_TINT = Color(1.00, 0.68, 0.28, 1)
local UNAVAILABLE_TINT = Color(0.70, 0.45, 0.45, 1)

local function maximumDetailLines(language, contentWidth, bodyPixels)
  local key = table.concat({ language, contentWidth, bodyPixels }, ":")
  if detailLineCache[key] then return detailLineCache[key] end
  local maximum = 1
  for _, goal in ipairs(Catalog.goals) do
    maximum = math.max(maximum,
      #Text.wrapPixels(Catalog.text(goal, language).detail, contentWidth, bodyPixels))
  end
  maximum = math.max(maximum, 4)
  detailLineCache[key] = maximum
  return maximum
end

local function measureMenuLayout(language, panelWidth, fontPixels)
  local contentWidth = panelWidth - SCREEN_HORIZONTAL_MARGIN * 2
  local lineHeight = Text.lineHeightPixels(fontPixels)
  local gridTop = 10 + lineHeight * 2
  local footerReserve = lineHeight + 6
  local maxDetailLines = maximumDetailLines(language, contentWidth, fontPixels)
  local detailHeight = (maxDetailLines + 1) * lineHeight
  local requiredHeight = gridTop + lineHeight + DETAIL_GAP + detailHeight + footerReserve
  return {
    contentWidth=contentWidth, lineHeight=lineHeight, gridTop=gridTop,
    footerReserve=footerReserve, maxDetailLines=maxDetailLines,
    detailHeight=detailHeight, requiredHeight=requiredHeight
  }
end

local function fitMenuLayout(state)
  local screenWidth, screenHeight = Isaac.GetScreenWidth(), Isaac.GetScreenHeight()
  local maximumPanelWidth = screenWidth - SCREEN_HORIZONTAL_MARGIN * 2
  local maximumPanelHeight = screenHeight - SCREEN_VERTICAL_MARGIN * 2
  local basePanelWidth = math.min(MAX_PANEL_WIDTH,
    math.max(MIN_PANEL_WIDTH, math.floor(screenWidth * PANEL_WIDTH_RATIO)))
  basePanelWidth = math.min(basePanelWidth, maximumPanelWidth)
  local basePanelHeight = math.min(BASE_PANEL_HEIGHT, maximumPanelHeight)
  local language = Text.resolveLanguage(state.settings.language)
  local requestedPixels = state.settings.f3 and state.settings.f3.fontPixels or 11
  local requestedIndex = 1
  for index, pixels in ipairs(F3_FONT_PIXELS) do
    if pixels == requestedPixels then requestedIndex = index end
  end

  for tierIndex = requestedIndex, 1, -1 do
    local fontPixels = F3_FONT_PIXELS[tierIndex]
    local panelWidth = basePanelWidth
    local measured = measureMenuLayout(language, panelWidth, fontPixels)
    if measured.requiredHeight > maximumPanelHeight then
      for panelWidth = basePanelWidth + 1, maximumPanelWidth do
        measured = measureMenuLayout(language, panelWidth, fontPixels)
        if measured.requiredHeight <= maximumPanelHeight then break end
      end
    end
    if measured.requiredHeight <= maximumPanelHeight and panelWidth <= maximumPanelWidth then
      local panelHeight = math.max(basePanelHeight, measured.requiredHeight)
      local panelX = math.floor((screenWidth - panelWidth) / 2)
      local panelY = math.floor((screenHeight - panelHeight) / 2)
      local x, top = panelX + SCREEN_HORIZONTAL_MARGIN, panelY + 10
      local gridTop = panelY + measured.gridTop
      local contentBottom = panelY + panelHeight - measured.footerReserve
      local rows = math.max(1, math.min(MAX_ROWS, math.floor(
        (contentBottom - gridTop - DETAIL_GAP - measured.detailHeight)
          / measured.lineHeight)))
      return {
        panelWidth=panelWidth, panelHeight=panelHeight, panelX=panelX, panelY=panelY,
        x=x, top=top, contentWidth=measured.contentWidth,
        columnWidth=math.floor(measured.contentWidth / COLUMNS), gridTop=gridTop,
        contentBottom=contentBottom, maxDetailLines=measured.maxDetailLines,
        rows=rows, pageSize=rows * COLUMNS, lineHeight=measured.lineHeight,
        detailY=gridTop + rows * measured.lineHeight + DETAIL_GAP,
        footerReserve=measured.footerReserve, fontPixels=fontPixels
      }
    end
  end

  error("F3 11px layout does not fit the supported screen size")
end

function Menu.new()
  return { open=false, cursor=1, offset=1, goals=nil, filterIndex=1,
    query="", searchFocused=false, relevanceContext=nil,
    relevanceSignature=nil, completionSignature=nil, opportunitySignature=nil,
    routeSignature=nil, expandedEndpoint=nil, detailPage=1,
    repeatKeys={},
    mouseDown=false, mouseX=nil, mouseY=nil }
end

local function isCompleted(state, goal)
  return (state.profileCompleted and state.profileCompleted[goal.id])
    or (state.run.completedGoals and state.run.completedGoals[goal.id])
    or CompletionMarks.isSatisfied(goal, state.settings.completionMarks)
end

local function isCompletable(goal)
  return Catalog.isCompletable(goal, Isaac.GetChallenge())
end

local VISUAL_STATES = {
  completed={ key="completed", label="completed", iconFrame=0,
    ink=COMPLETED_INK, iconTint=COMPLETED_TINT },
  current={ key="current", label="currentAvailable", iconFrame=1,
    ink=CURRENT_INK, iconTint=CURRENT_TINT },
  general={ key="general", label="generalAvailable", iconFrame=1,
    ink=CURRENT_INK, iconTint=CURRENT_TINT },
  convertible={ key="convertible", label="convertiblePending", iconFrame=2,
    ink=CONVERTIBLE_INK, iconTint=CONVERTIBLE_TINT },
  conflict={ key="conflict", label="routeConflict", iconFrame=4,
    ink=UNAVAILABLE_INK, iconTint=UNAVAILABLE_TINT },
  unavailable={ key="unavailable", label="currentModeUnavailable", iconFrame=4,
    ink=UNAVAILABLE_INK, iconTint=UNAVAILABLE_TINT }
}
local ROUTE_DISABLED = { key="route_unavailable", label="unavailableRoute", iconFrame=4,
  ink=MUTED, iconTint=Color(0.55, 0.52, 0.48, 1) }
local ROUTE_WARNING = { key="route_warning", label="availableRoute", iconFrame=2,
  ink=TRACKED_INK, iconTint=CONVERTIBLE_TINT }

local function routeEvaluationContext(routeContext, relevanceContext)
  if not routeContext then return nil end
  local result, players = {}, {}
  for key, value in pairs(routeContext) do result[key] = value end
  for player in pairs(routeContext.players or {}) do players[player] = true end
  for player in pairs(relevanceContext.convertible or {}) do players[player] = true end
  for player in pairs(relevanceContext.ascentConvertible or {}) do players[player] = true end
  result.players = players
  return result
end

local function resolveVisualState(state, goal, context)
  if isCompleted(state, goal) then return VISUAL_STATES.completed end
  if not isCompletable(goal) then return VISUAL_STATES.unavailable end
  if Tracker.contains(state.tracker, goal.id) and state.tracker.route
    and RouteRecommendations.conflicts(goal, state.tracker.route, {
      difficulty=CompletionMarks.difficultyValue(Game()),
      completionStore=state.settings.completionMarks,
      currentPlayers=(state.routeContext and state.routeContext.players) or {}
    }) then return VISUAL_STATES.conflict end
  local routeResult = state.routeContext and Routes.evaluate(goal,
    routeEvaluationContext(state.routeContext, context), state.settings.completionMarks,
    Text.resolveLanguage(state.settings.language)) or nil
  if routeResult and routeResult.severity == "failed" then
    return VISUAL_STATES.unavailable
  end
  local relevance = CharacterRelevance.classify(goal, context)
  if relevance == "general" then return VISUAL_STATES.general end
  if relevance == "current" then return VISUAL_STATES.current end
  if relevance == "convertible" then return VISUAL_STATES.convertible end
  if relevance == "other" then return VISUAL_STATES.unavailable end
  return VISUAL_STATES.unavailable
end

local function completedSignature(state)
  local ids = {}
  for _, goal in ipairs(Catalog.goals) do
    if isCompleted(state, goal) then table.insert(ids, goal.id) end
  end
  return table.concat(ids, ",")
end

local function sceneOpportunitySignature(state)
  local parts = {}
  for _, opportunity in ipairs(state.sceneOpportunities or {}) do
    parts[#parts + 1] = table.concat({ opportunity.goalId or "",
      tostring(opportunity.priority or 99) }, ":")
  end
  return table.concat(parts, "|")
end

local function matchesFilter(goal, filter, route)
  if filter == "all" then return true end
  if filter == "route" then return false end
  return Rewards.filterKind(Rewards.display(goal)) == filter
end

local ROUTE_SEARCH = {
  blue_baby="chest boss rush mom heart hush isaac blue baby ??? mega satan delirium 宝箱层 妈心",
  lamb="dark room boss rush mom heart hush satan lamb mega satan delirium 暗室 羔羊 妈心",
  mother="mother boss rush 妈妈 母亲",
  beast="beast home boss rush dogma 祸兽 家",
  greed="greed ultra greed 贪婪 究极贪婪",
  greedier="greedier ultra greedier 超级贪婪"
}

local function routeEntry(candidate, tracked, recommended)
  local route = candidate.route
  return { id="route:" .. (route.endpoint or route.family), entryKind="route", route=route,
    candidate=candidate, tracked=tracked == true, recommended=recommended == true,
    priority=route.priority or "normal" }
end

local function routeOptionEntry(parent, option)
  local endpoint = parent.route.endpoint or parent.route.family
  return { id="route_option:" .. endpoint .. ":" .. option.mark,
    entryKind="route_option", route=parent.route, parentCandidate=parent.candidate,
    option=option, priority="normal", tracked=parent.tracked }
end

local function candidateMemberIds(candidate)
  local result, seen = {}, {}
  for _, ids in ipairs({ candidate.availableMemberIds or {}, candidate.conditionalMemberIds or {},
      candidate.unavailableMemberIds or {} }) do
    for _, id in ipairs(ids) do
      if not seen[id] then result[#result + 1], seen[id] = id, true end
    end
  end
  return result
end

local function routeMatchesQuery(candidate, query, language, routeContext)
  if query == "" then return true end
  local route = candidate.route
  local haystack = RouteRecommendations.label(route, language) .. " "
    .. (ROUTE_SEARCH[route.family] or "")
    .. " " .. table.concat(RouteRecommendations.fullProcess(route, language), " ")
  for _, remedy in ipairs(RouteRecommendations.remedies(route, routeContext, language)) do
    haystack = haystack .. " " .. remedy.text
  end
  for _, option in ipairs(RouteRecommendations.optionalBossEntries(route, {
      context=routeContext, language=language })) do
    haystack = haystack .. " " .. CompletionMarks.label(option.mark, language)
      .. " " .. (option.reason or "")
  end
  for _, id in ipairs(candidateMemberIds(candidate)) do
    local goal = Catalog.get(id)
    if goal then
      haystack = haystack .. " " .. Catalog.text(goal, language).name
        .. " " .. Catalog.text(goal, language).detail
    end
  end
  return string.find(string.lower(haystack), string.lower(query), 1, true) ~= nil
end

local function routeSelectionAllowed(game)
  if Isaac.GetChallenge() ~= 0 then return false end
  local seeds = game:GetSeeds()
  if seeds and seeds.IsCustomRun then
    local ok, custom = pcall(function() return seeds:IsCustomRun() end)
    if ok and custom then return false end
  end
  if game.GetVictoryLap then
    local ok, lap = pcall(function() return game:GetVictoryLap() end)
    if ok and lap > 0 then return false end
  end
  if game.AchievementUnlocksDisallowed then
    local ok, disallowed = pcall(function() return game:AchievementUnlocksDisallowed() end)
    if ok and disallowed then return false end
  end
  return true
end

local function liveRouteCandidates(state, relevanceContext, language)
  local game = Game()
  local routeContext = state.routeContext or Routes.context(game, state.run)
  return RouteRecommendations.list(Catalog.goals, {
    allowed=routeSelectionAllowed(game), greed=game:IsGreedMode(),
    greedier=game.Difficulty == (Difficulty and Difficulty.DIFFICULTY_GREEDIER or 3),
    context=routeContext,
    difficulty=CompletionMarks.difficultyValue(game),
    completionStore=state.settings.completionMarks,
    currentPlayers=routeContext.players, relevanceContext=relevanceContext,
    isCompleted=function(goal) return isCompleted(state, goal) end,
    isTracked=function(id) return Tracker.contains(state.tracker, id) end,
    includeDiscouraged=true,
    evaluate=function(goal)
      return Routes.evaluate(goal, routeContext,
        state.settings.completionMarks, language)
    end
  })
end

local function scoreIds(ids)
  local score = { strong=0, recommended=0, normal=0, discouraged=0,
    total=0, earliest=math.huge }
  for _, id in ipairs(ids or {}) do
    local goal = Catalog.get(id)
    if goal then
      local priority = Recommendations.priority(goal)
      score[priority] = score[priority] + 1
      score.total = score.total + 1
      score.earliest = math.min(score.earliest, catalogOrder[id] or math.huge)
    end
  end
  return score
end

local function trackedCandidate(state, language)
  local route = state.tracker.route
  if not route then return nil end
  local available, conditional, unavailable, reason = {}, {}, {}, nil
  local routeContext = state.routeContext or Routes.context(Game(), state.run)
  for _, id in ipairs(route.memberIds or {}) do
    local goal = Catalog.get(id)
    if goal and not isCompleted(state, goal) then
      local result = Routes.evaluate(goal, routeContext,
        state.settings.completionMarks, language)
      if result and result.severity == "failed" then
        unavailable[#unavailable + 1] = id
        reason = reason or result.current
      elseif result and result.severity == "warning" then
        conditional[#conditional + 1] = id
      else
        available[#available + 1] = id
      end
    end
  end
  local scored = {}
  for _, id in ipairs(available) do scored[#scored + 1] = id end
  for _, id in ipairs(conditional) do scored[#scored + 1] = id end
  local routeEvaluation = RouteRecommendations.combinedEvaluation(route, {
    getGoal=Catalog.get, context=routeContext,
    completionStore=state.settings.completionMarks, language=language,
    tracked=true, completedBosses=state.run.routeBosses
  })
  return { route=route, availableMemberIds=available,
    conditionalMemberIds=conditional,
    unavailableMemberIds=unavailable, selectable=true,
    failed=#unavailable > 0 or routeEvaluation.missed ~= nil, recoverable=false,
    failureReason=reason or routeEvaluation.missed,
    score=scoreIds(scored), order=0, evaluation=routeEvaluation }
end

local function sortByRecommendation(goals)
  table.sort(goals, function(left, right)
    local leftRank, rightRank = Recommendations.rank(left), Recommendations.rank(right)
    if leftRank ~= rightRank then return leftRank > rightRank end
    return catalogOrder[left.id] < catalogOrder[right.id]
  end)
end

local function refreshGoals(state, context, preserveSelection)
  local layout = fitMenuLayout(state)
  local selectedGoalId = preserveSelection and state.menu.goals
    and state.menu.goals[state.menu.cursor]
    and state.menu.goals[state.menu.cursor].id
  local tracked, routeEntries, scenePending, currentCharacterPending, convertiblePending,
    generalPending, unavailable, completed = {}, {}, {}, {}, {}, {}, {}, {}
  local searchMeta = {}
  local trackedOrder = {}
  for index, id in ipairs(state.tracker.ids) do trackedOrder[id] = index end
  local activeRoute = state.tracker.route
  local routeOrder = {}
  for index, id in ipairs(activeRoute and activeRoute.memberIds or {}) do
    routeOrder[id] = index
  end
  local sceneGoalIds = {}
  for index, opportunity in ipairs(state.sceneOpportunities or {}) do
    local current = sceneGoalIds[opportunity.goalId]
    local priority = opportunity.priority or 99
    if not current or priority < current.priority then
      sceneGoalIds[opportunity.goalId] = { priority=priority, order=index }
    end
  end
  context = context or CharacterRelevance.buildContext(Game(), Catalog.goals, state.run)
  local filter = FILTERS[state.menu.filterIndex] or "all"
  local language = Text.resolveLanguage(state.settings.language)
  if filter == "all" or filter == "route" then
    local liveCandidates = liveRouteCandidates(state, context, language)
    if filter == "route" and not state.menu.expandedEndpoint then
      state.menu.expandedEndpoint = activeRoute
        and (activeRoute.endpoint or activeRoute.family)
        or (liveCandidates[1] and (liveCandidates[1].route.endpoint
          or liveCandidates[1].route.family))
    end
    local function appendRoute(candidate, isTracked, isRecommended, stableOrder)
      local entry = routeEntry(candidate, isTracked, isRecommended)
      routeEntries[#routeEntries + 1] = entry
      searchMeta[entry.id] = { score=0, priorityRank=isTracked and 0 or 2,
        recommendationRank=Recommendations.SCORE[entry.priority] or 1,
        stableOrder=stableOrder }
      local endpoint = entry.route.endpoint or entry.route.family
      if filter == "route" and state.menu.expandedEndpoint == endpoint then
        for _, option in ipairs(RouteRecommendations.optionalBossEntries(entry.route, {
            context=state.routeContext, language=language })) do
          local optionName = CompletionMarks.label(option.mark, language)
          if state.menu.query == "" or string.find(string.lower(optionName .. " "
              .. (option.reason or "")), string.lower(state.menu.query), 1, true) then
            local optionEntry = routeOptionEntry(entry, option)
            routeEntries[#routeEntries + 1] = optionEntry
            searchMeta[optionEntry.id] = { score=0, priorityRank=isTracked and 0 or 2,
              recommendationRank=0, stableOrder=stableOrder }
          end
        end
      end
    end
    local current = trackedCandidate(state, language)
    if current and routeMatchesQuery(current, state.menu.query, language,
        state.routeContext) then
      appendRoute(current, true, false, 0)
    end
    local recommended = false
    for _, candidate in ipairs(liveCandidates) do
      if not activeRoute or not Tracker.sameRoute(candidate.route, activeRoute) then
        local isRecommended = candidate.selectable and candidate.score.total > 0 and not recommended
        if isRecommended then recommended = true end
        if routeMatchesQuery(candidate, state.menu.query, language,
            state.routeContext) then
          appendRoute(candidate, false, isRecommended, candidate.order)
        end
      end
    end
  end
  for _, match in ipairs(Catalog.search(state.menu.query)) do
    local goal = match.goal
    if matchesFilter(goal, filter, activeRoute) then
      local visualState = resolveVisualState(state, goal, context)
      local bucket, priorityRank = completed, 7
      local challengeUnavailable = goal.challengeId ~= nil
        and visualState.key == "unavailable"
      if challengeUnavailable then
        bucket, priorityRank = unavailable, 6
      elseif Tracker.containsAny(state.tracker, goal.id) then
        bucket, priorityRank = tracked, 1
      elseif sceneGoalIds[goal.id] and visualState.key ~= "completed"
          and visualState.key ~= "unavailable" then
        bucket, priorityRank = scenePending, 2
      elseif visualState.key == "unavailable" then
        bucket, priorityRank = unavailable, 6
      elseif visualState.key ~= "completed" then
        if visualState.key == "current" then bucket, priorityRank = currentCharacterPending, 3
        elseif visualState.key == "convertible" then bucket, priorityRank = convertiblePending, 4
        elseif visualState.key == "general" then bucket, priorityRank = generalPending, 5 end
      end
      table.insert(bucket, goal)
      searchMeta[goal.id] = { score=match.score, priorityRank=priorityRank,
        recommendationRank=priorityRank >= 2 and priorityRank <= 5
          and Recommendations.rank(goal) or 0,
        stableOrder=trackedOrder[goal.id] or routeOrder[goal.id] or (sceneGoalIds[goal.id]
          and sceneGoalIds[goal.id].order) or match.catalogIndex }
    end
  end
  table.sort(tracked, function(left, right)
    local leftOrder = trackedOrder[left.id]
      or (#state.tracker.ids + (routeOrder[left.id] or math.huge))
    local rightOrder = trackedOrder[right.id]
      or (#state.tracker.ids + (routeOrder[right.id] or math.huge))
    return leftOrder < rightOrder
  end)
  table.sort(scenePending, function(left, right)
    local leftMeta, rightMeta = sceneGoalIds[left.id], sceneGoalIds[right.id]
    local leftRank, rightRank = Recommendations.rank(left), Recommendations.rank(right)
    if leftRank ~= rightRank then return leftRank > rightRank end
    if leftMeta.priority ~= rightMeta.priority then
      return leftMeta.priority < rightMeta.priority
    end
    return leftMeta.order < rightMeta.order
  end)
  sortByRecommendation(currentCharacterPending)
  sortByRecommendation(convertiblePending)
  sortByRecommendation(generalPending)
  local goals = {}
  for _, bucket in ipairs({ routeEntries, tracked, scenePending, currentCharacterPending, convertiblePending,
    generalPending, unavailable, completed }) do
    for _, goal in ipairs(bucket) do table.insert(goals, goal) end
  end
  if state.menu.query ~= "" then
    table.sort(goals, function(leftGoal, rightGoal)
      local left, right = searchMeta[leftGoal.id], searchMeta[rightGoal.id]
      if left.priorityRank ~= right.priorityRank then
        return left.priorityRank < right.priorityRank
      end
      if left.score ~= right.score then return left.score < right.score end
      if left.recommendationRank ~= right.recommendationRank then
        return left.recommendationRank > right.recommendationRank
      end
      return left.stableOrder < right.stableOrder
    end)
  end
  state.menu.goals = goals
  state.menu.relevanceContext = context
  state.menu.relevanceSignature = context.signature
  state.menu.completionSignature = completedSignature(state)
  state.menu.opportunitySignature = sceneOpportunitySignature(state)
  state.menu.routeSignature = state.routeContext
  state.menu.cursor = math.max(1, math.min(state.menu.cursor, #goals))
  if selectedGoalId then
    for index, goal in ipairs(goals) do
      if goal.id == selectedGoalId then
        state.menu.cursor = index
        break
      end
    end
  end
  state.menu.offset = #goals > 0
    and math.floor((state.menu.cursor - 1) / layout.pageSize) * layout.pageSize + 1 or 1
end

local function triggered(key)
  return type(key) == "number" and Input.IsButtonTriggered(key, 0) or false
end

local function resetRepeatKeys(state)
  state.menu.repeatKeys = {}
end

local function repeated(state, key, now)
  if triggered(key) then
    state.menu.repeatKeys[key] = { nextAt=now + HOLD_DELAY_MS }
    return true
  end
  if not Input.IsButtonPressed(key, 0) then
    state.menu.repeatKeys[key] = nil
    return false
  end
  local held = state.menu.repeatKeys[key]
  if held and now >= held.nextAt then
    held.nextAt = now + HOLD_REPEAT_MS
    return true
  end
  return false
end

local function pointInside(position, left, top, right, bottom)
  return position.X >= left and position.X < right
    and position.Y >= top and position.Y < bottom
end

local function mouseInsidePanel(position, layout)
  return pointInside(position, layout.panelX, layout.panelY,
    layout.panelX + layout.panelWidth, layout.panelY + layout.panelHeight)
end

local function mouseGoalIndex(state, position, layout)
  if not pointInside(position, layout.x, layout.gridTop,
    layout.x + layout.columnWidth * COLUMNS,
    layout.gridTop + layout.lineHeight * layout.rows) then return nil end
  local column = math.floor((position.X - layout.x) / layout.columnWidth)
  local row = math.floor((position.Y - layout.gridTop) / layout.lineHeight)
  local index = state.menu.offset + row * COLUMNS + column
  local goals = state.menu.goals or {}
  if index > #goals or index >= state.menu.offset + layout.pageSize then return nil end
  return index
end

local function updateMouseSelection(state)
  local position = Input.GetMousePosition(false)
  local moved = state.menu.mouseX ~= position.X or state.menu.mouseY ~= position.Y
  state.menu.mouseX, state.menu.mouseY = position.X, position.Y
  local index = mouseGoalIndex(state, position, fitMenuLayout(state))
  if moved and index then state.menu.cursor = index end
  local mouseDown = Input.IsMouseBtnPressed(Mouse.MOUSE_BUTTON_LEFT)
  local clicked = mouseDown and not state.menu.mouseDown
  state.menu.mouseDown = mouseDown
  if clicked and index then
    state.menu.cursor = index
    return index
  end
  return nil
end

local function toggleGoal(state, goal, save, context)
  if not goal then return false end
  if goal.entryKind == "route_option" then
    local route = goal.route
    local active = state.tracker.route and Tracker.sameRoute(state.tracker.route, route)
    if active then route = state.tracker.route end
    local optionContext = { context=state.routeContext,
      language=Text.resolveLanguage(state.settings.language) }
    local updated, toggled
    if not active and goal.option.selected then
      updated, toggled = RouteRecommendations.normalize(route), true
    else
      updated, toggled = RouteRecommendations.toggleOptionalBoss(route,
        goal.option.mark, optionContext)
    end
    if not toggled then
      state.quickTrackNotice = { key="routeOptionUnavailable",
        untilFrame=Isaac.GetFrameCount() + 240 }
      return false
    end
    local relevance = context or CharacterRelevance.buildContext(Game(), Catalog.goals, state.run)
    updated = RouteRecommendations.refreshMembers(updated, Catalog.goals, {
      difficulty=CompletionMarks.difficultyValue(Game()),
      completionStore=state.settings.completionMarks,
      currentPlayers=(state.routeContext and state.routeContext.players) or {},
      relevanceContext=relevance,
      isCompleted=function(candidate) return isCompleted(state, candidate) end,
      isTracked=function(id) return Tracker.contains(state.tracker, id) end
    })
    if RouteRecommendations.isComplete(updated, state.run.routeBosses) then
      Tracker.untrackRoute(state.tracker)
      updated = nil
    elseif not Tracker.replaceRoute(state.tracker, updated) then
      state.quickTrackNotice = { key="trackerFull", untilFrame=Isaac.GetFrameCount() + 240 }
      return false
    end
    state.menu.expandedEndpoint = (updated or route).endpoint
    state.run.trackedRoute = updated
    state.run.pendingRouteExtension = nil
    save()
    refreshGoals(state, context, true)
    return true
  end
  if goal.entryKind == "route" then
    local changed
    if state.tracker.route and Tracker.sameRoute(state.tracker.route, goal.route) then
      changed = Tracker.untrackRoute(state.tracker)
      state.run.trackedRoute = nil
    else
      changed = Tracker.replaceRoute(state.tracker, goal.route)
      if changed then state.run.trackedRoute = state.tracker.route end
    end
    state.menu.expandedEndpoint = goal.route.endpoint or goal.route.family
    state.run.pendingRouteExtension = nil
    if not changed then
      state.quickTrackNotice = { key="trackerFull", untilFrame=Isaac.GetFrameCount() + 240 }
      return false
    end
    save()
    refreshGoals(state, context, true)
    return true
  end
  if isCompleted(state, goal) then return false end
  if Tracker.routeContains(state.tracker, goal.id) then
    state.menu.routeMemberNotice = goal.id
    return false
  end
  local wasTracked = Tracker.contains(state.tracker, goal.id)
  if not Tracker.toggle(state.tracker, goal.id) then return false end
  state.settings.tracked = state.tracker.ids
  save()
  if not wasTracked then refreshGoals(state, context, true) end
  return true
end

local function typedSearchCharacter()
  for key = Keyboard.KEY_A, Keyboard.KEY_Z do
    if triggered(key) then return string.char(string.byte("a") + key - Keyboard.KEY_A) end
  end
  for key = Keyboard.KEY_0, Keyboard.KEY_9 do
    if triggered(key) then return string.char(string.byte("0") + key - Keyboard.KEY_0) end
  end
  if triggered(Keyboard.KEY_SPACE) then return " " end
  return nil
end

local function updateSearchInput(state)
  if triggered(Keyboard.KEY_ESCAPE) then
    local changed = state.menu.query ~= ""
    state.menu.query, state.menu.searchFocused = "", false
    return changed, true
  end
  if triggered(Keyboard.KEY_ENTER) then
    state.menu.searchFocused = false
    return false, true
  end
  if triggered(Keyboard.KEY_DELETE) then
    local changed = state.menu.query ~= ""
    state.menu.query = ""
    return changed, true
  end
  if triggered(Keyboard.KEY_BACKSPACE) then
    if state.menu.query ~= "" then
      state.menu.query = string.sub(state.menu.query, 1, #state.menu.query - 1)
      return true, true
    end
    return false, true
  end
  local character = typedSearchCharacter()
  if character and #state.menu.query < MAX_SEARCH_LENGTH then
    if character ~= " " or (state.menu.query ~= ""
      and string.sub(state.menu.query, -1) ~= " ") then
      state.menu.query = state.menu.query .. character
      return true, true
    end
  end
  return false, false
end

function Menu.isMultiplayer(game)
  local controllers, count = {}, 0
  for index = 0, game:GetNumPlayers() - 1 do
    local player = Isaac.GetPlayer(index)
    local controller = player and player.ControllerIndex
    if controller ~= nil and controller >= 0 and not controllers[controller] then
      controllers[controller] = true
      count = count + 1
    end
  end
  return count > 1
end

function Menu.shouldPause(state, game)
  return state and state.menu and state.menu.open and not Menu.isMultiplayer(game)
end

function Menu.shouldBlockInput(state, entity, inputHook, buttonAction)
  if not state or not state.menu or not state.menu.open then return false end
  local player = entity and entity:ToPlayer()
  if not player or player.ControllerIndex ~= 0 then return false end
  if buttonAction == ButtonAction.ACTION_PAUSE
    or buttonAction == ButtonAction.ACTION_MAP then return true end
  local shootKey = SHOOT_KEYS[buttonAction]
  if shootKey and (Input.IsButtonPressed(shootKey, 0)
    or mouseInsidePanel(Input.GetMousePosition(false), fitMenuLayout(state))) then
    return true
  end
  if buttonAction == ButtonAction.ACTION_ITEM
    and Input.IsButtonPressed(Keyboard.KEY_SPACE, 0) then return true end
  return state.menu.searchFocused
end

function Menu.update(state, save)
  if triggered(Keyboard.KEY_F3) then
    if state.menu.open then
      state.menu.open = false
    elseif not Game():IsPaused() or ModCallbacks.MC_PRE_PAUSE_SCREEN_RENDER then
      state.menu.open = true
      state.menu.cursor, state.menu.offset, state.menu.filterIndex = 1, 1, 1
      state.menu.query, state.menu.searchFocused = "", false
      state.menu.detailPage, state.menu.expandedEndpoint = 1, nil
      resetRepeatKeys(state)
      state.menu.mouseDown = Input.IsMouseBtnPressed(Mouse.MOUSE_BUTTON_LEFT)
      state.menu.mouseX, state.menu.mouseY = nil, nil
      refreshGoals(state, nil, false)
    end
  end
  if triggered(Keyboard.KEY_F4) then state.settings.hud.visible = not state.settings.hud.visible; save() end
  if not state.menu.open then
    resetRepeatKeys(state)
    state.menu.mouseDown = Input.IsMouseBtnPressed(Mouse.MOUSE_BUTTON_LEFT)
    return
  end
  local context = CharacterRelevance.buildContext(Game(), Catalog.goals, state.run)
  local completionSignature = completedSignature(state)
  local opportunitySignature = sceneOpportunitySignature(state)
  local routeSignature = state.routeContext
  if state.menu.relevanceSignature ~= context.signature
    or state.menu.completionSignature ~= completionSignature
    or state.menu.opportunitySignature ~= opportunitySignature
    or state.menu.routeSignature ~= routeSignature then
    refreshGoals(state, context, true)
  end
  local searchConsumed = false
  local searchShortcut = triggered(Keyboard.KEY_SLASH)
  if searchShortcut then
    state.menu.searchFocused = true
    resetRepeatKeys(state)
    searchConsumed = true
  elseif state.menu.searchFocused then
    local queryChanged
    queryChanged, searchConsumed = updateSearchInput(state)
    if queryChanged then
      state.menu.cursor, state.menu.offset = 1, 1
      refreshGoals(state, context, false)
    end
  end
  if triggered(Keyboard.KEY_TAB) then
    state.menu.filterIndex = state.menu.filterIndex % #FILTERS + 1
    state.menu.cursor, state.menu.offset = 1, 1
    state.menu.detailPage = 1
    refreshGoals(state, context, false)
  end
  local goals = state.menu.goals or {}
  local count = #goals
  local layout = fitMenuLayout(state)
  local keyboardActivated = false
  local previousCursor = state.menu.cursor
  if count > 0 then
    if not state.menu.searchFocused then
      local now = Isaac.GetTime()
      if repeated(state, Keyboard.KEY_LEFT, now) then
        state.menu.cursor = math.max(1, state.menu.cursor - 1)
      end
      if repeated(state, Keyboard.KEY_RIGHT, now) then
        state.menu.cursor = math.min(count, state.menu.cursor + 1)
      end
      if repeated(state, Keyboard.KEY_UP, now) then
        state.menu.cursor = math.max(1, state.menu.cursor - COLUMNS)
      end
      if repeated(state, Keyboard.KEY_DOWN, now) then
        state.menu.cursor = math.min(count, state.menu.cursor + COLUMNS)
      end
      keyboardActivated = not searchConsumed
        and (triggered(Keyboard.KEY_ENTER) or triggered(Keyboard.KEY_SPACE))
      if triggered(Keyboard.KEY_PAGE_UP) then
        state.menu.detailPage = math.max(1, (state.menu.detailPage or 1) - 1)
      elseif triggered(Keyboard.KEY_PAGE_DOWN) then
        state.menu.detailPage = (state.menu.detailPage or 1) + 1
      end
      if Input.GetMouseWheel then
        local position = Input.GetMousePosition(false)
        if pointInside(position, layout.x, layout.detailY,
            layout.x + layout.contentWidth, layout.contentBottom) then
          local okWheel, wheel = pcall(Input.GetMouseWheel)
          local delta = okWheel and (type(wheel) == "number" and wheel
            or wheel and wheel.Y) or 0
          if delta and delta > 0 then
            state.menu.detailPage = math.max(1, (state.menu.detailPage or 1) - 1)
          elseif delta and delta < 0 then
            state.menu.detailPage = (state.menu.detailPage or 1) + 1
          end
        end
      end
    else
      resetRepeatKeys(state)
    end
    state.menu.offset = math.floor((state.menu.cursor - 1) / layout.pageSize) * layout.pageSize + 1
  else
    state.menu.cursor, state.menu.offset = 1, 1
  end
  local keyboardIndex = keyboardActivated and state.menu.cursor
  local mouseIndex = updateMouseSelection(state)
  if state.menu.cursor ~= previousCursor then
    state.menu.detailPage = 1
    local focused = (state.menu.goals or {})[state.menu.cursor]
    if focused and focused.entryKind == "route"
      and (FILTERS[state.menu.filterIndex] or "all") == "route" then
      local endpoint = focused.route.endpoint or focused.route.family
      if state.menu.expandedEndpoint ~= endpoint then
        state.menu.expandedEndpoint = endpoint
        refreshGoals(state, context, true)
      end
    end
  end
  local activatedIndex = mouseIndex or keyboardIndex
  goals = state.menu.goals or {}
  if #goals > 0 and activatedIndex then
    state.menu.cursor = activatedIndex
    toggleGoal(state, goals[activatedIndex], save, context)
  end
  if not searchConsumed and triggered(Keyboard.KEY_ESCAPE) then
    state.menu.open = false
    resetRepeatKeys(state)
  end
end

local function filterLine(labels, active)
  local filter = FILTERS[active] or "all"
  local name = labels.filterNames[filter] or filter
  return string.format(labels.filterStatus, name, active, #FILTERS)
end

local function rewardName(goal, language)
  return string.gsub(Catalog.text(goal, language).name, "^#%d+%s*", "")
end

local function rewardMeta(reward, labels)
  local kind = labels.rewardKinds[reward.kind] or labels.rewardKinds.other
  if reward.kind == "pickup" and reward.variant ~= nil and reward.subtype ~= nil then
    return string.format("%s  ·  %s 5.%d.%d", kind, labels.rewardId,
      reward.variant, reward.subtype)
  end
  if reward.kind == "slot" and reward.variant ~= nil then
    return string.format("%s  ·  %s 6.%d", kind, labels.rewardId, reward.variant)
  end
  if reward.kind == "grid" and reward.gridType ~= nil and reward.variant ~= nil then
    return string.format("%s  ·  %s %d.%d", kind, labels.rewardId,
      reward.gridType, reward.variant)
  end
  if reward.id then return string.format("%s  ·  %s %d", kind, labels.rewardId, reward.id) end
  return kind
end

local function routeVisualState(entry)
  if entry.tracked and entry.candidate.failed then return ROUTE_WARNING end
  if not entry.candidate.selectable then return ROUTE_DISABLED end
  return VISUAL_STATES.current
end

local function routeStatusLabel(entry, labels)
  if entry.tracked then return labels.trackedRoute end
  if not entry.candidate.selectable then return labels.unavailableRoute end
  return entry.recommended and labels.routeRecommendation or labels.availableRoute
end

local function routeOptionVisualState(entry)
  if not entry.option.selectable and not entry.option.selected then return ROUTE_DISABLED end
  return VISUAL_STATES.current
end

function Menu.render(state)
  if not state.menu.open then return end
  local goals = state.menu.goals or {}
  local language = Text.resolveLanguage(state.settings.language)
  local labels = Text.labels(language)
  local context = state.menu.relevanceContext
    or CharacterRelevance.buildContext(Game(), Catalog.goals, state.run)
  local layout = fitMenuLayout(state)
  local panelWidth, panelHeight = layout.panelWidth, layout.panelHeight
  local panelX, panelY = layout.panelX, layout.panelY
  local fontPixels = layout.fontPixels
  local x, top = layout.x, layout.top
  local contentWidth, columnWidth = layout.contentWidth, layout.columnWidth
  local gridTop = layout.gridTop
  RewardIcons.renderPaper(panelX, panelY, panelWidth, panelHeight)

  local title = labels.menuTitle
  if state.menu.searchFocused or state.menu.query ~= "" then
    title = labels.searchPrompt .. ": " .. state.menu.query
      .. (state.menu.searchFocused and "_" or "")
  end
  Text.drawPixels(Text.ellipsizePixels(title, contentWidth, fontPixels), panelX, top,
    fontPixels, DARK_INK,
    language, panelWidth, true)
  local filterStatus = filterLine(labels, state.menu.filterIndex)
  local filterHint = state.menu.query ~= ""
    and string.format(labels.searchResults, #goals) or labels.filterHint
  local hintWidth = Text.widthPixels(filterHint, fontPixels)
  Text.drawPixels(Text.ellipsizePixels(filterStatus,
      math.max(20, contentWidth - hintWidth - 8), fontPixels), x, top + layout.lineHeight,
    fontPixels, INK, language)
  Text.drawPixels(filterHint, panelX + panelWidth - 12 - hintWidth, top + layout.lineHeight,
    fontPixels, MUTED, language)

  local last = math.min(#goals, state.menu.offset + layout.pageSize - 1)
  for index = state.menu.offset, last do
    local goal = goals[index]
    local localIndex = index - state.menu.offset
    local column, row = localIndex % COLUMNS, math.floor(localIndex / COLUMNS)
    local tileX, tileY = x + column * columnWidth,
      gridTop + row * layout.lineHeight
    local selected = index == state.menu.cursor
    local routeRow = goal.entryKind == "route"
    local routeOption = goal.entryKind == "route_option"
    local routeLike = routeRow or routeOption
    local visualState = routeRow and routeVisualState(goal)
      or routeOption and routeOptionVisualState(goal)
      or resolveVisualState(state, goal, context)
    local tracked = routeRow and goal.tracked
      or routeOption and goal.option.selected
      or Tracker.containsAny(state.tracker, goal.id)
    local reward = not routeLike and Rewards.display(goal) or nil
    local priority = routeLike and goal.priority or Recommendations.priority(goal)
    local marker = selected and ">" or " "
    local tracking = tracked and "*" or " "
    local textX = tileX + 13
    local markerWidth = Text.widthPixels(">", fontPixels)
    local trackingX = textX + markerWidth
    local trackingWidth = Text.widthPixels("*", fontPixels)
    local statusSize = math.floor(fontPixels * 7 / 11 + 0.5)
    local statusGap = math.max(1, math.floor(fontPixels / 11 + 0.5))
    local statusX = trackingX + trackingWidth + statusGap + statusSize / 2
    local nameX = statusX + statusSize / 2 + statusGap
    local nameWidth = math.max(0, tileX + columnWidth - 2 - nameX)
    local displayName = routeRow
      and (routeStatusLabel(goal, labels)
        .. "：" .. RouteRecommendations.label(goal.route, language))
      or routeOption and ((goal.option.selected and "[x] " or "[ ] ")
        .. CompletionMarks.label(goal.option.mark, language))
      or Catalog.text(goal, language).name
    local name = Text.ellipsizePixels(displayName,
      nameWidth, fontPixels)
    if not routeLike or (routeRow and (goal.candidate.selectable or goal.tracked))
      or (routeOption and goal.option.selected) then
      RewardIcons.renderPriorityBackground(priority, nameX, tileY,
        math.max(0, tileX + columnWidth - 2 - nameX), layout.lineHeight - 1)
    end
    if selected then
      RewardIcons.renderSelection(tileX + 1, tileY, columnWidth - 2,
        layout.lineHeight - 1)
    end
    if reward then RewardIcons.render(reward, tileX + 8, tileY + 6, 12, visualState.iconTint) end
    Text.drawPixels(marker, textX, tileY, fontPixels,
      routeLike and visualState == ROUTE_DISABLED
        and visualState.ink or DARK_INK, language)
    Text.drawPixels(tracking, trackingX, tileY, fontPixels,
      tracked and TRACKED_INK or (routeLike and visualState == ROUTE_DISABLED
        and visualState.ink or INK), language)
    RewardIcons.renderStatus(visualState.iconFrame, statusX,
      tileY + layout.lineHeight / 2, statusSize, visualState.iconTint)
    Text.drawPixels(name, nameX, tileY, fontPixels, visualState.ink, language)
  end

  local detailY = layout.detailY
  local selected = goals[state.menu.cursor]
  if selected then
    local routeRow = selected.entryKind == "route"
    local routeOption = selected.entryKind == "route_option"
    local routeLike = routeRow or routeOption
    local reward = not routeLike and Rewards.display(selected) or nil
    local visualState = routeRow and routeVisualState(selected)
      or routeOption and routeOptionVisualState(selected)
      or resolveVisualState(state, selected, context)
    local priority = routeLike and selected.priority or Recommendations.priority(selected)
    local statusLabel = routeRow
      and routeStatusLabel(selected, labels)
      or routeOption and (selected.option.selected and labels.routeOptionSelected
        or labels.routeOption)
      or labels[visualState.label]
    local statusWidth = Text.widthPixels(statusLabel, fontPixels)
    local minimumRewardWidth = math.floor(fontPixels * 45 / 11 + 0.5)
    local leftWidth = math.min(contentWidth - minimumRewardWidth,
      math.max(math.floor(contentWidth * 0.43), statusWidth + 6))
    local leftHeader = statusLabel
    leftHeader = labels.recommendationPriorities[priority] .. " · " .. leftHeader
    Text.drawPixels(Text.ellipsizePixels(leftHeader, leftWidth - 6, fontPixels),
      x, detailY, fontPixels, visualState.ink, language)

    local rewardX = x + leftWidth
    local rewardWidth = contentWidth - leftWidth
    local summary
    if routeRow then
      summary = string.format(labels.routeSlot,
        #(selected.route.memberIds or {}))
    elseif routeOption then
      summary = RouteRecommendations.label(selected.route, language)
    else
      local meta = labels.unlockReward .. " " .. rewardMeta(reward, labels)
      local separator = " · "
      local nameWidth = math.max(0, rewardWidth
        - Text.widthPixels(meta .. separator, fontPixels))
      summary = meta
      if nameWidth > Text.widthPixels("...", fontPixels) then
        summary = meta .. separator
          .. Text.ellipsizePixels(rewardName(selected, language), nameWidth, fontPixels)
      end
    end
    Text.drawPixels(Text.ellipsizePixels(summary, rewardWidth, fontPixels),
      rewardX, detailY, fontPixels, MUTED, language)

    local detail
    if routeRow then
      local memberNames = {}
      for _, ids in ipairs({ selected.candidate.availableMemberIds or {},
          selected.candidate.conditionalMemberIds or {} }) do
        for _, id in ipairs(ids) do
          local member = Catalog.get(id)
          if member then memberNames[#memberNames + 1] = Catalog.text(member, language).name end
        end
      end
      local score = selected.candidate.score
      detail = labels.routeProcess .. "："
        .. table.concat(RouteRecommendations.fullProcess(selected.route, language, {
          context=state.routeContext, completedBosses=state.run.routeBosses }), " → ")
        .. "  ·  " .. labels.routeStableEnd .. "："
        .. CompletionMarks.label(selected.route.confirmedThrough
          or RouteRecommendations.ENDPOINTS[selected.route.endpoint].endpointMark, language)
        .. "  ·  " .. string.format(labels.routeScore, score.strong, score.recommended,
        score.normal, score.discouraged)
      if #memberNames > 0 then
        detail = detail .. "  ·  " .. labels.routeMembers .. "："
          .. table.concat(memberNames, "、")
      end
      local missed = #(selected.candidate.unavailableMemberIds or {})
      local conditional = #(selected.candidate.conditionalMemberIds or {})
      if conditional > 0 then
        detail = detail .. "  ·  " .. string.format(labels.routeConditional, conditional)
      end
      if missed > 0 then
        detail = detail .. "  ·  " .. string.format(labels.routeMissed, missed)
        if selected.candidate.failureReason then
          detail = detail .. "：" .. selected.candidate.failureReason
        end
      end
      local routeEvaluation = selected.candidate.evaluation
        or RouteRecommendations.combinedEvaluation(selected.route, {
          getGoal=Catalog.get, context=state.routeContext,
          completionStore=state.settings.completionMarks, language=language,
          tracked=selected.tracked, completedBosses=state.run.routeBosses
        })
      if routeEvaluation.missed then
        detail = detail .. "  ·  " .. labels.routeMissedRemedies .. "："
        local remedyLabels = { available=labels.remedyAvailable,
          possible=labels.remedyPossible, expired=labels.remedyExpired }
        for _, remedy in ipairs(routeEvaluation.remedies or {}) do
          detail = detail .. " [" .. (remedyLabels[remedy.status] or "")
            .. "] " .. remedy.text
        end
      end
      if not selected.tracked and selected.candidate.selectable then
        detail = detail .. "  ·  " .. labels.routeSelectHint
      end
    elseif routeOption then
      detail = CompletionMarks.label(selected.option.mark, language)
      if selected.option.reason then detail = detail .. "  ·  " .. selected.option.reason end
    else
      detail = Catalog.text(selected, language).detail
        .. (LongTermProgress.format(selected, state, language) or "")
      if Tracker.routeContains(state.tracker, selected.id) then
        detail = detail .. "  ·  " .. labels.routeMemberLocked
      end
    end
    local detailLines = Text.wrapPixels(detail,
      contentWidth, fontPixels)
    local detailPages = math.max(1, math.ceil(#detailLines / layout.maxDetailLines))
    state.menu.detailPage = math.max(1, math.min(state.menu.detailPage or 1, detailPages))
    if detailPages > 1 then
      local pageStart = (state.menu.detailPage - 1) * layout.maxDetailLines + 1
      local pageLines = {}
      for index = pageStart, math.min(#detailLines,
          pageStart + layout.maxDetailLines - 1) do pageLines[#pageLines + 1] = detailLines[index] end
      detailLines = pageLines
      local pageLabel = string.format(labels.routeDetailPage, state.menu.detailPage, detailPages)
      Text.drawPixels(pageLabel, x + contentWidth - Text.widthPixels(pageLabel, fontPixels),
        detailY, fontPixels, MUTED, language)
    end
    for lineIndex, line in ipairs(detailLines) do
      Text.drawPixels(line, x, detailY + lineIndex * layout.lineHeight,
        fontPixels, INK, language)
    end
  else
    local emptyLabel = state.menu.query ~= "" and labels.emptySearch or labels.emptyFilter
    Text.drawPixels(emptyLabel, x, detailY + layout.lineHeight,
      fontPixels, MUTED, language)
  end

  local page = #goals > 0
    and math.floor((state.menu.cursor - 1) / layout.pageSize) + 1 or 1
  local pages = math.max(1, math.ceil(#goals / layout.pageSize))
  local footerY = panelY + panelHeight - layout.footerReserve + 3
  local controls = state.menu.searchFocused and labels.controlsSearch or labels.controlsMenu
  if Menu.isMultiplayer(Game()) then
    controls = labels.multiplayerRealtime
  elseif not ModCallbacks.MC_PRE_UPDATE then
    controls = labels.pauseUnavailable
  end
  local statistics = string.format("%d/%d %s  |  %d/%d", Tracker.slotCount(state.tracker),
    state.tracker.max, labels.tracked, page, pages)
  local statisticsWidth = Text.widthPixels(statistics, fontPixels)
  Text.drawPixels(Text.ellipsizePixels(controls,
      math.max(20, contentWidth - statisticsWidth - 8), fontPixels),
    x, footerY, fontPixels, MUTED, language)
  Text.drawPixels(statistics, panelX + panelWidth - 12 - statisticsWidth,
    footerY, fontPixels, TRACKED_INK, language)
end

return Menu
