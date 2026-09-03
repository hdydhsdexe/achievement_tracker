local AchievementTracker = RegisterMod("Achievement Tracker", 1)
local GameInstance = Game()

local Catalog = require("scripts.data.goals")
local CharacterRelevance = require("scripts.core.character_relevance")
local CompletionMarks = require("scripts.core.completion_marks")
local Evaluator = require("scripts.core.evaluator")
local Hud = require("scripts.ui.hud")
local Mcm = require("scripts.integrations.mcm")
local Menu = require("scripts.ui.menu")
local LongTermProgress = require("scripts.core.long_term_progress")
local Opportunities = require("scripts.core.opportunities")
local Recommendations = require("scripts.data.recommendations")
local RouteRecommendations = require("scripts.core.route_recommendations")
local Sensors = require("scripts.core.sensors")
local Routes = require("scripts.core.routes")
local Storage = require("scripts.core.storage")
local Tracker = require("scripts.core.tracker")
local Unlocks = require("scripts.core.unlocks")

local State = {
  settings = nil,
  tracker = nil,
  evaluator = Evaluator.new(),
  run = Sensors.newRun(),
  menu = Menu.new(),
  activeWarning = nil,
  lastEvaluation = -1,
  profileCompleted = {},
  routeContext = nil,
  sceneOpportunities = {},
  quickTrackNotice = nil,
  completionBaseline = {},
  completionNotices = {}
}

local function save()
  if not State.settings then return end
  State.settings.tracked = State.tracker.ids
  State.run.trackedRoute = State.tracker.route
  State.settings.activeRun = State.run
  Storage.save(AchievementTracker, State.settings)
end

local function relevantPlayerTypes()
  local result = {}
  for _, goal in ipairs(Catalog.goals) do
    for _, requirement in ipairs(goal.completionRequirements or {}) do
      if requirement.playerType ~= nil then result[requirement.playerType] = true end
    end
  end
  for index = 0, GameInstance:GetNumPlayers() - 1 do
    result[CharacterRelevance.normalize(Isaac.GetPlayer(index):GetPlayerType())] = true
  end
  return result
end

local function refreshCompletionFromMarks()
  for _, goal in ipairs(Catalog.goals) do
    if CompletionMarks.isSatisfied(goal, State.settings.completionMarks) then
      State.profileCompleted[goal.id] = true
    end
  end
end

local function isGoalCompleted(goal)
  return (State.profileCompleted and State.profileCompleted[goal.id])
    or (State.run.completedGoals and State.run.completedGoals[goal.id])
    or CompletionMarks.isSatisfied(goal, State.settings.completionMarks)
end

local function initializeCompletionBaseline()
  State.completionBaseline = {}
  local completedIds = {}
  for _, goal in ipairs(Catalog.goals) do
    if isGoalCompleted(goal) then
      State.completionBaseline[goal.id] = true
      completedIds[goal.id] = true
    end
  end
  return Tracker.removeIds(State.tracker, completedIds)
end

local function syncCompletionTransitions()
  local newlyCompleted = {}
  for _, goal in ipairs(Catalog.goals) do
    local completed = isGoalCompleted(goal) == true
    if completed and not State.completionBaseline[goal.id] then
      newlyCompleted[goal.id] = true
      table.insert(State.completionNotices, goal.id)
    end
    State.completionBaseline[goal.id] = completed or nil
  end
  return Tracker.removeIds(State.tracker, newlyCompleted)
end

local function trackingTaintedUnlock()
  if not State.tracker then return false end
  for _, id in ipairs(Tracker.allIds(State.tracker)) do
    local goal = Catalog.get(id)
    if goal and goal.routeKind == "tainted_unlock" then return true end
  end
  return false
end

