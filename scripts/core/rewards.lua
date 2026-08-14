local Rewards = {}

local validKinds = {
  collectible=true, trinket=true, card=true,
  character=true, area=true, challenge=true, feature=true, other=true
}

local standardKinds = { collectible=true, trinket=true, card=true }

local function enumTable(kind)
  if kind == "collectible" then return CollectibleType end
  if kind == "trinket" then return TrinketType end
  if kind == "card" then return Card end
  return nil
end

function Rewards.resolveId(reward)
  if not reward then return nil end
  if type(reward.id) == "number" then return reward.id end
  if type(reward.enum) ~= "string" then return nil end
  local values = enumTable(reward.kind)
  return values and values[reward.enum] or nil
end

function Rewards.config(reward)
  if not reward or not standardKinds[reward.kind] then return nil end
  local id = Rewards.resolveId(reward)
  if not id then return nil end
  local config = Isaac.GetItemConfig()
  if reward.kind == "collectible" then return config:GetCollectible(id) end
  if reward.kind == "trinket" then return config:GetTrinket(id) end
  if reward.kind == "card" then return config:GetCard(id) end
  return nil
end

local function inferredKind(goal)
  local observation = goal and goal.observation
  if observation and observation.kind == "player" then return "character" end
  if observation and (observation.kind == "stage" or observation.kind == "stage_type") then return "area" end
  local english = goal and goal.en and goal.en.detail or ""
  if string.find(string.lower(english), "challenge #", 1, true) then return "challenge" end
  if goal and goal.category and goal.category ~= "achievement" then return "feature" end
  return "other"
end

function Rewards.display(goal)
  local reward = goal and goal.reward
  if reward and validKinds[reward.kind] then
    return { kind=reward.kind, id=Rewards.resolveId(reward), enum=reward.enum }
  end
  return { kind=inferredKind(goal) }
end

function Rewards.filterKind(reward)
  if reward and standardKinds[reward.kind] then return reward.kind end
  return "other"
end

function Rewards.isValidKind(kind) return validKinds[kind] == true end

return Rewards
