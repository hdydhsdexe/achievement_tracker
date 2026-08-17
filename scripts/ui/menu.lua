local Catalog = require("scripts.data.goals")
local CompletionMarks = require("scripts.core.completion_marks")
local CharacterRelevance = require("scripts.core.character_relevance")
local Rewards = require("scripts.core.rewards")
local RewardIcons = require("scripts.ui.reward_icons")
local Text = require("scripts.ui.text")
local Tracker = require("scripts.core.tracker")
local Menu = {}
local COLUMNS = 3
local ROWS = 9
local PAGE_SIZE = COLUMNS * ROWS
local FILTERS = { "all", "collectible", "trinket", "card", "other" }
local MAX_SEARCH_LENGTH = 48
local HOLD_DELAY_MS = 300
local HOLD_REPEAT_MS = 90
local PANEL_WIDTH_RATIO = 0.64
local MIN_PANEL_WIDTH = 270
local MAX_PANEL_WIDTH = 340
local MAX_PANEL_HEIGHT = 238
local LINE_HEIGHT = 13
local MENU_MIN_BODY_PIXELS = 8
local MENU_MAX_BODY_PIXELS = 11
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
local STAMP_INK = KColor(0.78, 0.86, 0.62, 1)
local DIMMED_INK = KColor(0.62, 0.60, 0.58, 1)
local DIMMED_TINT = Color(0.48, 0.48, 0.48, 1)
local CONVERTIBLE_INK = KColor(1.00, 0.72, 0.30, 1)
local CONVERTIBLE_TINT = Color(1.00, 0.68, 0.28, 1)

local function menuLayout()
  local screenWidth, screenHeight = Isaac.GetScreenWidth(), Isaac.GetScreenHeight()
  local panelWidth = math.min(MAX_PANEL_WIDTH,
    math.max(MIN_PANEL_WIDTH, math.floor(screenWidth * PANEL_WIDTH_RATIO)))
  panelWidth = math.min(panelWidth, screenWidth - 24)
  local panelHeight = math.min(MAX_PANEL_HEIGHT, screenHeight - 28)
  local panelX = math.floor((screenWidth - panelWidth) / 2)
  local panelY = math.floor((screenHeight - panelHeight) / 2)
  local x, top = panelX + 12, panelY + 10
  local contentWidth = panelWidth - 24
  return {
    panelWidth=panelWidth, panelHeight=panelHeight, panelX=panelX, panelY=panelY,
    x=x, top=top, contentWidth=contentWidth,
    columnWidth=math.floor(contentWidth / COLUMNS), gridTop=top + 32
  }
end

local function menuTypeScales(fontScale)
  local requestedPixels = math.floor((tonumber(fontScale) or 1) * 10 + 0.5)
  local bodyPixels = math.max(MENU_MIN_BODY_PIXELS,
    math.min(MENU_MAX_BODY_PIXELS, requestedPixels))
  return {
    title=Text.scaleForPixels(bodyPixels + 1),
    body=Text.scaleForPixels(bodyPixels),
    label=Text.scaleForPixels(math.max(8, bodyPixels - 1)),
    small=Text.scaleForPixels(math.max(7, bodyPixels - 2))
  }
end