local function completionAllowed()
  if Isaac.GetChallenge() ~= 0 then return false end
  local seeds = GameInstance:GetSeeds()
  if seeds and seeds.IsCustomRun then
    local ok, custom = pcall(function() return seeds:IsCustomRun() end)
    if ok and custom then return false end
  end
  if GameInstance.GetVictoryLap then
    local ok, victoryLap = pcall(function() return GameInstance:GetVictoryLap() end)
    if ok and victoryLap > 0 then return false end
  end
  if GameInstance.AchievementUnlocksDisallowed then
    local ok, disallowed = pcall(function() return GameInstance:AchievementUnlocksDisallowed() end)
    if ok and disallowed then return false end
  end
  return true
end

local function runStartRouteContext(routeContext, relevanceContext)
  local result, players = {}, {}
  for key, value in pairs(routeContext or {}) do result[key] = value end
  for player in pairs(routeContext and routeContext.players or {}) do players[player] = true end
  for player in pairs(relevanceContext.convertible or {}) do players[player] = true end
  for player in pairs(relevanceContext.ascentConvertible or {}) do players[player] = true end
  result.players = players
  return result
end

local function goalAvailableAtRunStart(goal, relevanceContext, routeContext)
  if isGoalCompleted(goal) or not Catalog.isCompletable(goal, Isaac.GetChallenge()) then
    return false
  end
  if not completionAllowed() and Isaac.GetChallenge() == 0 then return false end
  local relevance = CharacterRelevance.classify(goal, relevanceContext)
  if relevance ~= "current" and relevance ~= "general" and relevance ~= "convertible" then
    return false
  end
  local evaluationContext = runStartRouteContext(routeContext, relevanceContext)
  local _, _, remaining = CompletionMarks.progress(goal,
    State.settings.completionMarks, evaluationContext.players)
  local difficulty = CompletionMarks.difficultyValue(GameInstance)
  for _, requirement in ipairs(remaining) do
    if requirement.difficulty > difficulty then return false end
  end
  local routeResult = Routes.evaluate(goal, evaluationContext,
    State.settings.completionMarks, "en")
  if routeResult and routeResult.severity == "failed" then return false end
  return true
end

local function prepareNewRunTracking(relevanceContext, routeContext)
  Tracker.untrackRoute(State.tracker)
  State.run.trackedRoute = nil
  State.run.routeRecommendation = nil
  State.run.startRoomPrompt = false
  State.run.startRoomIndex = nil
  local unavailable = {}
  for _, id in ipairs(State.tracker.ids) do
    local goal = Catalog.get(id)
    if not goal or not goalAvailableAtRunStart(goal, relevanceContext, routeContext) then
      unavailable[id] = true
    end
  end
  return Tracker.removeIds(State.tracker, unavailable)
end

local VICTORY_LAP_OPPORTUNITY_IDS = {
  achievement_321=true,
  achievement_360=true,
  achievement_337=true,
}

local function victoryLapOpportunitiesAllowed()
  if Isaac.GetChallenge() ~= 0 or not GameInstance.GetVictoryLap then return false end
  local seeds = GameInstance:GetSeeds()
  if seeds and seeds.IsCustomRun then
    local ok, custom = pcall(function() return seeds:IsCustomRun() end)
    if ok and custom then return false end
  end
  local allowed = completionAllowed()
  if not allowed then
    local ok, victoryLap = pcall(function() return GameInstance:GetVictoryLap() end)
    allowed = ok and victoryLap > 0
  end
  return allowed and VICTORY_LAP_OPPORTUNITY_IDS.achievement_321
    and VICTORY_LAP_OPPORTUNITY_IDS.achievement_360
    and VICTORY_LAP_OPPORTUNITY_IDS.achievement_337
end

local function recordCompletionMark(mark)
  if not mark or not completionAllowed() then return false end
  local changed = false
  local value = CompletionMarks.difficultyValue(GameInstance)
  for index = 0, GameInstance:GetNumPlayers() - 1 do
    local playerType = CharacterRelevance.normalize(Isaac.GetPlayer(index):GetPlayerType())
    changed = CompletionMarks.merge(State.settings.completionMarks, playerType, mark, value) or changed
  end
  if changed then
    refreshCompletionFromMarks()
    syncCompletionTransitions()
    save()
  end
  return changed
end

