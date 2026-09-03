local CharacterRelevance = require("scripts.core.character_relevance")
local CompletionMarks = require("scripts.core.completion_marks")
local Routes = {}

local function enum(source, name, fallback)
  return source and source[name] or fallback
end

local STAGE = {
  BASEMENT1=enum(LevelStage,"STAGE1_1",1), BASEMENT2=enum(LevelStage,"STAGE1_2",2),
  CAVES1=enum(LevelStage,"STAGE2_1",3), CAVES2=enum(LevelStage,"STAGE2_2",4),
  DEPTHS1=enum(LevelStage,"STAGE3_1",5), DEPTHS2=enum(LevelStage,"STAGE3_2",6),
  WOMB1=enum(LevelStage,"STAGE4_1",7), WOMB2=enum(LevelStage,"STAGE4_2",8),
  BLUE_WOMB=enum(LevelStage,"STAGE4_3",9), CHAPTER5=enum(LevelStage,"STAGE5",10),
  CHAPTER6=enum(LevelStage,"STAGE6",11), VOID=enum(LevelStage,"STAGE7",12),
  HOME=enum(LevelStage,"STAGE8",13)
}
local GREED_STAGE = {
  BASEMENT=enum(LevelStage,"STAGE1_GREED",1), CAVES=enum(LevelStage,"STAGE2_GREED",2),
  DEPTHS=enum(LevelStage,"STAGE3_GREED",3), WOMB=enum(LevelStage,"STAGE4_GREED",4),
  SHEOL=enum(LevelStage,"STAGE5_GREED",5), SHOP=enum(LevelStage,"STAGE6_GREED",6),
  FINAL=enum(LevelStage,"STAGE7_GREED",7)
}
local REP_A = enum(StageType,"STAGETYPE_REPENTANCE",4)
local REP_B = enum(StageType,"STAGETYPE_REPENTANCE_B",5)
local ORIGINAL = enum(StageType,"STAGETYPE_ORIGINAL",0)
local WOTL = enum(StageType,"STAGETYPE_WOTL",1)
local ENTITY_URIEL = enum(EntityType,"ENTITY_URIEL",271)
local ENTITY_GABRIEL = enum(EntityType,"ENTITY_GABRIEL",272)
local GRID_STATUE = enum(GridEntityType,"GRID_STATUE",21)
local ROOM_BOSS = enum(RoomType,"ROOM_BOSS",5)
local ROOM_SECRET_EXIT_IDX = enum(GridRooms,"ROOM_SECRET_EXIT_IDX",-10)

local AID_DEFS = {
  knife1={kind="collectible", id=enum(CollectibleType,"COLLECTIBLE_KNIFE_PIECE_1",626), zh="菜刀碎片1", en="Knife Piece 1"},
  knife2={kind="collectible", id=enum(CollectibleType,"COLLECTIBLE_KNIFE_PIECE_2",627), zh="菜刀碎片2", en="Knife Piece 2"},
  key1={kind="collectible", id=enum(CollectibleType,"COLLECTIBLE_KEY_PIECE_1",238), zh="钥匙碎片1", en="Key Piece 1"},
  key2={kind="collectible", id=enum(CollectibleType,"COLLECTIBLE_KEY_PIECE_2",239), zh="钥匙碎片2", en="Key Piece 2"},
  polaroid={kind="collectible", id=enum(CollectibleType,"COLLECTIBLE_POLAROID",327), zh="全家福", en="The Polaroid"},
  negative={kind="collectible", id=enum(CollectibleType,"COLLECTIBLE_NEGATIVE",328), zh="底片", en="The Negative"},
  dads_note={kind="collectible", id=enum(CollectibleType,"COLLECTIBLE_DADS_NOTE",668), zh="爸爸的便条", en="Dad's Note"},
  red_key={kind="collectible", id=enum(CollectibleType,"COLLECTIBLE_RED_KEY",580), zh="红钥匙", en="Red Key"},
  sharp_key={kind="collectible", id=enum(CollectibleType,"COLLECTIBLE_SHARP_KEY",623), zh="尖头钥匙", en="Sharp Key"},
  cracked_orb={kind="collectible", id=enum(CollectibleType,"COLLECTIBLE_CRACKED_ORB",675), zh="碎裂的宝珠", en="Cracked Orb"},
  r_key={kind="collectible", id=enum(CollectibleType,"COLLECTIBLE_R_KEY",636), zh="R Key", en="R Key"},
  mama_mega={kind="collectible", id=enum(CollectibleType,"COLLECTIBLE_MAMA_MEGA",483), zh="超级妈妈！", en="Mama Mega!"},
  mega_bean={kind="collectible", id=enum(CollectibleType,"COLLECTIBLE_MEGA_BEAN",351), zh="超级豆子", en="Mega Bean"},
  dads_key={kind="collectible", id=enum(CollectibleType,"COLLECTIBLE_DADS_KEY",175), zh="爸爸的钥匙", en="Dad's Key"},
  mr_me={kind="collectible", id=enum(CollectibleType,"COLLECTIBLE_MR_ME",527), zh="店长先生！", en="Mr. ME!"},
  deeper={kind="collectible", id=enum(CollectibleType,"COLLECTIBLE_WE_NEED_GO_DEEPER",84), zh="我们需要深入挖掘！", en="We Need to Go Deeper!"},
  broken_shovel={kind="collectible", id=enum(CollectibleType,"COLLECTIBLE_BROKEN_SHOVEL",550), zh="铲子碎片", en="Broken Shovel"},
  strange_key={kind="trinket", id=enum(TrinketType,"TRINKET_STRANGE_KEY",175), zh="奇怪的钥匙", en="Strange Key"},
  faded_polaroid={kind="trinket", id=enum(TrinketType,"TRINKET_FADED_POLAROID",69), zh="褪色的全家福", en="Faded Polaroid"},
  broken_padlock={kind="trinket", id=enum(TrinketType,"TRINKET_BROKEN_PADLOCK",136), zh="坏掉的挂锁", en="Broken Padlock"},
  soul_cain={kind="card", id=enum(Card,"CARD_SOUL_CAIN",83), zh="该隐的魂石", en="Soul of Cain"},
  cracked_key={kind="card", id=enum(Card,"CARD_CRACKED_KEY",78), zh="红钥匙碎片", en="Cracked Key"},
  jail_free={kind="card", id=enum(Card,"CARD_GET_OUT_OF_JAIL",47), zh="免费出狱卡", en="Get Out of Jail Free"},
  ehwaz={kind="card", id=enum(Card,"RUNE_EHWAZ",34), zh="黑符文·艾瓦兹", en="Ehwaz"}
}

local function localText(language, zh, en)
  return language == "zh" and zh or en
end

local function message(zh, en) return {zh=zh, en=en} end

local function combineMessages(first, second)
  if not first then return second end
  if not second then return first end
  return message(first.zh .. " " .. second.zh, first.en .. " " .. second.en)
end

local MAIN_PATH_STEPS = {
  [STAGE.BASEMENT1]={
    current=message("击败本层头目后，进入地下室II/下水道I。","Defeat this floor's boss, then enter Basement II or Downpour I."),
    next=message("地下室II：进入洞穴I/下水道II；下水道I：进入下水道II。","Basement II: enter Caves I/Downpour II; Downpour I: enter Downpour II."),
    lockedCurrent=message("击败本层头目后，进入地下室II。","Defeat this floor's boss, then enter Basement II."),
    lockedNext=message("地下室II：进入洞穴I。","Basement II: enter Caves I.")
  },
  [STAGE.BASEMENT2]={
    current=message("击败本层头目后，进入洞穴I/下水道II。","Defeat this floor's boss, then enter Caves I or Downpour II."),
    next=message("洞穴I：进入洞穴II/矿层I；下水道II：进入洞穴II/矿层I。","Caves I: enter Caves II/Mines I; Downpour II: enter Caves II/Mines I."),
    lockedCurrent=message("击败本层头目后，进入洞穴I。","Defeat this floor's boss, then enter Caves I."),
    lockedNext=message("洞穴I：进入洞穴II。","Caves I: enter Caves II.")
  },
  [STAGE.CAVES1]={
    current=message("击败本层头目后，进入洞穴II/矿层I。","Defeat this floor's boss, then enter Caves II or Mines I."),
    next=message("洞穴II：进入深牢I/矿层II；矿层I：进入矿层II。","Caves II: enter Depths I/Mines II; Mines I: enter Mines II."),
    lockedCurrent=message("击败本层头目后，进入洞穴II。","Defeat this floor's boss, then enter Caves II."),
    lockedNext=message("洞穴II：进入深牢I。","Caves II: enter Depths I.")
  },
  [STAGE.CAVES2]={
    current=message("击败本层头目后，进入深牢I/矿层II。","Defeat this floor's boss, then enter Depths I or Mines II."),
    next=message("深牢I：进入深牢II/陵墓I；矿层II：进入深牢II/陵墓I。","Depths I: enter Depths II/Mausoleum I; Mines II: enter Depths II/Mausoleum I."),
    lockedCurrent=message("击败本层头目后，进入深牢I。","Defeat this floor's boss, then enter Depths I."),
    lockedNext=message("深牢I：进入深牢II。","Depths I: enter Depths II.")
  },
  [STAGE.DEPTHS1]={
    current=message("击败本层头目后，进入深牢II/陵墓I。","Defeat this floor's boss, then enter Depths II or Mausoleum I."),
    next=message("深牢II：进入子宫I；陵墓I：进入陵墓II。","Depths II: enter Womb I; Mausoleum I: enter Mausoleum II."),
    lockedCurrent=message("击败本层头目后，进入深牢II。","Defeat this floor's boss, then enter Depths II."),
    lockedNext=message("深牢II：进入子宫I。","Depths II: enter Womb I."),
    mainCurrent=message("击败本层头目后，进入普通深牢II。","Defeat this floor's boss, then enter normal Depths II."),
    mainNext=message("在深牢II击败 Mom 后进入子宫I。","Defeat Mom in Depths II, then enter Womb I."),
    altCurrent=message("击败本层头目后，进入陵墓I。","Defeat this floor's boss, then enter Mausoleum I."),
    altNext=message("陵墓I：进入陵墓II。","Mausoleum I: enter Mausoleum II.")
  },
  [STAGE.DEPTHS2]={
    current=message("击败 Mom 后，进入子宫I。","Defeat Mom, then enter Womb I."),
    next=message("子宫I：进入子宫II。","Womb I: enter Womb II.")
  },
  [STAGE.WOMB1]={
    current=message("击败本层头目后，进入子宫II。","Defeat this floor's boss, then enter Womb II."),
    next=message("在子宫II击败 Mom's Heart/It Lives! 并选择目标入口。","Defeat Mom's Heart/It Lives! in Womb II and take the required exit.")
  }
}

