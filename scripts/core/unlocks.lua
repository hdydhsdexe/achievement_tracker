local Rewards = require("scripts.core.rewards")
local Unlocks = {}
local MAX_ACHIEVEMENT_COUNT = 16384
local importCache = setmetatable({}, { __mode = "k" })

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

local function isInteger(value)
  return type(value) == "number" and value == math.floor(value)
end

local function importedAchievements(snapshot)
  if type(snapshot) ~= "table" then return nil end
  local cached = importCache[snapshot]
  if cached then return cached.unlocked, cached.achievementCount end
  local function invalid()
    importCache[snapshot] = {}
    return nil
  end
  if snapshot.formatVersion ~= 1 then return invalid() end
  if not isInteger(snapshot.saveSlot) or snapshot.saveSlot < 1 or snapshot.saveSlot > 3 then return invalid() end
  if not isInteger(snapshot.achievementCount) or snapshot.achievementCount <= 0
    or snapshot.achievementCount > MAX_ACHIEVEMENT_COUNT then return invalid() end
  if type(snapshot.unlockedIds) ~= "table" then return invalid() end

  local unlocked = {}
  local entryCount = 0
  local maxIndex = 0
  for index, id in pairs(snapshot.unlockedIds) do
    if not isInteger(index) or index < 1 then return invalid() end
    if not isInteger(id) or id < 1 or id >= snapshot.achievementCount then return invalid() end
    if entryCount >= snapshot.achievementCount - 1 then return invalid() end
    entryCount = entryCount + 1
    maxIndex = math.max(maxIndex, index)
    unlocked[id] = true
  end
  if maxIndex ~= entryCount then return invalid() end
  local result = { unlocked=unlocked, achievementCount=snapshot.achievementCount }
  importCache[snapshot] = result
  return result.unlocked, result.achievementCount
end

function Unlocks.scan(goals, observedCompleted, achievementImport)
  local completed = {}
  for id, value in pairs(observedCompleted or {}) do
    if value == true then completed[id] = true end
  end
  local importedUnlocked, achievementCount = importedAchievements(achievementImport)
  for _, goal in ipairs(goals) do
    local achievementId = goal.achievementId
    if importedUnlocked and isInteger(achievementId)
      and achievementId >= 1 and achievementId < achievementCount then
      if importedUnlocked[achievementId] then
        completed[goal.id] = true
      else
        completed[goal.id] = nil
      end
    elseif Unlocks.isCompleted(goal) then
      completed[goal.id] = true
    end
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

function Unlocks.observe(goals, observedCompleted, profileCompleted,
  kind, value, variant, achievementImport)
  local changed = false
  local _, achievementCount = importedAchievements(achievementImport)
  for _, goal in ipairs(goals) do
    local achievementId = goal.achievementId
    local importedAuthoritative = achievementCount and isInteger(achievementId)
      and achievementId >= 1 and achievementId < achievementCount
    if not importedAuthoritative and not observedCompleted[goal.id]
      and matches(goal.observation, kind, value, variant) then
      observedCompleted[goal.id] = true
      profileCompleted[goal.id] = true
      changed = true
    end
  end
  return changed
end

return Unlocks