local function bossRushCompleted()
  local ok, completed = pcall(function()
    return GameInstance:GetStateFlag(GameStateFlag.STATE_BOSSRUSH_DONE)
  end)
  if ok and completed then return true end

  -- Compatibility fallback for older API environments. The run-wide game
  -- state flag above is authoritative and remains available after leaving.
  local room = GameInstance:GetRoom()
  return room:GetType() == RoomType.ROOM_BOSSRUSH
    and room.IsAmbushDone and room:IsAmbushDone()
end

local function syncBossRushCompletion()
  if State.settings and bossRushCompleted() then
    recordCompletionMark("BOSS_RUSH")
  end
end

local function refreshRouteFloor()
  local level = GameInstance:GetLevel()
  local okSeed, floorSeed = pcall(function() return level:GetDungeonPlacementSeed() end)
  if not okSeed or floorSeed == nil then
    local okRoom, roomSeed = pcall(function() return level:GetCurrentRoomDesc().SpawnSeed end)
    floorSeed = okRoom and roomSeed or nil
  end
  local okAscent, ascent = pcall(function() return level:IsAscent() end)
  ascent = okAscent and ascent == true
  local current = { stage=level:GetStage(), stageType=level:GetStageType(), seed=floorSeed }
  local previous = State.run.routeFloor
  local reset = previous and not ascent and (current.stage < previous.stage
    or (current.stage == previous.stage and current.seed and previous.seed
      and current.seed ~= previous.seed))
  if reset then
    Routes.resetAttempt(State.run)
    Opportunities.resetAttempt(State.run)
    CharacterRelevance.resetAttempt(State.run)
  end
  local aidsChanged = Routes.beginFloor(State.run,
    current.stage, current.stageType, current.seed)
  State.run.routeFloor = current
  return reset or aidsChanged
end