local ALT_PATH_STEPS = {
  [STAGE.BASEMENT1]={
    current=message("击败本层头目后，进入下水道II。","Defeat this floor's boss, then enter Downpour II."),
    next=message("下水道II：进入洞穴II/矿层I。","Downpour II: enter Caves II/Mines I.")
  },
  [STAGE.BASEMENT2]={
    current=message("击败本层头目后，进入洞穴II/矿层I。","Defeat this floor's boss, then enter Caves II or Mines I."),
    next=message("洞穴II：进入深牢I/矿层II；矿层I：进入矿层II。","Caves II: enter Depths I/Mines II; Mines I: enter Mines II.")
  },
  [STAGE.CAVES1]={
    current=message("击败本层头目后，进入矿层II。","Defeat this floor's boss, then enter Mines II."),
    next=message("矿层II：进入深牢II/陵墓I。","Mines II: enter Depths II/Mausoleum I.")
  },
  [STAGE.CAVES2]={
    current=message("击败本层头目后，进入深牢II/陵墓I。","Defeat this floor's boss, then enter Depths II or Mausoleum I."),
    next=message("深牢II：进入子宫I；陵墓I：进入陵墓II。","Depths II: enter Womb I; Mausoleum I: enter Mausoleum II."),
    mainCurrent=message("击败本层头目后，进入普通深牢II。","Defeat this floor's boss, then enter normal Depths II."),
    mainNext=message("在深牢II击败 Mom 后进入子宫I。","Defeat Mom in Depths II, then enter Womb I."),
    altCurrent=message("击败本层头目后，进入陵墓I。","Defeat this floor's boss, then enter Mausoleum I."),
    altNext=message("陵墓I：进入陵墓II。","Mausoleum I: enter Mausoleum II.")
  },
  [STAGE.DEPTHS1]={
    current=message("击败本层头目后，进入陵墓II。","Defeat this floor's boss, then enter Mausoleum II."),
    next=message("在陵墓II击败强化 Mom 后进入子宫II。","Defeat the stronger Mom in Mausoleum II, then enter Womb II.")
  },
  [STAGE.DEPTHS2]={
    current=message("击败强化 Mom 后，进入子宫II。","Defeat the stronger Mom, then enter Womb II."),
    next=message("在子宫II击败 Mom's Heart/It Lives! 并选择目标入口。","Defeat Mom's Heart/It Lives! in Womb II and take the required exit.")
  }
}

local GREED_PATH_STEPS = {
  [GREED_STAGE.BASEMENT]=message("完成本层波次并进入洞穴。","Clear this floor's waves and enter Caves."),
  [GREED_STAGE.CAVES]=message("完成本层波次并进入深牢。","Clear this floor's waves and enter Depths."),
  [GREED_STAGE.DEPTHS]=message("完成本层波次并进入子宫。","Clear this floor's waves and enter Womb."),
  [GREED_STAGE.WOMB]=message("完成本层波次并进入阴间。","Clear this floor's waves and enter Sheol."),
  [GREED_STAGE.SHEOL]=message("完成本层波次并进入商店层。","Clear this floor's waves and enter The Shop."),
  [GREED_STAGE.SHOP]=message("完成商店层并进入究极贪婪层。","Finish The Shop and enter the Ultra Greed floor.")
}

local function secretExitUnlocked()
  if not Isaac or type(Isaac.GetPersistentGameData) ~= "function" then return nil end
  local okData, persistentData = pcall(Isaac.GetPersistentGameData)
  if not okData or not persistentData then return nil end
  local okUnlock, unlocked = pcall(function() return persistentData:Unlocked(407) end)
  if not okUnlock then return nil end
  return unlocked == true
end

local function aidNames(context, keys, language)
  local result = {}
  for _, key in ipairs(keys or {}) do
    if context.aids[key] then
      local aid = AID_DEFS[key]
      table.insert(result, localText(language, aid.zh, aid.en))
    end
  end
  return result
end

local function hasAny(context, keys)
  for _, key in ipairs(keys or {}) do if context.aids[key] then return true end end
  return false
end

local function routeResult(current, nextStep, severity, alternatives)
  return { current=current, next=nextStep, severity=severity or "normal",
    alternatives=alternatives or {} }
end

local function isRepentanceFloor(context)
  return context.stageType == REP_A or context.stageType == REP_B
end

local function mainPathStep(context, policy)
  local alternate = isRepentanceFloor(context)
  local step = (alternate and ALT_PATH_STEPS or MAIN_PATH_STEPS)[context.stage]
  if not step then return nil end
  if policy == "main" then
    if alternate and context.stage == STAGE.DEPTHS1 then return nil end
    return {current=step.mainCurrent or step.current, next=step.mainNext or step.next}
  elseif policy == "alternate" then
    if not alternate and context.secretExitUnlocked == false then return nil end
    if step.altCurrent then return {current=step.altCurrent, next=step.altNext} end
  end
  if not alternate and context.secretExitUnlocked == false and step.lockedCurrent then
    return {current=step.lockedCurrent, next=step.lockedNext}
  end
  return {current=step.current, next=step.next}
end

local function pathResult(context, severity, alternatives, currentExtra, nextExtra, policy)
  local step = mainPathStep(context, policy)
  if not step then return nil end
  return routeResult(combineMessages(step.current, currentExtra),
    combineMessages(step.next, nextExtra), severity, alternatives)
end

local function scanGroundAids(context)
  if not Isaac or type(Isaac.GetRoomEntities) ~= "function" then return end
  for _, entity in ipairs(Isaac.GetRoomEntities()) do
    local pickup = entity.ToPickup and entity:ToPickup() or nil
    if pickup then
      local collecting = pickup.GetSprite and pickup:GetSprite():IsPlaying("Collect")
      for key, aid in pairs(AID_DEFS) do
        local variant = aid.kind == "collectible" and enum(PickupVariant,"PICKUP_COLLECTIBLE",100)
          or aid.kind == "trinket" and enum(PickupVariant,"PICKUP_TRINKET",350)
          or enum(PickupVariant,"PICKUP_TAROTCARD",300)
        if not collecting and pickup.Variant == variant and pickup.SubType == aid.id then
          context.aids[key] = true
          context.groundAids[key] = true
        end
      end
    end
  end
end

local function scanGroundTrinkets(context)
  if not Isaac or type(Isaac.GetRoomEntities) ~= "function" then return end
  local trinketVariant = enum(PickupVariant,"PICKUP_TRINKET",350)
  for _, entity in ipairs(Isaac.GetRoomEntities()) do
    local pickup = entity.ToPickup and entity:ToPickup() or nil
    local collecting = pickup and pickup.GetSprite
      and pickup:GetSprite():IsPlaying("Collect")
    if pickup and not collecting and pickup.Variant == trinketVariant and pickup.SubType > 0 then
      table.insert(context.groundTrinkets, {
        pickupSeed=tostring(pickup.InitSeed), subtype=pickup.SubType
      })
    end
  end
end

local function scanTrapdoors(context, room)
  if not room or type(room.GetGridSize) ~= "function" then return end
  for index = 0, room:GetGridSize() - 1 do
    local grid = room:GetGridEntity(index)
    if grid and grid.GetType and grid:GetType() == enum(GridEntityType,"GRID_TRAPDOOR",17) then
      local variant = grid.GetVariant and grid:GetVariant() or 0
      local varData = tonumber(grid.VarData) or 0
      if variant == 1 or varData == 1 then context.voidPortal = true end
      if variant == 0 and varData ~= 1 then context.normalTrapdoor = true end
    end
  end
end

local function scanExitDoors(context, room)
  if context.roomType ~= ROOM_BOSS or not room or type(room.GetDoor) ~= "function" then return end
  for slot = 0, 7 do
    local door = room:GetDoor(slot)
    if door and door.TargetRoomIndex == ROOM_SECRET_EXIT_IDX then
      context.secretExitDoor = true
      return
    end
  end
end

local function floorBossDefeated(level)
  if not level or type(level.GetRooms) ~= "function" then return false end
  local rooms = level:GetRooms()
  local found = false
  for index = 0, rooms.Size - 1 do
    local descriptor = rooms:Get(index)
    if descriptor and descriptor.Data and descriptor.Data.Type == ROOM_BOSS then
      found = true
      if not descriptor.Clear then return false end
    end
  end
  return found
end

local function scanAngelRoom(context, room)
  if context.roomType ~= enum(RoomType,"ROOM_ANGEL",15) then return end
  if Isaac and type(Isaac.GetRoomEntities) == "function" then
    for _, entity in ipairs(Isaac.GetRoomEntities()) do
      local alive = not entity.IsDead or not entity:IsDead()
      if alive and (entity.Type == ENTITY_URIEL or entity.Type == ENTITY_GABRIEL) then
        context.angelAlive = true
      end
    end
  end
  if not room or type(room.GetGridSize) ~= "function" then return end
  for index = 0, room:GetGridSize() - 1 do
    local grid = room:GetGridEntity(index)
    if grid and grid.GetType and grid:GetType() == GRID_STATUE
      and (grid.State == nil or grid.State == 0) then
      context.angelStatue = true
    end
  end
end

