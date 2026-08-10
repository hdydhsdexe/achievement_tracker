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
  State.profileCompleted = Unlocks.scan(Catalog.goals)
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

function AchievementTracker:onUsePill(pillEffect)
  if State.settings then Sensors.onUsePill(State.run, pillEffect) end
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
AchievementTracker:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, AchievementTracker.onExit)

return AchievementTracker
