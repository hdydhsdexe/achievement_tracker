local Rewards = require("scripts.core.rewards")
local Unlocks = {}

local function rewardAvailable(reward)
  local entry = Rewards.config(reward)
  if not entry or not entry.IsAvailable then return nil end
  return entry:IsAvailable()
end

function Unlocks.isCompleted(goal)
  local reward = goal and goal.reward
  if not reward then return nil end
  local ok, available = pcall(rewardAvailable, reward)
  return ok and available == true or nil
end

function Unlocks.scan(goals, observedCompleted)
  local completed = {}
  for id, value in pairs(observedCompleted or {}) do
    if value == true then completed[id] = true end
  end
  for _, goal in ipairs(goals) do
    if Unlocks.isCompleted(goal) then completed[goal.id] = true end
  end
  return completed
end

local function matches(observation, kind, value, variant)
  if not observation or observation.kind ~= kind then return false end
  for _, expected in ipairs(observation.values or {}) do
    if kind == "boss" or kind == "stage_type" then
      if expected[1] == value and (expected[2] == nil or expected[2] == variant) then return true end
    elseif expected == value then
      return true
    end
  end
  return false
end

function Unlocks.observe(goals, observedCompleted, profileCompleted, kind, value, variant)
  local changed = false
  for _, goal in ipairs(goals) do
    if not observedCompleted[goal.id] and matches(goal.observation, kind, value, variant) then
      observedCompleted[goal.id] = true
      profileCompleted[goal.id] = true
      changed = true
    end
  end
  return changed
end

return Unlocks
