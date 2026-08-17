local Rewards = require("scripts.core.rewards")
local RewardIcons = {}
local cache = {}

local fallbackFrames = {
  character=0,
  area=1,
  challenge=2,
  feature=3,
  other=4
}

-- Vanilla player portraits live in the packed game resources. Keeping this
-- mapping here lets resource-replacement mods remain visible without bundling
-- copies of the original art.
local characterPortraits = {
  [0]="playerportrait_isaac.png",
  [1]="playerportrait_magdalene.png",
  [2]="playerportrait_cain.png",
  [3]="playerportrait_judas.png",
  [4]="playerportrait_bluebaby.png",
  [5]="playerportrait_eve.png",
  [6]="playerportrait_samson.png",
  [7]="playerportrait_azazel.png",
  [8]="playerportrait_lazarus.png",
  [9]="playerportrait_eden.png",
  [10]="playerportrait_thelost.png",
  [11]="playerportrait_lazarus2.png",
  [12]="playerportrait_darkjudas.png",
  [13]="playerportrait_lilith.png",
  [14]="playerportrait_keeper.png",
  [15]="playerportrait_apollyon.png",
  [16]="playerportrait_theforgotten.png",
  [17]="playerportrait_theforgotten.png",
  [18]="playerportrait_bethany.png",
  [19]="playerportrait_jacob.png",
  [20]="playerportrait_jacob.png",
  [21]="playerportrait_isaac_b.png",
  [22]="playerportrait_magdalene_b.png",
  [23]="playerportrait_cain_b.png",
  [24]="playerportrait_judas_b.png",
  [25]="playerportrait_bluebaby_b.png",
  [26]="playerportrait_eve_b.png",
  [27]="playerportrait_samson_b.png",
  [28]="playerportrait_azazel_b.png",
  [29]="playerportrait_lazarus_b.png",
  [30]="playerportrait_eden_b.png",
  [31]="playerportrait_thelost_b.png",
  [32]="playerportrait_lilith_b.png",
  [33]="playerportrait_keeper_b.png",
  [34]="playerportrait_apollyon_b.png",
  [35]="playerportrait_theforgotten_b.png",
  [36]="playerportrait_bethany_b.png",
  [37]="playerportrait_jacob_b.png",
  [38]="playerportrait_lazarus_b_dead.png",
  [39]="playerportrait_jacob_b.png",
  [40]="playerportrait_theforgotten_b.png"
}

local TALL_CHARACTER_PORTRAITS = { [37]=true, [39]=true }
local TAINTED_EDEN = 30
local VANILLA_CARD_MAX = Card and Card.NUM_CARDS and (Card.NUM_CARDS - 1) or 97

-- ui_cardspills.anm2 exposes card faces by Card ID through its CardFronts
-- animation, but rune-like objects and soul stones deliberately leave blank
-- frames there. Those IDs use the same native HUD actors as the game itself.
local nativeCardResources = {
  [32]="gfx/005.303_rune1.anm2",
  [33]="gfx/005.303_rune1.anm2",
  [34]="gfx/005.303_rune1.anm2",
  [35]="gfx/005.303_rune1.anm2",
  [36]="gfx/005.304_rune2.anm2",
  [37]="gfx/005.304_rune2.anm2",
  [38]="gfx/005.304_rune2.anm2",
  [39]="gfx/005.304_rune2.anm2",
  [40]="gfx/005.304_rune2.anm2",
  [41]="gfx/005.307_blackrune.anm2",
  [55]="gfx/005.313_rune shard.anm2",
  [78]="gfx/005.300.15_cracked key.anm2",
  [80]="gfx/005.300.17_unus card.anm2",
  [81]="gfx/005.300.18_soul of isaac.anm2",
  [82]="gfx/005.300.19_soul of magdalene.anm2",
  [83]="gfx/005.300.20_soul of cain.anm2",
  [84]="gfx/005.300.21_soul of judas.anm2",
  [85]="gfx/005.300.22_soul of blue baby.anm2",
  [86]="gfx/005.300.23_soul of eve.anm2",
  [87]="gfx/005.300.24_soul of samson.anm2",
  [88]="gfx/005.300.25_soul of azazel.anm2",
  [89]="gfx/005.300.26_soul of lazarus.anm2",
  [90]="gfx/005.300.27_soul of eden.anm2",
  [91]="gfx/005.300.28_soul of the lost.anm2",
  [92]="gfx/005.300.29_soul of lilith.anm2",
  [93]="gfx/005.300.30_soul of the keeper.anm2",
  [94]="gfx/005.300.31_soul of apollyon.anm2",
  [95]="gfx/005.300.32_soul of the forgotten.anm2",
  [96]="gfx/005.300.33_soul of bethany.anm2",
  [97]="gfx/005.300.34_soul of jacob.anm2"
}

