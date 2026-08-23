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

-- Shared persistent counters are declared once. Achievement metadata only
-- selects a source and its milestone, keeping localized wording independent.
local greedDonationEvents = {}
for eventId = 159, 172 do greedDonationEvents[#greedDonationEvents + 1] = eventId end
greedDonationEvents[#greedDonationEvents + 1] = 212
for eventId = 385, 403 do greedDonationEvents[#greedDonationEvents + 1] = eventId end

local longTermSources = {
  momsHeart={eventIds={1}, observable=true}, rocks={eventIds={2}},
  tintedRocks={eventIds={3}}, poop={eventIds={5}}, deathCard={eventIds={7}, observable=true},
  arcades={eventIds={9}, observable=true}, deaths={eventIds={10}}, isaacKills={eventIds={11}, observable=true},
  shopkeepers={eventIds={12}}, satanKills={eventIds={13}, observable=true},
  shellGames={eventIds={14}}, angelDeals={eventIds={15}}, devilDeals={eventIds={16}},
  bloodMachine={eventIds={17}}, slotsBroken={eventIds={18}}, donation={eventIds={20}},
  hushKills={eventIds={158}, observable=true}, greedDonation={eventIds=greedDonationEvents, aggregate="sum"},
  dailiesPlayed={eventIds={190}}, dailyStreak={eventIds={192}}, dailiesWon={eventIds={193}},
  rainbowPoop={eventIds={194}}, batteries={eventIds={195}, observable=true}, cards={eventIds={196}, observable=true},
  purchases={eventIds={197}}, lockedChests={eventIds={198}}, openedWalls={eventIds={199}},
  bloodClot={eventIds={200}, observable=true}, rubberCement={eventIds={201}, observable=true}, beds={eventIds={202}},
  babyPlum={eventIds={493}, observable=true}, batteryBumKills={eventIds={494}},
  batteryBumPayouts={eventIds={495}},
  blueBabyCharacters={kind="completion_mark_count", mark="BLUE_BABY",
    playerTypes={0,1,2,3,4,5,6,7,8,9,10,13,14,15,16,18,19}}
}

local longTermMilestones = {
  momsHeart={{150,2},{8,3},{139,4},{33,5},{140,6},{141,7},{10,8},{11,9},
    {32,10},{234,10},{34,11},{342,11},{343,16},{344,21},{345,30}},
  isaacKills={{57,5},{68,10}}, satanKills={{78,5}}, hushKills={{407,3}}, babyPlum={{409,10}},
  tintedRocks={{28,10},{12,100}}, rocks={{85,100},{350,500}}, poop={{145,100}},
  rainbowPoop={{353,5}}, arcades={{26,10}}, deaths={{30,100}}, deathCard={{36,4}},
  shopkeepers={{61,20}}, shellGames={{64,100}}, angelDeals={{66,10},{380,25}},
  devilDeals={{142,20},{376,25},{383,50}}, bloodMachine={{147,30}}, slotsBroken={{148,30}},
  donation={{134,10},{151,20},{135,50},{152,100},{136,150},{153,200},{137,400},
    {154,600},{59,900},{138,999}},
  greedDonation={{242,2},{243,14},{244,33},{245,68},{246,111},{247,234},{248,439},
    {341,500},{249,666},{250,879},{275,999},{251,1000}},
  dailiesPlayed={{325,31}}, dailyStreak={{336,5}}, dailiesWon={{354,7}},
  batteries={{358,20}}, cards={{362,20}}, purchases={{364,50}}, lockedChests={{371,20}},
  openedWalls={{375,50}}, bloodClot={{377,10}}, rubberCement={{382,5}}, beds={{385,10}},
  batteryBumPayouts={{523,5}}, batteryBumKills={{545,10}},
  blueBabyCharacters={{346,3},{347,6}}
}
for sourceKey, milestones in pairs(longTermMilestones) do
  local source = longTermSources[sourceKey]
  for _, milestone in ipairs(milestones) do
    trackingMetadata["achievement_" .. milestone[1]] = {
      longTerm={source=source, sourceKey=sourceKey, target=milestone[2]}
    }
  end
end

-- Generated catalog rows only encode standard reward types. These overrides
-- describe non-standard unlockable rewards without editing generated data.
local rewardOverrides = {
  -- Non-standard unlocks use explicit reward semantics. Completion-condition
  -- text is intentionally not used because it describes how to unlock the
  -- reward, not what the reward is.
  achievement_142 = {kind="monster"},
  achievement_155 = {kind="monster"},
  achievement_346 = {kind="monster"},
  achievement_347 = {kind="monster"},
  achievement_348 = {kind="monster"},
  achievement_234 = {kind="area"},
  achievement_320 = {kind="area"},
  achievement_342 = {kind="area"},
  achievement_343 = {kind="area"},
  achievement_344 = {kind="area"},
  achievement_345 = {kind="area"},
  achievement_406 = {kind="area"},
  achievement_407 = {kind="area"},
  achievement_412 = {kind="area"},
  achievement_413 = {kind="area"},
  achievement_414 = {kind="area"},
  achievement_635 = {kind="area"},
  achievement_157 = {kind="challenge"},
  achievement_158 = {kind="challenge"},
  achievement_160 = {kind="challenge"},
  achievement_163 = {kind="challenge"},
  achievement_166 = {kind="challenge"},
  achievement_265 = {kind="challenge"},
  achievement_266 = {kind="challenge"},
  achievement_269 = {kind="challenge"},
  achievement_270 = {kind="challenge"},
  achievement_272 = {kind="challenge"},
  achievement_273 = {kind="challenge"},
  achievement_274 = {kind="challenge"},
  achievement_277 = {kind="challenge"},
  achievement_278 = {kind="challenge"},
  achievement_279 = {kind="challenge"},
  achievement_510 = {kind="challenge"},
  achievement_511 = {kind="challenge"},
  achievement_513 = {kind="challenge"},
  achievement_514 = {kind="challenge"},
  achievement_515 = {kind="challenge"},
  achievement_516 = {kind="challenge"},
  achievement_151 = {kind="feature"},
  achievement_152 = {kind="feature"},
  achievement_153 = {kind="feature"},
  achievement_154 = {kind="feature"},
  achievement_178 = {kind="feature"},
  achievement_191 = {kind="feature"},
  achievement_243 = {kind="feature"},
  achievement_246 = {kind="feature"},
  achievement_247 = {kind="feature"},
  achievement_275 = {kind="feature"},
  achievement_323 = {kind="feature"},
  achievement_337 = {kind="feature"},
  achievement_341 = {kind="feature"},
  achievement_593 = {kind="feature"},
  achievement_617 = {kind="feature"},
  achievement_638 = {kind="feature"},
  achievement_639 = {kind="feature"},
  achievement_640 = {kind="feature"},
  achievement_641 = {kind="feature"},
  achievement_227 = {kind="pickup"},
  achievement_228 = {kind="pickup"},
  achievement_332 = {kind="pickup"},
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
for _, goal in ipairs(goals) do
  if goal.longTerm and goal.longTerm.source.kind == "completion_mark_count" then
    goal.completionRequirements = nil
  end
end

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
  collectible="item collectible active passive familiar 道具",
  trinket="trinket 饰品",
  card="card rune soul 卡牌 符文 魂石",
  pickup="pickup consumable heart coin key bomb pill chest sack battery 掉落物",
  slot="machine beggar slot arcade scenery world 机器 乞丐 场景 机器与场景",
  grid="grid obstacle poop rock scenery world 大便 石头 愚人金 场景 机器与场景",
  character="character player 人物 角色",
  monster="monster enemy boss 怪物 敌人 头目",
  area="area location floor room route 地点 区域 楼层 房间 路线",
  challenge="challenge 挑战",
  feature="feature mechanic mode 机制 功能 模式",
  other="other reward 其他"
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
