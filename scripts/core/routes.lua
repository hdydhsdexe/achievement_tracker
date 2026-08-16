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
local REP_A = enum(StageType,"STAGETYPE_REPENTANCE",4)
local REP_B = enum(StageType,"STAGETYPE_REPENTANCE_B",5)
local ORIGINAL = enum(StageType,"STAGETYPE_ORIGINAL",0)
local WOTL = enum(StageType,"STAGETYPE_WOTL",1)

local AID_DEFS = {
  knife1={kind="collectible", id=enum(CollectibleType,"COLLECTIBLE_KNIFE_PIECE_1",626), zh="菜刀碎片1", en="Knife Piece 1"},
  knife2={kind="collectible", id=enum(CollectibleType,"COLLECTIBLE_KNIFE_PIECE_2",627), zh="菜刀碎片2", en="Knife Piece 2"},
  key1={kind="collectible", id=enum(CollectibleType,"COLLECTIBLE_KEY_PIECE_1",238), zh="钥匙碎片1", en="Key Piece 1"},
  key2={kind="collectible", id=enum(CollectibleType,"COLLECTIBLE_KEY_PIECE_2",239), zh="钥匙碎片2", en="Key Piece 2"},
  polaroid={kind="collectible", id=enum(CollectibleType,"COLLECTIBLE_POLAROID",327), zh="全家福", en="The Polaroid"},
  negative={kind="collectible", id=enum(CollectibleType,"COLLECTIBLE_NEGATIVE",328), zh="底片", en="The Negative"},
  dads_note={kind="collectible", id=enum(CollectibleType,"COLLECTIBLE_DADS_NOTE",668), zh="爸爸的便条", en="Dad's Note"},
  sharp_key={kind="collectible", id=enum(CollectibleType,"COLLECTIBLE_SHARP_KEY",623), zh="尖头钥匙", en="Sharp Key"},
  cracked_orb={kind="collectible", id=enum(CollectibleType,"COLLECTIBLE_CRACKED_ORB",675), zh="碎裂的宝珠", en="Cracked Orb"},
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
  jail_free={kind="card", id=enum(Card,"CARD_GET_OUT_OF_JAIL",47), zh="免费出狱卡", en="Get Out of Jail Free"},
  ehwaz={kind="card", id=enum(Card,"RUNE_EHWAZ",34), zh="黑符文·艾瓦兹", en="Ehwaz"}
}

local function localText(language, zh, en)
  return language == "zh" and zh or en
end

local function message(zh, en) return {zh=zh, en=en} end

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

local function scanGroundAids(context)
  if not Isaac or type(Isaac.GetRoomEntities) ~= "function" then return end
  for _, entity in ipairs(Isaac.GetRoomEntities()) do
    local pickup = entity.ToPickup and entity:ToPickup() or nil
    if pickup then
      for key, aid in pairs(AID_DEFS) do
        local variant = aid.kind == "collectible" and enum(PickupVariant,"PICKUP_COLLECTIBLE",100)
          or aid.kind == "trinket" and enum(PickupVariant,"PICKUP_TRINKET",350)
          or enum(PickupVariant,"PICKUP_TAROTCARD",300)
        if pickup.Variant == variant and pickup.SubType == aid.id then context.aids[key] = true end
      end
    end
  end
end

local function scanVoidPortal(context, room)
  if not room or type(room.GetGridSize) ~= "function" then return end
  for index = 0, room:GetGridSize() - 1 do
    local grid = room:GetGridEntity(index)
    if grid and grid.GetType and grid:GetType() == enum(GridEntityType,"GRID_TRAPDOOR",17)
      and grid.GetVariant and grid:GetVariant() == 1 then
      context.voidPortal = true
      return
    end
  end
end

