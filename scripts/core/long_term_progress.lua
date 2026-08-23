local CompletionMarks = require("scripts.core.completion_marks")
local LongTermProgress = {}

local MAX_COUNTER = 4294967295

local function integer(value)
  value = tonumber(value)
  if not value or value < 0 or value ~= math.floor(value) then return nil end
  return math.min(value, MAX_COUNTER)
end

local function persistentGameData()
  if not Isaac or type(Isaac.GetPersistentGameData) ~= "function" then return nil end
  local ok, data = pcall(Isaac.GetPersistentGameData)
  if not ok or not data then return nil end
  local okMethod, method = pcall(function() return data.GetEventCounter end)
  if not okMethod or type(method) ~= "function" then return nil end
  return data
end

local function nativeEvent(data, eventId)
  local ok, value = pcall(function() return data:GetEventCounter(eventId) end)
  return ok and integer(value) or nil
end

local function aggregateEventIds(source, read)
  local total, available = 0, 0
  for _, eventId in ipairs(source.eventIds or {}) do
    local value = read(eventId)
    if value ~= nil then total, available = total + value, available + 1 end
  end
  if available == 0 then return nil end
  if source.aggregate ~= "sum" and available ~= #(source.eventIds or {}) then return nil end
  return total
end

local function importedEvent(settings, eventId)
  local snapshot = settings and settings.progressImport
  if type(snapshot) ~= "table" or snapshot.formatVersion ~= 1
    or type(snapshot.values) ~= "table" then return nil end
  if eventId < 0 or eventId >= (tonumber(snapshot.eventCounterCount) or 0) then return nil end
  return integer(snapshot.values[eventId + 1])
end

local function observedEvent(settings, eventId)
  local counters = settings and settings.progressObserved
    and settings.progressObserved.eventCounters
  return integer(type(counters) == "table" and counters[tostring(eventId)] or nil) or 0
end

local function countCompletionMarks(source, settings)
  local count = 0
  for _, playerType in ipairs(source.playerTypes or {}) do
    if CompletionMarks.get(settings and settings.completionMarks, playerType, source.mark) > 0 then
      count = count + 1
    end
  end
  return count
end

local function importedAchievementsAvailable(settings)
  local snapshot = settings and settings.achievementImport
  return type(snapshot) == "table" and snapshot.formatVersion == 1
    and tonumber(snapshot.achievementCount) and snapshot.achievementCount > 0
end

local function completionMarkProgress(source, state)
  local value = countCompletionMarks(source, state.settings)
  if Isaac and type(Isaac.GetCompletionMarks) == "function" then return value, "native" end
  if importedAchievementsAvailable(state.settings) then return value, "imported" end
  if value > 0 then return value, "observed" end
  return nil, "unavailable"
end

local function isCompleted(goal, state)
  return (state.profileCompleted and state.profileCompleted[goal.id])
    or (state.run and state.run.completedGoals and state.run.completedGoals[goal.id])
    or CompletionMarks.isSatisfied(goal, state.settings and state.settings.completionMarks)
end

function LongTermProgress.resolve(goal, state)
  local metadata = goal and goal.longTerm
  if not metadata or not metadata.source or not state or not state.settings then return nil end
  local target = metadata.target
  if isCompleted(goal, state) then return {value=target, target=target, source="completed"} end

  local source = metadata.source
  if source.kind == "completion_mark_count" then
    local value, origin = completionMarkProgress(source, state)
    return {value=value and math.min(value, target) or nil, target=target, source=origin}
  end

  local nativeData = persistentGameData()
  if nativeData then
    local value = aggregateEventIds(source, function(eventId) return nativeEvent(nativeData, eventId) end)
    if value ~= nil then return {value=math.min(value, target), target=target, source="native"} end
  end

  local imported = aggregateEventIds(source, function(eventId)
    return importedEvent(state.settings, eventId)
  end)
  local observed = aggregateEventIds(source, function(eventId)
    return observedEvent(state.settings, eventId)
  end) or 0
  if imported ~= nil then
    local value = imported + (source.observable and observed or 0)
    return {value=math.min(value, target), target=target,
      source=source.observable and "live" or "imported"}
  end
  if source.observable and observed > 0 then
    return {value=math.min(observed, target), target=target, source="observed"}
  end
  return {value=nil, target=target, source="unavailable"}
