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
