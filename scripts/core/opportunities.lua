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
local ENTITY_LAMB = enum(EntityType, "ENTITY_THE_LAMB", 273)
local ENTITY_URIEL = enum(EntityType, "ENTITY_URIEL", 271)
local ENTITY_GABRIEL = enum(EntityType, "ENTITY_GABRIEL", 272)
local ENTITY_PICKUP = enum(EntityType, "ENTITY_PICKUP", 5)
local ENTITY_SLOT = enum(EntityType, "ENTITY_SLOT", 6)
local BATTERY_BUM = enum(SlotVariant, "BATTERY_BUM", 13)
local ROOM_SACRIFICE = enum(RoomType, "ROOM_SACRIFICE", 13)
local ROOM_BOSS = enum(RoomType, "ROOM_BOSS", 5)
local ROOM_BOSSRUSH = enum(RoomType, "ROOM_BOSSRUSH", 17)
local ROOM_ANGEL = enum(RoomType, "ROOM_ANGEL", 15)
local ROOM_SHOP = enum(RoomType, "ROOM_SHOP", 2)
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
local COLLECTIBLE_BALL_OF_BANDAGES = enum(CollectibleType, "COLLECTIBLE_BALL_OF_BANDAGES", 207)
local COLLECTIBLE_CUBE_OF_MEAT = enum(CollectibleType, "COLLECTIBLE_CUBE_OF_MEAT", 73)
local COLLECTIBLE_POTATO_PEELER = enum(CollectibleType, "COLLECTIBLE_POTATO_PEELER", 487)
local COLLECTIBLE_KEY_PIECE_1 = enum(CollectibleType, "COLLECTIBLE_KEY_PIECE_1", 238)
local COLLECTIBLE_KEY_PIECE_2 = enum(CollectibleType, "COLLECTIBLE_KEY_PIECE_2", 239)
local COLLECTIBLE_R_KEY = enum(CollectibleType, "COLLECTIBLE_R_KEY", 636)
local COLLECTIBLE_IPECAC = enum(CollectibleType, "COLLECTIBLE_IPECAC", 149)
local COLLECTIBLE_BOBS_ROTTEN_HEAD = enum(CollectibleType, "COLLECTIBLE_BOBS_ROTTEN_HEAD", 42)
local COLLECTIBLE_PYROMANIAC = enum(CollectibleType, "COLLECTIBLE_PYROMANIAC", 223)
local COLLECTIBLE_HOST_HAT = enum(CollectibleType, "COLLECTIBLE_HOST_HAT", 375)
local COLLECTIBLE_HOLY_MANTLE = enum(CollectibleType, "COLLECTIBLE_HOLY_MANTLE", 313)
local COLLECTIBLE_MAGIC_MUSHROOM = enum(CollectibleType, "COLLECTIBLE_MAGIC_MUSHROOM", 12)
local COLLECTIBLE_PLACEBO = enum(CollectibleType, "COLLECTIBLE_PLACEBO", 348)
local COLLECTIBLE_GUPPYS_HEAD = enum(CollectibleType, "COLLECTIBLE_GUPPYS_HEAD", 145)
local COLLECTIBLE_JAR_OF_FLIES = enum(CollectibleType, "COLLECTIBLE_JAR_OF_FLIES", 434)
local FAMILIAR_BANDAGE_GIRL = enum(FamiliarVariant, "BALL_OF_BANDAGES_3", 71)
local FAMILIAR_MEATBOY = enum(FamiliarVariant, "CUBE_OF_MEAT_3", 46)
local PICKUP_COLLECTIBLE = enum(PickupVariant, "PICKUP_COLLECTIBLE", 100)
local PICKUP_BED = enum(PickupVariant, "PICKUP_BED", 380)
local PICKUP_MOMSCHEST = enum(PickupVariant, "PICKUP_MOMSCHEST", 390)
local PILLEFFECT_HORF = enum(PillEffect, "PILLEFFECT_HORF", 44)
local PILLEFFECT_GULP = enum(PillEffect, "PILLEFFECT_GULP", 43)
local PILLEFFECT_ONE_MAKES_YOU_LARGER = enum(PillEffect, "PILLEFFECT_LARGER", 32)
local GRID_STATUE = enum(GridEntityType, "GRID_STATUE", 21)
local ITEM_PASSIVE = enum(ItemType, "ITEM_PASSIVE", 1)
local ITEM_FAMILIAR = enum(ItemType, "ITEM_FAMILIAR", 4)
local PRICE_ONE_HEART = enum(PickupPrice, "PRICE_ONE_HEART", -1)
local PRICE_TWO_HEARTS = enum(PickupPrice, "PRICE_TWO_HEARTS", -2)
local PRICE_THREE_SOULHEARTS = enum(PickupPrice, "PRICE_THREE_SOULHEARTS", -3)
local PRICE_ONE_HEART_AND_TWO_SOULHEARTS = enum(PickupPrice,
  "PRICE_ONE_HEART_AND_TWO_SOULHEARTS", -4)
