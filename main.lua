local AchievementTracker = RegisterMod("Achievement Tracker", 1)
local GameInstance = Game()

local Catalog = require("scripts.data.goals")
local CharacterRelevance = require("scripts.core.character_relevance")
local CompletionMarks = require("scripts.core.completion_marks")
local Evaluator = require("scripts.core.evaluator")
local Hud = require("scripts.ui.hud")
local Mcm = require("scripts.integrations.mcm")
local Menu = require("scripts.ui.menu")
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
  routeContext = nil
}

local function save()
  if not State.settings then return end
  State.settings.tracked = State.tracker.ids
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

local function completionAllowed()
  if GameInstance:GetChallenge() ~= 0 then return false end
  if GameInstance.AchievementUnlocksDisallowed then
    local ok, disallowed = pcall(function() return GameInstance:AchievementUnlocksDisallowed() end)
    if ok and disallowed then return false end
  end
  return true
end

local function recordCompletionMark(mark)
  if not mark or not completionAllowed() then return false end
  local changed = false
  local value = CompletionMarks.difficultyValue(GameInstance)
  for index = 0, GameInstance:GetNumPlayers() - 1 do
    local playerType = CharacterRelevance.normalize(Isaac.GetPlayer(index):GetPlayerType())
    changed = CompletionMarks.merge(State.settings.completionMarks, playerType, mark, value) or changed
  end
  if changed then refreshCompletionFromMarks(); save() end
  return changed
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
  if reset then Routes.resetAttempt(State.run) end
  State.run.routeFloor = current
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
  Evaluator.reset(State.evaluator)
  State.activeWarning = nil
  State.lastEvaluation = -1
  State.routeContext = nil
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
  Unlocks.observe(Catalog.goals, State.settings.observedCompleted, State.profileCompleted,
    "stage", GameInstance:GetLevel():GetStage(), nil, State.settings.achievementImport)
  Unlocks.observe(Catalog.goals, State.settings.observedCompleted, State.profileCompleted,
    "stage_type", GameInstance:GetLevel():GetStage(), GameInstance:GetLevel():GetStageType(),
    State.settings.achievementImport)
  save()
  Mcm.setup(State, save)
end

function AchievementTracker:onUpdate()
  if not State.settings then return end
  local player = Isaac.GetPlayer(0)
  if player then Sensors.update(State.run, player) end
  local second = math.floor(GameInstance.TimeCounter / 30)
  if second == State.lastEvaluation then return end
  State.lastEvaluation = second
  local routeContext = Routes.context(GameInstance, State.run)
  State.routeContext = routeContext
  if Routes.updateRun(State.run, routeContext) then save() end
  local room = GameInstance:GetRoom()
  if room:GetType() == RoomType.ROOM_BOSSRUSH and room.IsAmbushDone and room:IsAmbushDone() then
    recordCompletionMark("BOSS_RUSH")
  end
  for _, id in ipairs(State.tracker.ids) do
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

function AchievementTracker:onRender()
  if not State.settings then return end
  Menu.update(State, save)
  if not State.menu.open then
    Hud.render(State)
    Hud.renderWarning(State)
  end
  if not ModCallbacks.MC_POST_HUD_RENDER then
    Menu.render(State)
  end
end

function AchievementTracker:onPickupUpdate(pickup)
  if State.settings then Sensors.onPickupUpdate(State.run, pickup) end
end

function AchievementTracker:onUsePill(pillEffect)
  if State.settings then Sensors.onUsePill(State.run, pillEffect) end
end

local function observeAndSave(kind, value, variant)
  if not State.settings then return end
  if Unlocks.observe(Catalog.goals, State.settings.observedCompleted, State.profileCompleted,
    kind, value, variant, State.settings.achievementImport) then save() end
end

function AchievementTracker:onPlayerInit(player)
  observeAndSave("player", player:GetPlayerType())
end

function AchievementTracker:onNewLevel()
  refreshRouteFloor()
  observeAndSave("stage", GameInstance:GetLevel():GetStage())
  observeAndSave("stage_type", GameInstance:GetLevel():GetStage(), GameInstance:GetLevel():GetStageType())
end

function AchievementTracker:onNpcDeath(npc)
  if not npc:IsBoss() then return end
  local routeChanged = Routes.observeNpc(State.run, npc, GameInstance)
  observeAndSave("boss", npc.Type, npc.Variant)
  recordCompletionMark(Routes.markFromNpc(npc, GameInstance))
  if routeChanged then save() end
end

function AchievementTracker:onAchievementUnlocked(achievementId)
  if not State.settings then return end
  if Unlocks.recordImportedAchievement(Catalog.goals, State.settings.achievementImport,
    achievementId) then
    State.profileCompleted = Unlocks.scan(Catalog.goals, State.settings.observedCompleted,
      State.settings.achievementImport)
    CompletionMarks.infer(Catalog.goals, State.profileCompleted, State.settings.completionMarks)
    refreshCompletionFromMarks()
    save()
  end
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
AchievementTracker:AddCallback(ModCallbacks.MC_USE_PILL, AchievementTracker.onUsePill)
AchievementTracker:AddCallback(ModCallbacks.MC_POST_PLAYER_INIT, AchievementTracker.onPlayerInit)
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