function Menu.new()
  return { open=false, cursor=1, offset=1, goals=nil, filterIndex=1,
    query="", searchFocused=false, relevanceContext=nil,
    relevanceSignature=nil, completionSignature=nil, repeatKeys={},
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

local function completedSignature(state)
  local ids = {}
  for _, goal in ipairs(Catalog.goals) do
    if isCompleted(state, goal) then table.insert(ids, goal.id) end
  end
  return table.concat(ids, ",")
end

local function matchesFilter(goal, filter)
  if filter == "all" then return true end
  return Rewards.filterKind(Rewards.display(goal)) == filter
end

local function refreshGoals(state, context, preserveSelection)
  local selectedGoalId = preserveSelection and state.menu.goals
    and state.menu.goals[state.menu.cursor]
    and state.menu.goals[state.menu.cursor].id
  local tracked, currentPending, convertiblePending, otherCharacterPending, unavailable, completed = {}, {}, {}, {}, {}, {}
  local searchMeta = {}
  local trackedOrder = {}
  for index, id in ipairs(state.tracker.ids) do trackedOrder[id] = index end
  context = context or CharacterRelevance.buildContext(Game(), Catalog.goals)
  local filter = FILTERS[state.menu.filterIndex] or "all"
  for _, match in ipairs(Catalog.search(state.menu.query)) do
    local goal = match.goal
    if matchesFilter(goal, filter) then
      local completedGoal = isCompleted(state, goal)
      local completable = isCompletable(goal)
      local bucket, priorityRank = completed, 6
      if Tracker.contains(state.tracker, goal.id) and (completedGoal or completable) then
        bucket, priorityRank = tracked, 1
      elseif not completedGoal and not completable then
        bucket, priorityRank = unavailable, 5
      elseif not completedGoal then
        local relevance = CharacterRelevance.classify(goal, context)
        if relevance == "current" then bucket, priorityRank = currentPending, 2
        elseif relevance == "convertible" then bucket, priorityRank = convertiblePending, 3
        else bucket, priorityRank = otherCharacterPending, 4 end
      end
      table.insert(bucket, goal)
      searchMeta[goal.id] = { score=match.score, priorityRank=priorityRank,
        stableOrder=trackedOrder[goal.id] or match.catalogIndex }
    end
  end
  table.sort(tracked, function(left, right)
    return trackedOrder[left.id] < trackedOrder[right.id]
  end)
  local goals = {}
  for _, bucket in ipairs({ tracked, currentPending, convertiblePending, otherCharacterPending, unavailable, completed }) do
    for _, goal in ipairs(bucket) do table.insert(goals, goal) end
  end
  if state.menu.query ~= "" then
    table.sort(goals, function(leftGoal, rightGoal)
      local left, right = searchMeta[leftGoal.id], searchMeta[rightGoal.id]
      if left.priorityRank ~= right.priorityRank then
        return left.priorityRank < right.priorityRank
      end
      if left.score ~= right.score then return left.score < right.score end
      return left.stableOrder < right.stableOrder
    end)
  end
  state.menu.goals = goals
  state.menu.relevanceContext = context
  state.menu.relevanceSignature = context.signature
  state.menu.completionSignature = completedSignature(state)
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
    and math.floor((state.menu.cursor - 1) / PAGE_SIZE) * PAGE_SIZE + 1 or 1
end

local function triggered(key) return Input.IsButtonTriggered(key, 0) end

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
    layout.gridTop + LINE_HEIGHT * ROWS) then return nil end
  local column = math.floor((position.X - layout.x) / layout.columnWidth)
  local row = math.floor((position.Y - layout.gridTop) / LINE_HEIGHT)
  local index = state.menu.offset + row * COLUMNS + column
  local goals = state.menu.goals or {}
  if index > #goals or index >= state.menu.offset + PAGE_SIZE then return nil end
  return index
end

local function updateMouseSelection(state)
  local position = Input.GetMousePosition(false)
  local moved = state.menu.mouseX ~= position.X or state.menu.mouseY ~= position.Y
  state.menu.mouseX, state.menu.mouseY = position.X, position.Y
  local index = mouseGoalIndex(state, position, menuLayout())
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
  if not goal or not Tracker.toggle(state.tracker, goal.id) then return false end
  state.settings.tracked = state.tracker.ids
  save()
  refreshGoals(state, context, true)
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
    or mouseInsidePanel(Input.GetMousePosition(false), menuLayout())) then
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
  local context = CharacterRelevance.buildContext(Game(), Catalog.goals)
  local completionSignature = completedSignature(state)
  if state.menu.relevanceSignature ~= context.signature
    or state.menu.completionSignature ~= completionSignature then
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
    refreshGoals(state, context, false)
  end
  local goals = state.menu.goals or {}
  local count = #goals
  local keyboardActivated = false
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
    else
      resetRepeatKeys(state)
    end
    state.menu.offset = math.floor((state.menu.cursor - 1) / PAGE_SIZE) * PAGE_SIZE + 1
  else
    state.menu.cursor, state.menu.offset = 1, 1
  end
  local keyboardIndex = keyboardActivated and state.menu.cursor
  local mouseIndex = updateMouseSelection(state)
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
  local parts = {}
  for index, filter in ipairs(FILTERS) do
    local name = labels.filterNames[filter]
    table.insert(parts, index == active and ("[" .. name .. "]") or name)
  end
  return table.concat(parts, "  ")