local PRICE_FREE = enum(PickupPrice, "PRICE_FREE", -1000)
local PRICE_FREE_SHOPITEM = enum(PickupPrice, "PRICE_FREE_SHOPITEM", -1001)
local TRINKET_MISSING_POSTER = enum(TrinketType, "TRINKET_MISSING_POSTER", 23)
local CARD_MAGICIAN = enum(Card, "CARD_MAGICIAN", 2)
local CARD_SUN = enum(Card, "CARD_SUN", 5)
local CARD_STRENGTH = enum(Card, "CARD_STRENGTH", 12)
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
  bandageGirl=message("尝试拾取第四个绷带球，组成超级绷带女孩！",
    "Try picking up a fourth Ball of Bandages to build Super Bandage Girl!"),
  meatBoy=message("尝试拾取第四个肉块，组成超级食肉男孩！",
    "Try picking up a fourth Cube of Meat to build Super Meat Boy!"),
  angelStatue=message("尝试炸毁天使雕像，取得钥匙碎片！",
    "Try bombing the angel statue to obtain a Key Piece!"),
  angelFight=message("尝试击败天使并拾取掉落的钥匙碎片！",
    "Try defeating the angel and picking up the dropped Key Piece!"),
  keyPiece=message("尝试拾取地上的钥匙碎片！",
    "Try picking up the Key Piece on the floor!"),
  shopSpend=message("尝试在本商店再消费%d枚硬币，累计达到40枚！",
    "Try spending %d more coins in this shop to reach 40!"),
  goldenRazor=message("尝试把已经达到过99的硬币全部花光！",
    "Try spending every coin after having reached 99!"),
  bed=message("尝试使用这张床睡一觉！",
    "Try sleeping in this bed!"),
  victoryLap=message("尝试在击败羔羊后选择继续跑圈！",
    "Try choosing another Victory Lap after defeating The Lamb!"),
  lilSpewer=message("尝试在生命不多时用爆炸伤害击杀自己！",
    "Try killing yourself with explosion damage when it would be lethal!"),
  zip=message("尝试在剩余%02d:%02d内找到并击败羔羊！",
    "Try finding and defeating The Lamb within %02d:%02d!"),
  itsTheKey=message("尝试击败羔羊，并保持本局未拾取心、硬币或炸弹！",
    "Try defeating The Lamb without picking up Hearts, Coins, or Bombs!"),
  zipAndKey=message("尝试在剩余%02d:%02d内击败羔羊，并保持未拾取心、硬币或炸弹！",
    "Try defeating The Lamb within %02d:%02d without picking up Hearts, Coins, or Bombs!"),
  uBrokeIt=message("尝试拾取这个道具，使本局获得的道具达到50个！",
    "Try picking up this item to reach 50 items in this run!"),
  hugeGrowth=message("尝试使用当前的变大来源，完成第5次体型增大！",
    "Try using the available growth source for your fifth size increase!"),
  marbles=message("尝试使用咕噜！胶囊，完成本局第5次吞咽！",
    "Try using Gulp! for the fifth time in this run!"),
  rottenPenny=message("尝试使用当前主动道具，让蓝苍蝇达到20只！",
    "Try using the available active item to reach 20 Blue Flies!"),
  momsChest=message("尝试打开妈妈的箱子，解锁红钥匙！",
    "Try opening Mom's Chest to unlock Red Key!"),
}

