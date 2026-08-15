local AchievementTracker = RegisterMod("Achievement Tracker", 1)
local GameInstance = Game()

local Catalog = require("scripts.data.goals")
local Evaluator = require("scripts.core.evaluator")
local Hud = require("scripts.ui.hud")
local Mcm = require("scripts.integrations.mcm")
local Menu = require("scripts.ui.menu")
local Sensors = require("scripts.core.sensors")
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
  profileCompleted = {}
}

local function save()
  if not State.settings then return end
  State.settings.tracked = State.tracker.ids
  State.settings.activeRun = State.run
  Storage.save(AchievementTracker, State.settings)
end

local function load()
  State.settings = Storage.load(AchievementTracker)
  State.tracker = Tracker.new(State.settings.maxTracked, State.settings.tracked)
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
  local player = Isaac.GetPlayer(0)
  if player then Sensors.initialize(State.run, player) end
  State.profileCompleted = Unlocks.scan(Catalog.goals, State.settings.observedCompleted,
    State.settings.achievementImport)
  for index = 0, GameInstance:GetNumPlayers() - 1 do
    local currentPlayer = Isaac.GetPlayer(index)
    Unlocks.observe(Catalog.goals, State.settings.observedCompleted, State.profileCompleted,
      "player", currentPlayer:GetPlayerType(), nil, State.settings.achievementImport)
  end
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
  observeAndSave("stage", GameInstance:GetLevel():GetStage())
  observeAndSave("stage_type", GameInstance:GetLevel():GetStage(), GameInstance:GetLevel():GetStageType())
end

function AchievementTracker:onNpcInit(npc)
  if npc:IsBoss() then observeAndSave("boss", npc.Type, npc.Variant) end
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
AchievementTracker:AddCallback(ModCallbacks.MC_POST_NPC_INIT, AchievementTracker.onNpcInit)
AchievementTracker:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, AchievementTracker.onExit)
AchievementTracker:AddCallback(ModCallbacks.MC_INPUT_ACTION, AchievementTracker.onInputAction)
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
