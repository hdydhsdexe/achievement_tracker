local Sensors = {}

local PILLEFFECT_ONE_MAKES_YOU_LARGER = PillEffect and PillEffect.PILLEFFECT_LARGER or 32
local PILLEFFECT_GULP = PillEffect and PillEffect.PILLEFFECT_GULP or 43
local CARD_STRENGTH = Card and Card.CARD_STRENGTH or 12
local COLLECTIBLE_MAGIC_MUSHROOM = CollectibleType and CollectibleType.COLLECTIBLE_MAGIC_MUSHROOM or 12
local COLLECTIBLE_PLACEBO = CollectibleType and CollectibleType.COLLECTIBLE_PLACEBO or 348
local COLLECTIBLE_BLANK_CARD = CollectibleType and CollectibleType.COLLECTIBLE_BLANK_CARD or 286

local function playerUseKey(player)
  if not player then return "unknown" end
  if player.InitSeed ~= nil then return tostring(player.InitSeed) end
  if player.GetPlayerType then return tostring(player:GetPlayerType()) end
  return "unknown"
end

local function incrementProgress(run, progressKey, goalId, frameCount, sourceKey)
  Sensors.normalizeRun(run)
  local useKey = table.concat({ tostring(frameCount or Isaac.GetFrameCount()),
    tostring(sourceKey or "unknown") }, ":")
  if run.progressUseKeys[progressKey] == useKey then return false end
  run.progressUseKeys[progressKey] = useKey
  run.progress[progressKey] = run.progress[progressKey] + 1
  if run.progress[progressKey] >= 5 then
    if progressKey == "gulp" then
      run.completedGoals.achievement_386 = true
    elseif progressKey == "growth" then
      run.completedGoals.achievement_361 = true
    else
      run.completedGoals[goalId] = true
    end
  end
  return true
end

local function pocketPillEffect(player)
  if not player or not player.GetPill then return nil end
  local color = player:GetPill(0)
  if not color or color == 0 then return nil end
  local pool = Game():GetItemPool()
  return pool and pool:GetPillEffect(color, player) or nil
end

function Sensors.newRun(startSeed)
  return { startSeed=startSeed, disqualified={}, observedPickups={}, failedGoals={},
    completedGoals={}, progress={ items=0, growth=0, gulp=0 }, progressUseKeys={},
    routeItems={}, routeEvents={}, routeFloor=nil, routeFloorAids={},
    routeRecommendation=nil, trackedRoute=nil, startRoomPrompt=true, startRoomIndex=nil,
    pendingRouteExtension=nil, routeBosses={},
    characterSources={ ground={}, historical={}, floor=nil },
    longTermObservedPickups={}, longTermObservedRooms={} }
end

function Sensors.normalizeRun(run)
  run.disqualified = run.disqualified or {}
  run.observedPickups = run.observedPickups or {}
  run.failedGoals = run.failedGoals or {}
  run.completedGoals = run.completedGoals or {}
  run.progress = run.progress or {}
  run.routeItems = run.routeItems or {}
  run.routeEvents = run.routeEvents or {}
  run.routeFloorAids = type(run.routeFloorAids) == "table" and run.routeFloorAids or {}
  run.routeRecommendation = type(run.routeRecommendation) == "table"
    and run.routeRecommendation or nil
  run.trackedRoute = type(run.trackedRoute) == "table" and run.trackedRoute or nil
  run.pendingRouteExtension = type(run.pendingRouteExtension) == "table"
    and run.pendingRouteExtension or nil
  run.routeBosses = type(run.routeBosses) == "table" and run.routeBosses or {}
  if run.startRoomPrompt == nil then run.startRoomPrompt = false end
  run.characterSources = run.characterSources or { ground={}, historical={}, floor=nil }
  run.characterSources.ground = run.characterSources.ground or {}
  run.characterSources.historical = run.characterSources.historical or {}
  run.progressUseKeys = run.progressUseKeys or {}
  run.longTermObservedPickups = run.longTermObservedPickups or {}
  run.longTermObservedRooms = run.longTermObservedRooms or {}
  run.progress.gulp = tonumber(run.progress.gulp) or 0
  run.progress.growth = tonumber(run.progress.growth) or 0
  run.progress.items = tonumber(run.progress.items) or 0
  return run
end