function Routes.context(game, run)
  local level, room = game:GetLevel(), game:GetRoom()
  local context = {
    stage=level:GetStage(), stageType=level:GetStageType(), elapsed=math.floor(game.TimeCounter / 30),
    roomType=room:GetType(), greed=game:IsGreedMode(), players={}, aids={}, voidPortal=false,
    routeItems=run and run.routeItems or {}, routeEvents=run and run.routeEvents or {}
  }
  local ok, ascent = pcall(function() return level:IsAscent() end)
  context.ascent = ok and ascent == true
  for index = 0, game:GetNumPlayers() - 1 do
    local player = Isaac.GetPlayer(index)
    local playerType = CharacterRelevance.normalize(player:GetPlayerType())
    context.players[playerType] = true
    for key, aid in pairs(AID_DEFS) do
      if aid.kind == "collectible" and player.HasCollectible and player:HasCollectible(aid.id)
        or aid.kind == "trinket" and player.HasTrinket and player:HasTrinket(aid.id) then
        context.aids[key] = true
      elseif aid.kind == "card" and player.GetCard then
        if player:GetCard(0) == aid.id or player:GetCard(1) == aid.id then context.aids[key] = true end
      end
    end
  end
  scanGroundAids(context)
  scanVoidPortal(context, room)
  for _, key in ipairs({"knife1","knife2","key1","key2","dads_note"}) do
    if context.routeItems[key] then context.aids[key] = true end
  end
  return context
end

function Routes.updateRun(run, context)
  run.routeItems = run.routeItems or {}
  local changed = false
  for _, key in ipairs({"knife1","knife2","key1","key2","dads_note"}) do
    if context.aids[key] and not run.routeItems[key] then
      run.routeItems[key] = true
      changed = true
    end
  end
  return changed
end

function Routes.resetAttempt(run)
  run.routeItems = {}
  run.routeEvents = {}
end