-- World entity actors are read from the active game resources so texture
-- replacement mods remain visible. baseSize and offsets normalize actors whose
-- world pivots are larger or lower than regular 32x32 pickups.
local nativePickupResources = {
  ["10:8"]={path="gfx/005.018_heart (halfsoul).anm2", animation="Idle", frame=0, baseSize=32},
  ["10:7"]={path="gfx/005.017_goldheart.anm2", animation="Idle", frame=0, baseSize=32},
  ["10:9"]={path="gfx/005.020_scared heart.anm2", animation="Idle", frame=0, baseSize=32},
  ["10:11"]={path="gfx/005.01a_bone heart.anm2", animation="Idle", frame=0, baseSize=32},
  ["10:12"]={path="gfx/005.01b_rotten heart.anm2", animation="Idle", frame=0, baseSize=32},
  ["20:5"]={path="gfx/005.026_lucky penny.anm2", animation="Idle", frame=0, baseSize=32},
  ["20:6"]={path="gfx/005.025_sticky nickel.anm2", animation="Idle", frame=0, baseSize=32},
  ["20:7"]={path="gfx/005.027_golden penny.anm2", animation="Idle", frame=0, baseSize=32},
  ["30:4"]={path="gfx/005.034_chargedkey.anm2", animation="Idle", frame=0, baseSize=32},
  ["40:4"]={path="gfx/005.043_golden bomb.anm2", animation="Idle", frame=0, baseSize=32},
  ["56:0"]={path="gfx/005.056_wooden chest.anm2", animation="Idle", frame=0, baseSize=48, offsetY=4},
  ["57:0"]={path="gfx/005.057_mega chest.anm2", animation="Idle", frame=0, baseSize=80, offsetY=6},
  ["58:0"]={path="gfx/005.058_haunted chest.anm2", animation="Idle", frame=0, baseSize=48, offsetY=4},
  ["69:2"]={path="gfx/005.069_black sack.anm2", animation="Idle", frame=0, baseSize=32},
  ["70:14"]={path="gfx/005.084_pill gold-gold.anm2", animation="Idle", frame=0, baseSize=32},
  ["70:2049"]={path="gfx/005.071_horse pill blue-blue.anm2", animation="Idle", frame=0, baseSize=40},
  ["90:4"]={path="gfx/005.090_golden battery.anm2", animation="Idle", frame=0, baseSize=32}
}

local nativeSlotResources = {
  [15]={path="gfx/006.015_hell game.anm2", animation="Idle", frame=0, baseSize=64, offsetY=10},
  [16]={path="gfx/006.016_crane game.anm2", animation="Idle", frame=0, baseSize=64, offsetY=10},
  [17]={path="gfx/006.017_confessional.anm2", animation="Idle", frame=0, baseSize=64, offsetY=8},
  [18]={path="gfx/006.018_rotten beggar.anm2", animation="Idle", frame=0, baseSize=64, offsetY=10}
}

local nativeGridResources = {
  ["14:11"]={path="gfx/grid/grid_poop.anm2", animation="State1", frame=5,
    spritesheet="gfx/grid/grid_poop_charming.png", baseSize=32},
  ["27:0"]={path="gfx/grid/grid_rock.anm2", animation="foolsgold", frame=0,
    baseSize=32}
}

local cardFrontSprite
local cardSpillSprite
local nativeCardSprites = {}
local backdropSprite
local paperSprite

local function cacheKey(reward)
  return table.concat({ reward.kind, tostring(reward.id or reward.enum or ""),
    tostring(reward.variant or ""), tostring(reward.subtype or ""),
    tostring(reward.gridType or "") }, ":")
end

local function itemSprite(reward)
  local config = Rewards.config(reward)
  if not config or type(config.GfxFileName) ~= "string" or config.GfxFileName == "" then return nil end
  local sprite = Sprite()
  -- The world collectible animation has a built-in hovering offset. Use our
  -- neutral 32x32 frame so menu icons are centered consistently.
  sprite:Load("gfx/ui/achievement_tracker_ui.anm2", false)
  sprite:ReplaceSpritesheet(3, config.GfxFileName)
  sprite:LoadGraphics()
  sprite:SetFrame("RewardItem", 0)
  return { sprite=sprite, baseSize=32 }
