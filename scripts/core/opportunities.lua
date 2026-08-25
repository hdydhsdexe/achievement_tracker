local Catalog = require("scripts.data.goals")
local CharacterRelevance = require("scripts.core.character_relevance")
local Opportunities = {}

local function enum(source, name, fallback)
  return source and source[name] or fallback
end

local ENTITY_BABY_PLUM = enum(EntityType, "ENTITY_BABY_PLUM", 908)
local ENTITY_SIREN = enum(EntityType, "ENTITY_SIREN", 904)
local SIREN_SKULL_VARIANT = 1
local ENTITY_HORNFEL = enum(EntityType, "ENTITY_HORNFEL", 906)
local ENTITY_MINECART = enum(EntityType, "ENTITY_MINECART", 965)
local ENTITY_MOM = enum(EntityType, "ENTITY_MOM", 45)
local ENTITY_MOMS_HEART = enum(EntityType, "ENTITY_MOMS_HEART", 78)
local ENTITY_SLOT = enum(EntityType, "ENTITY_SLOT", 6)
local BATTERY_BUM = enum(SlotVariant, "BATTERY_BUM", 13)
local ROOM_SACRIFICE = enum(RoomType, "ROOM_SACRIFICE", 13)
local ROOM_BOSS = enum(RoomType, "ROOM_BOSS", 5)
local ROOM_BOSSRUSH = enum(RoomType, "ROOM_BOSSRUSH", 17)
local STAGE_BASEMENT1 = enum(LevelStage, "STAGE1_1", 1)
local STAGE_DARK_ROOM = enum(LevelStage, "STAGE6", 11)
local STAGE_HOME = enum(LevelStage, "STAGE8", 13)
local STAGE_ORIGINAL = enum(StageType, "STAGETYPE_ORIGINAL", 0)

local COLLECTIBLE_BIBLE = enum(CollectibleType, "COLLECTIBLE_BIBLE", 33)
local COLLECTIBLE_TELEPATHY = enum(CollectibleType, "COLLECTIBLE_TELEPATHY_BOOK", 192)
local COLLECTIBLE_BLANK_CARD = enum(CollectibleType, "COLLECTIBLE_BLANK_CARD", 286)
local COLLECTIBLE_PANDORAS_BOX = enum(CollectibleType, "COLLECTIBLE_PANDORAS_BOX", 297)
local COLLECTIBLE_BROKEN_SHOVEL = enum(CollectibleType, "COLLECTIBLE_BROKEN_SHOVEL", 550)
local COLLECTIBLE_MOMS_SHOVEL = enum(CollectibleType, "COLLECTIBLE_MOMS_SHOVEL", 552)
local TRINKET_MISSING_POSTER = enum(TrinketType, "TRINKET_MISSING_POSTER", 23)
local CARD_MAGICIAN = enum(Card, "CARD_MAGICIAN", 2)
local CARD_SUN = enum(Card, "CARD_SUN", 5)
local TEAR_HOMING = enum(TearFlags, "TEAR_HOMING", 1 << 2)

local function message(zh, en)
  return { zh=zh, en=en }
end

local COPY = {
  plum=message("尝试坚持30秒不攻击糖梅宝宝，让她逃跑！",
    "Try not to attack Baby Plum for 30 seconds so she escapes!"),
  siren=message("尝试炸毁海妖留下的头骨！",
    "Try bombing the skull left behind by The Siren!"),
  hornfel=message("尝试在矿车破裂后立刻击杀矿山鬼，别让它逃跑！",
    "Try killing Hornfel as soon as the minecart breaks; do not let him escape!"),
  hornfelUrgent=message("尝试立刻击杀矿山鬼，别让它逃跑！",
    "Try killing Hornfel now; do not let him escape!"),
  lost=message("尝试持有寻人启事死于献祭尖刺，解锁游魂！",
    "Try dying on the Sacrifice Room spikes while holding Missing Poster!"),
  blinding=message("尝试使用白卡复制XIX-太阳！",
    "Try using Blank Card with XIX - The Sun!"),
  movingBox=message("尝试在暗室使用潘多拉魔盒！",
    "Try using Pandora's Box in Dark Room!"),
  movingBoxCharge=message("尝试为潘多拉魔盒充能后在暗室使用！",
    "Try charging Pandora's Box, then use it in Dark Room!"),
  babyBender=message("尝试在已有追踪效果时使用魔术师或心灵感应！",
    "Try using The Magician or Telepathy while homing is already active!"),
  halo=message("尝试使用圣经击败当前Boss！",
    "Try using The Bible to defeat the current boss!"),
  chargedPenny=message("尝试给电池乞丐硬币，直到它奖励道具！",
    "Try giving the Battery Bum coins until it pays out with an item!"),
  oldCapacitor=message("尝试炸死电池乞丐，累计完成老旧电容！",
    "Try bombing the Battery Bum to progress Old Capacitor!"),
  taintedAscent=message("尝试保留红钥匙或红钥匙碎片直到抵达家！",
    "Try keeping Red Key or Cracked Key until reaching Home!"),
  taintedHome=message("尝试在妈妈卧室外的走廊使用红钥匙或红钥匙碎片！",
    "Try using Red Key or Cracked Key in the hallway outside Mom's bedroom!"),
  taintedPickup=message("尝试拾取红钥匙或红钥匙碎片，再开启隐藏衣柜！",
    "Try picking up Red Key or Cracked Key, then open the hidden closet!"),
  forgottenStart=message("尝试炸开初始房间，取得铲子碎片！",
    "Try bombing the starting room to reveal the Broken Shovel!"),
  forgottenCarry=message("尝试保留铲子碎片并完成头目车轮战！",
    "Try keeping the Broken Shovel and completing Boss Rush!"),
  forgottenRush=message("尝试完成头目车轮战，取得第二块铲子碎片！",
    "Try completing Boss Rush to obtain the second shovel piece!"),
  forgottenGrave=message("尝试站在碎土块上使用妈妈的铲子！",
    "Try using Mom's Shovel while standing on the dirt patch!"),
}