local function load()
  State.settings = Storage.load(AchievementTracker)
  local tracked = {}
  for _, id in ipairs(State.settings.tracked) do
    if Catalog.isTrackable(id) then tracked[#tracked + 1] = id end
  end
  State.settings.tracked = tracked
  State.tracker = Tracker.new(State.settings.maxTracked, tracked)
end

function AchievementTracker:onGameStarted(isContinued)
  load()
  local startSeed = GameInstance:GetSeeds():GetStartSeed()
  local savedRun = State.settings.activeRun
  local sameSavedRun = type(savedRun) == "table"
    and savedRun.startSeed ~= nil
    and savedRun.startSeed == startSeed
  if type(savedRun) == "table" and (isContinued or sameSavedRun) then
    State.run = savedRun
    Sensors.normalizeRun(State.run)
    State.run.startSeed = startSeed
  else
    State.run = Sensors.newRun(startSeed)
  end
  State.run.routeRecommendation = RouteRecommendations.normalize(State.run.routeRecommendation)
  State.run.trackedRoute = RouteRecommendations.normalize(State.run.trackedRoute)
  Tracker.setRoute(State.tracker, State.run.trackedRoute)
  Evaluator.reset(State.evaluator)
  State.activeWarning = nil
  State.lastEvaluation = -1
  State.routeContext = nil
  State.sceneOpportunities = {}
  State.quickTrackNotice = nil
  State.completionBaseline = {}
  State.completionNotices = {}
  local player = Isaac.GetPlayer(0)
  if player then Sensors.initialize(State.run, player) end
  Unlocks.refreshAchievementImport(Catalog.goals, State.settings.achievementImport)
  State.profileCompleted = Unlocks.scan(Catalog.goals, State.settings.observedCompleted,
    State.settings.achievementImport)
  CompletionMarks.infer(Catalog.goals, State.profileCompleted, State.settings.completionMarks)
  CompletionMarks.syncRepentogon(State.settings.completionMarks, relevantPlayerTypes())
  refreshCompletionFromMarks()
  for index = 0, GameInstance:GetNumPlayers() - 1 do
    local currentPlayer = Isaac.GetPlayer(index)
    Unlocks.observe(Catalog.goals, State.settings.observedCompleted, State.profileCompleted,
      "player", currentPlayer:GetPlayerType(), nil, State.settings.achievementImport)
  end
  refreshRouteFloor()
  CharacterRelevance.updateSources(State.run, GameInstance)
  State.routeContext = Routes.context(GameInstance, State.run)
  local relevanceContext = CharacterRelevance.buildContext(GameInstance, Catalog.goals, State.run)
  initializeCompletionBaseline()
  if not isContinued then
    prepareNewRunTracking(relevanceContext, State.routeContext)
    if completionAllowed() then
      local recommendation = RouteRecommendations.choose(Catalog.goals, {
        allowed=true,
        greed=GameInstance:IsGreedMode(),
        difficulty=CompletionMarks.difficultyValue(GameInstance),
        completionStore=State.settings.completionMarks,
        currentPlayers=State.routeContext.players,
        relevanceContext=relevanceContext,
        isCompleted=isGoalCompleted,
        isTracked=function(id) return Tracker.containsAny(State.tracker, id) end,
        evaluate=function(goal)
          return Routes.evaluate(goal, State.routeContext,
            State.settings.completionMarks, "en")
        end
      })
      State.run.routeRecommendation = recommendation
      local okStart, startRoomIndex = pcall(function()
        return GameInstance:GetLevel():GetStartingRoomIndex()
      end)
      State.run.startRoomIndex = okStart and startRoomIndex or State.routeContext.roomIndex
      State.run.startRoomPrompt = recommendation ~= nil
    end
  end
  if LongTermProgress.canObserve(GameInstance) then
    LongTermProgress.observeRoom(State.settings, State.run, GameInstance)
  end
  Unlocks.observe(Catalog.goals, State.settings.observedCompleted, State.profileCompleted,
    "stage", GameInstance:GetLevel():GetStage(), nil, State.settings.achievementImport)
  Unlocks.observe(Catalog.goals, State.settings.observedCompleted, State.profileCompleted,
    "stage_type", GameInstance:GetLevel():GetStage(), GameInstance:GetLevel():GetStageType(),
    State.settings.achievementImport)
  syncCompletionTransitions()
  save()
  Mcm.setup(State, save)
end

function AchievementTracker:onUpdate()
  if not State.settings then return end
  local player = Isaac.GetPlayer(0)
  local runChanged = player and Sensors.update(State.run, player) or false
  for index = 0, GameInstance:GetNumPlayers() - 1 do
    if Sensors.observeBlueFlies(State.run, Isaac.GetPlayer(index)) then runChanged = true end
  end
  if runChanged then
    syncCompletionTransitions()
    save()
  end
  if Opportunities.updateRun(State.run, GameInstance) then save() end
  local second = math.floor(GameInstance.TimeCounter / 30)
  if second == State.lastEvaluation then return end
  State.lastEvaluation = second
  local completedTracking = syncCompletionTransitions()
  if #completedTracking > 0 then save() end
  if CharacterRelevance.updateSources(State.run, GameInstance) then save() end
  local routeContext = Routes.context(GameInstance, State.run)
  State.routeContext = routeContext
  if Routes.updateRun(State.run, routeContext, trackingTaintedUnlock()) then save() end
  State.sceneOpportunities = Opportunities.evaluate(GameInstance, State.run,
    State.profileCompleted, completionAllowed(), routeContext, victoryLapOpportunitiesAllowed())
  syncBossRushCompletion()
  for _, id in ipairs(Tracker.allIds(State.tracker)) do
    local goal = Catalog.get(id)
    if goal then
      local warning = Evaluator.evaluate(State.evaluator, goal, Sensors.snapshot(goal, State.run, GameInstance))
      if warning then
        warning.untilFrame = Isaac.GetFrameCount() + 240
        State.activeWarning = warning
        if warning.kind == "failed" or warning.kind == "expired" then
          State.run.failedGoals[goal.id] = true
          save()
        end
      end
    end
  end
end

function AchievementTracker:onPreUpdate()
  if State.settings and Menu.shouldPause(State, GameInstance) then return true end
end

function AchievementTracker:onPrePauseScreenRender()
  if State.settings and State.menu and State.menu.open then return false end
end

function AchievementTracker:onInputAction(entity, inputHook, buttonAction)
  if State.settings and Menu.shouldBlockInput(State, entity, inputHook, buttonAction) then
    if inputHook == InputHook.GET_ACTION_VALUE then return 0 end
    return false
  end
end

function AchievementTracker:onPostHudRender()
  if State.settings then Menu.render(State) end
end

local function showQuickTrackNotice(key)
  State.quickTrackNotice = { key=key, untilFrame=Isaac.GetFrameCount() + 240 }
end

local function quickTrackGoal(goalId)
  if Tracker.containsAny(State.tracker, goalId) then return false end
  if Tracker.slotCount(State.tracker) >= State.tracker.max then
    showQuickTrackNotice("trackerFull")
    return true
  end
  if Tracker.track(State.tracker, goalId) then
    save()
    return true
  end
  return false
end

local function conflictOptions()
  local context = State.routeContext or Routes.context(GameInstance, State.run)
  return {
    difficulty=CompletionMarks.difficultyValue(GameInstance),
    completionStore=State.settings.completionMarks,
    currentPlayers=context.players
  }
end

local function bestOrdinaryGoal()
  if not State.tracker.route then return nil end
  local relevanceContext = CharacterRelevance.buildContext(GameInstance, Catalog.goals, State.run)
  local bestCurrent, bestGeneral
  for _, goal in ipairs(Catalog.goals) do
    if Catalog.isCompletable(goal, Isaac.GetChallenge())
      and not isGoalCompleted(goal)
      and not Tracker.containsAny(State.tracker, goal.id)
      and Recommendations.priority(goal) ~= "discouraged"
      and not RouteRecommendations.conflicts(goal, State.tracker.route, conflictOptions()) then
      local route = Routes.evaluate(goal, State.routeContext,
        State.settings.completionMarks, "en")
      if not route or route.severity ~= "failed" then
        local relevance = CharacterRelevance.classify(goal, relevanceContext)
        local current = relevance == "current" and bestCurrent
          or relevance == "general" and bestGeneral or nil
        if relevance == "current" or relevance == "general" then
          if not current or Recommendations.rank(goal) > Recommendations.rank(current) then
            if relevance == "current" then bestCurrent = goal else bestGeneral = goal end
          end
        end
      end
    end
  end
  return bestCurrent or bestGeneral
end

local function updateQuickTrack()
  if State.menu.open then return end
  if not Input.IsButtonTriggered(Keyboard.KEY_V, 0) then return end
  for _, opportunity in ipairs(State.sceneOpportunities or {}) do
    local goal = opportunity.goalId and Catalog.get(opportunity.goalId) or nil
    if goal and not isGoalCompleted(goal)
      and not Tracker.containsAny(State.tracker, goal.id) then
      quickTrackGoal(goal.id)
      return
    end
  end
  if not State.run.startRoomPrompt then return end
  if not State.tracker.route and State.run.routeRecommendation then
    if Tracker.slotCount(State.tracker) >= State.tracker.max then
      showQuickTrackNotice("trackerFull")
    elseif Tracker.trackRoute(State.tracker, State.run.routeRecommendation) then
      State.run.trackedRoute = State.tracker.route
      save()
    end
    return
  end
  local ordinary = bestOrdinaryGoal()
  if ordinary then quickTrackGoal(ordinary.id) end
end

function AchievementTracker:onRender()
  if not State.settings then return end
  Menu.update(State, save)
  updateQuickTrack()
  if not State.menu.open then
    Hud.render(State)
    Hud.renderWarning(State)
  end
  if not ModCallbacks.MC_POST_HUD_RENDER then
    Menu.render(State)
  end
end

function AchievementTracker:onPickupUpdate(pickup)
  if not State.settings then return end
  if CharacterRelevance.updateSources(State.run, GameInstance) then
    State.lastEvaluation = -1
    save()
  end
  if Sensors.onPickupUpdate(State.run, pickup) then
    State.lastEvaluation = -1
    syncCompletionTransitions()
    save()
  end
  if LongTermProgress.canObserve(GameInstance)
    and LongTermProgress.observePickup(State.settings, State.run, pickup) then save() end
  if Routes.observePickup(State.run, pickup, GameInstance, trackingTaintedUnlock()) then save() end
  if Opportunities.observePickup(State.run, pickup, GameInstance) then
    State.lastEvaluation = -1
    save()
  end
end

function AchievementTracker:onUseItem(collectible, rng, player)
  if not State.settings then return end
  local changed = Opportunities.onUseItem(State.run, collectible)
  changed = Sensors.onUseItem(State.run, collectible, player, Isaac.GetFrameCount()) or changed
  if changed then
    State.lastEvaluation = -1
    syncCompletionTransitions()
    save()
  end
end

function AchievementTracker:onUsePill(pillEffect, player)
  if State.settings and Sensors.onUsePill(State.run, pillEffect, player, Isaac.GetFrameCount()) then
    State.lastEvaluation = -1
    syncCompletionTransitions()
    save()
  end
end

function AchievementTracker:onUseCard(card, player)
  if not State.settings then return end
  local changed = Sensors.onUseCard(State.run, card, player, Isaac.GetFrameCount())
  if LongTermProgress.canObserve(GameInstance) then
    changed = LongTermProgress.increment(State.settings, 196, 1) or changed
    local deathCard = Card and Card.CARD_DEATH or 13
    if card == deathCard then
      changed = LongTermProgress.increment(State.settings, 7, 1) or changed
    end
  end
  if changed then
    State.lastEvaluation = -1
    syncCompletionTransitions()
    save()
  end
end

local function observeAndSave(kind, value, variant)
  if not State.settings then return end
  if Unlocks.observe(Catalog.goals, State.settings.observedCompleted, State.profileCompleted,
    kind, value, variant, State.settings.achievementImport) then
    syncCompletionTransitions()
    save()
  end
end

function AchievementTracker:onPlayerInit(player)
  observeAndSave("player", player:GetPlayerType())
end

function AchievementTracker:onNewLevel()
  syncBossRushCompletion()
  local changed = refreshRouteFloor()
  if CharacterRelevance.updateSources(State.run, GameInstance) then changed = true end
  if changed then save() end
  observeAndSave("stage", GameInstance:GetLevel():GetStage())
  observeAndSave("stage_type", GameInstance:GetLevel():GetStage(), GameInstance:GetLevel():GetStageType())
end

function AchievementTracker:onNewRoom()
  State.completionNotices = {}
  syncBossRushCompletion()
  local changed = Opportunities.onNewRoom(State.run, GameInstance)
  if CharacterRelevance.updateSources(State.run, GameInstance) then changed = true end
  if LongTermProgress.canObserve(GameInstance)
    and LongTermProgress.observeRoom(State.settings, State.run, GameInstance) then changed = true end
  local roomIndex = GameInstance:GetLevel():GetCurrentRoomIndex()
  if State.run.startRoomPrompt and State.run.startRoomIndex ~= roomIndex then
    State.run.startRoomPrompt = false
    changed = true
  end
  State.lastEvaluation = -1
  if changed then save() end
end

function AchievementTracker:onNpcDeath(npc)
  local opportunityChanged = Opportunities.observeNpc(State.run, npc, GameInstance)
  State.lastEvaluation = -1
  if not npc:IsBoss() then return end
  local routeChanged = Routes.observeNpc(State.run, npc, GameInstance)
  local mark = Routes.markFromNpc(npc, GameInstance)
  if LongTermProgress.canObserve(GameInstance) then
    local eventByMark = { MOMS_HEART=1, ISAAC=11, SATAN=13, HUSH=158 }
    local eventId = eventByMark[mark]
    if not eventId and EntityType and EntityType.ENTITY_BABY_PLUM
      and npc.Type == EntityType.ENTITY_BABY_PLUM then eventId = 493 end
    if eventId then LongTermProgress.increment(State.settings, eventId, 1) end
  end
  observeAndSave("boss", npc.Type, npc.Variant)
  recordCompletionMark(mark)
  if opportunityChanged or routeChanged or (LongTermProgress.canObserve(GameInstance)
    and (mark == "MOMS_HEART" or mark == "ISAAC" or mark == "SATAN" or mark == "HUSH"
      or (EntityType and EntityType.ENTITY_BABY_PLUM
        and npc.Type == EntityType.ENTITY_BABY_PLUM))) then save() end
end

function AchievementTracker:onAchievementUnlocked(achievementId)
  if not State.settings then return end
  local importedChanged = Unlocks.recordImportedAchievement(Catalog.goals,
    State.settings.achievementImport, achievementId)
  State.profileCompleted = Unlocks.scan(Catalog.goals, State.settings.observedCompleted,
    State.settings.achievementImport)
  CompletionMarks.infer(Catalog.goals, State.profileCompleted, State.settings.completionMarks)
  refreshCompletionFromMarks()
  State.lastEvaluation = -1
  local removed = syncCompletionTransitions()
  if importedChanged or #removed > 0 then save() end
end

function AchievementTracker:onExit(shouldSave)
  -- MC_PRE_GAME_EXIT's flag is not consistent across every way of leaving a
  -- run. Always persist our seed-bound run state; a different seed is reset on
  -- the next MC_POST_GAME_STARTED.
  save()
end

AchievementTracker:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, AchievementTracker.onGameStarted)
AchievementTracker:AddCallback(ModCallbacks.MC_POST_UPDATE, AchievementTracker.onUpdate)
AchievementTracker:AddCallback(ModCallbacks.MC_POST_RENDER, AchievementTracker.onRender)
AchievementTracker:AddCallback(ModCallbacks.MC_POST_PICKUP_UPDATE, AchievementTracker.onPickupUpdate)
AchievementTracker:AddCallback(ModCallbacks.MC_USE_ITEM, AchievementTracker.onUseItem)
AchievementTracker:AddCallback(ModCallbacks.MC_USE_PILL, AchievementTracker.onUsePill)
AchievementTracker:AddCallback(ModCallbacks.MC_USE_CARD, AchievementTracker.onUseCard)
AchievementTracker:AddCallback(ModCallbacks.MC_POST_PLAYER_INIT, AchievementTracker.onPlayerInit)
AchievementTracker:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, AchievementTracker.onNewRoom)
AchievementTracker:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, AchievementTracker.onNewLevel)
AchievementTracker:AddCallback(ModCallbacks.MC_POST_NPC_DEATH, AchievementTracker.onNpcDeath)
AchievementTracker:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, AchievementTracker.onExit)
AchievementTracker:AddCallback(ModCallbacks.MC_INPUT_ACTION, AchievementTracker.onInputAction)
if ModCallbacks.MC_POST_ACHIEVEMENT_UNLOCK then
  AchievementTracker:AddCallback(ModCallbacks.MC_POST_ACHIEVEMENT_UNLOCK,
    AchievementTracker.onAchievementUnlocked)
end
-- MC_PRE_UPDATE is provided by REPENTOGON. Vanilla Repentance keeps the menu
-- usable in real time instead of turning the script extender into a hard dependency.
if ModCallbacks.MC_PRE_UPDATE then
  AchievementTracker:AddCallback(ModCallbacks.MC_PRE_UPDATE, AchievementTracker.onPreUpdate)
end
if ModCallbacks.MC_PRE_PAUSE_SCREEN_RENDER then
  AchievementTracker:AddCallback(ModCallbacks.MC_PRE_PAUSE_SCREEN_RENDER,
    AchievementTracker.onPrePauseScreenRender)
end
if ModCallbacks.MC_POST_HUD_RENDER then
  AchievementTracker:AddCallback(ModCallbacks.MC_POST_HUD_RENDER,
    AchievementTracker.onPostHudRender)
end

return AchievementTracker
