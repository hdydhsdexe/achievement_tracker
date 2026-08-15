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

local cardSprite
local backdropSprite
local paperSprite

local function cacheKey(reward)
  return reward.kind .. ":" .. tostring(reward.id or reward.enum or "fallback")
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

local function cached(reward)
  local key = cacheKey(reward)
  if cache[key] ~= nil then return cache[key] or nil end
  local entry
  if reward.kind == "collectible" or reward.kind == "trinket" then entry = itemSprite(reward) end
  if reward.kind == "character" then entry = characterSprite(reward) end
  if not entry and reward.kind ~= "card" then entry = fallbackSprite(reward) end
  cache[key] = entry or false
  return entry
end

local function getCardSprite()
  if cardSprite then return cardSprite end
  cardSprite = Sprite()
  cardSprite:Load("gfx/ui/ui_cardspills.anm2", true)
  -- Vanilla card-spill frames use a top-left pivot; normalize them to the
  -- center-based contract shared by collectibles and fallback icons.
  cardSprite.Offset = Vector(-8, -10)
  return cardSprite
end

function RewardIcons.render(reward, x, y, size, tint)
  if not reward then return false end
  if reward.kind == "card" and reward.id and reward.id >= 1 and reward.id <= 97 then
    local sprite = getCardSprite()
    sprite:SetFrame("Cards", reward.id - 1)
    sprite.Scale = Vector(size / 20, size / 20)
    sprite.Color = tint or Color(1, 1, 1, 1)
    sprite:Render(Vector(x, y))
    return true
  end
  local entry = cached(reward)
  if not entry then return false end
  entry.sprite.Scale = Vector(size / entry.baseSize, size / entry.baseSize)
  entry.sprite.Color = tint or Color(1, 1, 1, 1)
  entry.sprite:Render(Vector(x, y))
  if entry.overlay then
    entry.overlay.Scale = entry.sprite.Scale
    entry.overlay.Color = entry.sprite.Color
    entry.overlay:Render(Vector(x, y))
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
  cardSprite = nil
  backdropSprite = nil
  paperSprite = nil
end

return RewardIcons