local function normalizeRun(run)
  if not run then return {} end
  run.sceneOpportunityEvents = run.sceneOpportunityEvents or {}
  local events = run.sceneOpportunityEvents
  events.forgotten = events.forgotten or {}
  events.shopPurchases = events.shopPurchases or {}
  events.shopPickupPrices = events.shopPickupPrices or {}
  events.shopSpent = tonumber(events.shopSpent) or 0
  return events
end

local function completed(profileCompleted, goalId)
  return profileCompleted and profileCompleted[goalId] == true
end

local function roomKey(game)
  local level = game:GetLevel()
  local ok, descriptor = pcall(function() return level:GetCurrentRoomDesc() end)
  if ok and descriptor and descriptor.ListIndex ~= nil then
    return table.concat({ level:GetStage(), level:GetStageType(), descriptor.ListIndex }, ":")
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

local function formatted(copy, value)
  return message(string.format(copy.zh, value), string.format(copy.en, value))
end

local function addPairedGoals(result, profileCompleted, firstGoalId, secondGoalId,
  copy, priority, danger)
  if not completed(profileCompleted, firstGoalId) then
    result[#result + 1] = make(firstGoalId, copy, priority, danger)
  end
  if not completed(profileCompleted, secondGoalId) then
    result[#result + 1] = make(secondGoalId, copy, priority, danger)
  end
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

local function hasRoomBomb(game)
  for _, player in ipairs(players(game)) do
    if (player.GetNumBombs and player:GetNumBombs() > 0)
      or (player.HasGoldenBomb and player:HasGoldenBomb()) then return true end
  end
  return false
end

local function hasAngelStatue(game)
  local room = game:GetRoom()
  if not room.GetGridSize or not room.GetGridEntity then return false end
  for index = 0, room:GetGridSize() - 1 do
    local grid = room:GetGridEntity(index)
    if grid and grid.GetType and grid:GetType() == GRID_STATUE
      and (grid.State == nil or grid.State == 0) then return true end
  end
  return false
end

local function needsKeyPiece(game, keyPiece)
  for _, player in ipairs(players(game)) do
    if not hasCollectible(player, keyPiece) then return true end
  end
  return false
end

local function addAngelRoom(result, game, profileCompleted)
  if game:GetRoom():GetType() ~= ROOM_ANGEL
    or (completed(profileCompleted, "achievement_58")
      and completed(profileCompleted, "achievement_370")) then return end
  local needsOne = needsKeyPiece(game, COLLECTIBLE_KEY_PIECE_1)
  local needsTwo = needsKeyPiece(game, COLLECTIBLE_KEY_PIECE_2)
  if not needsOne and not needsTwo then return end

  local copy
  if firstEntity(ENTITY_PICKUP, PICKUP_COLLECTIBLE) then
    for _, pickup in ipairs(entities()) do
      if pickup.Type == ENTITY_PICKUP and pickup.Variant == PICKUP_COLLECTIBLE
        and ((pickup.SubType == COLLECTIBLE_KEY_PIECE_1 and needsOne)
          or (pickup.SubType == COLLECTIBLE_KEY_PIECE_2 and needsTwo)) and alive(pickup) then
        copy = COPY.keyPiece
        break
      end
    end
  end
  if not copy and ((needsOne and firstEntity(ENTITY_URIEL))
      or (needsTwo and firstEntity(ENTITY_GABRIEL))) then
    copy = COPY.angelFight
  end
  if not copy and hasRoomBomb(game) and hasAngelStatue(game) then
    copy = COPY.angelStatue
  end
  if copy then
    addPairedGoals(result, profileCompleted, "achievement_58", "achievement_370", copy, 1)
  end
end

local function findUsableBed()
  for _, pickup in ipairs(entities()) do
    if pickup.Type == ENTITY_PICKUP and pickup.Variant == PICKUP_BED
      and alive(pickup) and not pickup.Touched then return pickup end
  end
  return nil
end

local function addBed(result, profileCompleted)
  if (not completed(profileCompleted, "achievement_359")
      or not completed(profileCompleted, "achievement_385")) and findUsableBed() then
    addPairedGoals(result, profileCompleted, "achievement_359", "achievement_385", COPY.bed, 2)
  end
end

local function hasLevelThreeFamiliar(player, collectible, familiarVariant)
  if not player.GetCollectibleNum then return false end
  local count = player:GetCollectibleNum(collectible, true)
  local effects = player.GetEffects and player:GetEffects() or nil
  if effects and effects.GetCollectibleEffectNum then
    count = count + effects:GetCollectibleEffectNum(collectible)
  end
  if count >= 3 then return true end
  for _, entity in ipairs(entities()) do
    if entity.Variant == familiarVariant and alive(entity) then
      local familiar = entity.ToFamiliar and entity:ToFamiliar() or nil
      if familiar and familiar.Player == player then return true end
    end
  end
  return false
end

local function addSuperFamiliar(result, game, profileCompleted)
  local bandagePedestal, meatPedestal = false, false
  for _, pickup in ipairs(entities()) do
    if pickup.Type == ENTITY_PICKUP and pickup.Variant == PICKUP_COLLECTIBLE and alive(pickup) then
      if pickup.SubType == COLLECTIBLE_BALL_OF_BANDAGES then bandagePedestal = true end
      if pickup.SubType == COLLECTIBLE_CUBE_OF_MEAT then meatPedestal = true end
    end
  end
  for _, player in ipairs(players(game)) do
    if bandagePedestal and not completed(profileCompleted, "achievement_19")
      and hasLevelThreeFamiliar(player, COLLECTIBLE_BALL_OF_BANDAGES,
        FAMILIAR_BANDAGE_GIRL) then
      result[#result + 1] = make("achievement_19", COPY.bandageGirl, 1)
    end
    if not completed(profileCompleted, "achievement_144")
      and hasLevelThreeFamiliar(player, COLLECTIBLE_CUBE_OF_MEAT, FAMILIAR_MEATBOY) then
      if meatPedestal then
        result[#result + 1] = make("achievement_144", COPY.meatBoy, 1)
      elseif activeReady(player, COLLECTIBLE_POTATO_PEELER)
        and player.GetMaxHearts and player:GetMaxHearts() >= 2 then
        result[#result + 1] = make("achievement_144", COPY.meatBoy, 1)
      end
    end
  end
end

local function shopRoomKey(game)
  return roomKey(game)
end

local function collectingPickup(pickup)
  if not pickup.GetSprite then return false end
  local ok, sprite = pcall(function() return pickup:GetSprite() end)
  return ok and sprite and sprite.IsPlaying and sprite:IsPlaying("Collect")
end

local function heldPillSlot(player, game, pillEffect, identifiedOnly)
  if not player.GetPill or not game.GetItemPool then return nil end
  local pool = game:GetItemPool()
  if not pool or not pool.GetPillEffect then return nil end
  for slot = 0, 3 do
    local okColor, color = pcall(function() return player:GetPill(slot) end)
    if okColor and color and color ~= 0 then
      local identified = not identifiedOnly or not pool.IsPillIdentified
        or pool:IsPillIdentified(color)
      local okEffect, effect = pcall(function() return pool:GetPillEffect(color, player) end)
      if identified and okEffect and effect == pillEffect then return slot end
    end
  end
  return nil
end

local function addZip(result, game, profileCompleted)
  local level = game:GetLevel()
  if not completed(profileCompleted, "achievement_326")
    and level:GetStage() == STAGE_DARK_ROOM
    and level:GetStageType() == STAGE_ORIGINAL
    and game.TimeCounter < 20 * 60 * 30 then
    local remainingFrames = 20 * 60 * 30 - game.TimeCounter
    local remainingSeconds = math.ceil(remainingFrames / 30)
    local minutes, seconds = math.floor(remainingSeconds / 60), remainingSeconds % 60
    local copy = message(string.format(COPY.zip.zh, minutes, seconds),
      string.format(COPY.zip.en, minutes, seconds))
    local opportunity = make("achievement_326", copy, 1)
    result[#result + 1] = opportunity
    return { opportunity=opportunity, minutes=minutes, seconds=seconds }
  end
  return nil
end

local function addItsTheKey(result, game, run, profileCompleted, zipState)
  if completed(profileCompleted, "achievement_327")
    or game:GetLevel():GetStage() ~= STAGE_DARK_ROOM
    or game:GetLevel():GetStageType() ~= STAGE_ORIGINAL
    or game:GetRoom():GetType() ~= ROOM_BOSS or not firstEntity(ENTITY_LAMB) then return end
  local disqualified = run and run.disqualified or {}
  if not disqualified.heart and not disqualified.coin and not disqualified.bomb then
    if zipState then
      local copy = message(string.format(COPY.zipAndKey.zh,
        zipState.minutes, zipState.seconds), string.format(COPY.zipAndKey.en,
        zipState.minutes, zipState.seconds))
      zipState.opportunity.message = copy
      addPairedGoals(result, profileCompleted, "achievement_326", "achievement_327", copy, 1)
    else
      result[#result + 1] = make("achievement_327", COPY.itsTheKey, 1)
    end
  end
end

local function pedestalAffordable(pickup, player)
  local shopItem = pickup.IsShopItem and pickup:IsShopItem()
  if not shopItem then return true end
  local price = pickup.Price
  if price == nil then return false end
  if price == 0 or price == PRICE_FREE or price == PRICE_FREE_SHOPITEM then return true end
  if price > 0 then
    return player.GetNumCoins and player:GetNumCoins() >= price
  end
  if price == PRICE_ONE_HEART then
    return player.GetMaxHearts and player:GetMaxHearts() >= 2
  end
  if price == PRICE_TWO_HEARTS then
    return player.GetMaxHearts and player:GetMaxHearts() >= 4
  end
  if price == PRICE_THREE_SOULHEARTS then
    return player.GetSoulHearts and player:GetSoulHearts() >= 6
  end
  if price == PRICE_ONE_HEART_AND_TWO_SOULHEARTS then
    return player.GetMaxHearts and player:GetMaxHearts() >= 2
      and player.GetSoulHearts and player:GetSoulHearts() >= 4
  end
  return false
end

local function addFinalItem(result, game, run, profileCompleted)
  if completed(profileCompleted, "achievement_330")
    or not (run and run.progress and run.progress.items == 49) then return end
  local player = game:GetNumPlayers() > 0 and Isaac.GetPlayer(0) or nil
  if not player then return end
  local itemConfig = Isaac.GetItemConfig and Isaac.GetItemConfig() or nil
  for _, pickup in ipairs(entities()) do
    if pickup.Type == ENTITY_PICKUP and pickup.Variant == PICKUP_COLLECTIBLE
      and pickup.SubType > 0 and alive(pickup) and not pickup.Touched
      and (pickup.Wait == nil or pickup.Wait <= 0) and not collectingPickup(pickup) then
      local config = itemConfig and itemConfig:GetCollectible(pickup.SubType) or nil
      local counts = config and (config.Type == ITEM_PASSIVE or config.Type == ITEM_FAMILIAR)
      if counts and pedestalAffordable(pickup, player) then
        result[#result + 1] = make("achievement_330", COPY.uBrokeIt, 1)
        return
      end
    end
  end
end

local function addGrowth(result, game, run, profileCompleted)
  if not (run and run.progress and run.progress.growth == 4)
    or completed(profileCompleted, "achievement_361")
    or (run.completedGoals and run.completedGoals.achievement_361) then return end
  for _, player in ipairs(players(game)) do
    local pill = heldPillSlot(player, game, PILLEFFECT_ONE_MAKES_YOU_LARGER, true)
    local strength = cardSlot(player, CARD_STRENGTH)
    local placeboReady = activeReady(player, COLLECTIBLE_PLACEBO)
    local blankCardReady = activeReady(player, COLLECTIBLE_BLANK_CARD)
    if pill ~= nil or strength ~= nil or (pill ~= nil and placeboReady)
      or (strength ~= nil and blankCardReady) then
      result[#result + 1] = make("achievement_361", COPY.hugeGrowth, 1)
      return
    end
  end
  for _, pickup in ipairs(entities()) do
    if pickup.Type == ENTITY_PICKUP and pickup.Variant == PICKUP_COLLECTIBLE
      and pickup.SubType == COLLECTIBLE_MAGIC_MUSHROOM and alive(pickup)
      and not pickup.Touched and (pickup.Wait == nil or pickup.Wait <= 0)
      and not collectingPickup(pickup) then
      for _, player in ipairs(players(game)) do
        if pedestalAffordable(pickup, player) then
          result[#result + 1] = make("achievement_361", COPY.hugeGrowth, 1)
          return
        end
      end
    end
  end
end

local function addMarbles(result, game, run, profileCompleted)
  if not (run and run.progress and run.progress.gulp == 4)
    or completed(profileCompleted, "achievement_386")
    or (run.completedGoals and run.completedGoals.achievement_386) then return end
  for _, player in ipairs(players(game)) do
    local gulp = heldPillSlot(player, game, PILLEFFECT_GULP, true)
    if gulp ~= nil then
      local placeboReady = activeReady(player, COLLECTIBLE_PLACEBO)
      result[#result + 1] = make("achievement_386", COPY.marbles, placeboReady and 1 or 2)
      return
    end
  end
end

local function addBlueFlies(result, game, run, profileCompleted)
  if completed(profileCompleted, "achievement_388")
    or (run and run.completedGoals and run.completedGoals.achievement_388) then return end
  for _, player in ipairs(players(game)) do
    if player.GetNumBlueFlies and player:GetNumBlueFlies() < 20 then
      local guppyReady = activeReady(player, COLLECTIBLE_GUPPYS_HEAD)
      if guppyReady and player:GetNumBlueFlies() >= 18 then
        result[#result + 1] = make("achievement_388", COPY.rottenPenny, 1)
        return
      end
      local jarReady, jarSlot = activeReady(player, COLLECTIBLE_JAR_OF_FLIES)
      if jarSlot ~= nil and jarReady and player.GetJarFlies
        and player:GetNumBlueFlies() + player:GetJarFlies() >= 20 then
        result[#result + 1] = make("achievement_388", COPY.rottenPenny, 1)
        return
      end
    end
  end
end

local function addMomsChest(result, game, profileCompleted)
  if completed(profileCompleted, "achievement_415") then return end
  if game:GetLevel():GetStage() == STAGE_HOME then
    for _, pickup in ipairs(entities()) do
      if pickup.Type == ENTITY_PICKUP and pickup.Variant == PICKUP_MOMSCHEST
        and alive(pickup) and not pickup.Touched then
        local sprite = pickup.GetSprite and pickup:GetSprite() or nil
        local opened = sprite and ((sprite.IsPlaying and sprite:IsPlaying("Open"))
          or (sprite.IsFinished and sprite:IsFinished("Open")))
        if not opened then
          result[#result + 1] = make("achievement_415", COPY.momsChest, 1)
          return
        end
      end
    end
  end
end

function Opportunities.observePickup(run, pickup, game)
  if not run or not pickup or not game or game:GetRoom():GetType() ~= ROOM_SHOP
    or pickup.Type ~= ENTITY_PICKUP then return false end
  local events = normalizeRun(run)
  local key = shopRoomKey(game)
  if events.shopRoomKey ~= key then
    events.shopRoomKey = key
    events.shopSpent = 0
    events.shopPurchases = {}
    events.shopPickupPrices = {}
  end
  if pickup.InitSeed == nil then return false end
  local seed = table.concat({ tostring(pickup.InitSeed), tostring(pickup.Index or "") }, ":")
  if pickup.Price > 0 then events.shopPickupPrices[seed] = pickup.Price end
  if not collectingPickup(pickup) or events.shopPurchases[seed] then return false end
  local price = pickup.Price > 0 and pickup.Price or events.shopPickupPrices[seed]
  if not price or price <= 0 then return false end
  events.shopPurchases[seed] = true
  if pickup.Price > 0 then
    events.shopSpent = events.shopSpent + pickup.Price
  else
    events.shopSpent = events.shopSpent + price
  end
  return true
end

local function addMemberCard(result, game, run, profileCompleted)
  if completed(profileCompleted, "achievement_582")
    or game:GetRoom():GetType() ~= ROOM_SHOP then return end
  local events = normalizeRun(run)
  if events.shopRoomKey ~= shopRoomKey(game) then return end
  local remaining = 40 - events.shopSpent
  if remaining <= 0 then return end
  local available = 0
  for _, pickup in ipairs(entities()) do
    if pickup.Type == ENTITY_PICKUP and alive(pickup) and pickup.Price > 0
      and not collectingPickup(pickup) then available = available + pickup.Price end
  end
  for _, player in ipairs(players(game)) do
    if player.GetNumCoins and player:GetNumCoins() >= remaining and available >= remaining then
      result[#result + 1] = make("achievement_582", formatted(COPY.shopSpend, remaining), 2)
      return
    end
  end
end

local function heldHorfPill(player, game)
  return heldPillSlot(player, game, PILLEFFECT_HORF, false) ~= nil
end

local function explosionImmune(player)
  return hasCollectible(player, COLLECTIBLE_PYROMANIAC)
    or hasCollectible(player, COLLECTIBLE_HOST_HAT)
end

local function hasMantleShield(player)
  local effects = player.GetEffects and player:GetEffects() or nil
  return effects and effects.GetCollectibleEffectNum
    and effects:GetCollectibleEffectNum(COLLECTIBLE_HOLY_MANTLE) > 0
end

local function lethalExplosionHealth(player)
  if not player.GetHearts or not player.GetSoulHearts then return false end
  local health = player:GetHearts() + player:GetSoulHearts()
  if player.GetBoneHearts then health = health + player:GetBoneHearts() * 2 end
  return health == 1 and not hasMantleShield(player)
end

local function addLilSpewer(result, game, profileCompleted)
  if completed(profileCompleted, "achievement_384") then return end
  for _, player in ipairs(players(game)) do
    if lethalExplosionHealth(player) and not explosionImmune(player) then
      local ipecac = hasCollectible(player, COLLECTIBLE_IPECAC)
      local bobsHead = activeReady(player, COLLECTIBLE_BOBS_ROTTEN_HEAD)
      local horf = heldHorfPill(player, game)
      if ipecac or bobsHead or horf then
        result[#result + 1] = make("achievement_384", COPY.lilSpewer, 1, true)
        return
      end
    end
  end
end

local function victoryLapGoalId(victoryLap)
  local goals = {
    [0] = "achievement_321",
    [1] = "achievement_321",
    [2] = "achievement_360",
    [3] = "achievement_337",
  }
  return goals[victoryLap]
end

local function addVictoryLap(result, game, run, profileCompleted, allowed)
  if not allowed or game:GetRoom():GetType() ~= ROOM_BOSS
    or game:GetLevel():GetStage() ~= STAGE_DARK_ROOM
    or game:GetLevel():GetStageType() ~= STAGE_ORIGINAL then return end
  local room = game:GetRoom()
  if not room.IsClear or not room:IsClear() then return end
  local events = normalizeRun(run)
  if events.lambDefeatedRoom ~= roomKey(game) then return end
  local ok, victoryLap = pcall(function() return game:GetVictoryLap() end)
  if not ok then return end
  local goalId = victoryLapGoalId(victoryLap)
  if goalId and not completed(profileCompleted, goalId) then
    result[#result + 1] = make(goalId, COPY.victoryLap, 1)
  end
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

local function addGoldenRazor(result, game, run, profileCompleted)
  if completed(profileCompleted, "achievement_583") then return end
  local events = normalizeRun(run)
  local player = game:GetNumPlayers() > 0 and Isaac.GetPlayer(0) or nil
  if events.goldenRazorReached99 and player and player.GetNumCoins
    and player:GetNumCoins() > 0 then
    result[#result + 1] = make("achievement_583", COPY.goldenRazor, 2)
  end
end

function Opportunities.observeNpc(run, npc, game)
  if not run or not npc or not game then return false end
  local events = normalizeRun(run)
  local changed = false
  if npc.Type == ENTITY_LAMB and game:GetRoom():GetType() == ROOM_BOSS
    and game:GetLevel():GetStage() == STAGE_DARK_ROOM then
    local key = roomKey(game)
    changed = events.lambDefeatedRoom ~= key
    events.lambDefeatedRoom = key
  end
  local forgotten = events.forgotten
  if npc.IsBoss and npc:IsBoss() and game:GetLevel():GetStage() == STAGE_BASEMENT1
    and game:GetRoom():GetType() == ROOM_BOSS
    and not forgotten.firstBossDefeatedInTime then
    local deathAt = math.floor(game.TimeCounter / 30)
    local key = roomKey(game)
    local changed = forgotten.bossRoomDeathAt ~= deathAt or forgotten.bossRoomKey ~= key
    forgotten.bossRoomDeathAt = deathAt
    forgotten.bossRoomKey = key
    return true
  end
  return changed
end

function Opportunities.updateRun(run, game)
  if not run or not game then return false end
  local events = normalizeRun(run)
  local changed = false
  local player = game:GetNumPlayers() > 0 and Isaac.GetPlayer(0) or nil
  if player and player.GetNumCoins then
    if player:GetNumCoins() >= 99 and not events.goldenRazorReached99 then
      events.goldenRazorReached99 = true
      changed = true
    end
    if events.goldenRazorReached99 and player:GetNumCoins() == 0 then
      events.goldenRazorReached99 = nil
      changed = true
    end
  end

  local forgotten = events.forgotten
  if forgotten.firstBossDefeatedInTime or not forgotten.bossRoomDeathAt
    or forgotten.bossRoomKey ~= roomKey(game)
    or game:GetRoom():GetType() ~= ROOM_BOSS then return changed end
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
  if not cleared then return changed end
  forgotten.firstBossDefeatedInTime = math.floor(game.TimeCounter / 30) <= 60
  forgotten.bossRoomDeathAt = nil
  forgotten.bossRoomKey = nil
  return true
end

function Opportunities.onNewRoom(run, game)
  if not run or not game then return false end
  local events = normalizeRun(run)
  local changed = false
  local key = shopRoomKey(game)
  if events.shopRoomKey ~= key then
    events.shopRoomKey = key
    events.shopSpent = 0
    events.shopPurchases = {}
    events.shopPickupPrices = {}
    changed = true
  end
  if events.lambDefeatedRoom and events.lambDefeatedRoom ~= roomKey(game) then
    events.lambDefeatedRoom = nil
    changed = true
  end
  local forgotten = events.forgotten
  if forgotten.bossRoomKey and forgotten.bossRoomKey ~= roomKey(game) then
    forgotten.bossRoomDeathAt = nil
    forgotten.bossRoomKey = nil
    changed = true
  end
  return changed
end

function Opportunities.onUseItem(run, collectible)
  if not run or collectible ~= COLLECTIBLE_R_KEY then return false end
  local events = normalizeRun(run)
  local changed = events.goldenRazorReached99 ~= nil
    or events.lambDefeatedRoom ~= nil or events.shopSpent ~= 0
  events.goldenRazorReached99 = nil
  events.lambDefeatedRoom = nil
  events.shopSpent = 0
  events.shopPurchases = {}
  events.shopPickupPrices = {}
  return changed
end

function Opportunities.resetAttempt(run)
  if not run then return end
  run.sceneOpportunityEvents = { forgotten={} }
end

function Opportunities.evaluate(game, run, profileCompleted, completionAllowed, context,
  victoryLapAllowed)
  if not victoryLapAllowed then
    if not completionAllowed then return {} end
  end
  local result = {}

  if completionAllowed then
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
    addAngelRoom(result, game, profileCompleted)
    addBed(result, profileCompleted)
    addSuperFamiliar(result, game, profileCompleted)
    addMemberCard(result, game, run, profileCompleted)
    addGoldenRazor(result, game, run, profileCompleted)
    addLilSpewer(result, game, profileCompleted)
    local zipState = addZip(result, game, profileCompleted)
    addItsTheKey(result, game, run, profileCompleted, zipState)
    addFinalItem(result, game, run, profileCompleted)
    addGrowth(result, game, run, profileCompleted)
    addMarbles(result, game, run, profileCompleted)
    addBlueFlies(result, game, run, profileCompleted)
    addMomsChest(result, game, profileCompleted)
  end
  addVictoryLap(result, game, run, profileCompleted, victoryLapAllowed)

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