end

function LongTermProgress.format(goal, state, language)
  local progress = LongTermProgress.resolve(goal, state)
  if not progress then return nil end
  local value = progress.value
  if progress.source == "unavailable" or value == nil then
    return language == "zh" and "（进度不可用）" or " (progress unavailable)"
  end
  local ratio = string.format("%d/%d", value, progress.target)
  if progress.source == "imported" then
    return language == "zh" and ("（截至导入 " .. ratio .. "）")
      or (" (as imported " .. ratio .. ")")
  end
  if progress.source == "observed" then
    return language == "zh" and ("（已记录 ≥" .. ratio .. "）")
      or (" (recorded ≥" .. ratio .. ")")
  end
  return language == "zh" and ("（" .. ratio .. "）") or (" (" .. ratio .. ")")
end

function LongTermProgress.canObserve(game)
  if persistentGameData() then return false end
  if Isaac and type(Isaac.GetChallenge) == "function" and Isaac.GetChallenge() ~= 0 then return false end
  if game and game.AchievementUnlocksDisallowed then
    local ok, disallowed = pcall(function() return game:AchievementUnlocksDisallowed() end)
    if ok and disallowed then return false end
  end
  return true
end

function LongTermProgress.increment(settings, eventId, amount)
  eventId, amount = integer(eventId), integer(amount or 1)
  if not settings or eventId == nil or not amount or amount <= 0 then return false end
  settings.progressObserved = type(settings.progressObserved) == "table"
    and settings.progressObserved or {eventCounters={}}
  settings.progressObserved.eventCounters = type(settings.progressObserved.eventCounters) == "table"
    and settings.progressObserved.eventCounters or {}
  local key = tostring(eventId)
  local previous = integer(settings.progressObserved.eventCounters[key]) or 0
  settings.progressObserved.eventCounters[key] = math.min(MAX_COUNTER, previous + amount)
  return true
end

function LongTermProgress.observePickup(settings, run, pickup)
  if not settings or not run or not pickup or not pickup.GetSprite
    or not pickup:GetSprite():IsPlaying("Collect") then return false end
  run.longTermObservedPickups = run.longTermObservedPickups or {}
  local seed = tostring(pickup.InitSeed)
  if run.longTermObservedPickups[seed] then return false end
  local eventId
  if PickupVariant and pickup.Variant == PickupVariant.PICKUP_LIL_BATTERY then
    eventId = 195
  elseif PickupVariant and pickup.Variant == PickupVariant.PICKUP_COLLECTIBLE then
    if pickup.SubType == 15 then eventId = 200 end
    if pickup.SubType == 221 then eventId = 201 end
  end
  if not eventId then return false end
  run.longTermObservedPickups[seed] = true
  return LongTermProgress.increment(settings, eventId, 1)
end

function LongTermProgress.observeRoom(settings, run, game)
  if not settings or not run or not game then return false end
  local room = game:GetRoom()
  if not RoomType or room:GetType() ~= RoomType.ROOM_ARCADE then return false end
  local desc = game:GetLevel():GetCurrentRoomDesc()
  local seed = desc and desc.SpawnSeed
  local key = tostring(seed or game:GetLevel():GetCurrentRoomIndex())
  run.longTermObservedRooms = run.longTermObservedRooms or {}
  if run.longTermObservedRooms[key] then return false end
  run.longTermObservedRooms[key] = true
  return LongTermProgress.increment(settings, 9, 1)
end

return LongTermProgress