function Routes.context(game, run)
  local level, room = game:GetLevel(), game:GetRoom()
  local floorAids = run and run.routeFloorAids and run.routeFloorAids.aids or {}
  local context = {
    stage=level:GetStage(), stageType=level:GetStageType(), elapsed=math.floor(game.TimeCounter / 30),
    roomType=room:GetType(), roomIndex=level:GetCurrentRoomIndex(),
    greed=game:IsGreedMode(), players={}, aids={}, heldAids={}, groundAids={}, groundTrinkets={},
    voidPortal=false, normalTrapdoor=false, secretExitDoor=false,
    bossDefeated=floorBossDefeated(level), angelAlive=false, angelStatue=false, hasBomb=false,
    routeItems=run and run.routeItems or {}, routeEvents=run and run.routeEvents or {},
    floorAids=floorAids,
    secretExitUnlocked=secretExitUnlocked()
  }
  for key in pairs(floorAids) do context.aids[key] = true end
  local ok, ascent = pcall(function() return level:IsAscent() end)
  context.ascent = ok and ascent == true
  for index = 0, game:GetNumPlayers() - 1 do
    local player = Isaac.GetPlayer(index)
    local playerType = CharacterRelevance.normalize(player:GetPlayerType())
    context.players[playerType] = true
    if (player.GetNumBombs and player:GetNumBombs() > 0)
      or (player.HasGoldenBomb and player:HasGoldenBomb()) then context.hasBomb = true end
    for key, aid in pairs(AID_DEFS) do
      local held = aid.kind == "collectible" and player.HasCollectible
          and player:HasCollectible(aid.id)
        or aid.kind == "trinket" and player.HasTrinket and player:HasTrinket(aid.id)
      if held then
        context.aids[key] = true
        context.heldAids[key] = true
      elseif aid.kind == "card" and player.GetCard then
        if player:GetCard(0) == aid.id or player:GetCard(1) == aid.id then
          context.aids[key] = true
          context.heldAids[key] = true
        end
      end
    end
  end
  scanGroundAids(context)
  scanGroundTrinkets(context)
  scanTrapdoors(context, room)
  scanExitDoors(context, room)
  scanAngelRoom(context, room)
  for _, key in ipairs({"knife1","knife2","key1","key2","dads_note"}) do
    if context.routeItems[key] then context.aids[key] = true end
  end
  return context
end

local NORMAL_EXITS = {
  [STAGE.BASEMENT1]={ main={zh="进入地下室II",en="Enter Basement II"},
    alt={zh="进入下水道I",en="Enter Downpour I"} },
  [STAGE.BASEMENT2]={ main={zh="进入洞穴I",en="Enter Caves I"},
    alt={zh="进入下水道II",en="Enter Downpour II"} },
  [STAGE.CAVES1]={ main={zh="进入洞穴II",en="Enter Caves II"},
    alt={zh="进入矿层I",en="Enter Mines I"} },
  [STAGE.CAVES2]={ main={zh="进入深牢I",en="Enter Depths I"},
    alt={zh="进入矿层II",en="Enter Mines II"} },
  [STAGE.DEPTHS1]={ main={zh="进入深牢II",en="Enter Depths II"},
    alt={zh="进入陵墓I",en="Enter Mausoleum I"} },
  [STAGE.DEPTHS2]={ main={zh="进入子宫I",en="Enter Womb I"} },
  [STAGE.WOMB1]={ main={zh="进入子宫II",en="Enter Womb II"} }
}

local REPENTANCE_EXITS = {
  [STAGE.BASEMENT1]={ main={zh="进入下水道II",en="Enter Downpour II"} },
  [STAGE.BASEMENT2]={ main={zh="进入洞穴II",en="Enter Caves II"},
    alt={zh="进入矿层I",en="Enter Mines I"} },
  [STAGE.CAVES1]={ main={zh="进入矿层II",en="Enter Mines II"} },
  [STAGE.CAVES2]={ main={zh="进入深牢II",en="Enter Depths II"},
    alt={zh="进入陵墓I",en="Enter Mausoleum I"} },
  [STAGE.DEPTHS1]={ main={zh="进入陵墓II",en="Enter Mausoleum II"} }
}

function Routes.compactActions(context, language)
  if not context or context.greed then return nil end
  local exits = (isRepentanceFloor(context) and REPENTANCE_EXITS or NORMAL_EXITS)[context.stage]
  if not exits then return nil end
  local exitHere = context.normalTrapdoor or context.secretExitDoor
  if not context.bossDefeated then
    if not exitHere then
      return { { text=localText(language,"击败本层头目","Defeat this floor's boss"), available=true } }
    end
  end
  if not exitHere and context.roomType ~= ROOM_BOSS then
    return { { text=localText(language,"返回头目房选择出口","Return to the Boss Room and choose an exit"),
      available=true } }
  end
  local actions = {
    { text=exits.main[language] or exits.main.en, available=context.normalTrapdoor }
  }
  if exits.alt then
    actions[#actions + 1] = {
      text=exits.alt[language] or exits.alt.en, available=context.secretExitDoor
    }
  end
  return actions
end

local function isCrackedKeyRoom(roomType)
  return roomType == enum(RoomType,"ROOM_TREASURE",4)
    or roomType == enum(RoomType,"ROOM_BOSS",5)
end

local function sameRecordedRoom(record, context)
  return record and record.stage == context.stage and record.stageType == context.stageType
    and record.roomIndex == context.roomIndex
end

local function groundTrinketSeeds(context)
  local seeds = {}
  for _, trinket in ipairs(context.groundTrinkets or {}) do
    seeds[trinket.pickupSeed] = true
  end
  return seeds
end

function Routes.beginFloor(run, stage, stageType, seed)
  if not run then return false end
  local current = run.routeFloorAids
  if current and current.stage == stage and current.stageType == stageType
    and current.seed == seed then return false end
  run.routeFloorAids = { stage=stage, stageType=stageType, seed=seed, aids={} }
  return true
end

function Routes.updateRun(run, context, trackTaintedUnlock)
  run.routeItems = run.routeItems or {}
  run.routeEvents = run.routeEvents or {}
  local heldAids = context.heldAids or {}
  local changed = false
  local floorAids = run.routeFloorAids and run.routeFloorAids.aids
  if floorAids then
    for key in pairs(heldAids) do
      if not floorAids[key] then floorAids[key], changed = true, true end
    end
    for key in pairs(context.groundAids or {}) do
      if not floorAids[key] then floorAids[key], changed = true, true end
    end
  end
  for _, key in ipairs({"knife1","knife2","key1","key2","dads_note"}) do
    if context.aids[key] and not run.routeItems[key] then
      run.routeItems[key] = true
      changed = true
    end
  end
  local routeEvents = run.routeEvents
  local ground = context.groundTrinkets or {}
  local candidate = routeEvents.crackedKeyCandidate
  local maintainTaintedState = trackTaintedUnlock or candidate ~= nil
    or routeEvents.crackedKeyPrepared ~= nil or routeEvents.taintedTrinketPending ~= nil
  if maintainTaintedState then
    if candidate and (context.ascent or context.stage == STAGE.HOME
      or not sameRecordedRoom(candidate, context)) then
      routeEvents.crackedKeyPrepared = {
        stage=candidate.stage, stageType=candidate.stageType,
        roomType=candidate.roomType, roomIndex=candidate.roomIndex,
        pickupSeed=candidate.pickupSeed
      }
      routeEvents.crackedKeyCandidate = nil
      routeEvents.taintedTrinketPending = nil
      candidate = nil
      changed = true
    end

    if context.ascent or context.stage == STAGE.HOME then
      if routeEvents.taintedTrinketPending ~= nil then
        routeEvents.taintedTrinketPending = nil
        changed = true
      end
    else
      if candidate and sameRecordedRoom(candidate, context) and #ground == 0 then
        routeEvents.crackedKeyCandidate = nil
        routeEvents.taintedTrinketPending = true
        candidate = nil
        changed = true
      end

      if trackTaintedUnlock and not heldAids.red_key and not heldAids.cracked_key
        and isCrackedKeyRoom(context.roomType) and #ground > 0 then
        local seeds = groundTrinketSeeds(context)
        local first = ground[1]
        local sameCandidate = candidate and sameRecordedRoom(candidate, context)
          and candidate.pickupSeeds and candidate.pickupSeeds[first.pickupSeed]
        if not sameCandidate then
          routeEvents.crackedKeyCandidate = {
            stage=context.stage, stageType=context.stageType,
            roomType=context.roomType, roomIndex=context.roomIndex,
            pickupSeed=first.pickupSeed, pickupSeeds=seeds
          }
          changed = true
        else
          candidate.pickupSeeds = seeds
        end
        if routeEvents.taintedTrinketPending ~= nil then
          routeEvents.taintedTrinketPending = nil
          changed = true
        end
      elseif trackTaintedUnlock and not heldAids.red_key and not heldAids.cracked_key
        and #ground > 0 and not routeEvents.crackedKeyPrepared
        and routeEvents.taintedTrinketPending ~= true then
        routeEvents.taintedTrinketPending = true
        changed = true
      end
    end
  end
  return changed
end