local function motherRoute(context, language)
  local knife1, knife2 = context.aids.knife1, context.aids.knife2
  local bypassKeys = {"sharp_key","soul_cain","cracked_orb"}
  local bypass = hasAny(context, bypassKeys)
  local alternatives = aidNames(context, bypassKeys, language)
  local stage, alt = context.stage, isRepentanceFloor(context)
  if stage == STAGE.BASEMENT1 then
    return routeResult(message("（可选）击败头目后进入水层。","(Optional) Enter Downpour/Dross after the boss."),
      message("若仍未进入，地下室II是进入水层的最后机会。","Basement II is the final chance to enter the water path."))
  elseif stage == STAGE.BASEMENT2 and not alt then
    return routeResult(message("进入水层（最后机会）。","Enter Downpour/Dross now (last chance)."),
      message("在镜像世界的宝箱房拾取菜刀碎片1。","Take Knife Piece 1 from the mirrored Treasure Room."), "warning")
  elseif stage == STAGE.BASEMENT2 and alt and not knife1 then
    return routeResult(message("触碰白火，以游魂形态穿过镜子并拾取菜刀碎片1。","Touch the white fire, enter the mirror as The Lost, and take Knife Piece 1."),
      message("之后可进入矿层；未进入时洞穴II仍有最后机会。","Mines is optional next; Caves II is the final fallback entrance."))
  elseif stage == STAGE.CAVES1 then
    if not knife1 and not bypass then
      return routeResult(message("已错过菜刀碎片1，标准 Mother 路线失败。","Knife Piece 1 was missed; the standard Mother route has failed."),
        message("若之后遇到可开启肉门的道具，路线会自动恢复。","The route can recover if a flesh-door bypass appears later."), "failed")
    end
    if not knife1 and bypass then
      return routeResult(message("标准菜刀路线已错过；保留当前肉门替代工具。","The knife route was missed; keep the current flesh-door bypass."),
        message("在深牢I或矿层II后进入陵墓，并用替代工具开启肉门。","Enter Mausoleum after Depths I or Mines II and use the bypass on the flesh door."), "warning", alternatives)
    end
    return routeResult(message("（可选）击败头目后进入矿层。","(Optional) Enter Mines/Ashpit after the boss."),
      message("矿层II是最后入口；有碎片1时可取得碎片2。","Mines II is the final entrance and contains Knife Piece 2."), "normal", alternatives)
  elseif stage == STAGE.CAVES2 and not alt then
    if not knife1 and not bypass then
      return routeResult(message("已错过水层，且没有肉门替代工具。","The water path was missed and no flesh-door bypass is available."),
        message("遇到尖头钥匙、该隐魂石或碎裂宝珠可恢复。","Sharp Key, Soul of Cain, or Cracked Orb can recover the route."), "failed")
    end
    return routeResult(message("进入矿层（最后机会）。","Enter Mines/Ashpit now (last chance)."),
      message("按下三枚黄色按钮，进入矿车区域拾取菜刀碎片2并逃生。","Press three yellow buttons, take Knife Piece 2, and escape the chase."), "warning", alternatives)
  elseif stage == STAGE.CAVES2 and alt and not knife2 then
    if not knife1 and bypass then
      return routeResult(message("保留肉门替代工具并击败本层头目。","Keep the flesh-door bypass and defeat this floor's boss."),
        message("进入陵墓/炼狱，并用替代工具开启肉门。","Enter Mausoleum/Gehenna and use the bypass on the flesh door."), "warning", alternatives)
    end
    return routeResult(message("按下三枚黄色按钮，乘矿车取得菜刀碎片2并逃生。","Press three yellow buttons, ride the minecart, take Knife Piece 2, and escape."),
      message("击败头目后进入陵墓/炼狱。","Enter Mausoleum/Gehenna after the boss."), "normal", alternatives)
  elseif stage == STAGE.DEPTHS1 and not alt then
    if not knife2 and not bypass then
      return routeResult(message("已错过完整菜刀，Mother 路线失败。","The completed knife was missed; the Mother route has failed."),
        message("若当前或之后遇到肉门替代工具，路线会恢复。","A flesh-door bypass can still recover the route."), "failed")
    end
    return routeResult(message("击败头目后进入陵墓/炼狱（最后机会）。","Enter Mausoleum/Gehenna after the boss (last chance)."),
      message("在陵墓II击败强化 Mom 并开启红色肉门。","In Mausoleum II, defeat Mom and open the red flesh door."), "warning", alternatives)
  elseif (stage == STAGE.DEPTHS1 or stage == STAGE.DEPTHS2) and alt then
    if stage == STAGE.DEPTHS2 and context.routeEvents.fleshHeartDefeated then
      return routeResult(message("特殊 Mom's Heart 已击败，进入新出现的尸宫活板门。","The special Mom's Heart is defeated; take the new Corpse trapdoor."),
        message("探索尸宫并前往尸宫II。","Explore Corpse and continue to Corpse II."), "normal", alternatives)
    elseif stage == STAGE.DEPTHS2 and context.routeEvents.mausoleumMomDefeated then
      return routeResult(message("用完整菜刀或可用替代工具开启红色肉门。","Open the red flesh door with the knife or an available bypass."),
        message("进入肉门并击败特殊 Mom's Heart。","Enter the flesh door and defeat the special Mom's Heart."), "normal", alternatives)
    end
    return routeResult(message("前往陵墓/炼狱II并击败强化 Mom。","Reach Mausoleum/Gehenna II and defeat the stronger Mom."),
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
    return routeResult(message("前往普通深牢II；保留传送手段以离开 Mom 房。","Reach normal Depths II and keep a teleport to escape Mom's room."),
      message("击败 Mom，取得全家福/底片，再返回起始房的奇怪门。","Defeat Mom, take a photo, then return to the Strange Door."), "normal", alternatives)
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
  local severity = context.elapsed >= deadline and ((#alternatives == 0 and not canStillChooseMausoleum)
      and "failed" or "warning")
    or deadline - context.elapsed <= 300 and "warning" or "normal"
  local current = canStillChooseMausoleum and context.elapsed >= 1200
    and message("普通 Mom 的20分钟时限已过；可改走陵墓II争取25分钟入口。","The normal 20-minute limit passed; Mausoleum II remains available until 25:00.")
    or message("在时限内击败 Mom 并进入墙上的头目车轮战入口。","Defeat Mom before the deadline and enter the Boss Rush opening.")
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
  end
  local severity = context.elapsed >= 1800 and (#alternatives == 0 and "failed" or "warning")
    or 1800 - context.elapsed <= 300 and "warning" or "normal"
  return routeResult(message("30分钟内击败 Mom's Heart/It Lives! 并进入蓝色裂口。","Defeat Mom's Heart/It Lives! within 30 minutes and enter the blue opening."),
    message("在蓝色子宫击败死寂。","Defeat Hush in Blue Womb."), severity, alternatives)
end

local function branchRoute(mark, context, language)
  local stage = context.stage
  if mark == "MOMS_HEART" then
    if stage < STAGE.WOMB2 then return routeResult(message("沿主线前往子宫II。","Follow the main path to Womb II."), message("击败 Mom's Heart/It Lives!。","Defeat Mom's Heart/It Lives!.")) end
    return routeResult(message("在本层击败 Mom's Heart/It Lives!。","Defeat Mom's Heart/It Lives! on this floor."), message("击败后即取得该通关标记。","The mark is awarded on defeat."))
  elseif mark == "ISAAC" or mark == "BLUE_BABY" then
    if stage < STAGE.CHAPTER5 then
      local nextText = mark == "BLUE_BABY" and message("击败 Mom 时取得全家福，之后进入教堂。","Take The Polaroid from Mom, then enter Cathedral.")
        or message("击败 It Lives! 后进入通往教堂的光柱。","Enter the Cathedral beam after It Lives!.")
      return routeResult(message("沿主线推进并选择教堂分支。","Follow the main path and choose Cathedral."), nextText, "normal", aidNames(context,{"polaroid"},language))
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
      local nextText = mark == "LAMB" and message("击败 Mom 时取得底片，之后进入阴间。","Take The Negative from Mom, then enter Sheol.")
        or message("击败 It Lives! 后进入通往阴间的活板门。","Take the Sheol trapdoor after It Lives!.")
      return routeResult(message("沿主线推进并选择阴间分支。","Follow the main path and choose Sheol."), nextText, "normal", aidNames(context,{"negative","deeper","ehwaz"},language))
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
    return routeResult(message("完成当前贪婪楼层的波次并进入下一层。","Clear the current Greed floor waves and continue."),
      message("在商店层击败究极贪婪；困难贪婪需击败贪婪形态。","Defeat Ultra Greed; Greedier requires the harder phase."))
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
    return routeResult(message("优先进入天使房，炸毁雕像并收集两枚钥匙碎片。","Prefer Angel Rooms; bomb statues and collect both Key Pieces."),
      message("击败 Mom 时选择全家福或底片，前往宝箱层/暗室。","Take The Polaroid or Negative from Mom and reach Chest/Dark Room."), hasGate and "normal" or "warning", alternatives)
  elseif context.stage < STAGE.CHAPTER6 then
    return routeResult(message("击败以撒或撒但，并用对应照片进入第六章。","Defeat Isaac or Satan and use the matching photo to enter Chapter 6."),
      message("在起始房开启金门。","Open the Golden Gate in the starting room."), hasGate and "normal" or "warning", alternatives)
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
  elseif context.stage <= STAGE.WOMB2 then
    local hush = hushRoute(context, language)
    hush.next = message("击败死寂后进入保证生成的虚空传送门。","After Hush, enter the guaranteed Void portal.")
    return hush
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

function Routes.evaluate(goal, context, completionStore, language)
  if not goal or not goal.completionRequirements then return nil end
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
  if requirement.playerType ~= nil and not context.players[requirement.playerType] then
    result.severity = "failed"
    result.current = result.current .. mismatchSuffix(goal, requirement, language)
  end
  if #result.alternatives > 0 then
    local prefix = language == "zh" and "可用替代：" or "Available alternative: "
    result.current = result.current .. "  " .. prefix .. table.concat(result.alternatives, "/")
  end
  return result
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
  if level:GetStage() ~= STAGE.DEPTHS2
    or (level:GetStageType() ~= REP_A and level:GetStageType() ~= REP_B) then return false end
  local key
  if npc.Type == enum(EntityType,"ENTITY_MOM",45) then key = "mausoleumMomDefeated" end
  if npc.Type == enum(EntityType,"ENTITY_MOMS_HEART",78) then key = "fleshHeartDefeated" end
  if key and not run.routeEvents[key] then run.routeEvents[key] = true; return true end
  return false
end

return Routes