function Sensors.initialize(run, player)
  -- Reserved for sensors which need a start-of-run player snapshot.
end

function Sensors.update(run, player)
  Sensors.normalizeRun(run)
  if player.GetCollectibleCount then
    local previous = run.progress.items
    run.progress.items = math.max(run.progress.items, player:GetCollectibleCount())
    if run.progress.items >= 50 then run.completedGoals.achievement_330 = true end
    return run.progress.items ~= previous
  end
  return false
end

function Sensors.observeBlueFlies(run, player)
  Sensors.normalizeRun(run)
  if run.completedGoals.achievement_388 then return false end
  if player and player.GetNumBlueFlies and player:GetNumBlueFlies() >= 20 then
    run.completedGoals.achievement_388 = true
    return true
  end
  return false
end

function Sensors.onUsePill(run, pillEffect, player, frameCount)
  Sensors.normalizeRun(run)
  if pillEffect == PILLEFFECT_GULP then
    return incrementProgress(run, "gulp", "achievement_386", frameCount, playerUseKey(player))
  end
  if pillEffect == PILLEFFECT_ONE_MAKES_YOU_LARGER then
    return incrementProgress(run, "growth", "achievement_361", frameCount, playerUseKey(player))
  end
  return false
end

function Sensors.onUseCard(run, card, player, frameCount)
  if card ~= CARD_STRENGTH then return false end
  return incrementProgress(run, "growth", "achievement_361", frameCount, playerUseKey(player))
end

function Sensors.onUseItem(run, collectible, player, frameCount)
  if collectible == COLLECTIBLE_PLACEBO then
    local effect = pocketPillEffect(player)
    if effect == PILLEFFECT_GULP then
      return incrementProgress(run, "gulp", "achievement_386", frameCount, playerUseKey(player))
    end
    if effect == PILLEFFECT_ONE_MAKES_YOU_LARGER then
      return incrementProgress(run, "growth", "achievement_361", frameCount, playerUseKey(player))
    end
  elseif collectible == COLLECTIBLE_BLANK_CARD and player and player.GetCard
    and player:GetCard(0) == CARD_STRENGTH then
    return incrementProgress(run, "growth", "achievement_361", frameCount, playerUseKey(player))
  end
  return false
end

function Sensors.progress(goal, run)
  Sensors.normalizeRun(run)
  if not goal.progressKey or not goal.target then return nil end
  return math.min(goal.target, math.max(0, tonumber(run.progress[goal.progressKey]) or 0)), goal.target
end

function Sensors.onPickupUpdate(run, pickup)
  local sprite = pickup:GetSprite()
  if not sprite:IsPlaying("Collect") then return false end
  Sensors.normalizeRun(run)
  -- InitSeed can be a very large integer. Numeric keys make the game's JSON
  -- encoder treat this table as a gigantic sparse array and exhaust memory.
  local seed = tostring(pickup.InitSeed)
  if run.observedPickups[seed] then return false end
  run.observedPickups[seed] = true
  local changed = false
  if pickup.Variant == PickupVariant.PICKUP_HEART and not run.disqualified.heart then
    run.disqualified.heart, changed = true, true
  end
  if pickup.Variant == PickupVariant.PICKUP_COIN and not run.disqualified.coin then
    run.disqualified.coin, changed = true, true
  end
  if pickup.Variant == PickupVariant.PICKUP_BOMB and not run.disqualified.bomb then
    run.disqualified.bomb, changed = true, true
  end
  if pickup.Variant == PickupVariant.PICKUP_COLLECTIBLE
    and pickup.SubType == COLLECTIBLE_MAGIC_MUSHROOM then
    local sourceKey = table.concat({ "pickup", seed, tostring(pickup.Index or "") }, ":")
    changed = incrementProgress(run, "growth", "achievement_361", Isaac.GetFrameCount(),
      sourceKey) or changed
  end
  return changed
end

function Sensors.snapshot(goal, run, game)
  local snapshot = { elapsed = math.floor(game.TimeCounter / 30), eligible = true }
  if goal.sensor == "no_pickups" then
    for _, reason in ipairs({"heart", "coin", "bomb"}) do
      if run.disqualified[reason] then snapshot.eligible=false; snapshot.reason=reason; break end
    end
  end
  return snapshot
end

return Sensors
