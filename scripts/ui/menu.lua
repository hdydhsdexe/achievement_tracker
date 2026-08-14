local Catalog = require("scripts.data.goals")
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
local PANEL_WIDTH_RATIO = 0.64
local MIN_PANEL_WIDTH = 270
local MAX_PANEL_WIDTH = 340
local MAX_PANEL_HEIGHT = 238
local MENU_MIN_BODY_PIXELS = 8
local MENU_MAX_BODY_PIXELS = 11

-- Warm monochrome inks sampled from the referenced Isaac paper-menu style.
-- Body tones are slightly darker than the reference because this panel uses
-- the game's darker parchment texture.
local DARK_INK = KColor(0.169, 0.129, 0.110, 1)
local INK = KColor(0.33, 0.24, 0.19, 1)
local MUTED = KColor(0.36, 0.27, 0.21, 1)
local STAMP_INK = KColor(0.30, 0.22, 0.17, 1)
local DIMMED_INK = KColor(0.48, 0.46, 0.43, 1)
local DIMMED_TINT = Color(0.48, 0.48, 0.48, 1)
local CONVERTIBLE_INK = KColor(0.67, 0.40, 0.10, 1)
local CONVERTIBLE_TINT = Color(1.00, 0.68, 0.28, 1)

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
    relevanceContext=nil, relevanceSignature=nil, completionSignature=nil }
end

local function isCompleted(state, goal)
  return (state.profileCompleted and state.profileCompleted[goal.id])
    or (state.run.completedGoals and state.run.completedGoals[goal.id])
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
  local currentPending, convertiblePending, otherCharacterPending, completed = {}, {}, {}, {}
  context = context or CharacterRelevance.buildContext(Game(), Catalog.goals)
  local filter = FILTERS[state.menu.filterIndex] or "all"
  for _, goal in ipairs(Catalog.goals) do
    if matchesFilter(goal, filter) then
      local bucket = completed
      if not isCompleted(state, goal) then
        local relevance = CharacterRelevance.classify(goal, context)
        if relevance == "current" then bucket = currentPending
        elseif relevance == "convertible" then bucket = convertiblePending
        else bucket = otherCharacterPending end
      end
      table.insert(bucket, goal)
    end
  end
  local goals = {}
  for _, bucket in ipairs({ currentPending, convertiblePending, otherCharacterPending, completed }) do
    for _, goal in ipairs(bucket) do table.insert(goals, goal) end
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