end

local function rewardName(goal, language)
  return string.gsub(Catalog.text(goal, language).name, "^#%d+%s*", "")
end

local function rewardMeta(reward, labels)
  local kind = labels.rewardKinds[reward.kind] or labels.rewardKinds.other
  if reward.kind == "pickup" then
    return string.format("%s  ·  %s 5.%d.%d", kind, labels.rewardId,
      reward.variant or 0, reward.subtype or 0)
  end
  if reward.kind == "slot" then
    return string.format("%s  ·  %s 6.%d", kind, labels.rewardId, reward.variant or 0)
  end
  if reward.kind == "grid" then
    return string.format("%s  ·  %s %d.%d", kind, labels.rewardId,
      reward.gridType or 0, reward.variant or 0)
  end
  if reward.id then return string.format("%s  ·  %s %d", kind, labels.rewardId, reward.id) end
  return kind
end

function Menu.render(state)
  if not state.menu.open then return end
  local goals = state.menu.goals or {}
  local language = Text.resolveLanguage(state.settings.language)
  local labels = Text.labels(language)
  local context = state.menu.relevanceContext
    or CharacterRelevance.buildContext(Game(), Catalog.goals)
  local layout = menuLayout()
  local panelWidth, panelHeight = layout.panelWidth, layout.panelHeight
  local panelX, panelY = layout.panelX, layout.panelY
  local typeScale = menuTypeScales(state.settings.hud.fontScale)
  local x, top = layout.x, layout.top
  local contentWidth, columnWidth = layout.contentWidth, layout.columnWidth
  local gridTop = layout.gridTop
  RewardIcons.renderPaper(panelX, panelY, panelWidth, panelHeight)

  local title = labels.menuTitle
  if state.menu.searchFocused or state.menu.query ~= "" then
    title = labels.searchPrompt .. ": " .. state.menu.query
      .. (state.menu.searchFocused and "_" or "")
  end
  Text.draw(Text.ellipsize(title, contentWidth, typeScale.title), panelX, top,
    typeScale.title, DARK_INK,
    language, panelWidth, true)
  Text.draw(filterLine(labels, state.menu.filterIndex), x, top + 16,
    typeScale.label, INK, language)
  local filterHint = state.menu.query ~= ""
    and string.format(labels.searchResults, #goals) or labels.filterHint
  Text.draw(filterHint, panelX + panelWidth - 12
      - Text.width(filterHint, typeScale.small), top + 16,
    typeScale.small, MUTED, language)

  local last = math.min(#goals, state.menu.offset + PAGE_SIZE - 1)
  for index = state.menu.offset, last do
    local goal = goals[index]
    local localIndex = index - state.menu.offset
    local column, row = localIndex % COLUMNS, math.floor(localIndex / COLUMNS)
    local tileX, tileY = x + column * columnWidth, gridTop + row * LINE_HEIGHT
    local selected = index == state.menu.cursor
    local completed = isCompleted(state, goal)
    local completable = isCompletable(goal)
    local relevance = CharacterRelevance.classify(goal, context)
    local dimmed = not completed and relevance == "other"
    dimmed = dimmed or (not completed and not completable)
    local convertible = not completed and relevance == "convertible"
    local tracked = Tracker.contains(state.tracker, goal.id)
    local reward = Rewards.display(goal)
    local tint = completed and Color(0.72, 0.60, 0.48, 1)
      or (convertible and CONVERTIBLE_TINT or Color(1, 1, 1, 1))
    RewardIcons.render(reward, tileX + 8, tileY + 6, 12, dimmed and DIMMED_TINT or tint)
    local marker = selected and ">" or " "
    local tracking = tracked and "*" or " "
    local status = completed and "+" or (not completable and "!"
      or (convertible and "~" or "?"))
    local name = Text.ellipsize(Catalog.text(goal, language).name,
      columnWidth - 35, typeScale.body)
    local color = dimmed and DIMMED_INK
      or (completed and STAMP_INK
        or (convertible and CONVERTIBLE_INK or (selected and DARK_INK or INK)))
    Text.draw(marker .. tracking .. status .. " " .. name,
      tileX + 15, tileY, typeScale.body, color, language)
  end

  local detailY = gridTop + ROWS * LINE_HEIGHT + 4
  local selected = goals[state.menu.cursor]
  if selected then
    local reward = Rewards.display(selected)
    local completed = isCompleted(state, selected)
    local completable = isCompletable(selected)
    local relevance = CharacterRelevance.classify(selected, context)
    local dimmed = not completed and relevance == "other"
    dimmed = dimmed or (not completed and not completable)
    local convertible = not completed and relevance == "convertible"
    local detailInk = dimmed and DIMMED_INK
      or (convertible and CONVERTIBLE_INK or INK)
    local detailTint = dimmed and DIMMED_TINT
      or (convertible and CONVERTIBLE_TINT or Color(1, 1, 1, 1))
    local leftWidth = math.floor(contentWidth * 0.52)
    local rewardX = x + leftWidth + 15
    Text.draw(labels.completionCondition, x, detailY, typeScale.label, DARK_INK, language)
    local statusLabel = completed and labels.completed
      or (not completable and labels.unavailable
        or (convertible and labels.availableAfterTransformation or labels.unconfirmed))
    local statusInk = completed and STAMP_INK
      or (convertible and CONVERTIBLE_INK or MUTED)
    Text.draw(statusLabel, x + 72, detailY, typeScale.small, statusInk, language)
    Text.draw(Catalog.text(selected, language).detail, x, detailY + 13,
      typeScale.label, detailInk, language, leftWidth - 12)
    Text.draw("=>", x + leftWidth, detailY + 22, typeScale.body, DARK_INK, language)
    Text.draw(labels.unlockReward, rewardX, detailY, typeScale.label, DARK_INK, language)
    RewardIcons.render(reward, rewardX + 15, detailY + 29, 30, detailTint)
    local nameX = rewardX + 36
    Text.draw(Text.ellipsize(rewardName(selected, language),
      panelX + panelWidth - nameX - 10, typeScale.label),
      nameX, detailY + 18, typeScale.label, detailInk, language)
    Text.draw(rewardMeta(reward, labels), nameX, detailY + 34,
      typeScale.small, MUTED, language)
  else
    local emptyLabel = state.menu.query ~= "" and labels.emptySearch or labels.emptyFilter
    Text.draw(emptyLabel, x, detailY + 12, typeScale.body, MUTED, language)
  end

  local page = #goals > 0 and math.floor((state.menu.cursor - 1) / PAGE_SIZE) + 1 or 1
  local pages = math.max(1, math.ceil(#goals / PAGE_SIZE))
  local footerY = panelY + panelHeight - 14
  local controls = state.menu.searchFocused and labels.controlsSearch or labels.controlsMenu
  Text.draw(Text.ellipsize(controls, contentWidth - 94, typeScale.small),
    x, footerY, typeScale.small, MUTED, language)
  Text.draw(string.format("%d/%d %s  |  %d/%d", #state.tracker.ids,
    state.tracker.max, labels.tracked, page, pages),
    panelX + panelWidth - 112, footerY, typeScale.small, STAMP_INK, language)
  if Menu.isMultiplayer(Game()) then
    Text.draw(labels.multiplayerRealtime, x, footerY - 11,
      typeScale.small, DARK_INK, language)
  elseif not ModCallbacks.MC_PRE_UPDATE then
    Text.draw(labels.pauseUnavailable, x, footerY - 11,
      typeScale.small, DARK_INK, language)
  end
end

return Menu