function Routes.observePickup(run, pickup, game, trackTaintedUnlock)
  if not run or not pickup or not game
    or pickup.Variant ~= enum(PickupVariant,"PICKUP_TRINKET",350)
    or pickup.SubType <= 0 then return false end
  run.routeEvents = run.routeEvents or {}
  local routeEvents = run.routeEvents
  local candidate = routeEvents.crackedKeyCandidate
  local prepared = routeEvents.crackedKeyPrepared
  if not trackTaintedUnlock and not candidate and not prepared then return false end
  local level, room = game:GetLevel(), game:GetRoom()
  local seed = tostring(pickup.InitSeed)
  local collecting = pickup.GetSprite and pickup:GetSprite():IsPlaying("Collect")
  if collecting then
    if candidate and candidate.pickupSeeds and candidate.pickupSeeds[seed] then
      candidate.pickupSeeds[seed] = nil
      if next(candidate.pickupSeeds) == nil then
        routeEvents.crackedKeyCandidate = nil
        routeEvents.taintedTrinketPending = true
      else
        candidate.pickupSeed = next(candidate.pickupSeeds)
      end
      return true
    end
    if prepared and prepared.pickupSeed == seed then
      routeEvents.crackedKeyPrepared = nil
      routeEvents.taintedTrinketPending = true
      return true
    end
    return false
  end
  local okAscent, ascent = pcall(function() return level:IsAscent() end)
  if okAscent and ascent or level:GetStage() == STAGE.HOME then return false end
  if not trackTaintedUnlock then return false end
  if isCrackedKeyRoom(room:GetType()) then
    local sameRoom = candidate and candidate.stage == level:GetStage()
      and candidate.stageType == level:GetStageType()
      and candidate.roomIndex == level:GetCurrentRoomIndex()
    if sameRoom and candidate.pickupSeeds and not candidate.pickupSeeds[seed] then
      candidate.pickupSeeds[seed] = true
      return true
    elseif not sameRoom or not candidate.pickupSeeds then
      routeEvents.crackedKeyCandidate = {
        stage=level:GetStage(), stageType=level:GetStageType(), roomType=room:GetType(),
        roomIndex=level:GetCurrentRoomIndex(), pickupSeed=seed, pickupSeeds={[seed]=true}
      }
      routeEvents.taintedTrinketPending = nil
      return true
    end
  elseif not routeEvents.crackedKeyPrepared and routeEvents.taintedTrinketPending ~= true then
    routeEvents.taintedTrinketPending = true
    return true
  end
  return false
end

function Routes.resetAttempt(run)
  run.routeItems = {}
  run.routeEvents = {}
  run.routeFloorAids = {}
end

local function motherRoute(context, language)
  local knife1, knife2 = context.aids.knife1, context.aids.knife2
  local bypassKeys = {"sharp_key","soul_cain","cracked_orb"}
  local bypass = hasAny(context, bypassKeys)
  local alternatives = aidNames(context, bypassKeys, language)
  local stage, alt = context.stage, isRepentanceFloor(context)
  if context.secretExitUnlocked == false and not alt then
    return routeResult(message("尚未解锁秘密出口，当前无法进入 Mother 路线。","A Secret Exit is not unlocked, so the Mother route is unavailable."),
      message("先击败死寂3次以解锁下水道、矿层和陵墓入口。","Defeat Hush three times to unlock Downpour, Mines, and Mausoleum."), "failed")
  end
  if stage == STAGE.BASEMENT1 and alt then
    return routeResult(message("击败本层头目后，进入下水道II。","Defeat this floor's boss, then enter Downpour II."),
      message("在下水道II的镜像世界拾取菜刀碎片1。","Take Knife Piece 1 from the mirrored world in Downpour II."))
  elseif stage == STAGE.BASEMENT1 then
    return routeResult(message("击败本层头目后，进入地下室II/下水道I。","Defeat this floor's boss, then enter Basement II or Downpour I."),
      message("地下室II：进入下水道II（最后机会）；下水道I：进入下水道II。","Basement II: enter Downpour II (last chance); Downpour I: enter Downpour II."))
  elseif stage == STAGE.BASEMENT2 and not alt then
    return routeResult(message("击败本层头目后，进入下水道II（最后机会）。","Defeat this floor's boss, then enter Downpour II (last chance)."),
      message("在镜像世界的宝箱房拾取菜刀碎片1。","Take Knife Piece 1 from the mirrored Treasure Room."), "warning")
  elseif stage == STAGE.BASEMENT2 and alt and not knife1 then
    return routeResult(message("触碰白火，以游魂形态穿过镜子并拾取菜刀碎片1。","Touch the white fire, enter the mirror as The Lost, and take Knife Piece 1."),
      message("击败本层头目后进入洞穴II/矿层I；洞穴II仍可进入矿层II。","After the boss, enter Caves II or Mines I; Caves II still leads to Mines II."))
  elseif stage == STAGE.BASEMENT2 and alt then
    return routeResult(message("已取得菜刀碎片1；击败本层头目后进入洞穴II/矿层I。","Knife Piece 1 is secured; defeat this floor's boss and enter Caves II or Mines I."),
      message("洞穴II：进入矿层II（最后机会）；矿层I：进入矿层II。","Caves II: enter Mines II (last chance); Mines I: enter Mines II."))
  elseif stage == STAGE.CAVES1 then
    if not knife1 and not bypass then
      return routeResult(message("已错过菜刀碎片1，标准 Mother 路线失败。","Knife Piece 1 was missed; the standard Mother route has failed."),
        message("若之后遇到可开启肉门的道具，路线会自动恢复。","The route can recover if a flesh-door bypass appears later."), "failed")
    end
    if not knife1 and bypass then
      if alt then
        return routeResult(message("保留肉门替代工具；击败本层头目后进入矿层II。","Keep the flesh-door bypass; defeat this floor's boss and enter Mines II."),
          message("矿层II：进入陵墓I，并用替代工具开启肉门。","Mines II: enter Mausoleum I; use the bypass on the flesh door."), "warning", alternatives)
      end
      return routeResult(message("保留肉门替代工具；击败本层头目后进入洞穴II/矿层I。","Keep the flesh-door bypass; defeat this floor's boss and enter Caves II or Mines I."),
        message("洞穴II：进入深牢I/矿层II；之后进入陵墓I。","Caves II: enter Depths I/Mines II; then enter Mausoleum I."), "warning", alternatives)
    end
    if alt then
      return routeResult(message("击败本层头目后，进入矿层II。","Defeat this floor's boss, then enter Mines II."),
        message("在矿层II取得菜刀碎片2，再进入陵墓I。","Take Knife Piece 2 in Mines II, then enter Mausoleum I."), "normal", alternatives)
    end
    return routeResult(message("击败本层头目后，进入洞穴II/矿层I。","Defeat this floor's boss, then enter Caves II or Mines I."),
      message("洞穴II：进入矿层II（最后机会）；矿层I：进入矿层II。","Caves II: enter Mines II (last chance); Mines I: enter Mines II."), "normal", alternatives)
  elseif stage == STAGE.CAVES2 and not alt then
    if not knife1 and not bypass then
      return routeResult(message("已错过水层，且没有肉门替代工具。","The water path was missed and no flesh-door bypass is available."),
        message("遇到尖头钥匙、该隐魂石或碎裂宝珠可恢复。","Sharp Key, Soul of Cain, or Cracked Orb can recover the route."), "failed")
    end
    if not knife1 and bypass then
      return routeResult(message("保留肉门替代工具；击败本层头目后进入深牢I/矿层II。","Keep the flesh-door bypass; defeat this floor's boss and enter Depths I or Mines II."),
        message("深牢I/矿层II：进入陵墓I，并用替代工具开启肉门。","From Depths I/Mines II, enter Mausoleum I and use the bypass on the flesh door."), "warning", alternatives)
    end
    return routeResult(message("击败本层头目后，进入矿层II（最后机会）。","Defeat this floor's boss, then enter Mines II (last chance)."),
      message("按下三枚黄色按钮，进入矿车区域拾取菜刀碎片2并逃生。","Press three yellow buttons, take Knife Piece 2, and escape the chase."), "warning", alternatives)
  elseif stage == STAGE.CAVES2 and alt and not knife2 then
    if not knife1 and bypass then
      return routeResult(message("保留肉门替代工具并击败本层头目。","Keep the flesh-door bypass and defeat this floor's boss."),
        message("进入陵墓I；之后在陵墓II用替代工具开启肉门。","Enter Mausoleum I; use the bypass on the flesh door in Mausoleum II."), "warning", alternatives)
    end
    return routeResult(message("按下三枚黄色按钮，乘矿车取得菜刀碎片2并逃生。","Press three yellow buttons, ride the minecart, take Knife Piece 2, and escape."),
      message("击败本层头目后进入陵墓I。","Defeat this floor's boss, then enter Mausoleum I."), "normal", alternatives)
  elseif stage == STAGE.CAVES2 and alt then
    return routeResult(message("完整菜刀已取得；击败本层头目后进入陵墓I。","The knife is complete; defeat this floor's boss and enter Mausoleum I."),
      message("陵墓I：进入陵墓II；在陵墓II开启红色肉门。","Mausoleum I: enter Mausoleum II; open the red flesh door in Mausoleum II."), "normal", alternatives)
  elseif stage == STAGE.DEPTHS1 and not alt then
    if not knife2 and not bypass then
      return routeResult(message("已错过完整菜刀，Mother 路线失败。","The completed knife was missed; the Mother route has failed."),
        message("若当前或之后遇到肉门替代工具，路线会恢复。","A flesh-door bypass can still recover the route."), "failed")
    end
    return routeResult(message("击败本层头目后进入陵墓I（最后机会）。","Defeat this floor's boss, then enter Mausoleum I (last chance)."),
      message("在陵墓II击败强化 Mom 并开启红色肉门。","In Mausoleum II, defeat Mom and open the red flesh door."), "warning", alternatives)
  elseif (stage == STAGE.DEPTHS1 or stage == STAGE.DEPTHS2) and alt then
    if stage == STAGE.DEPTHS2 and context.routeEvents.fleshHeartDefeated then
      return routeResult(message("特殊 Mom's Heart 已击败，进入新出现的尸宫活板门。","The special Mom's Heart is defeated; take the new Corpse trapdoor."),
        message("探索尸宫并前往尸宫II。","Explore Corpse and continue to Corpse II."), "normal", alternatives)
    elseif stage == STAGE.DEPTHS2 and context.routeEvents.mausoleumMomDefeated then
      return routeResult(message("用完整菜刀或可用替代工具开启红色肉门。","Open the red flesh door with the knife or an available bypass."),
        message("进入肉门并击败特殊 Mom's Heart。","Enter the flesh door and defeat the special Mom's Heart."), "normal", alternatives)
    end
    return routeResult(stage == STAGE.DEPTHS1
        and message("击败本层头目后进入陵墓II。","Defeat this floor's boss, then enter Mausoleum II.")
        or message("在陵墓II击败强化 Mom。","Defeat the stronger Mom in Mausoleum II."),
      message("用完整菜刀或可用替代工具开启红色肉门。","Open the red flesh door with the knife or an available bypass."), "normal", alternatives)
  elseif stage == STAGE.DEPTHS2 and not alt then
    return routeResult(message("已进入普通深牢II，无法再进入 Mother 路线。","Normal Depths II was entered; the Mother route is no longer reachable."),
      message("使用 R Key 或楼层重置后会重新评估。","R Key or a route reset will re-evaluate the route."), "failed")
  elseif (stage == STAGE.WOMB1 or stage == STAGE.WOMB2) and alt then
    return routeResult(stage == STAGE.WOMB1
        and message("探索尸宫并前往尸宫II。","Explore Corpse and continue to Corpse II.")
        or message("跳入 Boss 房深坑并击败 Mother。","Drop into the boss-room pit and defeat Mother."),
      stage == STAGE.WOMB1
        and message("在尸宫II跳入 Boss 房深坑并击败 Mother。","In Corpse II, drop into the boss-room pit and defeat Mother.")
        or message("击败后取得 Mother 通关标记。","The Mother mark is awarded on defeat."), "normal", alternatives)
  elseif (stage == STAGE.WOMB1 or stage == STAGE.WOMB2) and not alt then
    return routeResult(message("已进入普通子宫，Mother 路线失败。","Normal Womb was entered; the Mother route has failed."),
      message("使用 R Key 后可重新尝试。","Use R Key to try the route again."), "failed")
  end
  return routeResult(message("继续推进并保持 Mother 路线条件。","Continue while preserving the Mother route."),
    message("最终在尸宫II击败 Mother。","Defeat Mother in Corpse II."), "normal", alternatives)