end

local function taintedEdenOverlay()
  local ok, sprite = pcall(function()
    local edenHead = Sprite()
    edenHead:Load("gfx/ui/stage/eden_b_head.anm2", true)
    if not edenHead:IsLoaded() then return nil end
    edenHead:SetFrame(edenHead:GetDefaultAnimation(), 0)
    return edenHead
  end)
  return ok and sprite or nil
end

local function characterSprite(reward)
  local filename = characterPortraits[reward.id]
  if not filename then return nil end
  local ok, entry = pcall(function()
    local tall = TALL_CHARACTER_PORTRAITS[reward.id] == true
    local sprite = Sprite()
    sprite:Load("gfx/ui/achievement_tracker_ui.anm2", false)
    sprite:ReplaceSpritesheet(4, "gfx/ui/stage/" .. filename)
    sprite:LoadGraphics()
    sprite:SetFrame(tall and "RewardPortraitTall" or "RewardPortrait", 0)
    if not sprite:IsLoaded() then return nil end

    local overlay = reward.id == TAINTED_EDEN and taintedEdenOverlay() or nil
    return { sprite=sprite, overlay=overlay, baseSize=tall and 166 or 144 }
  end)
  return ok and entry or nil
end

local function fallbackSprite(reward)
  local sprite = Sprite()
  sprite:Load("gfx/ui/achievement_tracker_ui.anm2", true)
  sprite:SetFrame("FallbackIcon", fallbackFrames[reward.kind] or fallbackFrames.other)
  return { sprite=sprite, baseSize=16 }
end

local function getCardFrontSprite()
  if cardFrontSprite ~= nil then return cardFrontSprite or nil end
  local ok, sprite = pcall(function()
    local loaded = Sprite()
    loaded:Load("gfx/ui/ui_cardfronts.anm2", true)
    return loaded:IsLoaded() and loaded or nil
  end)
  cardFrontSprite = ok and sprite or false
  return cardFrontSprite or nil
end

local function getCardSpillSprite()
  if cardSpillSprite ~= nil then return cardSpillSprite or nil end
  local ok, sprite = pcall(function()
    local loaded = Sprite()
    loaded:Load("gfx/ui/ui_cardspills.anm2", true)
    return loaded:IsLoaded() and loaded or nil
  end)
  cardSpillSprite = ok and sprite or false
  return cardSpillSprite or nil
end

local function getNativeCardSprite(path)
  if nativeCardSprites[path] ~= nil then return nativeCardSprites[path] or nil end
  local ok, sprite = pcall(function()
    local loaded = Sprite()
    loaded:Load(path, true)
    return loaded:IsLoaded() and loaded or nil
  end)
  nativeCardSprites[path] = ok and sprite or false
  return nativeCardSprites[path] or nil
end

local function validFrame(sprite, animation, frame)
  if not sprite or not sprite:IsLoaded() or type(animation) ~= "string"
    or animation == "" then return false end
  local ok, valid = pcall(function()
    sprite:SetFrame(animation, frame)
    return sprite:GetAnimation() == animation and sprite:GetFrame() == frame
  end)
  return ok and valid == true
end

local function nativeEntityEntry(resource)
  if not resource then return nil end
  local ok, entry = pcall(function()
    local sprite = Sprite()
    sprite:Load(resource.path, false)
    if resource.spritesheet then
      sprite:ReplaceSpritesheet(0, resource.spritesheet)
    end
    sprite:LoadGraphics()
    if not validFrame(sprite, resource.animation, resource.frame) then return nil end
    return {
      sprite=sprite, animation=resource.animation, frame=resource.frame,
      baseSize=resource.baseSize or 32,
      offsetX=resource.offsetX or 0, offsetY=resource.offsetY or 0
    }
  end)
  return ok and entry or nil
end

local function worldEntityEntry(reward)
  if reward.kind == "pickup" then
    return nativeEntityEntry(nativePickupResources[
      tostring(reward.variant) .. ":" .. tostring(reward.subtype)])
  end
  if reward.kind == "slot" then
    return nativeEntityEntry(nativeSlotResources[reward.variant])
  end
  if reward.kind == "grid" then
    return nativeEntityEntry(nativeGridResources[
      tostring(reward.gridType) .. ":" .. tostring(reward.variant)])
  end
  return nil
end

