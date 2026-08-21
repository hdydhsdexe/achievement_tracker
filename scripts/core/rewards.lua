local Rewards = {}

local validKinds = {
  collectible=true, trinket=true, card=true,
  pickup=true, slot=true, grid=true,
  character=true, monster=true, area=true, challenge=true, feature=true, other=true
}

local standardKinds = { collectible=true, trinket=true, card=true }
local filterKinds = {
  collectible="collectible", trinket="trinket", card="card",
  pickup="pickup", slot="world", grid="world",
  character="character", monster="monster", area="area",
  challenge="challenge", feature="feature", other="other"
}

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
  if observation and observation.kind == "boss" then return "monster" end
  if observation and (observation.kind == "stage" or observation.kind == "stage_type") then return "area" end
  if goal and goal.category and goal.category ~= "achievement" then return "feature" end
  return "other"
end

function Rewards.display(goal)
  local reward = goal and goal.reward
  if reward and validKinds[reward.kind] then
    return {
      kind=reward.kind, id=Rewards.resolveId(reward), enum=reward.enum,
      variant=reward.variant, subtype=reward.subtype, gridType=reward.gridType,
      achievementId=goal.achievementId
    }
  end
  local kind = inferredKind(goal)
  local observation = goal and goal.observation
  local id
  if kind == "character" and observation and type(observation.values) == "table"
    and type(observation.values[1]) == "number" then
    id = observation.values[1]
  end
  return { kind=kind, id=id, achievementId=goal and goal.achievementId }
end

function Rewards.filterKind(reward)
  return reward and filterKinds[reward.kind] or "other"
end

function Rewards.isValidKind(kind) return validKinds[kind] == true end

return Rewards
