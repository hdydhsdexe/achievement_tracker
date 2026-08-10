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

local State = {
  settings = nil,
  tracker = nil,
  evaluator = Evaluator.new(),
  run = Sensors.newRun(),
  menu = Menu.new(),
  activeWarning = nil,
  lastEvaluation = -1
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
  if isContinued and type(State.settings.activeRun) == "table" then
    State.run = State.settings.activeRun
    State.run.disqualified = State.run.disqualified or {}
    State.run.observedPickups = State.run.observedPickups or {}
  else
    State.run = Sensors.newRun()
  end
  Evaluator.reset(State.evaluator)
  State.activeWarning = nil
  local player = Isaac.GetPlayer(0)
  if player then Sensors.initialize(State.run, player) end
  if not isContinued then save() end
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
      if warning then warning.untilFrame = Isaac.GetFrameCount() + 240; State.activeWarning = warning end
    end
  end
end

function AchievementTracker:onRender()
  if not State.settings then return end
  Menu.update(State, save)
  Hud.render(State)
  Hud.renderWarning(State)
  Menu.render(State)
end

function AchievementTracker:onPickupUpdate(pickup)
  if State.settings then Sensors.onPickupUpdate(State.run, pickup) end
end

function AchievementTracker:onExit(shouldSave)
  if shouldSave then save() end
end

AchievementTracker:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, AchievementTracker.onGameStarted)
AchievementTracker:AddCallback(ModCallbacks.MC_POST_UPDATE, AchievementTracker.onUpdate)
AchievementTracker:AddCallback(ModCallbacks.MC_POST_RENDER, AchievementTracker.onRender)
AchievementTracker:AddCallback(ModCallbacks.MC_POST_PICKUP_UPDATE, AchievementTracker.onPickupUpdate)
AchievementTracker:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, AchievementTracker.onExit)

return AchievementTracker