local function setCardSpillFrame(sprite, frame)
  if not sprite or not sprite:IsLoaded() or type(frame) ~= "number" then return false end
  local ok, valid = pcall(function()
    -- CardFronts declares only 78 animation frames, while its face layer stores
    -- later cards (notably Queen of Hearts) at their actual Card IDs. Pin the
    -- animation itself to frame zero and select the face directly on layer zero.
    sprite:SetFrame("CardFronts", 0)
    sprite:SetLayerFrame(0, frame)
    return sprite:GetAnimation() == "CardFronts" and sprite:GetFrame() == 0
  end)
  return ok and valid == true
end

local function cardEntry(reward)
  local configOk, config = pcall(Rewards.config, reward)
  if not configOk then config = nil end
  local hudAnimation = config and config.HudAnim
  if type(hudAnimation) == "string" and hudAnimation ~= "" then
    local sprite = getCardFrontSprite()
    if validFrame(sprite, hudAnimation, 0) then
      return { sprite=sprite, animation=hudAnimation, frame=0, baseSize=32 }
    end
  end

  -- Repentance returns a blank HudAnim for vanilla cards, so resolve their
  -- native HUD actor explicitly. Resource replacements still flow through
  -- because every sprite is loaded from the active game's virtual filesystem.
  if type(reward.id) == "number" and reward.id >= 1
    and reward.id <= VANILLA_CARD_MAX then
    local path = nativeCardResources[reward.id]
    if path then
      local sprite = getNativeCardSprite(path)
      if validFrame(sprite, "HUD", 0) then
        return { sprite=sprite, animation="HUD", frame=0, baseSize=32 }
      end
    else
      local sprite = getCardSpillSprite()
      -- Frame zero is an empty sentinel; the remaining layer frames are keyed
      -- directly by the vanilla Card ID rather than by ID minus one.
      if setCardSpillFrame(sprite, reward.id) then
        return {
          sprite=sprite, animation="CardFronts", frame=0,
          layer=0, layerFrame=reward.id, baseSize=24
        }
      end
    end
  end
  return nil
end

local function cached(reward)
  local key = cacheKey(reward)
  if cache[key] ~= nil then return cache[key] or nil end
  local entry
  if reward.kind == "collectible" or reward.kind == "trinket" then entry = itemSprite(reward) end
  if reward.kind == "character" then entry = characterSprite(reward) end
  if reward.kind == "card" then entry = cardEntry(reward) end
  if reward.kind == "pickup" or reward.kind == "slot" or reward.kind == "grid" then
    entry = worldEntityEntry(reward)
  end
  if not entry then entry = fallbackSprite(reward) end
  cache[key] = entry or false
  return entry
end

function RewardIcons.render(reward, x, y, size, tint)
  if not reward then return false end
  local entry = cached(reward)
  if not entry then return false end
  if entry.animation then entry.sprite:SetFrame(entry.animation, entry.frame) end
  if entry.layerFrame then entry.sprite:SetLayerFrame(entry.layer, entry.layerFrame) end
  local scale = size / entry.baseSize
  entry.sprite.Scale = Vector(scale, scale)
  entry.sprite.Color = tint or Color(1, 1, 1, 1)
  local position = Vector(x + (entry.offsetX or 0) * scale,
    y + (entry.offsetY or 0) * scale)
  entry.sprite:Render(position)
  if entry.overlay then
    entry.overlay.Scale = entry.sprite.Scale
    entry.overlay.Color = entry.sprite.Color
    entry.overlay:Render(position)
  end
  return true
end

function RewardIcons.renderPaper(panelX, panelY, panelWidth, panelHeight)
  if not backdropSprite then
    backdropSprite = Sprite()
    backdropSprite:Load("gfx/ui/achievement_tracker_ui.anm2", true)
    backdropSprite:Play("Backdrop", true)
  end
  if not paperSprite then
    paperSprite = Sprite()
    paperSprite:Load("gfx/ui/achievement_tracker_ui.anm2", true)
    paperSprite:Play("Paper", true)
  end
  local center = Vector(panelX + panelWidth / 2, panelY + panelHeight / 2)
  backdropSprite.Scale = Vector((panelWidth + 8) / 120, (panelHeight + 8) / 68)
  backdropSprite:Render(center + Vector(2, 2))
  paperSprite.Scale = Vector(panelWidth / 263, panelHeight / 176)
  paperSprite:Render(center)
end

function RewardIcons.clear()
  cache = {}
  cardFrontSprite = nil
  cardSpillSprite = nil
  nativeCardSprites = {}
  backdropSprite = nil
  paperSprite = nil
end

return RewardIcons
