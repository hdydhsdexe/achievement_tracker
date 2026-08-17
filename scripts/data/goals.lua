local Rewards = require("scripts.core.rewards")
local CompletionMarks = require("scripts.core.completion_marks")
local goals = {}
for _, goal in ipairs(require("scripts.data.achievements_1_50")) do table.insert(goals, goal) end
for _, goal in ipairs(require("scripts.data.achievements_51_100")) do table.insert(goals, goal) end
for _, goal in ipairs(require("scripts.data.achievements_101_200")) do table.insert(goals, goal) end
for _, goal in ipairs(require("scripts.data.achievements_201_300")) do table.insert(goals, goal) end
for _, goal in ipairs(require("scripts.data.achievements_301_400")) do table.insert(goals, goal) end
for _, goal in ipairs(require("scripts.data.achievements_401_500")) do table.insert(goals, goal) end
for _, goal in ipairs(require("scripts.data.achievements_501_600")) do table.insert(goals, goal) end
for _, goal in ipairs(require("scripts.data.achievements_601_641")) do table.insert(goals, goal) end

-- Progress metadata lives separately from localized copy so counter goals can be
-- extended without coupling sensors to display text.
local trackingMetadata = {
  achievement_326 = { deadline=1200, thresholds={300,120,30} },
  achievement_327 = { sensor="no_pickups" },
  achievement_330 = { progressKey="items", target=50 },
  achievement_386 = { progressKey="gulp", target=5 }
}

-- Generated catalog rows only encode collectibles, trinkets, and cards. These
-- overrides describe unlockable world entities without editing generated data.
local rewardOverrides = {
  achievement_33 = {kind="pickup", variant=10, subtype=8},
  achievement_224 = {kind="pickup", variant=10, subtype=7},
  achievement_226 = {kind="pickup", variant=40, subtype=4},
  achievement_240 = {kind="pickup", variant=20, subtype=6},
  achievement_242 = {kind="pickup", variant=20, subtype=5},
  achievement_328 = {kind="pickup", variant=10, subtype=9},
  achievement_333 = {kind="pickup", variant=30, subtype=4},
  achievement_391 = {kind="pickup", variant=10, subtype=11},
  achievement_411 = {kind="pickup", variant=10, subtype=12},
  achievement_601 = {kind="pickup", variant=57, subtype=0},
  achievement_603 = {kind="pickup", variant=70, subtype=14},
  achievement_604 = {kind="pickup", variant=69, subtype=2},
  achievement_605 = {kind="grid", gridType=14, variant=11},
  achievement_606 = {kind="pickup", variant=70, subtype=2049},
  achievement_607 = {kind="slot", variant=16},
  achievement_608 = {kind="slot", variant=15},
  achievement_609 = {kind="pickup", variant=56, subtype=0},
  achievement_611 = {kind="pickup", variant=58, subtype=0},
  achievement_612 = {kind="grid", gridType=27, variant=0},
  achievement_613 = {kind="pickup", variant=20, subtype=7},
  achievement_614 = {kind="slot", variant=18},
  achievement_615 = {kind="pickup", variant=90, subtype=4},
  achievement_616 = {kind="slot", variant=17}
}
local CHALLENGE_ACHIEVEMENT_IDS = {
  89,90,91,92,93,94,120,96,97,98,99,100,60,63,101,
  102,103,104,62,95,224,225,226,227,228,229,230,231,232,233,
  331,332,333,334,335,517,518,519,520,521,522,531,532,533,538
}
local challengeGoals = {}
local challengeIdsByGoal = {}
for challengeId, achievementId in ipairs(CHALLENGE_ACHIEVEMENT_IDS) do
  challengeIdsByGoal["achievement_" .. achievementId] = challengeId
end
for _, goal in ipairs(goals) do
  local metadata = trackingMetadata[goal.id]
  if metadata then
    for key, value in pairs(metadata) do goal[key] = value end
  end
  local challengeId = challengeIdsByGoal[goal.id]
  if challengeId then
    goal.challengeId = challengeId
    challengeGoals[challengeId] = goal
  end
  local override = rewardOverrides[goal.id]
  if override then goal.reward = override end
  goal.reward = Rewards.display(goal)
end
CompletionMarks.attach(goals)

local Catalog = { goals = goals }