end

local function beastRoute(context, language)
  local doorKeys = {"polaroid","negative","faded_polaroid","dads_key","sharp_key",
    "soul_cain","cracked_orb","broken_padlock"}
  local alternatives = aidNames(context, doorKeys, language)
  if context.stage == STAGE.HOME then
    return routeResult(message("在客厅睡觉后进入电视房并击败 Dogma。","Sleep in Mom's bed, enter the TV room, and defeat Dogma."),
      message("击败四位究极天启骑士与祸兽。","Defeat the Ultra Harbingers and The Beast."))
  elseif context.ascent then
    return routeResult(message("沿光柱逐层完成回溯。","Follow each beam of light through the Ascent."),
      message("从地下室I的光柱进入家。","Enter Home through the Basement I beam."))
  elseif context.stage < STAGE.DEPTHS2 then
    local result = pathResult(context, "normal", alternatives,
      message("保留传送手段，以便离开 Mom 房。","Keep a teleport ready to leave Mom's room."),
      message("目标是进入普通深牢II并返回奇怪门。","The route must reach normal Depths II and return to the Strange Door."), "main")
    if result then return result end
    return routeResult(message("已进入陵墓I，无法返回普通深牢II开启奇怪门。","Mausoleum I was entered, so normal Depths II and the Strange Door are no longer reachable."),
      message("使用 R Key 或路线重置后重新选择普通深牢II。","Use R Key or reset the route, then choose normal Depths II."), "failed")
  elseif context.stage == STAGE.DEPTHS2 and not isRepentanceFloor(context) then
    return routeResult(message("击败 Mom，取得照片并传送回起始房开启奇怪门。","Defeat Mom, take a photo, teleport out, and open the Strange Door."),
      message("在特殊陵墓II的 Boss 房拾取爸爸的便条。","Take Dad's Note from the special Mausoleum II boss room."), "warning", alternatives)
  elseif context.stage == STAGE.DEPTHS2 and isRepentanceFloor(context) then
    return routeResult(message("前往 Boss 房拾取爸爸的便条。","Reach the boss room and take Dad's Note."),
      message("沿光柱完成回溯并进入家。","Complete the Ascent and enter Home."), "normal", alternatives)
  end
  return routeResult(message("已错过奇怪门，祸兽路线失败。","The Strange Door was missed; the Beast route has failed."),
    message("使用 R Key 或路线重置后可重新尝试。","Use R Key or reset the route to try again."), "failed")
end

local function taintedUnlockRoute(goal, context, language)
  local requiredTypes = CharacterRelevance.requiredPlayerTypes(goal)
  local requiredType, matchingPlayer = next(requiredTypes), next(requiredTypes) == nil
  for playerType in pairs(requiredTypes) do
    requiredType = requiredType or playerType
    if context.players[playerType] then matchingPlayer = true end
  end
  if not matchingPlayer then
    local name = CharacterRelevance.characterName(requiredType) or tostring(requiredType)
    local zhDetail = goal.zh and goal.zh.detail or ""
    local zhName = zhDetail:match("^用(.-)在家") or name
    return routeResult(
      message("当前队伍没有" .. zhName .. "，无法解锁对应堕化角色。",
        "The current team does not include " .. name .. ", so this tainted character cannot be unlocked."),
      message("请使用" .. zhName .. "进入家并开启隐藏衣柜。",
        "Reach Home as " .. name .. " and open the hidden closet."), "failed")
  end

  local routeEvents = context.routeEvents or {}
  local prepared = routeEvents.crackedKeyPrepared
  local candidate = routeEvents.crackedKeyCandidate
  local heldAids = context.heldAids or {}
  local heldKey = heldAids.red_key or heldAids.cracked_key
  local availableKey = context.aids.red_key or context.aids.cracked_key
  if context.stage == STAGE.HOME then
    if heldKey then
      return routeResult(
        message("在妈妈卧室外的走廊使用红钥匙或红钥匙碎片，开启隐藏衣柜。",
          "Use Red Key or Cracked Key in the hallway outside Mom's bedroom to open the hidden closet."),
        message("进入衣柜并触碰里面的角色以完成解锁。",
          "Enter the closet and touch the character inside to complete the unlock."))
    elseif availableKey then
      return routeResult(
        message("拾取当前房间的红钥匙或红钥匙碎片。",
          "Pick up the Red Key or Cracked Key in the current room."),
        message("在妈妈卧室外的走廊使用它开启隐藏衣柜。",
          "Use it in the hallway outside Mom's bedroom to open the hidden closet."), "warning")
    end
    return routeResult(
      message("打开妈妈的箱子寻找红钥匙；当前没有可用的钥匙来源。",
        "Open Mom's Chest and look for Red Key; no key source is currently available."),
      message("若未获得红钥匙，本次将无法保证开启隐藏衣柜。",
        "Without Red Key, opening the hidden closet cannot be guaranteed this run."), "warning")
  elseif context.ascent then
    if heldKey then
      return routeResult(
        message("沿光柱逐层完成回溯，并保留红钥匙或红钥匙碎片。",
          "Follow each beam through the Ascent and keep Red Key or Cracked Key."),
        message("进入家后，在妈妈卧室外开启隐藏衣柜。",
          "At Home, open the hidden closet outside Mom's bedroom."))
    elseif availableKey then
      return routeResult(
        message("拾取当前房间的红钥匙或红钥匙碎片并带回家。",
          "Pick up the Red Key or Cracked Key in this room and carry it to Home."),
        message("在妈妈卧室外使用它开启隐藏衣柜。",
          "Use it outside Mom's bedroom to open the hidden closet."), "warning")
    elseif prepared then
      local roomNameZh = prepared.roomType == enum(RoomType,"ROOM_BOSS",5) and "头目房" or "宝箱房"
      local roomNameEn = prepared.roomType == enum(RoomType,"ROOM_BOSS",5) and "Boss Room" or "Treasure Room"
      if context.stage > prepared.stage then
        return routeResult(
          message("继续沿光柱回溯；尚未到达存放饰品的楼层。",
            "Continue through the Ascent; the floor with the stored trinket is still ahead."),
          message("到达对应楼层后进入" .. roomNameZh .. "拾取红钥匙碎片。",
            "On that floor, enter the " .. roomNameEn .. " and collect Cracked Key."))
      elseif context.stage == prepared.stage then
        return routeResult(
          message("本层进入之前存放饰品的" .. roomNameZh .. "，拾取红钥匙碎片。",
            "Enter the " .. roomNameEn .. " where the trinket was stored and collect Cracked Key."),
          message("取得碎片后继续回溯并将其带到家。",
            "After taking it, continue the Ascent and carry it to Home."), "warning")
      end
      return routeResult(
        message("已经越过存放饰品的楼层，当前没有红钥匙碎片。",
          "The floor with the stored trinket has been passed without collecting Cracked Key."),
        message("继续前往家并检查妈妈的箱子，但本次解锁已无法保证。",
          "Continue to Home and check Mom's Chest, but the unlock is no longer guaranteed."), "warning")
    end
    return routeResult(
      message("继续沿光柱回溯；当前没有已准备的红钥匙碎片。",
        "Continue through the Ascent; no Cracked Key has been prepared."),
      message("进入家后检查妈妈的箱子，但本次解锁无法保证。",
        "Check Mom's Chest at Home, but the unlock cannot be guaranteed."), "warning")
  end

  local prepCurrent, prepNext, severity
  if heldKey then
    prepNext = message("保留红钥匙或红钥匙碎片，进入家后用于开启隐藏衣柜。",
      "Keep Red Key or Cracked Key for the hidden closet at Home.")
  elseif availableKey then
    prepCurrent = message("拾取当前房间的红钥匙或红钥匙碎片并保留到家。",
      "Pick up the Red Key or Cracked Key in this room and keep it for Home.")
    severity = "warning"
  elseif routeEvents.taintedTrinketPending then
    prepCurrent = message("发现了多余饰品：回溯开始前将一枚留在头目房或宝箱房。",
      "A spare trinket was found: leave one in a Boss Room or Treasure Room before the Ascent.")
    severity = "warning"
  elseif candidate then
    prepCurrent = message("当前房间已有用于转化的饰品；离开前不要将它拾回。",
      "A trinket is ready in this room; leave without picking it back up.")
    severity = "warning"
  elseif prepared then
    prepNext = message("饰品已留好；回溯到对应楼层时进入原房间拾取红钥匙碎片。",
      "A trinket is prepared; revisit that room during the Ascent to collect Cracked Key.")
  end

  if context.stage < STAGE.DEPTHS2 then
    local result = pathResult(context, severity or "normal", {},
      combineMessages(message("保留传送手段，以便离开 Mom 房。",
        "Keep a teleport ready to leave Mom's room."), prepCurrent),
      combineMessages(message("目标是进入普通深牢II并返回奇怪门。",
        "Reach normal Depths II and return to the Strange Door."), prepNext), "main")
    if result then return result end
    return routeResult(
      message("已进入陵墓I，无法返回普通深牢II开启奇怪门。",
        "Mausoleum I was entered, so normal Depths II and the Strange Door are no longer reachable."),
      message("使用 R Key 或路线重置后重新选择普通深牢II。",
        "Use R Key or reset the route, then choose normal Depths II."), "failed")
  elseif context.stage == STAGE.DEPTHS2 and not isRepentanceFloor(context) then
    return routeResult(combineMessages(
      message("击败 Mom，取得照片并传送回起始房开启奇怪门。",
        "Defeat Mom, take a photo, teleport out, and open the Strange Door."), prepCurrent),
      combineMessages(message("在特殊陵墓II的头目房拾取爸爸的便条。",
        "Take Dad's Note from the special Mausoleum II boss room."), prepNext),
      severity or "warning")
  elseif context.stage == STAGE.DEPTHS2 and isRepentanceFloor(context) then
    return routeResult(combineMessages(
      message("前往头目房拾取爸爸的便条。",
        "Reach the boss room and take Dad's Note."), prepCurrent),
      combineMessages(message("拾取便条后沿光柱开始回溯。",
        "Take the note, then begin the Ascent through the beam."), prepNext),
      severity or "normal")
  end
  return routeResult(
    message("已错过奇怪门，当前回溯路线失败。",
      "The Strange Door was missed, so the Ascent route has failed."),
    message("使用 R Key 或路线重置后可重新尝试。",
      "Use R Key or reset the route to try again."), "failed")