local function normalizeRun(run)
  if not run then return {} end
  run.sceneOpportunityEvents = run.sceneOpportunityEvents or {}
  run.sceneOpportunityEvents.forgotten = run.sceneOpportunityEvents.forgotten or {}
  return run.sceneOpportunityEvents
end

local function completed(profileCompleted, goalId)
  return profileCompleted and profileCompleted[goalId] == true
end

local function roomKey(game)
  local level = game:GetLevel()
  local ok, descriptor = pcall(function() return level:GetCurrentRoomDesc() end)
  if ok and descriptor and descriptor.ListIndex ~= nil then
    return tostring(descriptor.ListIndex)
  end
  return table.concat({ level:GetStage(), level:GetStageType(),
    level:GetCurrentRoomIndex() }, ":")
end

local function alive(entity)
  if not entity then return false end
  if entity.Exists and not entity:Exists() then return false end
  if entity.IsDead and entity:IsDead() then return false end
  return true
end

local function entities()
  local ok, result = pcall(function() return Isaac.GetRoomEntities() end)
  return ok and result or {}
end

local function firstEntity(entityType, variant)
  for _, entity in ipairs(entities()) do
    if entity.Type == entityType and (variant == nil or entity.Variant == variant)
      and alive(entity) then return entity end
  end
  return nil
end