function Catalog.get(id)
  for _, goal in ipairs(goals) do if goal.id == id then return goal end end
  return nil
end

function Catalog.isTrackable(id)
  local goal = Catalog.get(id)
  return goal ~= nil and goal.achievementId ~= nil
end

function Catalog.challengeGoal(challengeId)
  return challengeGoals[tonumber(challengeId) or 0]
end

function Catalog.isCompletable(goal, challengeId)
  challengeId = tonumber(challengeId) or 0
  if challengeId == 0 then return goal.challengeId == nil end
  return goal.challengeId == challengeId
end

function Catalog.text(goal, language)
  return goal[language] or goal.en
end

local SEARCH_KIND_ALIASES = {
  collectible="item collectible active passive familiar",
  trinket="trinket",
  card="card rune soul",
  pickup="pickup consumable heart coin key bomb pill chest sack battery 掉落物",
  slot="machine beggar slot arcade 机器 乞丐",
  grid="grid obstacle poop rock 大便 石头 愚人金",
  character="character player",
  area="area location floor room route",
  challenge="challenge",
  feature="feature mechanic",
  other="other reward"
}

local function normalizeSearch(value)
  local normalized = string.lower(tostring(value or ""))
  normalized = string.gsub(normalized, "[%c%p%s]+", " ")
  normalized = string.gsub(normalized, "^%s+", "")
  normalized = string.gsub(normalized, "%s+$", "")
  return normalized
end

local function compactSearch(value)
  return string.gsub(normalizeSearch(value), "%s+", "")
end

local function subsequenceScore(haystack, needle)
  if needle == "" then return 0 end
  local position, skipped = 1, 0
  for index = 1, #needle do
    local found = string.find(haystack, string.sub(needle, index, index), position, true)
    if not found then return nil end
    skipped = skipped + found - position
    position = found + 1
  end
  return skipped
end

local function searchFields(goal)
  local reward = goal.reward or {}
  return {
    { value=goal.zh and goal.zh.name, priority=0 },
    { value=goal.en and goal.en.name, priority=0 },
    { value=goal.zh and goal.zh.detail, priority=100 },
    { value=goal.en and goal.en.detail, priority=100 },
    { value=table.concat({ goal.id or "", tostring(goal.achievementId or "") }, " "),
      priority=200 },
    { value=table.concat({ goal.category or "", reward.kind or "",
        SEARCH_KIND_ALIASES[reward.kind] or "", tostring(reward.id or ""),
        reward.enum or "", tostring(reward.variant or ""),
        tostring(reward.subtype or ""), tostring(reward.gridType or "") }, " "),
      priority=300 }
  }
end

local function fieldScore(field, term)
  local normalized = normalizeSearch(field.value)
  if normalized == "" then return nil end
  if normalized == term then return field.priority end
  for word in string.gmatch(normalized, "[^%s]+") do
    if word == term then return 1000 + field.priority end
  end
  for word in string.gmatch(normalized, "[^%s]+") do
    if string.sub(word, 1, #term) == term then
      return 2000 + field.priority + #word - #term
    end
  end
  local start = string.find(normalized, term, 1, true)
  if start then return 3000 + field.priority + start - 1 end
  local gap = subsequenceScore(compactSearch(normalized), compactSearch(term))
  if gap then return 4000 + field.priority + gap end
  return nil
end

local function queryTerms(query)
  local terms = {}
  for term in string.gmatch(normalizeSearch(query), "[^%s]+") do
    table.insert(terms, term)
  end
  return terms
end

function Catalog.search(query)
  local results, terms = {}, queryTerms(query)
  for catalogIndex, goal in ipairs(goals) do
    local totalScore, matched = 0, true
    for _, term in ipairs(terms) do
      local best
      for _, field in ipairs(searchFields(goal)) do
        local score = fieldScore(field, term)
        if score and (not best or score < best) then best = score end
      end
      if not best then matched = false; break end
      totalScore = totalScore + best
    end
    if matched then
      table.insert(results, { goal=goal, score=totalScore, catalogIndex=catalogIndex })
    end
  end
  table.sort(results, function(left, right)
    if left.score ~= right.score then return left.score < right.score end
    return left.catalogIndex < right.catalogIndex
  end)
  return results
end

return Catalog