end

local function bossRushRoute(context, language)
  local deadline = isRepentanceFloor(context) and context.stage == STAGE.DEPTHS2 and 1500 or 1200
  local keys = {"mama_mega","mega_bean","broken_shovel"}
  local alternatives = aidNames(context, keys, language)
  if context.roomType == enum(RoomType,"ROOM_BOSSRUSH",17) then
    return routeResult(message("拾取房间中央的奖励并完成15波头目。","Take a center reward and clear all 15 boss waves."),
      message("最后一波结束后取得头目车轮战标记。","The mark is awarded after the final wave."))
  elseif context.stage > STAGE.DEPTHS2 then
    return routeResult(message("已经离开 Mom 所在楼层，头目车轮战路线失败。","Mom's floor was left; the Boss Rush route has failed."),
      message("使用 R Key 后可重新尝试。","Use R Key to try again."), "failed")
  end
  local canStillChooseMausoleum = context.stage < STAGE.DEPTHS2
    and context.secretExitUnlocked ~= false and context.elapsed < 1500
  local severity = context.elapsed >= deadline and ((#alternatives == 0 and not canStillChooseMausoleum)
      and "failed" or "warning")
    or deadline - context.elapsed <= 300 and "warning" or "normal"
  local current
  if canStillChooseMausoleum and context.elapsed >= 1200 then
    current = message("普通 Mom 的20分钟时限已过；改走陵墓II争取25分钟入口。","The normal 20-minute limit passed; use Mausoleum II's 25-minute entrance.")
  elseif context.elapsed >= deadline and #alternatives > 0 then
    current = message("时限已过；使用当前补救手段开启头目车轮战入口。","The deadline passed; use the available recovery method to open Boss Rush.")
  elseif context.elapsed >= deadline then
    current = message("头目车轮战时限已过，且没有可用补救手段。","The Boss Rush deadline passed with no available recovery method.")
  else
    current = message("在时限内击败 Mom 并进入墙上的头目车轮战入口。","Defeat Mom before the deadline and enter the Boss Rush opening.")
  end
  if context.stage < STAGE.DEPTHS2 then
    local policy = canStillChooseMausoleum and context.elapsed >= 1200 and "alternate" or nil
    local result = pathResult(context, severity, alternatives, current,
      message("抵达 Mom 所在楼层后进入头目车轮战入口。","Enter the Boss Rush opening after reaching Mom's floor."), policy)
    if result then return result end
  end
  return routeResult(current,
    message("拾取一个奖励开始战斗并完成全部15波。","Take one reward to start and clear all 15 waves."), severity, alternatives)
end

local function hushRoute(context, language)
  local keys = {"strange_key","mama_mega","mega_bean"}
  local alternatives = aidNames(context, keys, language)
  if context.stage == STAGE.BLUE_WOMB then
    return routeResult(message("搜刮两个宝箱房与商店后进入巨型 Boss 房。","Loot the two Treasure Rooms and Shop, then enter the giant boss room."),
      message("击败死寂。","Defeat Hush."))
  elseif context.stage > STAGE.WOMB2 then
    return routeResult(message("已错过蓝色子宫入口，死寂路线失败。","The Blue Womb entrance was missed; the Hush route has failed."),
      message("使用 R Key 后可重新尝试。","Use R Key to try again."), "failed")
  elseif isRepentanceFloor(context) and context.stage >= STAGE.WOMB1 then
    return routeResult(message("已进入尸宫，无法前往蓝色子宫。","Corpse was entered, so Blue Womb is no longer reachable."),
      message("使用 R Key 后重新前往普通子宫II。","Use R Key and return to normal Womb II."), "failed")
  end
  local severity = context.elapsed >= 1800 and (#alternatives == 0 and "failed" or "warning")
    or 1800 - context.elapsed <= 300 and "warning" or "normal"
  local deadlineStep = context.elapsed >= 1800
    and (#alternatives > 0
      and message("30分钟时限已过；保留当前补救手段。","The 30-minute limit passed; keep the available recovery method.")
      or message("30分钟时限已过。","The 30-minute limit has passed."))
    or message("保持30分钟时限。","Stay within the 30-minute limit.")
  local result = pathResult(context, severity, alternatives, deadlineStep,
    message("抵达子宫II后击败 Mom's Heart/It Lives! 并进入蓝色裂口。","In Womb II, defeat Mom's Heart/It Lives! and enter the blue opening."))
  if result then return result end
  return routeResult(message("30分钟内击败 Mom's Heart/It Lives! 并进入蓝色裂口。","Defeat Mom's Heart/It Lives! within 30 minutes and enter the blue opening."),
    message("在蓝色子宫击败死寂。","Defeat Hush in Blue Womb."), severity, alternatives)
end

local function branchRoute(mark, context, language)
  local stage = context.stage
  local heldAids = context.heldAids or {}
  if mark == "MOMS_HEART" then
    if stage < STAGE.WOMB2 then
      local result = pathResult(context, "normal", nil, nil,
        message("最终在子宫II击败 Mom's Heart/It Lives!。","Ultimately defeat Mom's Heart/It Lives! in Womb II."))
      if result then return result end
    elseif stage == STAGE.WOMB2 and not isRepentanceFloor(context) then
      return routeResult(message("在本层击败 Mom's Heart/It Lives!。","Defeat Mom's Heart/It Lives! on this floor."),
        message("击败后即取得该通关标记。","The mark is awarded on defeat."))
    end
  elseif mark == "ISAAC" or mark == "BLUE_BABY" then
    if stage < STAGE.CHAPTER5 then
      if mark == "BLUE_BABY" and stage == STAGE.DEPTHS2
        and context.routeEvents.momDefeated and not heldAids.polaroid then
        return routeResult(message("Mom 已击败：拾取全家福。","Mom is defeated: take The Polaroid."),
          message("之后击败 Mom's Heart/It Lives!，进入教堂。","Then defeat Mom's Heart/It Lives! and enter Cathedral."))
      elseif mark == "BLUE_BABY" and stage > STAGE.DEPTHS2 and not heldAids.polaroid then
        return routeResult(message("离开 Mom 所在楼层前未拾取全家福，无法进入宝箱层。","The Polaroid was not taken before leaving Mom's floor, so Chest cannot be reached."),
          message("使用 R Key 后重新击败 Mom 并拾取全家福。","Use R Key, defeat Mom again, and take The Polaroid."), "failed")
      end
      if stage == STAGE.WOMB2 and not isRepentanceFloor(context) then
        return routeResult(message("击败 Mom's Heart/It Lives! 后进入教堂光柱。","Defeat Mom's Heart/It Lives!, then enter the Cathedral beam."),
          mark == "BLUE_BABY" and message("在教堂击败以撒，并用全家福进入宝箱层。","Defeat Isaac in Cathedral and use The Polaroid to enter Chest.")
            or message("在教堂击败以撒。","Defeat Isaac in Cathedral."))
      elseif mark == "BLUE_BABY" and stage == STAGE.DEPTHS2
        and context.routeEvents.momDefeated and heldAids.polaroid then
        if isRepentanceFloor(context) then
          return routeResult(message("已取得全家福；进入子宫II。","The Polaroid is secured; enter Womb II."),
            message("击败 It Lives! 后进入教堂，再前往宝箱层。","Defeat It Lives!, enter Cathedral, then continue to Chest."))
        end
        return routeResult(message("已取得全家福；进入子宫I。","The Polaroid is secured; enter Womb I."),
          message("子宫I：进入子宫II；击败 It Lives! 后进入教堂。","Womb I: enter Womb II; defeat It Lives!, then enter Cathedral."))
      end
      local nextText = mark == "BLUE_BABY" and heldAids.polaroid
          and message("保留全家福，最终从教堂进入宝箱层。","Keep The Polaroid and enter Chest from Cathedral.")
        or mark == "BLUE_BABY" and message("击败 Mom 后拾取全家福，之后进入教堂。","Take The Polaroid after defeating Mom, then enter Cathedral.")
        or message("击败 It Lives! 后进入通往教堂的光柱。","Enter the Cathedral beam after It Lives!.")
      local result = pathResult(context, "normal", aidNames(context,{"polaroid"},language),
        mark == "BLUE_BABY" and heldAids.polaroid
          and message("已取得全家福。","The Polaroid is secured.") or nil, nextText)
      if result then return result end
    elseif stage == STAGE.CHAPTER5 and context.stageType == WOTL then
      if mark == "BLUE_BABY" and not context.aids.polaroid then
        return routeResult(message("未携带全家福，无法从教堂进入宝箱层。","The Polaroid is missing, so Chest cannot be reached from Cathedral."),
          message("使用 R Key 后重新取得全家福。","Use R Key and take The Polaroid on the next attempt."), "failed")
      end
      return routeResult(message("在教堂击败以撒。","Defeat Isaac in Cathedral."), mark == "BLUE_BABY" and message("持有全家福时进入宝箱并前往宝箱层。","With The Polaroid, enter the chest to reach Chest.") or message("击败后取得以撒标记。","The Isaac mark is awarded on defeat."))
    elseif stage == STAGE.CHAPTER6 and context.stageType == WOTL and mark == "BLUE_BABY" then
      return routeResult(message("探索宝箱层并击败???。","Explore Chest and defeat ???."), message("击败后取得???标记。","The ??? mark is awarded on defeat."))
    end
  elseif mark == "SATAN" or mark == "LAMB" then
    if stage < STAGE.CHAPTER5 then
      if mark == "LAMB" and stage == STAGE.DEPTHS2
        and context.routeEvents.momDefeated and not heldAids.negative then
        return routeResult(message("Mom 已击败：拾取底片。","Mom is defeated: take The Negative."),
          message("之后击败 Mom's Heart/It Lives!，进入阴间。","Then defeat Mom's Heart/It Lives! and enter Sheol."))
      elseif mark == "LAMB" and stage > STAGE.DEPTHS2 and not heldAids.negative then
        return routeResult(message("离开 Mom 所在楼层前未拾取底片，无法进入暗室。","The Negative was not taken before leaving Mom's floor, so Dark Room cannot be reached."),
          message("使用 R Key 后重新击败 Mom 并拾取底片。","Use R Key, defeat Mom again, and take The Negative."), "failed")
      end
      if stage == STAGE.WOMB2 and not isRepentanceFloor(context) then
        return routeResult(message("击败 Mom's Heart/It Lives! 后进入阴间活板门。","Defeat Mom's Heart/It Lives!, then take the Sheol trapdoor."),
          mark == "LAMB" and message("在阴间击败撒但，并用底片进入暗室。","Defeat Satan in Sheol and use The Negative to enter Dark Room.")
            or message("在阴间击败撒但。","Defeat Satan in Sheol."))
      elseif mark == "LAMB" and stage == STAGE.DEPTHS2
        and context.routeEvents.momDefeated and heldAids.negative then
        if isRepentanceFloor(context) then
          return routeResult(message("已取得底片；进入子宫II。","The Negative is secured; enter Womb II."),
            message("击败 It Lives! 后进入阴间，再前往暗室。","Defeat It Lives!, enter Sheol, then continue to Dark Room."))
        end
        return routeResult(message("已取得底片；进入子宫I。","The Negative is secured; enter Womb I."),
          message("子宫I：进入子宫II；击败 It Lives! 后进入阴间。","Womb I: enter Womb II; defeat It Lives!, then enter Sheol."))
      end
      local nextText = mark == "LAMB" and heldAids.negative
          and message("保留底片，最终从阴间进入暗室。","Keep The Negative and enter Dark Room from Sheol.")
        or mark == "LAMB" and message("击败 Mom 后拾取底片，之后进入阴间。","Take The Negative after defeating Mom, then enter Sheol.")
        or message("击败 It Lives! 后进入通往阴间的活板门。","Take the Sheol trapdoor after It Lives!.")
      local result = pathResult(context, "normal", aidNames(context,{"negative","deeper","ehwaz"},language),
        mark == "LAMB" and heldAids.negative
          and message("已取得底片。","The Negative is secured.") or nil, nextText)
      if result then return result end
    elseif stage == STAGE.CHAPTER5 and context.stageType == ORIGINAL then
      if mark == "LAMB" and not context.aids.negative then
        return routeResult(message("未携带底片，无法从阴间进入暗室。","The Negative is missing, so Dark Room cannot be reached from Sheol."),
          message("使用 R Key 后重新取得底片。","Use R Key and take The Negative on the next attempt."), "failed")
      end
      return routeResult(message("在阴间击败撒但。","Defeat Satan in Sheol."), mark == "LAMB" and message("持有底片时进入宝箱并前往暗室。","With The Negative, enter the chest to reach Dark Room.") or message("击败后取得撒但标记。","The Satan mark is awarded on defeat."))
    elseif stage == STAGE.CHAPTER6 and context.stageType == ORIGINAL and mark == "LAMB" then
      return routeResult(message("探索暗室并击败羔羊。","Explore Dark Room and defeat The Lamb."), message("击败后取得羔羊标记。","The Lamb mark is awarded on defeat."))
    end
  elseif mark == "ULTRA_GREED" then
    if stage == GREED_STAGE.FINAL then
      return routeResult(message("进入最终房间并击败究极贪婪。","Enter the final room and defeat Ultra Greed."),
        message("困难贪婪模式还需击败究极贪婪形态。","Greedier Mode also requires defeating the Ultra Greedier phase."))
    end
    local current = GREED_PATH_STEPS[stage]
    if current then
      return routeResult(current, GREED_PATH_STEPS[stage + 1]
        or message("进入最终房间并击败究极贪婪。","Enter the final room and defeat Ultra Greed."))
    end
  end
  return routeResult(message("当前已偏离所需 Boss 分支。","The run is on the wrong boss branch."),
    message("使用 R Key 后可重新选择路线。","Use R Key to choose the route again."), "failed")
end

local function megaSatanRoute(context, language)
  local gateKeys = {"dads_key","jail_free","mr_me","sharp_key","soul_cain","cracked_orb"}
  local alternatives = aidNames(context, gateKeys, language)
  if context.roomType == enum(RoomType,"ROOM_ANGEL",15) then
    table.insert(alternatives, localText(language,"炸毁当前天使雕像","bomb the current Angel Statue"))
  elseif context.roomType == enum(RoomType,"ROOM_SACRIFICE",13) then
    table.insert(alternatives, localText(language,"献祭房第9/11次取钥匙碎片","Sacrifice Room hits 9/11 for Key Pieces"))
  end
  local hasGate = (context.aids.key1 and context.aids.key2) or #alternatives > 0
  if context.stage < STAGE.CHAPTER5 then
    local heldAids = context.heldAids or {}
    if context.stage == STAGE.DEPTHS2 and context.routeEvents.momDefeated
      and not heldAids.polaroid and not heldAids.negative then
      return routeResult(message("Mom 已击败：拾取全家福或底片。","Mom is defeated: take The Polaroid or The Negative."),
        message("按所选照片进入教堂/阴间，再前往宝箱层/暗室。","Follow the chosen photo through Cathedral/Sheol to Chest/Dark Room."), hasGate and "normal" or "warning", alternatives)
    elseif context.stage == STAGE.WOMB2 and not isRepentanceFloor(context) then
      return routeResult(message("击败 Mom's Heart/It Lives!，按照片进入教堂/阴间。","Defeat Mom's Heart/It Lives! and take the branch matching the photo."),
        message("击败以撒/撒但并进入宝箱层/暗室。","Defeat Isaac/Satan and enter Chest/Dark Room."), hasGate and "normal" or "warning", alternatives)
    end
    local currentExtra = message("优先进入天使房，炸毁雕像并收集两枚钥匙碎片。","Prefer Angel Rooms; bomb statues and collect both Key Pieces.")
    local nextExtra = message("击败 Mom 后选择全家福或底片，前往宝箱层/暗室。","Take The Polaroid or Negative after defeating Mom and reach Chest/Dark Room.")
    local result = pathResult(context, hasGate and "normal" or "warning", alternatives,
      currentExtra, nextExtra)
    if result then return result end
  elseif context.stage == STAGE.CHAPTER5 and context.stageType == WOTL then
    return routeResult(message("在教堂击败以撒，并用全家福进入宝箱层。","Defeat Isaac in Cathedral and use The Polaroid to enter Chest."),
      message("在宝箱层起始房开启金门。","Open the Golden Gate in Chest's starting room."), hasGate and "normal" or "warning", alternatives)
  elseif context.stage == STAGE.CHAPTER5 and context.stageType == ORIGINAL then
    return routeResult(message("在阴间击败撒但，并用底片进入暗室。","Defeat Satan in Sheol and use The Negative to enter Dark Room."),
      message("在暗室起始房开启金门。","Open the Golden Gate in Dark Room's starting room."), hasGate and "normal" or "warning", alternatives)
  elseif context.stage == STAGE.CHAPTER6 then
    return routeResult(message("在起始房用金钥匙或可用工具开启金门。","Use the golden key or an available tool on the starting-room gate."),
      message("进入五芒星并击败超级撒但两个阶段。","Step onto the pentagram and defeat both Mega Satan phases."), hasGate and "normal" or "failed", alternatives)
  end
  return routeResult(message("已离开宝箱层/暗室，超级撒但路线失败。","Chest/Dark Room was left; the Mega Satan route has failed."),
    message("使用 R Key 后可重新尝试。","Use R Key to try again."), "failed")
end

local function deliriumRoute(context, language)
  if context.stage == STAGE.VOID then
    return routeResult(message("探索虚空中的多个 Boss 房。","Explore the multiple boss rooms in The Void."),
      message("找到真正的精神错乱并击败它。","Find and defeat the real Delirium."))
  elseif context.voidPortal then
    return routeResult(message("当前房间已出现虚空传送门，立即进入。","A Void portal is present in this room; enter it now."),
      message("在虚空中寻找并击败精神错乱。","Find and defeat Delirium in The Void."), "warning")
  elseif isRepentanceFloor(context) and context.stage == STAGE.WOMB1 then
    return routeResult(message("击败本层头目后，进入尸宫II。","Defeat this floor's boss, then enter Corpse II."),
      message("在尸宫II击败 Mother，并检查虚空传送门。","Defeat Mother in Corpse II and check for a Void portal."), "warning")
  elseif isRepentanceFloor(context) and context.stage == STAGE.WOMB2 then
    return routeResult(message("在尸宫II击败 Mother。","Defeat Mother in Corpse II."),
      message("若生成虚空传送门，立即进入。","Enter the Void portal immediately if it appears."), "warning")
  elseif context.stage <= STAGE.WOMB2 then
    local hush = hushRoute(context, language)
    hush.next = message("击败死寂后进入保证生成的虚空传送门。","After Hush, enter the guaranteed Void portal.")
    return hush
  elseif context.stage == STAGE.CHAPTER5 and context.stageType == WOTL then
    return routeResult(message("在教堂击败以撒，并检查虚空传送门。","Defeat Isaac in Cathedral and check for a Void portal."),
      message("若未生成，使用全家福进入宝箱层。","If none appears, use The Polaroid to enter Chest."), "warning")
  elseif context.stage == STAGE.CHAPTER5 and context.stageType == ORIGINAL then
    return routeResult(message("在阴间击败撒但，并检查虚空传送门。","Defeat Satan in Sheol and check for a Void portal."),
      message("若未生成，使用底片进入暗室。","If none appears, use The Negative to enter Dark Room."), "warning")
  elseif context.stage == STAGE.CHAPTER6 and context.stageType == WOTL then
    return routeResult(message("在宝箱层击败???，并检查虚空传送门。","Defeat ??? in Chest and check for a Void portal."),
      message("若传送门出现，立即进入。","Enter the portal immediately if it appears."), "warning")
  elseif context.stage == STAGE.CHAPTER6 and context.stageType == ORIGINAL then
    return routeResult(message("在暗室击败羔羊，并检查虚空传送门。","Defeat The Lamb in Dark Room and check for a Void portal."),
      message("若传送门出现，立即进入。","Enter the portal immediately if it appears."), "warning")
  end
  return routeResult(message("击败当前主要 Boss，并检查是否生成虚空传送门。","Defeat the current major boss and check for a Void portal."),
    message("若未生成，继续前往更深层的主要 Boss。","If none appears, continue to a later major boss."), "warning")
end

local ROUTE_PRIORITY = {
  BOSS_RUSH=1, HUSH=2, MOTHER=3, BEAST=4, MOMS_HEART=5, ISAAC=6,
  BLUE_BABY=7, SATAN=8, LAMB=9, MEGA_SATAN=10, DELIRIUM=11, ULTRA_GREED=12
}

local function chooseRequirement(remaining, context)
  table.sort(remaining, function(left, right)
    return (ROUTE_PRIORITY[left.mark] or 99) < (ROUTE_PRIORITY[right.mark] or 99)
  end)
  if context.greed then
    for _, requirement in ipairs(remaining) do if requirement.mark == "ULTRA_GREED" then return requirement end end
  elseif context.stage == STAGE.VOID then
    for _, requirement in ipairs(remaining) do if requirement.mark == "DELIRIUM" then return requirement end end
  elseif context.stage == STAGE.HOME or context.ascent then
    for _, requirement in ipairs(remaining) do if requirement.mark == "BEAST" then return requirement end end
  elseif isRepentanceFloor(context) and context.stage >= STAGE.WOMB1 then
    for _, requirement in ipairs(remaining) do if requirement.mark == "MOTHER" then return requirement end end
  end
  return remaining[1]
end

local function mismatchSuffix(goal, requirement, language)
  if requirement.playerType == nil then return nil end
  local name = CharacterRelevance.characterName(requirement.playerType) or tostring(requirement.playerType)
  if language == "zh" then
    local detail = goal.zh and goal.zh.detail or ""
    local localized = detail:match("用(.-)获得") or detail:match("用(.-)击败") or name
    return "（需使用" .. localized .. "击败该 Boss！）"
  end
  return " (Defeat this boss as " .. name .. "!)"
end

local function applyRKeyRecovery(result, context, language, blocked)
  if blocked or result.severity ~= "failed" or context.greed
    or not context.aids or not context.aids.r_key then return result end
  result.severity = "warning"
  result.current = localText(language,
    "取得并使用本层发现的 R Key 后，可重新开始这条路线。",
    "Collect and use the R Key found on this floor to restart this route.")
  result.next = localText(language,
    "重置后将按新楼层状态重新评估路线。",
    "The route will be re-evaluated after the reset.")
  result.alternatives = { "R Key" }
  return result
end

local function requiredPlayerPresent(goal, players)
  local required = CharacterRelevance.requiredPlayerTypes(goal)
  if next(required) == nil then return true end
  for playerType in pairs(required) do
    if players and players[playerType] then return true end
  end
  return false
end

function Routes.evaluate(goal, context, completionStore, language)
  if not goal then return nil end
  if goal.routeKind == "tainted_unlock" then
    local result = taintedUnlockRoute(goal, context, language)
    result.current = result.current and (result.current[language] or result.current.en) or nil
    result.next = result.next and (result.next[language] or result.next.en) or nil
    result.known, result.required, result.mark = 0, 1, "TAINTED_UNLOCK"
    return applyRKeyRecovery(result, context, language,
      not requiredPlayerPresent(goal, context.players))
  end
  if not goal.completionRequirements then return nil end
  local known, required, remaining = CompletionMarks.progress(goal, completionStore, context.players)
  if required == 0 then return nil end
  if #remaining == 0 then
    return { current=localText(language,"所有已知通关标记均已完成。","All known completion marks are complete."),
      next=nil, severity="completed", alternatives={}, known=known, required=required }
  end
  local requirement = chooseRequirement(remaining, context)
  local result
  if requirement.mark == "MOTHER" then result = motherRoute(context, language)
  elseif requirement.mark == "BEAST" then result = beastRoute(context, language)
  elseif requirement.mark == "BOSS_RUSH" then result = bossRushRoute(context, language)
  elseif requirement.mark == "HUSH" then result = hushRoute(context, language)
  elseif requirement.mark == "MEGA_SATAN" then result = megaSatanRoute(context, language)
  elseif requirement.mark == "DELIRIUM" then result = deliriumRoute(context, language)
  else result = branchRoute(requirement.mark, context, language) end
  result.current = result.current and (result.current[language] or result.current.en) or nil
  result.next = result.next and (result.next[language] or result.next.en) or nil
  result.known, result.required, result.mark = known, required, requirement.mark
  local characterMismatch = requirement.playerType ~= nil
    and not context.players[requirement.playerType]
  if characterMismatch then
    result.severity = "failed"
    result.current = result.current .. mismatchSuffix(goal, requirement, language)
  end
  if #result.alternatives > 0 then
    local prefix = language == "zh" and "可用替代：" or "Available alternative: "
    result.current = result.current .. "  " .. prefix .. table.concat(result.alternatives, "/")
  end
  local permanentlyLocked = requirement.mark == "MOTHER"
    and context.secretExitUnlocked == false
  return applyRKeyRecovery(result, context, language,
    characterMismatch or permanentlyLocked)
end

function Routes.markFromNpc(npc, game)
  if not npc then return nil end
  local entityType, variant = npc.Type, npc.Variant
  if entityType == enum(EntityType,"ENTITY_MOMS_HEART",78) then
    local level = game and game:GetLevel()
    if level and level:GetStage() == STAGE.WOMB2 and level:GetStageType() ~= REP_A
      and level:GetStageType() ~= REP_B then return "MOMS_HEART" end
    return nil
  end
  if entityType == enum(EntityType,"ENTITY_ISAAC",102) then return variant == 1 and "BLUE_BABY" or "ISAAC" end
  if entityType == enum(EntityType,"ENTITY_SATAN",84) then return "SATAN" end
  if entityType == enum(EntityType,"ENTITY_THE_LAMB",273) then return "LAMB" end
  if entityType == enum(EntityType,"ENTITY_MEGA_SATAN_2",275) then return "MEGA_SATAN" end
  if entityType == enum(EntityType,"ENTITY_ULTRA_GREED",406) then
    local difficulty = game and game.Difficulty
    local greedier = Difficulty and Difficulty.DIFFICULTY_GREEDIER or 3
    if difficulty ~= greedier or variant ~= 0 then return "ULTRA_GREED" end
  end
  if entityType == enum(EntityType,"ENTITY_HUSH",407) then return "HUSH" end
  if entityType == enum(EntityType,"ENTITY_DELIRIUM",412) then return "DELIRIUM" end
  if entityType == enum(EntityType,"ENTITY_MOTHER",912) then return "MOTHER" end
  if entityType == enum(EntityType,"ENTITY_BEAST",951) then return "BEAST" end
  return nil
end

function Routes.observeNpc(run, npc, game)
  if not run or not npc or not game then return false end
  run.routeEvents = run.routeEvents or {}
  local level = game:GetLevel()
  if level:GetStage() ~= STAGE.DEPTHS2 then return false end
  local repentanceFloor = level:GetStageType() == REP_A or level:GetStageType() == REP_B
  local changed = false
  if npc.Type == enum(EntityType,"ENTITY_MOM",45) then
    if not run.routeEvents.momDefeated then run.routeEvents.momDefeated = true; changed = true end
    if repentanceFloor and not run.routeEvents.mausoleumMomDefeated then
      run.routeEvents.mausoleumMomDefeated = true
      changed = true
    end
  elseif repentanceFloor and npc.Type == enum(EntityType,"ENTITY_MOMS_HEART",78)
    and not run.routeEvents.fleshHeartDefeated then
    run.routeEvents.fleshHeartDefeated = true
    changed = true
  end
  return changed
end

return Routes