function Menu.update(state, save)
  if triggered(Keyboard.KEY_F3) then
    if state.menu.open then
      state.menu.open = false
    elseif not Game():IsPaused() or ModCallbacks.MC_PRE_PAUSE_SCREEN_RENDER then
      state.menu.open = true
      state.menu.cursor, state.menu.offset, state.menu.filterIndex = 1, 1, 1
      refreshGoals(state, nil, false)
    end
  end
  if triggered(Keyboard.KEY_F4) then state.settings.hud.visible = not state.settings.hud.visible; save() end
  if not state.menu.open then return end
  local context = CharacterRelevance.buildContext(Game(), Catalog.goals)
  local completionSignature = completedSignature(state)
  if state.menu.relevanceSignature ~= context.signature
    or state.menu.completionSignature ~= completionSignature then
    refreshGoals(state, context, true)
  end
  if triggered(Keyboard.KEY_TAB) then
    state.menu.filterIndex = state.menu.filterIndex % #FILTERS + 1
    state.menu.cursor, state.menu.offset = 1, 1
    refreshGoals(state, context, false)
  end
  local goals = state.menu.goals or {}
  local count = #goals
  if count > 0 then
    if triggered(Keyboard.KEY_LEFT) then state.menu.cursor = math.max(1, state.menu.cursor - 1) end
    if triggered(Keyboard.KEY_RIGHT) then state.menu.cursor = math.min(count, state.menu.cursor + 1) end
    if triggered(Keyboard.KEY_UP) then state.menu.cursor = math.max(1, state.menu.cursor - COLUMNS) end
    if triggered(Keyboard.KEY_DOWN) then state.menu.cursor = math.min(count, state.menu.cursor + COLUMNS) end
    if triggered(Keyboard.KEY_ENTER) or triggered(Keyboard.KEY_SPACE) then
      Tracker.toggle(state.tracker, goals[state.menu.cursor].id)
      state.settings.tracked = state.tracker.ids
      save()
    end
    state.menu.offset = math.floor((state.menu.cursor - 1) / PAGE_SIZE) * PAGE_SIZE + 1
  else
    state.menu.cursor, state.menu.offset = 1, 1
  end
  if triggered(Keyboard.KEY_ESCAPE) then state.menu.open = false end
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
  local screenWidth, screenHeight = Isaac.GetScreenWidth(), Isaac.GetScreenHeight()
  local panelWidth = math.min(MAX_PANEL_WIDTH,
    math.max(MIN_PANEL_WIDTH, math.floor(screenWidth * PANEL_WIDTH_RATIO)))
  panelWidth = math.min(panelWidth, screenWidth - 24)
  local panelHeight = math.min(MAX_PANEL_HEIGHT, screenHeight - 28)
  local panelX = math.floor((screenWidth - panelWidth) / 2)
  local panelY = math.floor((screenHeight - panelHeight) / 2)
  local typeScale = menuTypeScales(state.settings.hud.fontScale)
  local lineHeight = 13
  local x, top = panelX + 12, panelY + 10
  local contentWidth = panelWidth - 24
  local columnWidth = math.floor(contentWidth / COLUMNS)
  local gridTop = top + 32
  RewardIcons.renderPaper(panelX, panelY, panelWidth, panelHeight)

  Text.draw(labels.menuTitle, panelX, top, typeScale.title, DARK_INK,
    language, panelWidth, true)
  Text.draw(filterLine(labels, state.menu.filterIndex), x, top + 16,
    typeScale.label, INK, language)
  Text.draw(labels.filterHint, panelX + panelWidth - 76, top + 16,
    typeScale.small, MUTED, language)

  local last = math.min(#goals, state.menu.offset + PAGE_SIZE - 1)
  for index = state.menu.offset, last do
    local goal = goals[index]
    local localIndex = index - state.menu.offset
    local column, row = localIndex % COLUMNS, math.floor(localIndex / COLUMNS)
    local tileX, tileY = x + column * columnWidth, gridTop + row * lineHeight
    local selected = index == state.menu.cursor
    local completed = isCompleted(state, goal)
    local relevance = CharacterRelevance.classify(goal, context)
    local dimmed = not completed and relevance == "other"
    local convertible = not completed and relevance == "convertible"
    local tracked = Tracker.contains(state.tracker, goal.id)
    local reward = Rewards.display(goal)
    local tint = completed and Color(0.72, 0.60, 0.48, 1)
      or (convertible and CONVERTIBLE_TINT or Color(1, 1, 1, 1))
    RewardIcons.render(reward, tileX + 8, tileY + 6, 12, dimmed and DIMMED_TINT or tint)
    local marker = selected and ">" or " "
    local tracking = tracked and "*" or " "
    local status = completed and "+" or (convertible and "~" or "?")
    local name = Text.ellipsize(Catalog.text(goal, language).name,
      columnWidth - 35, typeScale.body)
    local color = dimmed and DIMMED_INK
      or (completed and STAMP_INK
        or (convertible and CONVERTIBLE_INK or (selected and DARK_INK or INK)))
    Text.draw(marker .. tracking .. status .. " " .. name,
      tileX + 15, tileY, typeScale.body, color, language)
  end

  local detailY = gridTop + ROWS * lineHeight + 4
  local selected = goals[state.menu.cursor]
  if selected then
    local reward = Rewards.display(selected)
    local completed = isCompleted(state, selected)
    local relevance = CharacterRelevance.classify(selected, context)
    local dimmed = not completed and relevance == "other"
    local convertible = not completed and relevance == "convertible"
    local detailInk = dimmed and DIMMED_INK
      or (convertible and CONVERTIBLE_INK or INK)
    local detailTint = dimmed and DIMMED_TINT
      or (convertible and CONVERTIBLE_TINT or Color(1, 1, 1, 1))
    local leftWidth = math.floor(contentWidth * 0.52)
    local rewardX = x + leftWidth + 15
    Text.draw(labels.completionCondition, x, detailY, typeScale.label, DARK_INK, language)
    local statusLabel = completed and labels.completed
      or (convertible and labels.availableAfterTransformation or labels.unconfirmed)
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
    Text.draw(labels.emptyFilter, x, detailY + 12, typeScale.body, MUTED, language)
  end

  local page = #goals > 0 and math.floor((state.menu.cursor - 1) / PAGE_SIZE) + 1 or 1
  local pages = math.max(1, math.ceil(#goals / PAGE_SIZE))
  local footerY = panelY + panelHeight - 14
  Text.draw(Text.ellipsize(labels.controlsMenu, contentWidth - 94, typeScale.small),
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