local function players(game)
  local result = {}
  for index = 0, game:GetNumPlayers() - 1 do
    local player = Isaac.GetPlayer(index)
    if player then result[#result + 1] = player end
  end
  return result
end

local function hasCollectible(player, collectible)
  return player.HasCollectible and player:HasCollectible(collectible)
end

local function hasTrinket(player, trinket)
  if player.GetTrinketMultiplier then
    local ok, multiplier = pcall(function() return player:GetTrinketMultiplier(trinket) end)
    if ok and multiplier and multiplier > 0 then return true end
  end
  return player.HasTrinket and player:HasTrinket(trinket)
end

local function cardSlot(player, card)
  if not player.GetCard then return nil end
  for slot = 0, 3 do
    local ok, held = pcall(function() return player:GetCard(slot) end)
    if ok and held == card then return slot end
  end
  return nil
end

local function activeSlot(player, collectible)
  if not player.GetActiveItem then return nil end
  for slot = 0, 3 do
    local ok, held = pcall(function() return player:GetActiveItem(slot) end)
    if ok and held == collectible then return slot end
  end
  return nil
end

local function activeReady(player, collectible)
  local slot = activeSlot(player, collectible)
  if slot == nil then return false, nil end
  if not player.NeedsCharge then return true, slot end
  local ok, needsCharge = pcall(function() return player:NeedsCharge(slot) end)
  return not ok or not needsCharge, slot
end

local function hasHoming(player)
  local flags = player.TearFlags
  if flags == nil then return false end
  if type(flags) == "number" then
    return flags % (TEAR_HOMING * 2) >= TEAR_HOMING
  end
  if flags.Get then
    local ok, result = pcall(function() return flags:Get(2) end)
    return ok and result == true
  end
  return false
end

local function make(goalId, copy, priority, danger)
  return { goalId=goalId, message=copy, priority=priority, danger=danger == true }
end

local function uniqueByGoal(opportunities)
  local result, seen = {}, {}
  for _, opportunity in ipairs(opportunities) do
    if not seen[opportunity.goalId] then
      seen[opportunity.goalId] = true
      result[#result + 1] = opportunity
    end
  end
  return result
end

local function addPlayerOpportunities(result, game, profileCompleted)
  local roomType = game:GetRoom():GetType()
  local level = game:GetLevel()
  local darkRoom = level:GetStage() == STAGE_DARK_ROOM
    and level:GetStageType() == STAGE_ORIGINAL
  local bibleBoss = firstEntity(ENTITY_MOM) or firstEntity(ENTITY_MOMS_HEART)
  for _, player in ipairs(players(game)) do
    if not completed(profileCompleted, "achievement_82")
      and roomType == ROOM_SACRIFICE and hasTrinket(player, TRINKET_MISSING_POSTER) then
      result[#result + 1] = make("achievement_82", COPY.lost, 2, true)
    end

    if not completed(profileCompleted, "achievement_258")
      and cardSlot(player, CARD_SUN) ~= nil then
      local ready = activeReady(player, COLLECTIBLE_BLANK_CARD)
      if ready then result[#result + 1] = make("achievement_258", COPY.blinding, 2) end
    end

    if not completed(profileCompleted, "achievement_366") and darkRoom then
      local ready, slot = activeReady(player, COLLECTIBLE_PANDORAS_BOX)
      if slot ~= nil then
        result[#result + 1] = make("achievement_366",
          ready and COPY.movingBox or COPY.movingBoxCharge, 2)
      end
    end

    if not completed(profileCompleted, "achievement_389") and hasHoming(player) then
      local telepathyReady = activeReady(player, COLLECTIBLE_TELEPATHY)
      if cardSlot(player, CARD_MAGICIAN) ~= nil or telepathyReady then
        result[#result + 1] = make("achievement_389", COPY.babyBender, 2)
      end
    end

    if not completed(profileCompleted, "achievement_27") and bibleBoss then
      local bibleReady = activeReady(player, COLLECTIBLE_BIBLE)
      if bibleReady then result[#result + 1] = make("achievement_27", COPY.halo, 2) end
    end
  end
end

local function addBatteryBum(result, game, profileCompleted)
  if not firstEntity(ENTITY_SLOT, BATTERY_BUM) then return end
  if not completed(profileCompleted, "achievement_523") then
    local hasCoins = false
    for _, player in ipairs(players(game)) do
      if player.GetNumCoins and player:GetNumCoins() > 0 then hasCoins = true; break end
    end
    result[#result + 1] = make("achievement_523",
      hasCoins and COPY.chargedPenny or nil, 2)
  elseif not completed(profileCompleted, "achievement_545") then
    result[#result + 1] = make("achievement_545", COPY.oldCapacitor, 2)
  end
end

local function addTaintedUnlocks(result, game, context, profileCompleted)
  if not context or not (context.ascent or context.stage == STAGE_HOME) then return end
  local held = context.heldAids or {}
  local available = context.aids or {}
  local routeEvents = context.routeEvents or {}
  if not (held.red_key or held.cracked_key or available.red_key or available.cracked_key
    or routeEvents.crackedKeyPrepared) then return end
  local primary = game:GetNumPlayers() > 0 and Isaac.GetPlayer(0) or nil
  local primaryPlayerType = primary
    and CharacterRelevance.normalize(primary:GetPlayerType()) or nil
  for achievementId = 474, 490 do
    local goalId = "achievement_" .. achievementId
    local goal = Catalog.get(goalId)
    if goal and goal.routeKind == "tainted_unlock" and not completed(profileCompleted, goalId) then
      local required = CharacterRelevance.requiredPlayerTypes(goal)
      local matches = primaryPlayerType ~= nil and required[primaryPlayerType] == true
      if matches then
        local copy = COPY.taintedAscent
        if context.stage == STAGE_HOME then
          copy = (held.red_key or held.cracked_key) and COPY.taintedHome
            or (available.red_key or available.cracked_key) and COPY.taintedPickup
            or nil
        end
        if copy then result[#result + 1] = make(goalId, copy, 3) end
      end
    end
  end
end

local function roomName(game)
  local ok, descriptor = pcall(function() return game:GetLevel():GetCurrentRoomDesc() end)
  local data = ok and descriptor and descriptor.Data
  return string.lower(tostring(data and data.Name or ""))
end

local function playerHas(game, collectible)
  for _, player in ipairs(players(game)) do
    if hasCollectible(player, collectible) then return true end
  end
  return false
end

local function addForgotten(result, game, run, profileCompleted)
  if completed(profileCompleted, "achievement_390")
    or not completed(profileCompleted, "achievement_348") then return end
  local events = normalizeRun(run)
  local forgotten = events.forgotten
  local level, room = game:GetLevel(), game:GetRoom()
  local hasBroken = playerHas(game, COLLECTIBLE_BROKEN_SHOVEL)
  local hasMomsShovel = playerHas(game, COLLECTIBLE_MOMS_SHOVEL)
  if hasMomsShovel then
    local currentRoomName = roomName(game)
    if level:GetStage() == STAGE_DARK_ROOM
      and string.find(currentRoomName, "grave", 1, true) then
      result[#result + 1] = make("achievement_390", COPY.forgottenGrave, 3)
    end
  elseif hasBroken then
    result[#result + 1] = make("achievement_390",
      room:GetType() == ROOM_BOSSRUSH and COPY.forgottenRush or COPY.forgottenCarry, 3)
  elseif forgotten.firstBossDefeatedInTime and level:GetStage() == STAGE_BASEMENT1 then
    local ok, startingRoom = pcall(function() return level:GetStartingRoomIndex() end)
    if ok and level:GetCurrentRoomIndex() == startingRoom then
      result[#result + 1] = make("achievement_390", COPY.forgottenStart, 3)
    end
  end
end

function Opportunities.observeNpc(run, npc, game)
  if not run or not npc or not game then return false end
  local events = normalizeRun(run)
  local forgotten = events.forgotten
  if npc.IsBoss and npc:IsBoss() and game:GetLevel():GetStage() == STAGE_BASEMENT1
    and game:GetRoom():GetType() == ROOM_BOSS
    and not forgotten.firstBossDefeatedInTime then
    local deathAt = math.floor(game.TimeCounter / 30)
    local key = roomKey(game)
    local changed = forgotten.bossRoomDeathAt ~= deathAt or forgotten.bossRoomKey ~= key
    forgotten.bossRoomDeathAt = deathAt
    forgotten.bossRoomKey = key
    return changed
  end
  return false
end

function Opportunities.updateRun(run, game)
  if not run or not game then return false end
  local forgotten = normalizeRun(run).forgotten
  if forgotten.firstBossDefeatedInTime or not forgotten.bossRoomDeathAt
    or forgotten.bossRoomKey ~= roomKey(game)
    or game:GetRoom():GetType() ~= ROOM_BOSS then return false end
  local room = game:GetRoom()
  local cleared, clearKnown = false, false
  if room.IsClear then
    local ok, isClear = pcall(function() return room:IsClear() end)
    if ok then cleared, clearKnown = isClear == true, true end
  end
  if not clearKnown then
    local ok, bosses = pcall(function() return room:GetAliveBossesCount() end)
    if ok then cleared = bosses == 0 end
  end
  if not cleared then return false end
  forgotten.firstBossDefeatedInTime = math.floor(game.TimeCounter / 30) <= 60
  forgotten.bossRoomDeathAt = nil
  forgotten.bossRoomKey = nil
  return true
end

function Opportunities.onNewRoom(run, game)
  if not run or not game then return false end
  local forgotten = normalizeRun(run).forgotten
  if forgotten.bossRoomKey and forgotten.bossRoomKey ~= roomKey(game) then
    forgotten.bossRoomDeathAt = nil
    forgotten.bossRoomKey = nil
    return true
  end
  return false
end

function Opportunities.resetAttempt(run)
  if not run then return end
  normalizeRun(run).forgotten = {}
end

function Opportunities.evaluate(game, run, profileCompleted, completionAllowed, context)
  if not completionAllowed then return {} end
  local result = {}

  if not completed(profileCompleted, "achievement_410") and not game:IsGreedMode()
    and game:GetRoom():GetType() == ROOM_BOSS and firstEntity(ENTITY_BABY_PLUM) then
    result[#result + 1] = make("achievement_410", COPY.plum, 1)
  end
  if not completed(profileCompleted, "achievement_408")
    and firstEntity(ENTITY_SIREN, SIREN_SKULL_VARIANT) then
    result[#result + 1] = make("achievement_408", COPY.siren, 1)
  end
  if not completed(profileCompleted, "achievement_546") and firstEntity(ENTITY_HORNFEL) then
    local minecart = firstEntity(ENTITY_MINECART)
    result[#result + 1] = make("achievement_546",
      minecart and COPY.hornfel or COPY.hornfelUrgent, 1)
  end

  addPlayerOpportunities(result, game, profileCompleted)
  addBatteryBum(result, game, profileCompleted)
  addTaintedUnlocks(result, game, context, profileCompleted)
  addForgotten(result, game, run, profileCompleted)

  result = uniqueByGoal(result)
  for index, opportunity in ipairs(result) do opportunity.stableOrder = index end
  table.sort(result, function(left, right)
    if left.priority ~= right.priority then return left.priority < right.priority end
    return left.stableOrder < right.stableOrder
  end)
  return result
end

function Opportunities.signature(opportunities)
  local parts = {}
  for _, opportunity in ipairs(opportunities or {}) do
    parts[#parts + 1] = table.concat({ opportunity.goalId,
      tostring(opportunity.priority), opportunity.message and opportunity.message.zh or "" }, ":")
  end
  return table.concat(parts, "|")
end

return Opportunities
