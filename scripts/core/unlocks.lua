local Unlocks = {}

-- Vanilla Repentance cannot query secrets directly. These goals can still be
-- inferred safely because each one unlocks a unique item, trinket, or card.
local rewards = {
  zip = { kind="card", enum="CARD_ACE_OF_DIAMONDS" },
  its_the_key = { kind="card", enum="CARD_ACE_OF_SPADES" },
  marbles = { kind="collectible", enum="COLLECTIBLE_MARBLES" },
  huge_growth = { kind="card", enum="CARD_HUGE_GROWTH" },
  u_broke_it = { kind="trinket", enum="TRINKET_BUTTER" },
  daily_streak = { kind="collectible", enum="COLLECTIBLE_BROKEN_MODEM" }
}

local function rewardAvailable(reward)
  local config = Isaac.GetItemConfig()
  local entry
  if reward.kind == "collectible" then
    local id = CollectibleType and CollectibleType[reward.enum]
    if not id then return nil end
    entry = config:GetCollectible(id)
  elseif reward.kind == "trinket" then
    local id = TrinketType and TrinketType[reward.enum]
    if not id then return nil end
    entry = config:GetTrinket(id)
  elseif reward.kind == "card" then
    local id = Card and Card[reward.enum]
    if not id then return nil end
    entry = config:GetCard(id)
  end
  if not entry or not entry.IsAvailable then return nil end
  return entry:IsAvailable()
end

function Unlocks.isCompleted(goal)
  local reward = goal and rewards[goal.id]
  if not reward then return nil end
  local ok, available = pcall(rewardAvailable, reward)
  return ok and available == true or nil
end

function Unlocks.scan(goals)
  local completed = {}
  for _, goal in ipairs(goals) do
    if Unlocks.isCompleted(goal) then completed[goal.id] = true end
  end
  return completed
end

return Unlocks
